#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
A module to read WebObs calibration file and extracting the names of the variables used in the calibration file.

Functions
---------
find_proc(proc)
    Find the absolute path toward the calibration file.
extract_vars(proc_name)
    Return a list of str containing the name of the channels used in the calibration file.
extract_date(proc_name)
    Return a list of str containing the dates of each channels in teh calibration file.
"""

import readconf as rc
import pandas as pd
import chardet

def find_proc(proc):
    """Read configuration file.

    Parameters
    ----------
    proc : str
        Node ID.

    Returns
    -------
    path : str
        Absolute path (str) toward the calibration file.
    """

    proc_name = proc.upper().split('.')[1]
    node_name = proc.upper().split('.')[2]

    wo = '/etc/webobs.d/WEBOBS.rc'
    parser = rc.read_file(wo)
    path = rc.find_path(parser,'path_nodes')

    return path + node_name + '/' + proc.upper() + '.clb'
    #return path + proc + '/PROC.METEO.' + proc + '.clb'

def extract_vars(proc_name):
    """Extract channel names from the calibration file.

    Parameters
    ----------
    proc_name : str
        Absolute path of the calibration file.

    Returns
    -------
    var_names : list of str
        List of the names of the channels used in the calibration file.
    """

    with open(proc_name, 'rb') as file:
        encoding = chardet.detect(file.read())['encoding']
    data = pd.read_csv(proc_name,sep='|',header=None,skiprows=2, encoding=encoding)
    #print(data)
    #print(data[3])
    n = data[3].size
    #print(n)
    var_names = [data[3][i]  for i in range(n)]
    #var_names = sorted(set(var_names), key=var_names.index) # checking if one variable appears twice in the calibration file
    
    n = data[0].size

    time_ymd = [[data[0][i]  for i in range(n)][j].replace('-',' ') for j in range(n)]
    time_hms = [[data[1][i]  for i in range(n)][j].replace(':',' ') for j in range(n)]

    dates = []
    for i in range(n):
        dates.append(time_ymd[i]+' '+time_hms[i])

    return var_names, dates

# This segment is executed only if the script is ran explicitly
if __name__ == "__main__":
    #proc='PROC.METEO.GMWCEDIG'
    #proc='PROC.HYDRO.GHYCEDIG'
    proc='PROC.METEO.GMTBDMDF'
    #proc='PROC.GROUNDWATER.GGWBDQCK'

    print(rc.__doc__)
    proc_name = find_proc(proc)
    print(proc_name)

    var_names, dates = extract_vars(proc_name)
    print(var_names)
    print(dates)
