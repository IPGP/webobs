import fiona
import matplotlib.pyplot as plt
from shapely.geometry import shape
import matplotlib.colors as colors
import rasterio
from PIL import Image
from adjustText import adjust_text
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
from matplotlib.cm import ScalarMappable
from matplotlib.patches import Polygon
import os
import datetime


def create_map(path_to_folder, dem, flow_id, map_layers, sim_layers, mode, language, display):
    """
    Create a map for either 'downflow' or 'downflowgo' based on the mode provided and in English or in French

    Parameters:
    - path_to_folder: Folder to save the generated map.
    - dem: DEM file path.
    - flow_id: ID of the flow.
    - map_layers: Dictionary containing map layer file paths.
    - sim_layers: Dictionary containing simulation layer file paths.
    - mode: Either 'downflow' or 'downflowgo' to choose the type of map. Default is 'downflow'.
    """
    plt.close('all')
    current_datetime = datetime.datetime.now()
    Date = current_datetime.strftime('%d-%m-%y %H:%M')

    losd_path = sim_layers['shp_losd_file']
    vent_path = sim_layers['shp_vent_file']
    sim_tif_file = sim_layers['cropped_geotiff_file']
    tiff_file = map_layers['img_tif_map_background']
    source_img_tif_map_background = map_layers["source_img_tif_map_background"]
    lavaflow_outline_path = map_layers['lava_flow_outline_path']
    monitoring_network_path = map_layers['monitoring_network_path']
    logo = map_layers['logo_path']
    unverified_data = map_layers['unverified_data']


    if mode == 'downflowgo':
        run_outs_path = sim_layers['shp_runouts']
    else:
        run_outs_path = None

    # Create the map figure
    fig, ax = plt.subplots(figsize=(8, 7))

    # Load the TIFF image, convert it to RGB and read

    if not tiff_file or tiff_file == "0":
        pass  # pass if no value or "0"
    else:
        tiff_image = Image.open(tiff_file)
        tiff_image_rgb = tiff_image.convert('RGB')
        with rasterio.open(tiff_file) as src:
            tiff_image = src.read(1)
            extent = src.bounds
        # Display the TIFF image as the background
        tif = ax.imshow(tiff_image_rgb, extent=(extent.left, extent.right, extent.bottom, extent.top))

    # ------------ plot simulation .tiff ----------

    # Load the compressed GeoTIFF file and extract the necessary information and data
    with rasterio.open(sim_tif_file) as src:
        data = src.read(1)
        transform = src.transform

    # Define value intervals and associated colors
    intervals = [0, 1, 10, 100, 1000, 10000]  # color intervals
    colors_list = ['none', 'gold', 'orange', 'orangered', 'red']  # associated colors
    colors_list2 = ['gold', 'orange', 'darkorange', 'orangered', 'red']  # colors for colorbar

    # Create a colormap for the legend colorbar
    cmap = colors.LinearSegmentedColormap.from_list('my_colormap', colors_list, N=256)
    bounds = [v - 0.5 for v in intervals]
    norm = colors.BoundaryNorm(bounds, cmap.N)

    # Plot the simulation data on the map
    ax.imshow(data, extent=(transform[2], transform[2] + transform[0] * data.shape[1],
                                  transform[5] + transform[4] * data.shape[0], transform[5]),  # Flip the y-axis
                    cmap=cmap, norm=norm)

    # Set the limit of the figure based on used DEM
    with open(dem) as file:
        header_lines = [next(file) for _ in range(6)]
        ncols_dem = int(header_lines[0].split()[1])
        nrows_dem = int(header_lines[1].split()[1])
        xllcorner_dem = float(header_lines[2].split()[1])
        yllcorner_dem = float(header_lines[3].split()[1])
        cellsize_dem = float(header_lines[4].split()[1])
        nodata_value = float(header_lines[5].split()[1])

    ax.set_xlim(xllcorner_dem, xllcorner_dem + ncols_dem * cellsize_dem)
    ax.set_ylim(yllcorner_dem, yllcorner_dem + nrows_dem * cellsize_dem)

    # ------------ Plot lava flow outline and monitoring network ----------

    if not lavaflow_outline_path or lavaflow_outline_path == "0":
        pass  # pass if no value or "0"
    else:
        with fiona.open(lavaflow_outline_path) as lavaflow_outline:
            for feature in lavaflow_outline:
                if feature.get('geometry') is not None:
                    geometry = shape(feature['geometry'])
                    if geometry.geom_type == 'Polygon':
                        coordinates = geometry.exterior.coords.xy
                        x = coordinates[0]
                        y = coordinates[1]
                        polygon_coords = list(zip(x, y))
                        polygon = Polygon(polygon_coords, edgecolor='black', facecolor='none')
                        ax.add_patch(polygon)
                else:
                    print("Lavaflow_outline does not have a valid geometry")

    # Plot monitoring network vector layer
    if not monitoring_network_path or monitoring_network_path == "0":
        pass  # pass if no value or "0"
    else:
        with fiona.open(monitoring_network_path) as monitoring_network:
            label_monitoring_network = []
            point_monitoring_network = []
            for feature in monitoring_network:
                geometry = shape(feature['geometry'])
                properties = feature['properties']
                if geometry.geom_type == 'Point':
                    x, y = geometry.x, geometry.y
                    point_monitoring_network.append((x, y))
                    label_monitoring_network.append(properties['Name'])
                    ax.plot(x, y, 'k.')
                else:
                    print("Monitoring_network does not have a valid geometry")
            # Create a dictionary to keep only the smallest label (lexicographically) for each unique point
            unique_monitoring_network = {}
            for (x, y), label in zip(point_monitoring_network, label_monitoring_network):
                if label is None:
                    continue  # Skip stations with no name
                if (x, y) not in unique_monitoring_network or label < unique_monitoring_network[(x, y)]:
                    unique_monitoring_network[(x, y)] = label

            # Displaying the monitoring_network names just above the points
            for (x, y), label in unique_monitoring_network.items():
                ax.annotate(
                    label, (x, y),
                    xytext=(0, 3),  # Offset of 5 units above the point
                    textcoords='offset points',
                    color='black', fontsize=8,
                    ha='center'  # Center the text horizontally
                )
    # ------------ Plot vector layers simulation path + vent + run out ----------

    # Plot the LOSD vector layer
    with fiona.open(losd_path) as losd:
        for feature in losd:
            geometry = shape(feature['geometry'])
            if geometry.geom_type == 'LineString':
                x, y = zip(*geometry.coords)
                ax.plot(x, y, 'darkred')

    # Plot the vent vector layer
    with fiona.open(vent_path) as vent:
        for feature in vent:
            geometry = shape(feature['geometry'])
            if geometry.geom_type == 'Point':
                x, y = geometry.x, geometry.y
                ax.plot(x, y, 'r^', markersize=10)

    # Plot additional runout layers for 'downflowgo'
    if mode == 'downflowgo' and run_outs_path:
        with fiona.open(run_outs_path) as run_outs:
            points = []
            labels = []

            for feature in run_outs:
                geometry = shape(feature['geometry'])
                properties = feature['properties']
                if geometry.geom_type == 'Point':
                    x, y = geometry.x, geometry.y
                    points.append((x, y))
                    labels.append(properties['Effusion_r'])
                    ax.plot(x, y, 'b', marker=7)

            unique_points = {}
            for (x, y), label in zip(points, labels):
                if (x, y) not in unique_points or label < unique_points[(x, y)]:
                    unique_points[(x, y)] = label

            for (x, y), label in unique_points.items():
                ax.annotate(label, (x, y), xytext=(0, 8), textcoords='offset points', color='blue', weight='bold',
                            fontsize=10, ha='center')

    # ------------ Add legend and colorbar ------------

    # Adjust the figure size
    fig.subplots_adjust(right=0.7)
    fig.subplots_adjust(left=0.1)
    fig.subplots_adjust(top=0.9)
    fig.subplots_adjust(bottom=0.1)

    # Create a colorbar for the simulation data in raster
    cax = fig.add_axes([0.71, 0.70, 0.2, 0.02])  # Coordinates and size of the axis
    # Create the colorbar with the colors of the intervals
    norm2 = colors.Normalize(vmin=min(intervals), vmax=max(intervals))
    cmap2 = colors.LinearSegmentedColormap.from_list('my_colormap', colors_list2, N=256)
    sm = ScalarMappable(cmap=cmap2, norm=norm2)
    sm.set_array([])  # Set empty array for the colorbar
    cbar = plt.colorbar(sm, cax=cax, orientation='horizontal')


    # Adjust the position of the legend and colorbar
    # Rotate label of Y and orientate vertically
    ax.set_yticks(ax.get_yticks())
    ax.set_yticklabels(ax.get_yticklabels(), rotation='vertical')



    if language == 'FR':
        # Add the legend image to the map
        ax.plot([], [], 'r^', markersize=7, label='Bouche éruptive ('+ flow_id+')')
        ax.plot([], [], '-r', label='Trajectoire principale')

        if mode == 'downflowgo':
            ax.plot([], [], 'bv', markersize=5, label='Distances atteintes \npour un débit donné (m$^{3}$/s)')

        # Plot monitoring network vector layer
        if not monitoring_network_path or monitoring_network_path == "0":
            pass  # pass if no value or "0"
        else:
            ax.plot([], [], 'k.', markersize=5, label='Stations de surveillance')

        if not lavaflow_outline_path or lavaflow_outline_path == "0":
            pass  # pass if no value or "0"
        else:
            ax.plot([], [], 'k-', markersize=10, label='Contour de la coulée')

        if mode == 'downflowgo':
            cbar.ax.set_title("Probabilité de passage de la coulée", fontsize=8, loc='left')
        else:
            cbar.ax.set_title("Probabilité de passage de la coulée", fontsize=8, loc='left')

        cbar.set_label("Basse                        Haute", fontsize=8, loc='left')
        cbar.set_ticks([])
        cbar.set_ticklabels([])
        #cbar.ax.set_position([0.71, 0.71, 0.2, 0.05])

        # ------------ Final adjustments ------------

        #show label from y axis en completo
        #formatter = ScalarFormatter(useMathText=False)
        #formatter.set_scientific(False)
        #ax.yaxis.set_major_formatter(formatter)

        # Adjust the position of the legend and colorbar
        # Rotate label of Y and orientate vertically
        ax.set_yticks(ax.get_yticks())
        ax.set_yticklabels(ax.get_yticklabels(), rotation='vertical')

        # Add title and date
        title = f'Carte de simulation DOWNFLOW'
        if mode == 'downflowgo':
            title = 'Carte de simulation DOWNFLOWGO'

        ax.set_title(f'{title} pour l\'éruption en cours\n' + str(Date))

    if language == "EN":

        # Add the legend image to the map
        ax.plot([], [], 'r^', markersize=7, label='Main vent (' + flow_id + ')')
        ax.plot([], [], '-r', label='Line of steepest descend')

        if mode == 'downflowgo':
            ax.plot([], [], 'bv', markersize=5, label='Runouts for a given \neffusion rate (m$^{3}$/s)')

        if not monitoring_network_path or monitoring_network_path == "0":
            pass  # pass if no value or "0"
        else:
            ax.plot([], [], 'k.', markersize=5, label='Monitoring network')

        if not lavaflow_outline_path or lavaflow_outline_path == "0":
            pass  # pass if no value or "0"
        else:
            ax.plot([], [], 'k-', markersize=10, label='Lava flow outline')

        if mode == 'downflowgo':
            cbar.ax.set_title("Lava flow path probability", fontsize=8, loc='left')
        else:
            cbar.ax.set_title("Lava flow path probability", fontsize=8, loc='left')

        cbar.set_label("Low                        High", fontsize=8, loc='left')
        cbar.set_ticks([])
        cbar.set_ticklabels([])
        # cbar.ax.set_position([0.71, 0.71, 0.2, 0.05])

        # ------------ Final adjustments ------------

        # Add title and date
        title = f'Short-term hazard map using DOWNFLOW'
        if mode == 'downflowgo':
            title = "Short-term hazard map using DOWNFLOWGO"

        ax.set_title(f'{title} modelling \n for the ongoing eruption :' + str(Date))

    # Load Logo image
    if not logo or logo == "0":
        pass  # pass if no value or "0"
    else:
        img = plt.imread(logo)
        logo_box = OffsetImage(img, zoom=0.05)  # size of the logo
        logo_anchor = (1.2, 0.02)  # Define the coordinate of the image anchor
        # Create the annotation of the image (remove frame
        ab = AnnotationBbox(logo_box, logo_anchor, xycoords='axes fraction', frameon=False)
        ax.add_artist(ab)

    legend = ax.legend(bbox_to_anchor=(1, 0.7), loc="upper left", fontsize='8')
    legend.get_frame().set_linewidth(0)

    # Adding the "UNVERIFIED DATA" text in the middle of the map
    if unverified_data == str('0'):
        pass
    else:
        ax.text(
            0.5, 0.5,  unverified_data.replace("-", "\n"),
            transform=ax.transAxes,  # This makes the text relative to the axes
            fontsize=30, color='red', alpha=0.5,  # Red color, semi-transparent
            ha='center', va='center',  # Centered horizontally and vertically
            rotation=45,  # Rotate the text 45 degrees
            fontweight='bold')  # Bold text
        
    # Adding text for credit of the background map
    if source_img_tif_map_background == str('0'):
        pass
    else:
        ax.text(
            0.01, 0.01, source_img_tif_map_background,
            transform=ax.transAxes,
            fontsize=8, color='k',
            ha='left', va='bottom')
    plt.savefig(os.path.join(path_to_folder, f"map_{flow_id}.png"), dpi=300, bbox_inches='tight')
    print('Map created')
    if display == 'yes':
        plt.show()
        plt.close()
    