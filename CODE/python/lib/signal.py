import numpy as np
from scipy.signal import detrend


def filter_signal(data):
    nan_mask = np.isnan(data)
    data_valid = data[~nan_mask]
    if data_valid.any():
        data[~nan_mask] = detrend(data_valid)
    return data
