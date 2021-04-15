# -*-coding:Utf-8 -*

# Feature library to be used as input of machine learning algorithms
# Last update: 03/2018 - Marielle MALFANTE
# Contact: marielle.malfante@gipsa-lab.fr (@gmail.com)
# Copyright: Marielle MALFANTE - GIPSA-Lab
# Univ. Grenoble Alpes, CNRS, Grenoble INP, GIPSA-lab, 38000 Grenoble, France

# Please respect functions signature for them to work properly with the other classes feature(signal, [arg_opt1,
# arg_opt2, arg_opt3, ...])

from pathlib import  Path
import sys
path = str(Path(Path(__file__).parent.absolute()).parent.absolute())
sys.path.insert(0,path)

# External library
from math import sqrt
import numpy as np
from math import log
from math import inf
from numpy import histogram
#from scipy.stats import threshold
from python_speech_features import mfcc

def threshold(a, threshmin=None, threshmax=None, newval=0 ):

    a= np.asarray(a).copy()
    mask=np.zeros(a.shape, dtype=bool)
    if threshmin is not None:
        mask |= (a<threshmin)
    if threshmax is not None:
        mask |= (a>threshmax)
    a[mask] = newval
    return a


def energy_u(signal, arg_dict={}):
    """ Returns signal power over signal dimension (E(u))
    - signal: [s1, s2, s3, ...]
    - domain: computation domain (time, frequency, welch, cepstral)
    - E_u: signal**2 """
    return np.square(signal)


def energy(signal, arg_dict):
    """ Returns signal power
    - signal: [s1, s2, s3, ...]
    - energy"""
    E_u = arg_dict['E_u']
    return np.sum(E_u)


def u_mean(signal, arg_dict):
    """Returns u mean
    - signal: [s1, s2, s3, ...]
    - fe: signal sample frequency
    - E_u: energy_u
    - E: energy
    - u_bar"""
    E_u = arg_dict['E_u']
    E = arg_dict['E']
    u = arg_dict['u']
    if np.isclose(E,0):
        return np.inner(E_u,u)
    else:
        f = np.inner(E_u, u) / E
        if np.isfinite(f):
            return f
        else:
            print('u_mean not finite')
            return 0


def RMS_u(signal, arg_dict):
    """Returns signal RMS over u axis
    - signal: [s1, s2, s3, ...]
    - fe: signal sampling frequency
    - E_u: energy_u
    - E: energy
    - u_bar: mean value of u
    - RMS_u"""
    E_u = arg_dict['E_u']
    E = arg_dict['E']
    u_bar = arg_dict['u_bar']
    u = arg_dict['u']
    RMS_u = np.inner(np.square(u), E_u)
    if np.isclose(E,0):
        RMS_u = RMS_u - u_bar**2
    else:
        RMS_u = RMS_u/E - u_bar**2

    if np.isfinite(RMS_u):
        if RMS_u <= 0:
            return -sqrt(-RMS_u)
        else:
            return sqrt(RMS_u)
    else:
        print('RMS_u not finite')
        return 0


def energy_maximum(signal, arg_dict):
    """Returns maximum of energy in signal
    - signal: [s1, s2, s3, ...]
    - E_max"""
    E_u = arg_dict['E_u']
    return np.max(E_u)


def average_energy(signal, arg_dict):
    E = arg_dict['E']
    return E/len(signal)


def skewness(signal, arg_dict):
    """Return signal skewness
    - signal: [s1, s2, s3, ...]
    - fe: signal sampling frequency
    - E_u: energy_u
    - E: Energy
    - u_bar: u_mean
    - RMS: RMS_u
    - skewness"""
    E_u = arg_dict['E_u']
    E = arg_dict['E']
    u_bar = arg_dict['u_bar']
    RMS = arg_dict['RMS_u']
    u = arg_dict['u']
    if np.isclose(E,0) or np.isclose(RMS,0):
        sk = 0
    else:
        sk = np.inner((u-u_bar)**3, E_u) / (E*RMS**3)
    if np.isfinite(sk):
        if sk <= 0:
            return -sqrt(-sk)
        else:
            return sqrt(sk)
    else:
        print('mean skewness is not finite')
        return 0


def kurtosis(signal, arg_dict):
    """Return signal kurtosis
    - signal: [s1, s2, s3, ...]
    - fe: signal sampling frequency
    - E_u: energy_u
    - E: Energy
    - u_bar: u_mean
    - RMS: RMS over u
    - kurtosis over u axis"""
    E_u = arg_dict['E_u']
    E = arg_dict['E']
    u_bar = arg_dict['u_bar']
    RMS = arg_dict['RMS_u']
    u = arg_dict['u']
    if np.isclose(E,0) or np.isclose(RMS,0):
        kur = 0
    else:
        kur = np.inner((u-u_bar)**4, E_u) / (E*RMS**4)
    # if kur <= 0:
    #    return -sqrt(-kur)
    # else:
    if np.isfinite(sqrt(kur)):
        if kur <= 0:
            return -sqrt(-kur)
        else:
            return sqrt(kur)
    else:
        print('mean kurtosis not finite')
        return 0


def energy_std(signal, arg_dict):
    """Returns energy standard deviation
    signal: [s1, s2, s2, ...]
    E_u: energy_u
    E: energy
    energy_std"""
    E_u = arg_dict['E_u']
    E = arg_dict['E']

    if np.isclose(E,0):
        E_std = 0
    else:
        E_std = len(signal) * np.inner(E_u, E_u)/E - 1
    if np.isfinite(E_std):
        return E_std
    else:
        print('energy_std not finite')
        return 0


def energy_skewness(signal, arg_dict):
    """Returns energy skewness
    - signal: [s1, s2, s3, ...]
    - E_u: energy_u
    - E: energy
    - energy_sk"""
    E_u = arg_dict['E_u']
    E = arg_dict['E']
    E_bar = E/(len(signal)*len(signal)/2)
    if np.isclose(E_bar,0):
        E_sk = 0
    else:
        E_sk = (1/len(signal)) * np.sum((E_u/(len(signal)/2)-E_bar)**3) / E_bar**3
    if np.isfinite(E_sk):
        return E_sk
    else:
        print('Energy-skewness is not finite')
        return 0


def energy_kurtosis(signal, arg_dict):
    """Returns energy kurtosis
    - signal: [s1, s2, s3, ...]
    - E_u: energy_u
    - E: energy
    - energy_kur"""
    E_u = arg_dict['E_u']
    E = arg_dict['E']
    E_bar = E/(len(signal)**2/2)
    if np.isclose(E_bar,0):
        E_kur = 0
    else:
        E_kur = (1/len(signal)/2) * np.sum((E_u/len(signal)-E_bar)**4) / E_bar**4
    if np.isfinite(E_kur):
        return E_kur
    else:
        print('energy_kurtosis is not finite')
        return 0


def rate_attack(signal, arg_dict):
    """Returns rate of attack
    - signal: [s1, s2, s3, ...]
    - E_u: energy_u
    - roa: max(st - st-1/max_energy"""
    # NB: Goes faster than numpy implementation
    E_u = arg_dict['E_u']
    l = E_u[1:] - E_u[:-1]
    Emax = energy_maximum(signal,arg_dict)
    if np.isclose(Emax,0):
        return 0
    else:
        roa = np.max(l)/energy_maximum(signal, arg_dict)
    if np.isfinite(roa):
        return roa
    else:
        print('ROA is not finite')
        return 0


def rate_decay(signal, arg_dict):
    """Returns rate of decay
    - signal: [s1, s2, s3, ...]
    - E_u: energy_u
    - roa: min(st+1 - st/max_energy"""
    E_u = arg_dict['E_u']
    l = E_u[1:] - E_u[:-1]
    Emax = energy_maximum(signal,arg_dict)
    if np.isclose(Emax,0):
        return 0
    else:
        rod = np.min(l)/Emax
    if np.isfinite(rod):
        return rod
    else:
        print('ROD is not finite')
        return 0


def max_sur_mean(signal, arg_dict):
    mu = np.mean(signal)
    if np.isclose(mu,0):
        return np.max(signal) - mu
    else:
        f = np.max(signal) / np.mean(signal)
        if np.isfinite(f):
            return f
        else:
            print('max sur mean is not finitie')
            return 0


def n_points(signal, arg_dict):
    f = len(signal)
    if np.isfinite(f):
        return f
    else:
        print('n points is not finite')
        return 0


def std_u(signal, arg_dict):
    s = np.std(signal)
    if np.isfinite(s):
        return s
    else:
        print('std_u is not finite')
        return 0


def skewness_(signal, arg_dict):
    if np.isclose(np.std(signal),0):
        return 0
    else:
        s = 1/len(signal) * sum(((signal - np.mean(signal))/np.std(signal))**3)
    if np.isfinite(s):
        return s
    else:
        print('skewness_ is not finite')
        return 0


def kurtosis_(signal, arg_dict):
    if np.isclose(np.std(signal),0):
        return 0
    else:
        k = 1/len(signal) * sum(((signal - np.mean(signal))/np.std(signal))**4)
    if np.isfinite(k):
        return k
    else:
        print('kurtosis_ is not finite')
        return 0


def u_of_e_max(signal, arg_dict):
    E_u = arg_dict['E_u']
    u = arg_dict['u']
    f = u[np.where(E_u == np.max(E_u))[0][0]]
    if np.isfinite(f):
        return f
    else:
        return 0


def u_of_u_mean(signal, arg_dict):
    u = arg_dict['u']
    u_bar = u_mean(signal, arg_dict)
    i = np.where(u < u_bar)[0]
    try:
        f = u[i[-1]]
    except:
        f = 0  # Case when u_bar was 0
        # print('except too')
        #  f = u[-1]

    if np.isfinite(f):
        return f
    else:
        return 0


def minimum_signal(signal, arg_dict):
    m = np.min(signal)
    if np.isfinite(m):
        return m
    else:
        print('minimum signal isno finite')
        return 0


def maximum_signal(signal, arg_dict):
    m = np.max(signal)
    if np.isfinite(m):
        return m
    else:
        print('maximum-signal is not finite')
        return 0


def mean_signal(signal, arg_dict):
    m = np.mean(signal)
    if np.isfinite(m):
        return m
    else:
        print('mean_signal is not finite')
        return 0


def min_sur_mean(signal, arg_dict):
    mu = np.mean(signal)
    if np.isclose(mu,0):
        return np.min(signal) - mu
    else:
        f = np.min(signal) / np.mean(signal)
        if np.isfinite(f):
            return f
        else:
            print('min sur mean is not finite')
            return 0


def where_min(signal, arg_dict):
    u = arg_dict['u']
    m = minimum_signal(signal, arg_dict)
    i = np.where(signal == m)[0]
    try:
        f = u[i[-1]]
    except:
        f = 0
    if np.isfinite(f):
        return f
    else:
        print('where min is not finite')
        return 0


def where_max(signal, arg_dict):
    u = arg_dict['u']
    m = maximum_signal(signal, arg_dict)
    i = np.where(signal == m)[0]
    try:
        f = u[i[-1]]
    except:
        f = 0
    if np.isfinite(f):
        return f
    else:
        print('where max is not finite')
        return 0

def shannon(signal, arg_dict):
    """Returns Shannon entropy
    - signal: [s1, s2, s3, ...]
    - n: number of bin in histogram to estimate proba
    - shannon_entropy"""
    n = arg_dict['n_bin']
    proba, bin_vector = histogram(signal, n)
    proba = proba/len(signal)
    proba = proba[np.nonzero(proba)]
    shannon_entropy = -np.inner(proba, np.log2(proba))
    if np.isfinite(shannon_entropy):
        return shannon_entropy
    else:
        return 0


def renyi(signal, arg_dict):
    """Returns Rényi entropy, order alpha
    - signal: [s1, s2, s3, ...]
    - n: bins number in hisstogram to estimate proba
    - alpha: order of Rényi entropy (2 or inf)
    - entropy"""
    n = arg_dict['n_bin']
    alpha = arg_dict['alpha']
    proba, bin_vector = histogram(signal, n)
    proba = proba/len(signal)
    proba = proba[np.nonzero(proba)]
    if alpha == 2:
        entropy = np.log2(np.sum(proba**alpha))/(1-alpha)
        if np.isfinite(entropy):
            return entropy
        else:
            return 0
    elif alpha == inf:
        e = -log(np.max(proba), 2)
        if np.isfinite(e):
            return e
        else:
            return 0
    else:
        print("alpha should be '2' or 'inf'. Current value is: ", alpha)


def threshold_crossing_rate(signal, arg_dict):
    t = arg_dict['threshold']
    # Normalization needed to max = 1
    if np.isclose(np.max(signal),0):
        signal = signal - t
        zero_crossing = np.where(np.diff(np.sign(signal)))[0]
        return len(zero_crossing)/len(signal)
    else:
        signal = signal / np.max(signal) - t
        zero_crossing = np.where(np.diff(np.sign(signal)))[0]
        return len(zero_crossing)/len(signal)

def silence_ratio(signal, arg_dict):
    t = arg_dict['silenceThreshold']
    if np.isclose(np.max(signal),0):
        signal = threshold(signal, threshmin=t, newval=-100)
        silent = np.where(signal == -100)[0]
        return len(silent)/len(signal)
    else:
        # Normalization needed to max = 1
        signal = signal / np.max(signal)
        signal = threshold(signal, threshmin=t, newval=-100)
        # print(signal)
        silent = np.where(signal == -100)[0]
        return len(silent)/len(signal)

def mfcc_vector(signal, arg_dict):
    n_coeff = arg_dict['n_coeff']
    appendEnergy = eval(arg_dict['appendEnergy'])
    fs = arg_dict['fs']
    winlen = arg_dict['window_length']
    return mfcc(signal, samplerate=fs, winlen=winlen, numcep=n_coeff, appendEnergy=appendEnergy)
