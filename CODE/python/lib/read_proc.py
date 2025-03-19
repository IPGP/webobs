import glob
import os
import re

import numpy as np
from obspy import Stream, Trace, UTCDateTime, read
from obspy.clients.fdsn import Client as Client_FDSN
from obspy.clients.fdsn.header import FDSNNoDataException
from obspy.clients.seedlink import Client as Client_Seedlink

from config import WEBOBS, print_config, read_config
from grids import read_node


def list_proc_names(proc_name):
    # TODO test user auth
    root_dir = os.path.join(WEBOBS["PATH_PROCS"], "**")
    procs = []
    for path in glob.glob(root_dir, recursive=False):
        name = os.path.normpath(path).split(os.sep)[-1]
        if os.path.isdir(path) and re.search(proc_name, name):
            procs.append(name)
    return procs


def stream2array(st):
    time = st[0].times()
    time = np.reshape(time, (-1, 1))
    data = np.array([tr.data.filled(np.nan) for tr in st])
    data = np.transpose(data)
    error = np.ones(shape=data.shape)
    return [time, data, error]


def read_data(proc, start_time, end_time):
    # delta = int((end_time - start_time).total_seconds())
    start_time = UTCDateTime(start_time)
    end_time = UTCDateTime(end_time)
    data = {"t": [], "d": [], "e": []}
    for node in proc["conf"]["NODESLIST"]:
        name = f"PROC.{proc['name']}."
        rawformat = proc["nodes"][node].get(name + "RAWFORMAT")
        rawdata = proc["nodes"][node].get(name + "RAWDATA")
        net = proc["nodes"][node].get(name + "FDSN_NETWORK_CODE")
        sta = proc["nodes"][node].get(name + "FID")
        clb = proc["nodes"][node]["CLB"]
        stnode = Stream()
        for val in clb.values():
            st = Stream()
            bulk = [(net, sta, val.get("lc"), val.get("nm"), start_time, end_time)]
            if rawformat in ["miniseed", "seedlink", "fdsnws-dataselect"]:
                try:
                    if rawformat == "miniseed":
                        st = read("test.mseed")
                    elif rawformat == "seedlink":
                        client = Client_Seedlink(rawdata)
                        st = client.get_waveforms_bulk(bulk)
                    elif rawformat == "fdsnws-dataselect":
                        client = Client_FDSN(rawdata)
                        st = client.get_waveforms_bulk(bulk)
                except (FDSNNoDataException, OSError):
                    st = Stream([Trace()])
                    pass
                st = st.trim(starttime=start_time, endtime=end_time - 1, pad=True)
                st = Stream([Trace(tr.data.astype("float64")) for tr in st])
            stnode += st.merge()
        if stnode:
            t, d, e = stream2array(stnode)
            data["d"].append(d)
            data["t"].append(t)
            data["e"].append(e)
    proc["data"] = data
    return proc


def read_procs(proc_names):
    if not isinstance(proc_names, list):
        proc_names = list_proc_names(proc_names)

    procs = {}
    for proc_id in proc_names:
        procs.update({proc_id: read_proc(proc_id)})
    return procs


def read_proc(proc_id):
    proc = {"name": proc_id}
    conf = os.path.join(WEBOBS["PATH_PROCS"], proc_id, f"{proc_id}.conf")
    infos = read_config(conf)
    root_dir = os.path.join(WEBOBS["PATH_GRIDS2NODES"], "**")
    nodes = []
    for path in glob.glob(root_dir, recursive=False):
        name = os.path.normpath(path).split(os.sep)[-1]
        if os.path.isdir(path) and re.match(f"PROC.{proc_id}", name):
            nodes.append(name.split(".")[-1])
    infos["NODESLIST"] = nodes
    proc["conf"] = infos
    proc["nodes"] = {}
    for node in nodes:
        proc["nodes"].update(read_node(node))
    return proc


if __name__ == "__main__":
    result = read_proc("GEOSCOPE")
    # result = read_procs(".*")
    result = read_procs(["GEOSCOPE", "HYPOWI"])
    print_config(result)
#    with open("/tmp/test.json", "w") as outfile:
#        json.dump(result, outfile, indent=4)
