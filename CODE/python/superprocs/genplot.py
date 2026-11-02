import logging
import logging.config
import os
import sys
import time

import matplotlib
import matplotlib.pyplot as plt
import numpy as np

from wolib.config import WEBOBS
from wolib.graphs import (
    channel_height_ratios,
    create_events_map_files,
    get_date_formatter,
    get_paper_size,
    plot_copyright,
    plot_events,
    plot_infos,
    plot_logos,
    plot_nodata,
    plot_status,
    plot_time_axis_label,
    plot_timestamp,
    plot_title,
    save_plot,
)
from wolib.processings import filter_node_data, smooth
from wolib.read_proc import Proc, get_data_stats
from wolib.utils import export_csv, graph_parameters, is_ok, str_to_int

logging.config.fileConfig("logging.ini")
logger = logging.getLogger("genplot")

start_proc_time = time.time()

if len(sys.argv) < 2:
    logger.info("No proc name specified! Operation canceled.")
    sys.exit()

# gets PROC's configuration, associated nodes for any TSCALE
logger.info(sys.argv[1])
proc = Proc(sys.argv[1])

if len(sys.argv) >= 4:
    proc.request = True
    proc.set_outdir(os.path.join(sys.argv[3], f"PROC.{proc.name}"))
    proc.set_config_file(os.path.join(sys.argv[3], "REQUEST.rc"))
proc.read_proc()

# Main graphical options
pernode_linestyle = getattr(proc, "PERNODE_LINESTYLE", "-")
pernode_title = getattr(
    proc, "PERNODE_TITLE", "{{\bf $node_alias: $node_name} ($timescale)}"
)
pernode_channels = getattr(proc, "PERNODE_CHANNELS", "")
summary_linestyle = getattr(proc, "SUMMARY_LINESTYLE", "-")
summary_title = getattr(proc, "SUMMARY_TITLE", "{{\bf $NAME} ($timescale)}")
pagemaxsubplot = int(getattr(proc, "PAGE_MAX_SUBPLOT", 8))
ylogscale = is_ok(getattr(proc, "YLOGSCALE", ""))
grid_on = is_ok(getattr(proc, "PLOT_GRID", ""))
movingaverage = str_to_int(getattr(proc, "MOVING_AVERAGE_SAMPLES", ""))
max_channels = min(max(node.CLB if node.CLB else [1]) for node in proc.nodes)
psz = get_paper_size(proc)
watermark = str_to_int(WEBOBS.get("MKGRAPH_TIMESTAMP", 5))
event_files = getattr(proc, "EVENTS_FILE", "")
csv = is_ok(getattr(proc, "EXPORTS", ""))
csv_header_title = WEBOBS["WEBOBS_TITLE"]

plt.rcParams["text.usetex"] = True
# plt.rcParams["savefig.dpi"] =  getattr(proc, "PPI", 100)
plt.rcParams["font.size"] = 8
plt.rcParams["lines.linewidth"] = 0.1
plt.rcParams["lines.markersize"] = 1
cmap = matplotlib.colormaps["brg"]
pc = 0.35  # Blending parameter between the colormap and white.

graph = graph_parameters(proc)
for timescale in graph.keys():
    logger.info(timescale)
    gopts = {k: graph[timescale][k] for k in ("linewidth", "markersize")}
    gopts["linestyle"] = pernode_linestyle
    date_form = get_date_formatter(timescale)
    proc.read_data(timescale)
    (start_time, end_time) = (proc.start_time, proc.end_time)
    for node in proc.nodes:
        channels = channel_height_ratios(pernode_channels, max(node.CLB))
        nc = len(channels)
        dt = filter_node_data(proc, node, timescale)
        colors = (1 - pc) * cmap(np.linspace(0, 1, nc)) + pc * np.ones((nc, 4))
        hr = channels.values()
        fig, axs = plt.subplots(nc, 1, sharex=True, height_ratios=hr, figsize=psz)
        plt.subplots_adjust(left=0.1, bottom=0.1, top=0.90, right=0.95)
        fig_width, fig_height = plt.gcf().get_size_inches()
        if nc > pagemaxsubplot:
            ratio = node.data.shape[1] / pagemaxsubplot
            plt.gcf().set_size_inches(fig_width, fig_height * ratio)
        for c in channels:
            c = c - 1
            data = node.data[:, c]
            axs[c].set_xlim(start_time.timestamp(), end_time.timestamp())
            axs[c].set_label("waveform" + str(c))
            axs[c].plot(dt, data, c=colors[c], **gopts)
            cal = node.CLB[c + 1]
            channel, unit = cal["nm"], cal["un"]
            axs[c].set_ylabel(f"{channel} ({unit})")
            if ylogscale:
                axs[c].set_yscale("log")
            if grid_on:
                axs[c].grid(linestyle=":")
            if np.isnan(data).all():
                plot_nodata(axs[c])
            elif movingaverage:
                # adjusts moving average filter to decimated data (keeps the cut-off frequency)
                mdec = round(movingaverage / graph[timescale].get("decimate"))
                if mdec >= 2:
                    mlw = float(gopts.get("linewidth", 0.1)) * 2
                    axs[c].plot(dt, smooth(data, mdec), c="lightgrey", lw=mlw)
                    axs[c].set_title(f"mov. avg {mdec}", c=colors[c], weight="bold")
        axs[-1].xaxis.set_major_formatter(date_form)
        plot_time_axis_label(axs[-1], start_time, end_time)
        fig.align_ylabels(axs)
        plot_title(pernode_title, proc, node)
        plot_logos(proc)
        plot_copyright(proc)
        if is_ok(graph[timescale].get("status")):
            plot_status(node)
        stats = get_data_stats(dt, node)
        plot_infos(stats)
        filename = f"{node.nodeid}_{timescale}".lower()
        if watermark:
            plot_timestamp(filename, proc, watermark)
        if event_files:
            events_html = plot_events(event_files)
            create_events_map_files(events_html, filename, proc)
        save_plot(filename, proc)
        if csv:
            export_csv(filename, csv_header_title, proc, node.fullid)

    if proc.SUMMARYLIST:
        alias = ", ".join(n.ALIAS for n in proc.nodes if ~np.isnan(n.data).all())
        gopts["linestyle"] = summary_linestyle
        channels = channel_height_ratios(proc.SUMMARY_CHANNELS, max_channels)
        nc = len(channels)
        cmap = matplotlib.colormaps["viridis"]
        colors = cmap(np.linspace(0, 1, len(graph.keys()) * node.data.shape[-1] + 1))
        hr = channels.values()
        fig, axs = plt.subplots(nc, 1, sharex=True, height_ratios=hr, figsize=psz)
        plt.subplots_adjust(left=0.1, bottom=0.1, top=0.90, right=0.95)
        fig_width, fig_height = plt.gcf().get_size_inches()
        if nc > pagemaxsubplot:
            ratio = max_channels / pagemaxsubplot
            plt.gcf().set_size_inches(fig_width, fig_height * ratio)

        for node in proc.nodes:
            if ~np.isnan(node.data).all():
                for c in channels:
                    c = c - 1
                    data = node.data[:, c]
                    axs[c].set_xlim(start_time.timestamp(), end_time.timestamp())
                    axs[c].set_label("waveform" + str(c))
                    axs[c].plot(dt, data, c=colors[c], **gopts)
                    axs[c].set_title(alias, c=colors[c], weight="bold")
                    cal = node.CLB[c + 1]
                    channel, unit = cal["nm"], cal["un"]
                    axs[c].set_ylabel(f"{channel} ({unit})")
                    if ylogscale:
                        axs[c].set_yscale("log")
                    if grid_on:
                        axs[c].grid(linestyle=":")
        axs[-1].xaxis.set_major_formatter(date_form)
        plot_time_axis_label(axs[-1], start_time, end_time)
        fig.align_ylabels(axs)
        plot_title(summary_title, proc, node)
        plot_logos(proc)
        plot_copyright(proc)
        if is_ok(graph[timescale].get("status")):
            plot_status(node)
        filename = f"_{timescale}"
        if watermark:
            plot_timestamp(filename, proc, watermark)
        if event_files:
            events_html = plot_events(event_files)
            create_events_map_files(events_html, filename, proc)
        save_plot(filename, proc)

end_proc_time = round(time.time() - start_proc_time, 1)
logger.info(f"Executed in {end_proc_time} seconds")
