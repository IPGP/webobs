import getpass
import os
import re
import sqlite3
from datetime import datetime
from datetime import timedelta

import numpy as np
import pendulum
import roman


def is_ok(value):
    if isinstance(value, str) and value.lower() in ("1", "y", "yes", "ok", "on", "oui"):
        return 1
    else:
        return 0


def fmt_float(x, p=5):
    return np.format_float_positional(x, precision=p, fractional=False, sign=True)


def str_to_int(x, nan=False, verbose=False):
    try:
        return int(x)
    except (TypeError, ValueError):
        if nan:
            return np.nan
        elif verbose:
            print(f"Unable to convert: {x} to int")


def str_to_float(x, nan=False, verbose=False):
    try:
        return float(x)
    except (TypeError, ValueError):
        if nan:
            return np.nan
        elif verbose:
            print(f"Unable to convert: {x} to float")


def str_to_date(x, timezone=None, nan=False, verbose=False):
    try:
        if timezone is None:
            timezone = pendulum.local_timezone()
        return pendulum.parse(x, tz=timezone)
    except (TypeError, ValueError):
        if nan:
            return np.nan
        elif verbose:
            print(f"Unable to parse string: {x} to datetime")


def str_to_timestamp(x, timezone=None, nan=False, verbose=False):
    try:
        if timezone is None:
            timezone = pendulum.local_timezone()
        timestamp = pendulum.parse(x, tz=timezone).timestamp()
        return np.array(timestamp).astype(float)
    except (TypeError, ValueError):
        if nan:
            return np.nan
        elif verbose:
            print(f"Unable to convert: {x} to timestamp")


def timestamp_to_date(x, utc=False, nan=False, verbose=False):
    try:
        date = pendulum.from_timestamp(x)
        if utc:
            return date.in_timezone(pendulum.timezone("UTC"))
        else:
            return date.in_timezone(pendulum.local_timezone())
    except (TypeError, ValueError):
        if nan:
            return np.nan
        elif verbose:
            print(f"Unable to convert: {x} to datetime")


def safe_eval(expression):
    # Limit expression size
    expression = expression[:200]
    # Removes any invalid characters
    expression = re.sub(r"[^\d\.+-\/\*^xE\ \(\)]", "", expression)
    return eval(expression)


def get_timescale(code, timezone=None):
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
        human_unit = "second"
    elif "n" in code:
        duration = timedelta(minutes=num)
        human_unit = "minute"
    elif "h" in code:
        duration = timedelta(hours=num)
        human_unit = "hour"
    elif "d" in code:
        duration = timedelta(days=num)
        human_unit = "day"
    elif "w" in code:
        duration = timedelta(weeks=num)
        human_unit = "week"
    elif "m" in code:
        duration = timedelta(days=30 * num)
        human_unit = "month"
    elif "y" in code:
        duration = timedelta(days=365.25 * num)
        human_unit = "year"
    else:
        print("invalid timescale string")
        exit()

    if timezone is None:
        timezone = pendulum.local_timezone()
    end_time = pendulum.now(tz=timezone)
    start_time = end_time - duration
    human_unit = f"{num} {human_unit}" if num <= 1 else f"{num} {human_unit}s"
    return (start_time, end_time, human_unit)


def update_db_status(proc, node_id):
    """Writes NODE status in the database from associated GRID (PROC or VIEW)"""

    if not hasattr(proc, "PATH_STATUS_DB"):
        return

    database = proc.PATH_STATUS_DB
    node = proc.find_node(node_id)
    comment = getattr(node, "comment", "")
    name = node.fullid
    sta = node.last
    acq = node.samp
    ke = node.ke
    if ke:
        ts = timestamp_to_date(node.time[ke], nan=False)

    create_table = """
        CREATE TABLE IF NOT EXISTS status (
            NODE varchar(150) PRIMARY KEY,
            STA int,
            ACQ int,
            TS timestamp,
            UPDATED timestamp,
            COMMENT varchar(1000)
        )
        """

    try:
        with sqlite3.connect(database) as conn:
            cursor = conn.cursor()
            # Create status database if not exists
            cursor.execute(create_table)
            # Updating
            if name and sta and acq and ts:
                values = f"'{name}', '{sta}', '{acq}', '{ts}', CURRENT_TIMESTAMP, '{comment}'"
                cursor.execute(f"REPLACE INTO status VALUES ({values})")
            conn.commit()
    except Exception as e:
        print(e)


def graph_parameters(proc):
    graph = {}
    timescalelist = getattr(proc, "TIMESCALELIST", "06h,24h,01w").split(",")
    decimatelist = getattr(proc, "DECIMATELIST", "1,1,1").split(",")
    cumulatelist = getattr(proc, "CUMULATELIST", "1,1,1").split(",")
    datestrlist = getattr(proc, "DATESTRLIST", "-1,-1,-1").split(",")
    markersizelist = getattr(proc, "MARKERSIZELIST", "1,1,1").split(",")
    linewidthlist = getattr(proc, "LINEWIDTHLIST", "1,1,1").split(",")
    statuslist = getattr(proc, "STATUSLIST", "1,1,1").split(",")
    for t, ts in enumerate(timescalelist):
        graph[ts] = {}
        try:
            graph[ts]["decimate"] = str_to_int(decimatelist[t])
            graph[ts]["cumulate"] = cumulatelist[t]
            graph[ts]["datestr"] = datestrlist[t]
            graph[ts]["markersize"] = markersizelist[t]
            graph[ts]["linewidth"] = linewidthlist[t]
            graph[ts]["status"] = statuslist[t]
        except IndexError:
            pass
    return graph


def get_events(filepaths):
    events = []
    for path in filepaths:
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#"):
                    data = line.split("|")
                    event = {}
                    event["dt1"] = str_to_date(data[0])
                    event["dt2"] = str_to_date(data[1])
                    event["lw"] = str_to_float(data[2])
                    event["color"] = data[3]
                    event["nam"] = data[4]
                    event["com"] = data[5]
                    event["out"] = 0
                    events.append(event)
    return events


def csv_comments(filename, title, proc, node_id):
    node = proc.find_node(node_id)
    comments = []
    comments.append("#" * 80)
    comments.append("# " + title + "\n#")
    comments.append(
        f'# PROC: {{{getattr(proc, "SELFREF", "")}}} {getattr(proc, "NAME", "")}'
    )
    subtitle = f"{node.ALIAS}: {node.NAME} {{{node_id}}}"
    comments.append(f"# TITLE: {subtitle}")
    comments.append(f"# FILENAME: {filename}.txt")
    if proc.start_time and proc.end_time:
        date1 = proc.start_time.strftime("%d-%b-%Y %H:%M:%S")
        date2 = proc.end_time.strftime("%d-%b-%Y %H:%M:%S")
        comments.append(f'# TIMESPAN: from "{date1}" to "{date2}"')
    else:
        comments.append("# TIMESPAN: all data")
    comments.append("#")
    comments.append("#")
    username, hostname = (getpass.getuser(), os.uname().nodename)
    date = datetime.now().strftime("%d-%b-%Y %H:%M:%S")
    ryear = roman.toRoman(datetime.now().year)
    comments.append(f"# CREATED: {date} by {username}@{hostname}")
    comments.append(f'# COPYRIGHT: {ryear}, {getattr(proc, "COPYRIGHT", "")}')
    comments.append("#" * 80 + "\n#")
    header = ["#yyyy mm dd HH MM SS"]
    header.extend([f'{v["nm"]}({v["un"]})' for v in node.CLB.values()])
    comments.append(" ".join(header))
    return comments


def export_csv(filename, title, proc, node_id):
    from .config import get_out_dir

    outg = os.path.join(get_out_dir(proc))
    os.makedirs(outg, exist_ok=True)
    path = os.path.join(outg, filename)
    node = proc.find_node(node_id)
    data = node.data
    time = node.time
    tnan = np.full(6, np.nan).tolist()
    with open(f"{path}.txt", "w", newline="") as csvfile:
        for comment in csv_comments(filename, title, proc, node_id):
            csvfile.write(comment + "\n")
        if np.isnan(data).all():
            return
        for t, d in zip(time, data):
            if np.isfinite(t):
                t = datetime.fromtimestamp(t)
                t = [t.year, t.month, t.day, t.hour, t.minute, t.second]
            else:
                t = tnan
            csvfile.write(" ".join(str(x) for x in t + d.tolist()) + "\n")
