#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import readclb as rc
import argparse
import pandas as pd
import numpy as np
import chardet

# getting python functions' parameters through standard input
parser = argparse.ArgumentParser(description='Preprocessor filter for "dsv" data format called by readfmtdata_dsv.m')
parser.add_argument('node_id', metavar='N.ID', type=str, help='WebObs node ID. Ex: PROC.METEO.GMWCEDIG')
parser.add_argument('fs', metavar='FS', type=str, help='Field separator in input data')
parser.add_argument('header_line', metavar='HEADERLINES', type=int, help='Number of header lines to be discarded')
parser.add_argument('field_numbers', metavar='FN', type=int, help='Number of variables')

args = parser.parse_args()

nid = vars(args)['node_id']
fds = vars(args)['fs']
hdl = vars(args)['header_line']

proc_name = rc.find_proc(nid)
inp, dates = rc.extract_vars(proc_name)    # extracting variable names in the calibration file

with open(0, 'rb') as f:            # reading the data files
    data = str(f.read().decode())

data = data.split('\n')
data = [v.replace('\r','') for v in data]

beg_files = []
for i in range(len(data)):
    if 'Titre de tracé' in data[i]:
        beg_files.append(i)

data = [v.replace(',','.').split(';') for v in data]

df = None

for i in range(len(beg_files)):
    n = beg_files[i]
    if df is None:
        m = beg_files[i+1]
        df=pd.DataFrame(data[n+2:m],columns=data[n+1])
    elif i!=len(beg_files)-1:
        m = beg_files[i+1]
        df=df.append(pd.DataFrame(data[n+2:m],columns=data[n+1]))
    else:
        df=df.append(pd.DataFrame(data[n+2:],columns=data[n+1]))

df.set_index('Date Heure', drop=True, inplace=True, verify_integrity=False)
df.index.name = None

out = None
for var in inp:
    for column in df.columns:
        if var in column and out is None:
            out = pd.DataFrame(df[column])
            out.rename(columns={column:var},inplace=True)
        elif var in column and out is not None:
            lst = len(out.columns)
            out.insert(lst,var, df[column])
        elif var not in column and out is not None and var not in out.columns:
            lst = len(out.columns)
            out.insert(lst,var, np.nan)

out.loc[out['Temp']==''] = np.nan

out = out.to_string(index=True, header=False)
#print(df)
print(out)

