import numpy as np
from scipy import signal

from wolib.utils import graph_parameters
from wolib.utils import is_ok
from wolib.utils import str_to_float
from wolib.utils import str_to_int


def filter_signal(data, proc):
    # removes flat intervals
    if hasattr(proc, "FLAT_IS_NAN") and is_ok(proc.FLAT_IS_NAN):
        data = data.astype(float)
        k = np.argwhere(np.diff(data) == 0)
        data[k + 1] = np.nan
        print("FLAT_IS_NAN")

    # cleanpicks filters
    data = cleanpicks(data, proc)

    # median filter
    kernel_size = str_to_int(getattr(proc, "MEDIAN_FILTER_SAMPLES", ""))
    if isinstance(kernel_size, int) and kernel_size > 1:
        if kernel_size % 2 == 0:
            print(f"Even kernel size {kernel_size} resized to {kernel_size + 1}")
            kernel_size = kernel_size + 1
        data = signal.medfilt(data, kernel_size)
    return data


def filter_node_data(proc, node, timescale):
    result = []
    data = node.data
    graph = graph_parameters(proc)
    down_factor = str_to_int(graph[timescale].get("decimate"))
    for c in range(data.shape[1]):
        fdata = filter_signal(data[:, c], proc)
        fdata = decimate(fdata, down_factor)
        result.append(fdata)
    node.data = np.array(result).T
    return decimate(node.time, down_factor)


def cleanpicks(data, proc):
    # Removes picks data.
    # Replaces by NaN the 1% of min and max data from vector data,
    # using a median-style filter and after removing a linear trend.

    filter1 = "PICKS_CLEAN_PERCENT"
    n1 = str_to_float(getattr(proc, "PICKS_CLEAN_PERCENT", ""))

    filter2 = "PICKS_CLEAN_STD"
    n2 = str_to_float(getattr(proc, "PICKS_CLEAN_STD", ""))

    # removes linear trend
    if (n1 or n2) and len(data) > 1:
        data = detrend(data)

    # median min/max filter
    if n1:
        if n1 < 0 or n1 >= 100:
            print(f"Input must be a percentage >= 0 and < 100 for filter {filter1}")
        else:
            data = data.astype(float)
            mn = np.nanmin(data) * (100 + n1) / 100
            mx = np.nanmax(data) * (100 - n1) / 100
            data[(data < mn) | (data > mx)] = np.nan

    # STD filter
    if n2:
        if n2 <= 0:
            print(f"Input must be a positive number for filter {filter2}")
        else:
            data = data.astype(float)
            data[np.abs(data) > n2 * np.nanstd(data)] = np.nan
    return data


def decimate(data, factor):
    if isinstance(factor, int) and factor > 1:
        data = np.array(data[::factor])
    return data


def detrend(data):
    nan_mask = np.isnan(data)
    data_valid = data[~nan_mask]
    if data_valid.any():
        data[~nan_mask] = signal.detrend(data_valid)
    return data


def smooth(data, N):
    if isinstance(N, int) and N > 1:
        x = np.copy(data)
        nan_mask = np.isnan(x)
        data_valid = x[~nan_mask]
        if data_valid.any():
            window = np.ones(N) / N
            x[~nan_mask] = signal.filtfilt(window, 1, data_valid)
    return x
