#!/usr/bin/env python
# -*- coding: utf8 -*-
"""
Parses event XML files (ShakeMap) and plots PGAs in mg on a map.

(c) 2017-2023 - Claudio Satriano <satriano@ipgp.fr>
                Félix Léger <leger@ipgp.fr>
                Jean-Marie Saurel <saurel@ipgp.fr>
"""
import os
from glob import glob
import argparse
import contextlib
from configparser import ConfigParser
from io import StringIO
from xml.dom import minidom
from datetime import datetime
import re
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.patheffects as path_effects
from mpl_toolkits.axes_grid1.axes_divider import make_axes_locatable
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from cartopy.io.img_tiles import GoogleWTS
from adjustText import adjust_text
from pyproj import Geod
import pdfkit
from pdf2image import convert_from_path
mpl.use('agg')  # NOQA
script_path = os.path.dirname(os.path.realpath(__file__))
import sys
sys.path.append("/etc/webobs.d/../CODE/python/superprocs/")
from wolib.config import read_config


class StamenTerrain(GoogleWTS):
    """
    Retrieves Stamen Terrain tiles from stadiamaps.com.
    """
    def __init__(self,
                 apikey,
                 cache=False):
        super().__init__(cache=cache, desired_tile_form="RGBA")
        self.apikey = apikey

    def _image_url(self, tile):
        x, y, z = tile
        return (
            'http://tiles.stadiamaps.com/tiles/stamen_terrain_background/'
            f'{z}/{x}/{y}.png?api_key={self.apikey}'
        )


class PgaMap(object):
    """Class for creating a PGA map report."""

    def __init__(self):
        """Initialize."""
        self.conf = None
        self.lon0 = None
        self.lon1 = None
        self.lat0 = None
        self.lat1 = None
        self.event = None
        self.attributes = None
        self.out_path = None
        self.fileprefix = None
        self.basename = None
        # markers for soil conditions
        self.markers = {'R': '^', 'S': 'o', 'U': 's'}
        self.legend_loc = None
        self.colorbar_bcsf = None
        self.debug = None
        self.copyright = None
        self.copyright2 = None
        self.logo_file = None
        self.logo2_file = None

    def parse_config(self, config_file, wo_root_code):
        """Parse config file."""
        self.conf = read_config(config_file)
        self.conf['soil_conditions'] = False
        self.lon0 = float(self.conf['MAP_XYLIM'].split(',')[0])
        self.lon1 = float(self.conf['MAP_XYLIM'].split(',')[1])
        self.lat0 = float(self.conf['MAP_XYLIM'].split(',')[2])
        self.lat1 = float(self.conf['MAP_XYLIM'].split(',')[3])
        legend_locations = {
            'LL': 'lower left',
            'LR': 'lower right',
            'UL': 'upper left',
            'UR': 'upper right',
        }
        self.legend_loc = legend_locations[self.conf['MAP_LEGEND_LOC']]
        try:
            self.colorbar_bcsf = bool(self.conf['COLORBAR_BCSF'])
        except Exception:
            self.colorbar_bcsf = False
        try:
            debug = self.conf['DEBUG']
            self.debug = re.search(
                '^(Y|YES|OK|ON|1)$', debug, re.IGNORECASE) is not None
        except KeyError:
            self.debug = False
        try:
            self.copyright = self.conf['COPYRIGHT']
        except KeyError:
            self.copyright = '(c) OVS-IPGP'
        self.copyright2 = self.conf.get('COPYRIGHT2')
        self.logo_file = self.conf.get('LOGO_FILE')
        self.logo2_file = self.conf.get('LOGO2_FILE')

    def parse_event_xml(self, xml_file):
        """Parse an event.xml file (input for ShakeMap)."""
        xmldoc = minidom.parse(xml_file)
        tag_earthquake = xmldoc.getElementsByTagName('earthquake')[0]
        event = {
            'year': int(tag_earthquake.attributes['year'].value),
            'month': int(tag_earthquake.attributes['month'].value),
            'day': int(tag_earthquake.attributes['day'].value),
            'hour': int(tag_earthquake.attributes['hour'].value),
            'minute': int(tag_earthquake.attributes['minute'].value),
            'second': int(tag_earthquake.attributes['second'].value),
        }
        event['time'] = datetime(
            event['year'], event['month'], event['day'],
            event['hour'], event['minute'], event['second'])
        event['timestr'] = event['time'].strftime('%Y%m%dT%H%M%S')
        locstring = tag_earthquake.attributes['locstring'].value
        event['id_sc3'] = locstring.split(' / ')[0]
        lat = tag_earthquake.attributes['lat'].value
        event['lat'] = float(lat)
        lon = tag_earthquake.attributes['lon'].value
        event['lon'] = float(lon)
        depth = tag_earthquake.attributes['depth'].value
        event['depth'] = float(depth)
        mag = tag_earthquake.attributes['mag'].value
        event['mag'] = float(mag)
        self.event = event

    def parse_event_dat_xml(self, xml_file, soil_conditions_file=None):
        """
        Parse an event_dat.xml file (input for ShakeMap).

        Creates a dictionary of channel attributes:
            lon, lat, pga, pgv, psa03, psa10, psa30
        """
        soil_conditions = {}
        if soil_conditions_file is not None:
            self.conf['soil_conditions'] = True
            soil_cnd_codes = {'soil': 'S', 'rock': 'R', 'NA': 'U'}
            for line in open(soil_conditions_file, 'r', encoding='utf8'):
                line = line.strip()
                if not line:
                    continue
                if line[0] == '#':
                    continue
                station, soil_cnd = line.split()
                soil_conditions[station] = soil_cnd_codes[soil_cnd]
        xmldoc = minidom.parse(xml_file)
        tag_stationlist = xmldoc.getElementsByTagName('stationlist')
        attributes = {}
        for slist in tag_stationlist:
            tag_station = slist.getElementsByTagName('station')
            for sta in tag_station:
                stname = sta.attributes['name'].value
                net = sta.attributes['netid'].value
                stla = float(sta.attributes['lat'].value)
                stlo = float(sta.attributes['lon'].value)
                tag_comp = sta.getElementsByTagName('comp')
                for comp in tag_comp:
                    cmp_name = comp.attributes['name'].value
                    cmp_id = '.'.join((net, stname, cmp_name))
                    # pga is in percent-g, transform it to milli-g
                    tag_acc = comp.getElementsByTagName('acc')[0]
                    pga = tag_acc.attributes['value'].value
                    # pgv is cm/s, transform it to m/s
                    tag_vel = comp.getElementsByTagName('vel')[0]
                    pgv = tag_vel.attributes['value'].value
                    # psa is in percent-g, transform it to milli-g
                    tag_psa03 = comp.getElementsByTagName('psa03')[0]
                    tag_psa10 = comp.getElementsByTagName('psa10')[0]
                    tag_psa30 = comp.getElementsByTagName('psa30')[0]
                    psa03 = tag_psa03.attributes['value'].value
                    psa10 = tag_psa10.attributes['value'].value
                    psa30 = tag_psa30.attributes['value'].value
                    try:
                        soil_cnd = soil_conditions[stname]
                    except KeyError:
                        soil_cnd = 'U'
                    cmp_attributes = {
                        'latitude': stla,
                        'longitude': stlo,
                        'pga': float(pga) * 10.0,
                        'pgv': float(pgv) / 100.0,
                        'psa03': float(psa03) * 10.0,
                        'psa10': float(psa10) * 10.0,
                        'psa30': float(psa30) * 10.0,
                        'soil_cnd': soil_cnd,
                    }
                    attributes[cmp_id] = cmp_attributes
        self.attributes = attributes

    def make_path(self, out_dir):
        """Create the output path."""
        event = self.event
        year = f"{event['year']:04d}"
        month = f"{event['month']:02d}"
        day = f"{event['day']:02d}"
        self.out_path = os.path.join(
            out_dir, year, month, day, event['id_sc3'])
        with contextlib.suppress(FileExistsError):
            os.makedirs(self.out_path)
        self.fileprefix = f"{event['timestr']}_{event['id_sc3']}"
        self.basename = os.path.join(self.out_path, self.fileprefix)

    def _colormap(self):
        if self.colorbar_bcsf:
            return self._colormap_bcsf()
        vmin = float(self.conf['COLORBAR_PGA_MIN_MAX'].split(',')[0])
        vmax = float(self.conf['COLORBAR_PGA_MIN_MAX'].split(',')[1])
        # Normalizing color scale
        norm = mpl.colors.Normalize(vmin=vmin, vmax=vmax)
        colors = [
            '#FFE39A',
            '#FFBE6A',
            '#FF875F',
            '#F3484E',
            '#E6004F',
            '#BD0064',
            '#7B0061'
        ]
        ncols = int(vmax-vmin)
        cmap = mpl.colors.LinearSegmentedColormap.from_list(
            'pga_cmap', colors, ncols)
        return norm, cmap, None

    def _colormap_bcsf(self):
        colors = [
            '#CCCCCC',
            '#70FFFF',
            '#00FF00',
            '#FCFF00',
            '#FFA800',
            '#FF0000',
            '#C60000',
            '#850000',
            '#A7009B',
            '#18009D'
        ]
        cmap = mpl.colors.LinearSegmentedColormap.from_list(
            'pga_cmap', colors, len(colors))
        # BCSF bounds (in %g)
        bounds = np.array(
            [0.02, 0.07, 0.3, 1.1, 4.7, 8.6, 16, 29, 52, 96, 100])
        # convert bounds to mg
        bounds *= 10.
        norm = mpl.colors.BoundaryNorm(
            boundaries=bounds, ncolors=len(colors))
        return norm, cmap, bounds[:-1]

    def _select_stations_pga(self):
        attributes = self.attributes
        lon0 = self.lon0
        lon1 = self.lon1
        lat0 = self.lat0
        lat1 = self.lat1
        # select cmp_ids inside geographic area
        cmp_ids = [cmp_id for cmp_id in attributes
                   if lon0 <= attributes[cmp_id]['longitude'] <= lon1
                   and lat0 <= attributes[cmp_id]['latitude'] <= lat1]
        if not cmp_ids:
            raise ValueError(
                'No stations in the selected area. No plot generated.')
        return sorted(cmp_ids, key=lambda x: x.split('.')[1])

    def _plot_circles(self, ax):
        geodetic_transform = ccrs.PlateCarree()
        g = Geod(ellps='WGS84')
        evlat = self.event['lat']
        evlon = self.event['lon']
        # Following values are for testing
        # evlat = 14.6
        # evlon = -61
        # evlat = 14.9
        # evlon = -60.8
        # evlat = 14.4
        # evlon = -61.2
        # evlat = 12.4
        # evlon = -63.2
        ax.plot(evlon, evlat, marker='*', markersize=12,
                markeredgewidth=1, markeredgecolor='k',
                color='green', transform=geodetic_transform,
                zorder=10)
        evdepth = self.event['depth']
        for hypo_dist in np.arange(10, 500, 10):
            if hypo_dist <= evdepth:
                continue
            dist = (hypo_dist**2 - evdepth**2)**0.5
            azimuths = np.arange(0, 360, 1)
            circle = np.array(
                [g.fwd(evlon, evlat, az, dist*1e3)[:2] for az in azimuths]
            )
            dlon = (self.lon1-self.lon0)*0.01
            dlat = (self.lat1-self.lat0)*0.01
            circle_visible = circle[
                (circle[:, 0] > self.lon0+dlon) &
                (circle[:, 0] < self.lon1-dlon) &
                (circle[:, 1] > self.lat0+dlat) &
                (circle[:, 1] < self.lat1-dlat)
            ]
            if len(circle_visible) < 2:
                continue
            p0 = circle_visible[np.argmax(circle_visible[:, 0])]
            p1 = circle_visible[np.argmax(circle_visible[:, 1])]
            # check if p1 and p0 are too close
            if sum(np.abs(p1-p0)) <= 1e-2:
                p1 = circle_visible[np.argmin(circle_visible[:, 1])]
            # ignore p1 if it is still too close
            if sum(np.abs(p1-p0)) <= 1e-1:
                p1 = None
            ax.plot(circle[:, 0], circle[:, 1],
                    color='#777777', linestyle='--',
                    transform=geodetic_transform)
            dist_text = f'{hypo_dist:d} km'
            t = plt.text(p0[0], p0[1], dist_text, size=6, weight='bold',
                         verticalalignment='center',
                         horizontalalignment='right',
                         transform=geodetic_transform, zorder=10)
            t.set_path_effects([
                path_effects.Stroke(linewidth=0.8, foreground='white'),
                path_effects.Normal()
            ])
            if p1 is not None:
                t = plt.text(p1[0], p1[1], dist_text, size=6, weight='bold',
                             verticalalignment='center',
                             horizontalalignment='left',
                             transform=geodetic_transform, zorder=10)
                t.set_path_effects([
                    path_effects.Stroke(linewidth=0.8, foreground='white'),
                    path_effects.Normal()
                ])

    def plot_map(self):
        """Plot the PGA map."""
        stamen_terrain = StamenTerrain(self.conf['STADIA_MAPS_API_KEY'])
        geodetic_transform = ccrs.PlateCarree()

        # Create a GeoAxes
        fig, ax = plt.subplots(
            1, figsize=(10, 10),
            subplot_kw={'projection': geodetic_transform})

        extent = (self.lon0, self.lon1, self.lat0, self.lat1)
        ax.set_extent(extent)

        ax.add_image(stamen_terrain, 11)
        # ax.coastlines('10m')
        # coast = cfeature.GSHHSFeature(scale='f')
        # ax.add_feature(coast)
        ax.gridlines(draw_labels=True, color='#777777', linestyle='--')
        self._plot_circles(ax)

        norm, cmap, bounds = self._colormap()

        unknown_soils = False
        cmp_ids = self._select_stations_pga()
        texts = []
        markers = []
        for cmp_id in cmp_ids:
            cmp_attrib = self.attributes[cmp_id]
            lon = cmp_attrib['longitude']
            lat = cmp_attrib['latitude']
            pga = cmp_attrib['pga']
            marker = '^'
            if self.conf['soil_conditions']:
                soil_cnd = cmp_attrib['soil_cnd']
                if soil_cnd == 'U':
                    unknown_soils = True
                marker = self.markers[soil_cnd]
            m, = ax.plot(
                lon, lat, marker=marker, markersize=12,
                markeredgewidth=1, markeredgecolor='k',
                color=cmap(norm(pga)),
                transform=geodetic_transform, zorder=10)
            markers.append(m)
            stname = cmp_id.split('.')[1]
            t = ax.text(lon, lat, stname, size=8, weight='bold', zorder=99)
            t.set_path_effects([
                path_effects.Stroke(linewidth=1.5, foreground='white'),
                path_effects.Normal()
            ])
            texts.append(t)

        if self.conf['soil_conditions']:
            self._plot_soil_conditions(geodetic_transform, ax, unknown_soils)
        # Add a colorbar
        ax_divider = make_axes_locatable(ax)
        cax = ax_divider.append_axes(
            'right', size='6%', pad='15%', axes_class=plt.Axes)
        sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
        sm.set_array([])
        if self.colorbar_bcsf:
            fig.colorbar(sm, extend='max', ticks=bounds, cax=cax)
        else:
            fig.colorbar(sm, extend='max', cax=cax)
        cax.get_yaxis().set_visible(True)
        cax.set_ylabel('PGA (mg)')

        self._adjust_text_labels(texts, markers, ax)

        outfile = f'{self.basename}_pga_map_fig.png'
        fig.savefig(outfile, dpi=300, bbox_inches='tight')

    def _adjust_text_labels(self, station_texts, markers, ax):
        """
        Adjust the text labels so that they do not overlap.
        """
        if not station_texts:
            return
        # store original text positions and texts
        text_pos = [(t.get_position(), t.get_text()) for t in station_texts]
        # compute mean position
        x_pos_mean = np.mean([p[0][0] for p in text_pos])
        y_pos_mean = np.mean([p[0][1] for p in text_pos])
        # first adjust text labels relatively to each other
        adjust_text(station_texts, ax=ax, maxshift=1e3)
        # then, try to stay away from markers
        adjust_text(station_texts, add_objects=markers, ax=ax, maxshift=1e3)
        # check if some text labels are too far away from the mean position
        # (i.e., bug in adjust_text) and move them back to their original
        # position
        for t in station_texts:
            txt = t.get_text()
            x_pos, y_pos = t.get_position()
            delta_x = np.abs(x_pos - x_pos_mean)
            delta_y = np.abs(y_pos - y_pos_mean)
            if delta_x > 100 or delta_y > 100:
                x_pos, y_pos = [tp[0] for tp in text_pos if tp[1] == txt][0]
                t.set_position((x_pos, y_pos))

    def _plot_soil_conditions(self, geodetic_transform, ax, unknown_soils):
        kwargs = {
            'markersize': 8,
            'markeredgewidth': 1,
            'markeredgecolor': 'k',
            'color': '#cccccc',
            'linewidth': 0,
            'transform': geodetic_transform
        }
        rock_station, = ax.plot(
            -self.lon0, -self.lat0, marker=self.markers['R'],
            label='rock', **kwargs)
        soil_station, = ax.plot(
            -self.lon0, -self.lat0, marker=self.markers['S'],
            label='soil', **kwargs)
        handles = [rock_station, soil_station]
        if unknown_soils:
            unk_station, = ax.plot(
                -self.lon0, -self.lat0, marker=self.markers['U'],
                label='unknown', **kwargs)
            handles.append(unk_station)
        legend = ax.legend(handles=handles, loc=self.legend_loc)
        legend.set_zorder(99)

    def _b3(self, mag, epi_dist, uncertainty=False):
        """Compute the B3 law (Beauducel et al., 2011)."""
        a = 0.61755
        b = -0.0030746
        c = -3.3968
        pga_exponent = a*mag + b*epi_dist - np.log10(epi_dist) + c
        pga = 10**pga_exponent
        if uncertainty:
            log_pga_uncertainty = 0.47
            pga_lower = 10**(pga_exponent - log_pga_uncertainty)
            pga_upper = 10**(pga_exponent + log_pga_uncertainty)
            return pga, pga_lower, pga_upper
        return pga

    def plot_pga_dist(self):
        """Plot PGA as a function of distance."""
        event = self.event
        fig, ax = plt.subplots(figsize=(8, 2.5))
        ax.set_xscale('log')
        ax.set_yscale('log')
        ax.grid(True, which='both', ls='--', color='#bbbbbb')
        ax.set_xlabel('Hypocentral distance (km)')
        ax.set_ylabel('PGA (mg)')
        # plot the b3 law (Beauducel et al., 2011)
        mag = event['mag']
        epi_dist = np.logspace(-1, 3, 50)
        pga, pga_lower, pga_upper = self._b3(mag, epi_dist, uncertainty=True)
        b3_curve, = ax.plot(epi_dist, pga*1e3, label=f'$B^3$: M {mag:.1f}')
        kwargs = {
            'color': '#999999', 'linestyle': '--', 'label': 'uncertainty'}
        b3_uncertainty, = ax.plot(epi_dist, pga_lower*1e3, **kwargs)
        b3_uncertainty, = ax.plot(epi_dist, pga_upper*1e3, **kwargs)
        legend_handles = [b3_curve, b3_uncertainty]

        g = Geod(ellps='WGS84')
        evlat = event['lat']
        evlon = event['lon']
        evdepth = event['depth']

        norm, cmap, _ = self._colormap()

        min_hypo_dist = 1e10
        unknown_soils = False
        cmp_ids = self._select_stations_pga()
        for cmp_id in cmp_ids:
            cmp_attrib = self.attributes[cmp_id]
            lon = cmp_attrib['longitude']
            lat = cmp_attrib['latitude']
            _, _, dist = g.inv(lon, lat, evlon, evlat)
            dist /= 1000.
            hypo_dist = (dist**2 + evdepth**2)**0.5
            if hypo_dist < min_hypo_dist:
                min_hypo_dist = hypo_dist
            pga = cmp_attrib['pga']
            marker = 'o'
            if self.conf['soil_conditions']:
                soil_cnd = cmp_attrib['soil_cnd']
                if soil_cnd == 'U':
                    unknown_soils = True
                marker = self.markers[soil_cnd]
            ax.scatter(
                hypo_dist, pga, marker=marker, color=cmap(norm(pga)),
                edgecolor='k', alpha=0.5, zorder=99
            )
        if self.conf['soil_conditions']:
            kwargs = {'color': '#cccccc', 'edgecolor': 'k'}
            rock = ax.scatter(
                0, 0, marker=self.markers['R'], label='rock', **kwargs)
            soil = ax.scatter(
                0, 0, marker=self.markers['S'], label='soil', **kwargs)
            legend_handles += [rock, soil]
            if unknown_soils:
                unk = ax.scatter(
                    0, 0, marker=self.markers['U'], label='unknown', **kwargs)
                legend_handles += [unk]
        ax.legend(handles=legend_handles)
        if min_hypo_dist <= 1:
            ax.set_xlim(0.5, 500)
            ax.set_ylim(1e-2, 1e6)
        else:
            ax.set_xlim(10, 500)
            ax.set_ylim(1e-2, 1e4)
        outfile = f'{self.basename}_pga_dist_fig.png'
        fig.savefig(outfile, dpi=300, bbox_inches='tight')

    def _build_pga_table_html(self, html):
        """Build the PGA info table for the HTML report."""
        cmp_ids = self._select_stations_pga()
        # find max pga and corresponding station
        pga_list = [(cmp_id.split('.')[1], self.attributes[cmp_id]['pga'])
                    for cmp_id in cmp_ids]
        pga_max_sta, _pga_max = max(pga_list, key=lambda x: x[1])
        if self.conf['soil_conditions']:
            _soil_cnds = [
                self.attributes[cmp_id]['soil_cnd'] for cmp_id in cmp_ids]
            if 'U' in _soil_cnds:
                pga_title = 'PGA (mg) (R/S/U: rock/soil/unknown)'
            else:
                pga_title = 'PGA (mg) (R/S: rock/soil)'
        else:
            pga_title = 'PGA (mg)'
        html = html.replace('%PGA_TITLE', pga_title)
        nsta = len(cmp_ids)
        nrows = 7
        ncols = int(np.ceil(nsta/nrows))
        rows = ''
        for nr in range(nrows):
            rows += '\n<tr>'
            for nc in range(ncols):
                val_number = nr + nc*nrows
                placeholder = f'%STA{val_number:02d}'
                rows += f'\n  <td class="left">{placeholder}</td>'
                placeholder = f'%PGA{val_number:02d}'
                rows += f'\n  <td class="right">{placeholder}</td>'
            rows += '\n</tr>'
        cmp_ids = sorted(cmp_ids, key=lambda x: x.split('.')[1])
        for n, cmp_id in enumerate(cmp_ids):
            cmp_attrib = self.attributes[cmp_id]
            pga = cmp_attrib['pga']
            pga_text = f'{pga:5.1f}'.replace(' ', '&nbsp;')
            stname = cmp_id.split('.')[1]
            if self.conf['soil_conditions']:
                soil_cnd = cmp_attrib['soil_cnd']
                st_text = f'{stname}({soil_cnd}):'
            else:
                st_text = f'{stname}:'
            if stname == pga_max_sta:
                st_text = f'<b>*{st_text}</b>'
                pga_text = f'<b>{pga_text}</b>'
            rows = rows\
                .replace(f'%STA{n:02d}', st_text)\
                .replace(f'%PGA{n:02d}', pga_text)
        # remove extra rows
        for nn in range(len(cmp_ids), nrows*ncols):
            rows = rows\
                .replace(f'%STA{nn:02d}', '')\
                .replace(f'%PGA{nn:02d}', '')
        html = html.replace('%ROWS', rows)
        return html

    def write_html(self):
        """Write the output HTML file."""
        event = self.event
        template_html = os.path.join(script_path, 'template.html')
        html = open(template_html, 'r', encoding='utf8').read()
        title = f"Peak Ground Acceleration &ndash; {self.conf['REGION']}"
        evid = event['id_sc3']
        subtitle = f'{evid} &ndash; '
        date = event['time'].strftime('%Y-%m-%d %H:%M:%S')
        subtitle += f'{date} &ndash; '
        subtitle += f"M {event['mag']:.1f}"

        # Event info table
        lat = f"{event['lat']:8.4f}".replace(' ', '&nbsp;')
        lon = f"{event['lon']:8.4f}".replace(' ', '&nbsp;')
        depth = f"{event['depth']:.3f} km".replace(' ', '&nbsp;')
        mag = f"{event['mag']:.2f}".replace(' ', '&nbsp;')
        html = html\
            .replace('%TITLE', title)\
            .replace('%SUBTITLE', subtitle)\
            .replace('%EVID', evid)\
            .replace('%DATE', date)\
            .replace('%LAT', lat)\
            .replace('%LON', lon)\
            .replace('%DEPTH', depth)\
            .replace('%MAG', mag)

        # PGA info table
        html = self._build_pga_table_html(html)

        # Map file
        map_fig_file = f'{self.basename}_pga_map_fig.png'
        map_fig_file = os.path.basename(map_fig_file)
        html = html.replace('%MAP', map_fig_file)
        # PGA-dist file
        pga_dist_fig_file = f'{self.basename}_pga_dist_fig.png'
        pga_dist_fig_file = os.path.basename(pga_dist_fig_file)
        html = html.replace('%PGA_DIST', pga_dist_fig_file)
        # Footer
        footers = []
        if self.copyright:
            footers.append(self.copyright)
        if self.copyright2:
            footers.append(self.copyright2)
        footers.append(datetime.now().strftime(' %Y-%m-%d %H:%M:%S'))
        footer_text = '; '.join(footers)
        html = html.replace('%FOOTER_TEXT', footer_text)

        # Write HTML file
        html_file = f'{self.basename}_pga_map.html'
        with open(html_file, 'w', encoding='utf8') as fp:
            fp.write(html)
        if self.debug:
            print(f'\nHTML report saved to {html_file}')

        # Link CSS file and logos
        styles_orig = os.path.join(script_path, 'styles.css')
        styles_link = os.path.join(self.out_path, 'styles.css')
        with contextlib.suppress(FileNotFoundError):
            os.remove(styles_link)
        os.symlink(styles_orig, styles_link)
        if self.logo_file:
            logo_link = os.path.join(self.out_path, 'logo_file.png')
            with contextlib.suppress(FileNotFoundError):
                os.remove(logo_link)
            os.symlink(self.logo_file, logo_link)
        if self.logo2_file:
            logo_link = os.path.join(self.out_path, 'logo2_file.png')
            with contextlib.suppress(FileNotFoundError):
                os.remove(logo_link)
            os.symlink(self.logo2_file, logo_link)

    def write_pdf(self):
        """Convert HTML file to PDF."""
        html_file = f'{self.basename}_pga_map.html'
        pdf_file = f'{self.basename}_pga_map.pdf'
        pdfkit_options = {
            'dpi': 300,
            'margin-bottom': '0cm',
            'quiet': '',
            'enable-local-file-access': None
        }
        pdfkit.from_file(html_file, pdf_file, options=pdfkit_options)
        print(f'\nPDF report saved to {pdf_file}')

    def write_images(self, thumb_height):
        """Convert PDF file to full size PNG and generate a JPEG thumbnail."""
        pdf_file = f'{self.basename}_pga_map.pdf'
        png_file = f'{self.basename}_pga_map.png'
        thumb_file = f'{self.basename}_pga_map.jpg'
        page = convert_from_path(pdf_file, dpi=300)[0]
        page.save(png_file, 'PNG')
        print(f'\nPNG report saved to {png_file}')
        size = page.size
        ratio = thumb_height/size[1]
        thumb_width = int(size[0]*ratio)
        page_thumb = page.resize((thumb_width, thumb_height))
        page_thumb.save(thumb_file, 'JPEG')
        print(f'\nThumbnail saved to {thumb_file}')

    def write_attributes(self):
        """Write attributes text file."""
        event = self.event
        attributes = self.attributes
        outfile = f'{self.basename}_pga_map.txt'
        fp = open(outfile, 'w', encoding='utf8')
        fp.write(
            f"#{event['id_sc3']} {event['timestr']} "
            f"lon {event['lon']:8.4f} lat {event['lat']:8.4f} "
            f"depth {event['depth']:8.3f} mag {event['mag']:.2f}\n"
        )
        fp.write('#id                pga      pgv    psa03   psa10   psa30\n')
        fp.write('#                 (mg)     (m/s)    (mg)    (mg)    (mg)\n')
        fp.write('#\n')
        for cmp_id in sorted(attributes.keys()):
            cmp_attrib = attributes[cmp_id]
            pga = cmp_attrib['pga']
            pgv = cmp_attrib['pgv']
            psa03 = cmp_attrib['psa03']
            psa10 = cmp_attrib['psa10']
            psa30 = cmp_attrib['psa30']
            fp.write(
                f'{cmp_id:14s} {pga:7.3f} {pgv:.3e} '
                f'{psa03:7.3f} {psa10:7.3f} {psa30:7.3f}\n'
            )
        print(f'\nText file saved to {outfile}')

    def make_symlinks(self):  # sourcery skip: use-fstring-for-concatenation
        """Create symbolic links."""
        cwd = os.getcwd()
        os.chdir(self.out_path)
        for ext in ['txt', 'jpg', 'png', 'pdf']:
            filename = f'{self.fileprefix}_pga_map.{ext}'
            if not os.access(filename, os.F_OK):
                continue
            with contextlib.suppress(FileNotFoundError):
                os.remove(f'pga_map.{ext}')
            os.symlink(filename, f'pga_map.{ext}')
        os.chdir(cwd)

    def clean_intermediate_files(self):
        """Remove intermediate files, except in DEBUG mode."""
        if self.debug:
            return
        html_file = f'{self.basename}_pga_map.html'
        os.remove(html_file)
        map_fig_file = f'{self.basename}_pga_map_fig.png'
        os.remove(map_fig_file)
        pga_dist_fig_file = f'{self.basename}_pga_dist_fig.png'
        os.remove(pga_dist_fig_file)
        styles_link = os.path.join(self.out_path, 'styles.css')
        with contextlib.suppress(FileNotFoundError):
            os.remove(styles_link)
        logos = os.path.join(script_path, 'logos', '*.png')
        for logo in glob(logos):
            logo_link = os.path.join(self.out_path, os.path.basename(logo))
            with contextlib.suppress(FileNotFoundError):
                os.remove(logo_link)


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument('xml_file')
    parser.add_argument('xml_dat_file')
    parser.add_argument('out_dir')
    parser.add_argument('-s', '--soil_conditions_file', type=str,
                        default=None,
                        help='Soil conditions file (default: None)')
    parser.add_argument('-c', '--config', type=str,
                        default='PROC.PGA_MAP',
                        help='Config file name (default: PROC.PGA_MAP)')
    parser.add_argument('-t', '--thumbnail_height', type=int,
                        default=200,
                        help='Thumbnails height (default: 200)')
    parser.add_argument('-w', '--wo_root_code', type=str,
                        default='/opt/webobs/CODE',
                        help='WebObs ROOT_CODE (default: /opt/webobs/CODE)')
    return parser.parse_args()


def main():
    """Run the main code."""
    args = parse_args()
    pgamap = PgaMap()
    pgamap.parse_config(args.config, args.wo_root_code)
    pgamap.parse_event_xml(args.xml_file)
    pgamap.parse_event_dat_xml(args.xml_dat_file, args.soil_conditions_file)
    pgamap.make_path(args.out_dir)
    pgamap.plot_map()
    pgamap.plot_pga_dist()
    pgamap.write_html()
    pgamap.write_pdf()
    pgamap.write_images(args.thumbnail_height)
    try:
        pgamap.write_attributes()
        pgamap.make_symlinks()
        pgamap.clean_intermediate_files()
    except OSError as oer:
        print(oer)


if __name__ == '__main__':
    main()
