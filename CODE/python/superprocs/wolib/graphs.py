import getpass
import os
import re
import sys

import matplotlib.pyplot as plt
import numpy as np
import pendulum
import roman
from matplotlib.patches import Rectangle
from matplotlib.ticker import FuncFormatter

from wolib.config import WEBOBS
from wolib.read_proc import get_last_data
from wolib.utils import fmt_float
from wolib.utils import get_events
from wolib.utils import is_ok
from wolib.utils import timestamp_to_date


def fmt_local_hour_minute(x, pos):
    return timestamp_to_date(x).strftime("%H:%M:%S")


def fmt_local_month_day(x, pos):
    return timestamp_to_date(x).strftime("%m/%d")


def get_date_formatter(timescale):
    if re.search("[wmy]", timescale):
        date_form = FuncFormatter(fmt_local_month_day)
    else:
        date_form = FuncFormatter(fmt_local_hour_minute)
    return date_form


def get_figure_ratio():
    width, height = plt.gcf().get_size_inches()
    return min(width, height) / max(width, height)


def get_paper_size(proc):
    # if PAPER_SIZE is defined, reformats paper size and figure position
    psz = getattr(proc, "PAPER_SIZE", "").split(",")
    if len(psz) == 2:
        if all(x.replace(".", "", 1).isdigit() and float(x) > 0 for x in psz):
            return float(psz[0]), float(psz[1])


def plot_logos(proc):
    if hasattr(proc, "LOGO_FILE") and hasattr(proc, "LOGO_HEIGHT"):
        plot_logo(name=proc.LOGO_FILE, size=proc.LOGO_HEIGHT, pos="left")
    if hasattr(proc, "LOGO2_FILE") and hasattr(proc, "LOGO2_HEIGHT"):
        plot_logo(name=proc.LOGO2_FILE, size=proc.LOGO2_HEIGHT, pos="right")


def plot_logo(name, size=None, pos="right"):
    if name:
        if not os.path.exists(name):
            print(f"This logo file does not exist: {name}")
            return
        if not size:
            size = 0.04
        logo = plt.imread(name)
        # logo_height, logo_width, _ = logo.shape
        fig = plt.gcf()
        ratio = get_figure_ratio()
        ax_h = float(size) * ratio
        ax_w = float(size) * ratio
        if pos == "left":
            rect, anchor = ((0.05, 0.99 - ax_h, ax_w, ax_h), "NE")
        else:
            rect, anchor = ((0.95 - ax_w, 0.99 - ax_h, ax_w, ax_h), "NW")
        logo_axis = fig.add_axes(rect, anchor=anchor)
        logo_axis.imshow(logo)
        logo_axis.axis("off")


def plot_title(title, proc, node, fontsize=10):
    fig = plt.gcf()
    fsize = re.search(r"\\fontsize{(\d+)}", title)
    fsize = fsize.group(1) if fsize else fontsize
    title = re.sub(r"\\fontsize{\d+}", "", title)
    title = re.sub(r"(\w)\$", r"\1 $", title)
    if proc.request:
        title = title.replace(r"($timescale)", "")
    else:
        title = title.replace(r"$timescale", getattr(proc, "timescale", ""))
    title = title.replace(r"$NAME", getattr(proc, "NAME", ""))
    title = title.replace(r"$node_alias", getattr(node, "ALIAS", ""))
    title = title.replace(r"$node_name", getattr(node, "NAME", ""))
    title = re.sub(r"\"", "", title)
    fig.suptitle(title, size=fsize, y=0.98)


def plot_time_axis_label(ax, t1, t2, fontsize=None, dist=0.04):
    """Plot the time axis label of the subplot."""
    t1 = t1.format("YYYY-MM-DD HH:mm:ss")
    t2 = t2.format("YYYY-MM-DD HH:mm:ssZ z")
    title = f"\\textbf{{{t1} -- {t2}}}"
    box = ax.get_position()
    y = -dist / (box.y1 - box.y0)
    title = ax.text(0.5, y, title, ha="center", va="center", size=fontsize)
    title.set_transform(ax.transAxes)


def plot_copyright(proc, fontsize=None):
    date = pendulum.now().year
    title = ""
    if hasattr(proc, "COPYRIGHT"):
        title += f"\N{COPYRIGHT SIGN} {proc.COPYRIGHT} {date}"
    if hasattr(proc, "COPYRIGHT2"):
        title += f" + {proc.COPYRIGHT2} {date}"
    plt.figtext(0.5, 0.93, title, ha="center", size=fontsize)


def plot_infos(stats, fontsize=None):
    fontsize = fontsize if fontsize else plt.rcParams["font.size"] - 1
    last_time, _ = get_last_data(stats)
    date = timestamp_to_date(last_time) if last_time > 0 else ""
    text = f"""Last data:\n {date}\n (min $|$ avr $|$ max)"""
    infos = ""
    for n, (cha, v) in enumerate(stats.items(), 1):
        last = fmt_float(v["last_data"])
        mi = fmt_float(v["min"])
        me = fmt_float(v["mean"])
        ma = fmt_float(v["max"])
        infos += f'{n} {cha} = {last} {v["unit"]} ({mi} $|$ {me} $|$ {ma})\n'
    plt.subplots_adjust(bottom=plt.gcf().subplotpars.bottom + 0.05)
    plt.figtext(0.05, 0.09, text, size=fontsize, va="top", ha="left")
    plt.figtext(0.3, 0.09, infos, size=fontsize, va="top", ha="left")


def plot_timestamp(filename, proc, fontsize):
    if not fontsize:
        return
    selfref = getattr(proc, "SELFREF", "")
    now = getattr(proc, "NOW", pendulum.now()).isoformat()
    user = getpass.getuser()
    auth = f"{user}@{os.uname().nodename} - {sys.argv[0]}"
    ryear = roman.toRoman(pendulum.now().year)
    text = f"{selfref} / {filename} / {auth} / {now} / WebObs {ryear}"
    plt.figtext(0.5, 0.01, text, color="gray", size=fontsize, ha="center")


def plot_nodata(ax, fontsize=9):
    xlim = ax.get_xlim()
    ylim = ax.get_ylim()
    cx = (xlim[0] + xlim[1]) / 2
    cy = (ylim[0] + ylim[1]) / 2
    ax.text(cx, cy, "No data", ha="center", va="center", size=fontsize, color="red")


def plot_status(node, fontsize=None):
    samp = node.samp
    last = node.last
    tlim2 = node.tlim[1]
    if np.isfinite(tlim2):
        tlim2 = timestamp_to_date(tlim2).strftime("%d-%B-%Y %H:%M:%S%z")
    title = rf"{tlim2} - Status {last}\% - Sampling {samp}\%"
    plt.figtext(0.5, 0.95, title, ha="center", size=fontsize)


def plot_events(event_files):
    events_html = []
    events = get_events(event_files.split(","))
    fig = plt.gcf()
    #  Coordinate origin at top left
    fig_height = fig.bbox.height.astype(int)
    for ax in fig.axes:
        if ax.get_label().startswith("waveform"):
            y_min, y_max = ax.get_ylim()
            trans = ax.transData.transform
            for event in events:
                if not event["dt1"] or not event["dt2"]:
                    continue
                rect = Rectangle(
                    (event["dt1"].timestamp(), y_min),
                    event["dt2"].timestamp() - event["dt1"].timestamp(),
                    y_max - y_min,
                    lw=event["lw"],
                    edgecolor=event["color"],
                    facecolor=event["color"],
                    alpha=0.5,
                )
                ax.add_patch(rect)
                x, y = rect.get_xy()
                width = rect.get_width()
                height = rect.get_height()

                # Top left corner coordinates
                x_top_left, y_top_left = trans((x, y + height)).astype(int)
                y_top_left = fig_height - y_top_left

                # Bottom right corner coordinates
                x_bottom_right, y_bottom_right = trans((x + width, y)).astype(int)
                y_bottom_right = fig_height - y_bottom_right

                sn = event["nam"]
                sc = f'<br><i>({event["com"]})</i>'
                date1 = event["dt1"].strftime("%d-%B-%Y %H:%M")
                date2 = event["dt2"].strftime("%d-%B-%Y %H:%M")
                color = event["color"]
                ev = f"'<i>start:</i> {date1}<br><i>end:</i> {date2}{sc}',CAPTION,'{sn}',BGCOLOR,'{color}',CAPCOLOR,'#000000',FGCOLOR,'#EEEEEE'"
                co = f"{x_top_left},{y_top_left},{x_bottom_right},{y_bottom_right}"
                html = f'<AREA onMouseOut="nd()" onMouseOver="overlib({ev})" shape=rect coords="{co}">\n'
                events_html.append(html)
    return events_html


def create_events_map_files(events_html, filename, proc):
    outg = os.path.join(get_graphs_out_dir(proc))
    os.makedirs(outg, exist_ok=True)
    path = os.path.join(outg, filename)
    with open(f"{path}.map", "w", newline="") as mapf:
        for html in reversed(events_html):
            mapf.write(html)


def get_graphs_out_dir(proc):
    outdir = getattr(proc, "OUTDIR", "")
    if hasattr(proc, "EVENTS"):
        outg = WEBOBS.get("PATH_OUTG_EVENTS", "")
        pout = os.path.join(outdir, outg, proc.EVENTS)
    else:
        outg = WEBOBS.get("PATH_OUTG_GRAPHS", "")
        pout = os.path.join(outdir, outg)
    return pout


def save_plot(filename, proc):
    outg = os.path.join(get_graphs_out_dir(proc))
    os.makedirs(outg, exist_ok=True)
    path = os.path.join(outg, filename)
    plt.savefig(f"{path}.png", dpi=getattr(proc, "PPI_PNG", 100))
    plt.savefig(f"{path}.jpg", dpi=getattr(proc, "PPI_JPG", 10))
    if is_ok(getattr(proc, "PDFOUTPUT", None)):
        plt.savefig(f"{path}.pdf", dpi=getattr(proc, "PPI_PDF", 300))
    if is_ok(getattr(proc, "SVGOUTPUT", None)):
        plt.savefig(f"{path}.svg", dpi=getattr(proc, "PPI_SVG", 300))


def channel_height_ratios(channels_str, max_channels):
    # Interprets the char string and return a dict
    # with the height ratio of each channel
    # Examples:
    # "1,2,3" means channels 1,2 and 3 on 3 equal size subplots
    # "2,,,1,3,10,11,," means channels 2, 1, 3, 10 and 11 with channel 2
    # three times higher and channel 11 two times higher in size than others.

    if not channels_str:
        return dict.fromkeys(range(1, max_channels + 1), 1)

    pos = 1
    channels_list = channels_str.split(",")
    nc = int(max(channels_list))
    channels = dict.fromkeys(range(1, nc + 1), 1)
    for x in channels_list[1:]:
        if x.isdigit():
            pos += 1
        elif x == "":
            channels[pos] += 1
    return channels
