import re
from datetime import datetime

import matplotlib.pyplot as plt


def plot_logo(name, size=0.05, pos="right"):
    fig = plt.gcf()
    width, height = plt.gcf().get_size_inches()
    logo = plt.imread(name)
    logo_height, logo_width, _ = logo.shape
    ratio = (min(width, height) / max(width, height)) * (fig.get_dpi() / 100.0)
    ax_height = float(size) * ratio
    ax_width = float(size) * ratio
    if pos == "left":
        rect, anchor = ((0, 1 - ax_height, ax_width, ax_height), "NE")
    else:
        rect, anchor = ((1 - ax_width, 1 - ax_height, ax_width, ax_height), "NW")
    logo_axis = fig.add_axes(rect, anchor=anchor)
    logo_axis.imshow(logo)
    logo_axis.axis("off")


def plot_title(title, timescale="", node=None):
    if node is None:
        node = {}
    fig = plt.gcf()
    fontsize = re.search(r"\\fontsize{(\d+)}", title)
    fontsize = fontsize.group(1) if fontsize else 10
    title = re.sub("(\w)\$", r"\1 $", title)
    title = re.sub(r"\\fontsize{\d+}", "", title)
    title = title.replace("$timescale", timescale)
    title = title.replace("$node_alias", node.get("ALIAS", ""))
    title = title.replace("$node_name", node.get("NAME", ""))
    title = re.sub(r"\"", "", title)
    fig.suptitle(title, fontsize=fontsize, y=0.98)


def plot_copyright(conf, fontsize=8):
    if conf is None:
        conf = {}
    fig = plt.gcf()
    date = datetime.today().strftime("%Y")
    title = ""
    if conf.get("COPYRIGHT"):
        title += f'\N{COPYRIGHT SIGN} {conf.get("COPYRIGHT")} {date}'
    if conf.get("COPYRIGHT2", " "):
        title += f' + {conf.get("COPYRIGHT2")} {date}'
    fig.text(0.5, 0.9, title, horizontalalignment="center", fontsize=fontsize)
