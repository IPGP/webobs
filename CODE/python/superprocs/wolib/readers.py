import re

import numpy as np
from obspy import Stream
from obspy import Trace
from obspy import UTCDateTime
from obspy import read
from obspy.clients.fdsn import Client as Client_FDSN
from obspy.clients.fdsn.header import FDSNNoDataException
from obspy.clients.seedlink import Client as Client_Seedlink

from wolib.processings import decimate
from wolib.utils import is_ok
from wolib.utils import str_to_int
from wolib.utils import str_to_timestamp
from wolib.utils import timestamp_to_date


def get_stream_sampling_rates(streams):
    return set(tr.stats.sampling_rate for st in streams for tr in st)


def read_miniseed(proc, node_id, timescale):
    start_time, end_time = proc.start_time, proc.end_time
    start, end = UTCDateTime(start_time), UTCDateTime(end_time)
    node = proc.find_node(node_id)
    rawformat = node.RAWFORMAT
    rawdata = node.RAWDATA
    if rawformat == "fdsnws-dataselect":
        rawdata = re.match(r"(http[s]?:\/\/[\w.:]*)\/?", rawdata).group(1)
    net = node.FDSN_NETWORK_CODE
    sta = node.FID
    clb = node.CLB
    # checks correct definition of codes and calibration for the node
    if not net:
        print(f"No FDSN code defined for node {node_id}!")
        exit()
    if not sta:
        print(f"No FID code defined for node {node_id}!")
        exit()
    if not clb:
        print(f"No CLB file for node {node_id}! Cannot import data.")
        exit()

    st_node_dic = {}
    for val in clb.values():
        cha = val.get("nm")
        loc = val.get("lc", "--")
        st_node_dic[cha] = Stream()
        try:
            if rawformat == "miniseed":
                st = read("test.mseed")
            elif rawformat == "seedlink":
                client = Client_Seedlink(rawdata)
                st = client.get_waveforms(net, sta, loc, cha, start, end)
            elif rawformat == "fdsnws-dataselect":
                client = Client_FDSN(rawdata)
                st = client.get_waveforms(net, sta, loc, cha, start, end)
        except (FDSNNoDataException, OSError):
            st = Stream(Trace(data=np.full(shape=2, fill_value=np.nan)))
            pass
        st_node_dic[cha] += st

    sampling_rates = get_stream_sampling_rates(st_node_dic.values())
    st_node = Stream()
    for st in st_node_dic.values():
        for tr in st:
            tr.data = tr.data.astype("float64")
        if len(sampling_rates) > 1:
            st.interpolate(max(sampling_rates))
        st = st.trim(starttime=start, endtime=end - 1, pad=True)
        st_node += st.merge()
    return st_node


def read_dsv(proc, node_id, timescale):
    node = proc.find_node(node_id)
    rawformat = node.RAWFORMAT
    rawdata = node.RAWDATA
    time_cols = getattr(node, "FID_TIMECOLS", "").split(",")
    data_cols = getattr(node, "FID_DATACOLS", "").split(",")
    error_cols = getattr(node, "FID_ERRORCOLS", "").split(",")

    # Input field separator
    fs = getattr(node, "FID_FS", ";")
    header = str_to_int(getattr(node, "FID_HEADERLINE", 1))
    decimal_comma = is_ok(getattr(node, "FID_DECIMAL_COMMA", None))
    data_decim = str_to_int(getattr(node, "FID_DATA_DECIMATE", 1))
    flag_col = str_to_int(getattr(node, "FID_FLAGCOL", None))
    flag_action = getattr(node, "FID_FLAGACTION", None)

    print(rawformat, header)
    print(decimal_comma, data_decim, flag_col, flag_action)

    rows = []
    with open(rawdata, newline="") as fp:
        for row in fp:
            row = [item.strip() for item in row.split(fs)]
            row = [r for r in row]
            if fs == " ":
                row = list(filter(lambda e: e != "", row))
            rows.append(row)
    data = np.array(rows).T

    time_cols = tuple(str_to_int(x) - 1 for x in time_cols)
    selected = data[time_cols, :].T
    vectorized_str_to_timestamp = np.vectorize(str_to_timestamp)
    t = np.squeeze(vectorized_str_to_timestamp(selected))
    proc.start_time = timestamp_to_date(t[0])
    proc.end_time = timestamp_to_date(t[-1])

    data_cols = tuple(str_to_int(x) - 1 for x in data_cols)
    selected = data[data_cols, :]
    d = np.array(selected).astype("float").T

    error_cols = tuple(str_to_int(x) - 1 for x in error_cols)
    selected = data[error_cols, :]
    e = np.array(selected).astype("float").T

    node.time = decimate(t, data_decim)
    node.data = decimate(d, data_decim)
    node.error = decimate(e, data_decim)
