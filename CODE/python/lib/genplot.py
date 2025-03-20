import re
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt

from read_proc import read_data, read_proc
from utils import get_pernode_title, timescale, filter_signal

plt.rcParams["text.usetex"] = True
plt.rcParams.update({"font.size": "5", "lines.linewidth": "0.2"})
cmap = mpl.colormaps["brg"]


# gets PROC's configuration, associated nodes for any TSCALE and the data
proc = read_proc("GEOSCOPE")
# print(proc)
conf = proc["conf"]

# Main graphical options
pernode_linestyle = conf.get("PERNODE_LINESTYLE", "-")
pernode_title = conf.get("PERNODE_TITLE", "{\fontsize{14}{\bf $node_alias: $node_name} ($timescale)}")

# pernode_title = r"\fontsize{14} \bf{$node_alias: $node_name} ($timescale)"

summary_linestyle = conf.get("SUMMARY_LINESTYLE", "-")
summary_title = conf.get("SUMMARY_TITLE", "{\fontsize{14}{\bf$name} ($timescale)}")
pagemaxsubplot = int(conf.get("PAGE_MAX_SUBPLOT", 8))
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
for code in timescalelist:
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
        fig, axs = plt.subplots(nc, 1, sharex=True)
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
        fig.suptitle(title, fontsize=fontsize)
        plt.savefig(f"{nid}_{code}.pdf")
