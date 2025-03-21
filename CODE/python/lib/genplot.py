import re

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np

from read_proc import read_data, read_proc
from utils import filter_signal, get_pernode_title, plot_logo, timescale

plt.rcParams["text.usetex"] = True
plt.rcParams["figure.dpi"] = 300
plt.rcParams["font.size"] = 5
plt.rcParams["lines.linewidth"] = 0.1
cmap = mpl.colormaps["brg"]


# gets PROC's configuration, associated nodes for any TSCALE and the data
proc = read_proc("GEOSCOPE")
# print(proc)
conf = proc["conf"]
print(conf)

# Main graphical options
pernode_linestyle = conf.get("PERNODE_LINESTYLE", "-")
pernode_title = conf.get("PERNODE_TITLE", "{\fontsize{14}{\bf $node_alias: $node_name} ($timescale)}")
summary_linestyle = conf.get("SUMMARY_LINESTYLE", "-")
summary_title = conf.get("SUMMARY_TITLE", "{\fontsize{14}{\bf$name} ($timescale)}")
pagemaxsubplot = 2  # int(conf.get("PAGE_MAX_SUBPLOT", 8))
# ylogscale = isok(P,'YLOGSCALE');
movingaverage = round(float(conf.get("MOVING_AVERAGE_SAMPLES", 1)))

timescalelist = conf["TIMESCALELIST"].split(",")
decimatelist = conf["DECIMATELIST"].split(",")
cumulatelist = conf["CUMULATELIST"].split(",")
datestrlist = conf["DATESTRLIST"].split(",")
markersizelist = conf["MARKERSIZELIST"].split(",")
linewidthlist = conf["LINEWIDTHLIST"].split(",")
statuslist = conf["STATUSLIST"].split(",")

print(timescalelist)
for code in timescalelist[:1]:
    start_time, end_time = timescale(code)
    proc = read_data(proc, start_time, end_time)
    nodes = proc["nodes"].items()
    nn = len(nodes)
    for n, (nid, node) in enumerate(nodes):
        datetime = proc["data"]["t"][n]
        chs_data = proc["data"]["d"][n]
        chs_cal = node["CLB"].values()
        nc = min(chs_data.shape[1], pagemaxsubplot)
        colors = cmap(np.linspace(0, 1, nc + 1))
        fig, axs = plt.subplots(nc, 1, sharex=True, num="genplot")
        for c, cal in enumerate(chs_cal):
            cha = cal["nm"]
            unit = cal["un"]
            zz = np.array(chs_data[:, c])
            data = filter_signal(chs_data[:, c])
            axs[c].plot(datetime, data, color=colors[c])
            # axs[i].plot(datetime, chX_mean)
            axs[c].set_ylabel(f"{cha} {unit}")
            if c == pagemaxsubplot - 1:
                break
        fig.align_ylabels(axs)
        fontsize = re.search(r"\\fontsize{(\d+)}", pernode_title)
        fontsize = fontsize.group(1) if fontsize else 10
        title = get_pernode_title(pernode_title, code, node)
        fig.suptitle(title, fontsize=fontsize, y=0.95)
        plot_logo(name=conf["LOGO_FILE"], size=conf["LOGO_HEIGHT"], pos="left")
        plot_logo(name=conf["LOGO2_FILE"], size=conf["LOGO2_HEIGHT"], pos="right")
        plt.savefig(f"{nid}_{code}.pdf")
