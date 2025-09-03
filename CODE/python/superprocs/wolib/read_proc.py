import glob
import os
import re
import time

import numexpr as ne
import numpy as np
import pendulum

from wolib.config import WEBOBS
from wolib.config import read_config
from wolib.grids import Grid
from wolib.grids import Node
from wolib.readers import read_dsv
from wolib.readers import read_miniseed
from wolib.utils import get_timescale
from wolib.utils import str_to_float
from wolib.utils import str_to_timestamp
from wolib.utils import update_db_status


def timestamps(start_timestamp, npts, sampling_rate):
    return np.arange(npts) / sampling_rate + start_timestamp


def stream_to_array(st):
    for tr in st:
        if np.ma.is_masked(tr):
            tr.data = tr.data.filled(np.nan)
    data = np.array([tr.data for tr in st])
    data = np.transpose(data)
    sr = st[0].stats.sampling_rate
    time = timestamps(st[0].stats.starttime.timestamp, data.shape[0], sr)
    error = np.ones(shape=data.shape)
    return [time, data, error]


def set_status(proc):
    # computes timescale parameters (data indexes and status)
    for node in proc.nodes:
        node.k1 = None
        node.ke = None
        k = np.empty(0)

        # last: status of the station, checking whether the channels have at least
        # one piece of data that is less than LAST_DELAY old
        last = 0

        # samp: data completeness, number of samples over the reference period
        # compared to the sampling specified in ACQ_RATE from the node
        samp = 0

        time = node.time
        data = node.data
        nstart = str_to_timestamp(node.INSTALL_DATE, nan=True)
        nend = str_to_timestamp(node.END_DATE, nan=True)
        nlast = getattr(node, "LAST_DELAY", 0)
        tlim1 = proc.start_time.timestamp() if proc.start_time else np.nan
        tlim2 = proc.end_time.timestamp() if proc.end_time else np.nan
        nc = np.shape(data)[1]

        if np.isfinite(tlim1) or np.isfinite(tlim2):
            k = np.where((time >= tlim1) & (time <= tlim2))[0]

        if k.any():
            node.k1 = k[0]
            node.ke = k[-1]
            xlim1 = np.nanmax([tlim1, nstart])
            xlim2 = np.nanmin([tlim2 - nlast, nend])
            ked = np.where(time[k] <= xlim2)[0]
            acq_rate = getattr(node, "ACQ_RATE", None)
            for ch in range(nc):
                if acq_rate:
                    valid = np.where(
                        (time[k] >= xlim1)
                        & (time[k] <= xlim2)
                        & (np.isfinite(data[k, ch]))
                    )
                    samp += 100 * len(valid[0]) * acq_rate / np.abs(xlim2 - xlim1)
                if ked.any():
                    # ked[-1] is the last sample time before LAST_DELAY
                    if np.isfinite(data[ked[-1], ch]):
                        last = last + 1
            node.samp = round(samp / nc, 2)
            node.last = round(100 * last / nc)
        node.k = k
        node.tlim = [tlim1, tlim2]
        update_db_status(proc, node.fullid)


def calib(time, data, clb):
    dates = {}
    nv = sorted(set(v["nv"] for v in clb.values()))
    for n in nv:
        dates[n] = [v["dt"] for v in clb.values() if n == v["nv"]]
        dates[n].append(np.inf)

    for v in clb.values():
        n = v["nv"]
        cn = int(n) - 1
        for ii in range(len(dates[n]) - 1):
            if v["dt"] == dates[n][ii]:
                # print(f'Calibration of {v["nm"]} between {dates[n][ii]} and {dates[n][ii+1]}.')
                k = (time >= dates[n][ii]) & (time < dates[n][ii + 1])
                clip = (data[k, cn] < v["vn"]) | (data[k, cn] > v["vm"])
                data[clip, cn] = np.nan
                x = data[k, cn]
                if isinstance(str_to_float(v["et"], verbose=False), float):
                    data[k, cn] = x * str_to_float(v["et"])
                else:
                    formula = re.sub(r"[^\w\d\.+-\/\*^xE\ \(\)]", "", v["et"])
                    data[k, cn] = ne.evaluate(formula)
                if isinstance(v["ga"], float) and isinstance(v["of"], float):
                    data[k, cn] = data[k, cn] * v["ga"] + v["of"]


def get_data_stats(dt, node):
    chs_cal = node.CLB.values()
    stats = {}
    for c, cal in enumerate(chs_cal):
        channel = cal["nm"]
        stats[channel] = {"unit": cal["un"]}
        stats[channel].update({"min": np.nan, "max": np.nan, "mean": np.nan})
        stats[channel].update({"last_time": -1, "last_data": np.nan})
        data = node.data[:, c]
        valid = np.isfinite(data)
        if valid.any():
            stats[channel].update({"min": np.nanmin(data)})
            stats[channel].update({"max": np.nanmax(data)})
            stats[channel].update({"mean": np.nanmean(data)})
            stats[channel].update({"last_data": data[valid][-1]})
            stats[channel].update({"last_time": dt[valid][-1]})
    return stats


def get_last_data(stats):
    last_time = -np.inf
    last_data = np.nan
    for k, v in stats.items():
        if v["last_time"] > last_time:
            last_time = v["last_time"]
            last_data = v["last_data"]
    return (last_time, last_data)


class Proc(Grid):
    def __init__(self, name, nodes=None):
        super().__init__(name, nodes)
        self.start_time = None
        self.end_time = None
        self.NOW = pendulum.now()
        self.SELFREF = f"PROC.{name}"
        self.OUTDIR = os.path.join(WEBOBS["ROOT_OUTG"], self.SELFREF)
        self.config_file = os.path.join(WEBOBS["PATH_PROCS"], name, f"{name}.conf")
        self.PATH_STATUS_DB = os.path.join(WEBOBS["PATH_DATA_DB"], "NODESSTATUS.db")

    def read_proc(self):
        name = self.name
        conf = read_config(self.config_file)
        for key, val in conf.items():
            key = key.replace(f"PROC.{self.name}.", "")  # For request mode
            setattr(self, key, val)
        root_dir = os.path.join(WEBOBS["PATH_GRIDS2NODES"], "**")
        nodes = []
        for path in glob.glob(root_dir, recursive=False):
            fullname = os.path.normpath(path).split(os.sep)[-1]
            if os.path.isdir(path) and re.match(f"PROC.{name}", fullname):
                nodes.append(fullname.split(".")[-1])

        tz = conf.get("TZ", "UTC")
        if bool(re.fullmatch(r"[+-]?0", tz)):
            tz = "UTC"
        try:
            pendulum.set_local_timezone(pendulum.timezone(tz))
        except pendulum.tz.exceptions.InvalidTimezone:
            print(
                f"Can't read {name} Proc. Please select a valid timezone such as 'UTC' or 'Europe/Paris'."
            )
            exit()

        for node_id in nodes:
            fullid = f"{self.SELFREF}.{node_id}"
            node = Node(fullid)
            self.add_node(node)

    def read_data(self, timescale):
        self.start_time, self.end_time, ts = get_timescale(timescale)
        self.timescale = ts
        start = time.time()
        for node in self.nodes:
            rawformat = node.RAWFORMAT
            if rawformat in ["miniseed", "seedlink", "fdsnws-dataselect"]:
                st_node = read_miniseed(self, node.fullid, timescale)
                if st_node:
                    t, d, e = stream_to_array(st_node)
                    node.time = t
                    node.data = d
                    node.error = e
                    calib(t, d, node.CLB)
            if rawformat in ["ascii", "dsv"]:
                read_dsv(self, node.fullid, timescale)
        duration = round(time.time() - start, 1)
        print(f"Fetch data for timescale '{ts}' in:", duration, "seconds")
        set_status(self)

    def set_outdir(self, outdir):
        self.OUTDIR = outdir

    def set_config_file(self, path):
        self.config_file = path

    def __repr__(self):
        attrs = ", ".join(f"\n  {k}={repr(v)}" for k, v in self.__dict__.items())
        return f"Proc({attrs}\n)"


def list_proc_names(proc_name):
    root_dir = os.path.join(WEBOBS["PATH_PROCS"], "**")
    procs = []
    for path in glob.glob(root_dir, recursive=False):
        name = os.path.normpath(path).split(os.sep)[-1]
        if os.path.isdir(path) and re.search(proc_name, name):
            procs.append(name)
    return procs


def read_procs(proc_names):
    if not isinstance(proc_names, list):
        proc_names = list_proc_names(proc_names)

    procs = {}
    for name in proc_names:
        procs.update({name: Proc(name)})
    return procs


if __name__ == "__main__":
    # cd ~/webobs/CODE/python/superprocs
    # python3 -m wolib.read_proc

    # result = Proc("GEOSCOPE")
    # result = read_procs(".*")
    result = read_procs(["GEOSCOPE", "HYPOWI"])
    print(result)
