import re

import numpy as np
from csiio import CSIDataFile
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
from wolib.utils import str_to_float
from wolib.utils import str_to_timestamp
from wolib.utils import timestamp_to_date


def get_stream_sampling_rates(streams):
    return set(tr.stats.sampling_rate for st in streams for tr in st)


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
                st = read(rawdata)
            elif rawformat == "seedlink":
                client = Client_Seedlink(rawdata)
                st = client.get_waveforms(net, sta, loc, cha, start, end)
            elif rawformat == "fdsnws-dataselect":
                client = Client_FDSN(rawdata)
                st = client.get_waveforms(net, sta, loc, cha, start, end)
        except (FDSNNoDataException, OSError) as ex:
            st = Stream(Trace(data=np.full(shape=2, fill_value=np.nan)))
            print(net, sta, loc, cha, start, end, ex)
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

    if st_node:
        t, d, e = stream_to_array(st_node)
        calib(t, d, node.CLB)
        node.time = t
        node.data = d
        node.error = e
    else:
        print("No data")


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

    calib(t, d, node.CLB)

    node.time = decimate(t, data_decim)
    node.data = decimate(d, data_decim)
    node.error = decimate(e, data_decim)


def read_campbell(proc, node_id, timescale):
    print("Reading Campbell Scientific data files")
    node = proc.find_node(node_id)
    reader = CSIDataFile(node.RAWDATA)
    reader.read()
    print(reader.data.head())

    t = reader.data.index.values.astype("int64")
    d = reader.data.values.astype("float")

    calib(t, d, node.CLB)

    node.time = t
    node.data = d
    node.error = np.ones(shape=node.data.shape)
