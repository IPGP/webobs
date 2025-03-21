import re
from datetime import datetime, timedelta

import matplotlib.pyplot as plt
import numpy as np
from scipy.signal import detrend


def timescale(code):
    """Return a tuple of datetime objects from a duration until now.

    Args:
        code (str): A duration until now of the form xxT, where xx is a number and
        T a letter indicating the time base among (s, n, h, d, w, m, y).
        For example, 06h for six hours, 10n for ten minutes, ...
    """
    num = re.match(r"\d+", code)
    if not num or re.search(r"\W+", code):
        print("invalid duration")
        exit()

    num = int(num[0])
    if "s" in code:
        duration = timedelta(seconds=num)
    elif "n" in code:
        duration = timedelta(minutes=num)
    elif "h" in code:
        duration = timedelta(hours=num)
    elif "d" in code:
        duration = timedelta(days=num)
    elif "w" in code:
        duration = timedelta(weeks=num)
    elif "m" in code:
        duration = timedelta(days=30 * num)
    elif "y" in code:
        duration = timedelta(days=365 * num)
    else:
        print("invalid duration")
        exit()

    end_time = datetime.now()
    start_time = end_time - duration
    return (start_time, end_time)


def get_pernode_title(title, timescale, node):
    title = re.sub("(\w)\$", r"\1 $", title)
    title = re.sub(r"\\fontsize{\d+}", "", title)
    title = title.replace("$timescale", timescale)
    title = title.replace("$node_alias", node["ALIAS"])
    title = title.replace("$node_name", node["NAME"])
    title = re.sub(r"\"", "", title)
    return title


def plot_logo(name, size=0.05, pos="right"):
    fig = plt.figure("genplot")
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
    return fig


def filter_signal(data):
    nan_mask = np.isnan(data)
    data_valid = data[~nan_mask]
    if data_valid.any():
        data[~nan_mask] = detrend(data_valid)
    return data


if __name__ == "__main__":
    (start_time, end_time) = timescale("01h")
    print(start_time)
    print(end_time)
