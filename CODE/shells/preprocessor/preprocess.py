#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import readclb as rc
import argparse
import pandas as pd
import numpy as np
#import sys

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
inp = [item.lower() for item in inp]
inp.insert(0, 'timestamp')          # adding a timestamp column name

with open(0, 'rb') as f:            # reading the data files
    data = str(f.read()).replace('"','').split(r'\n')

data = [data[i].split(fds) for i in range(len(data))]

# removing some sensor writing bugs
for i in range(len(data)):
    data[i] = [v.replace('\\r','').replace("0'",'0') for v in data[i]]
""" if '0TOA5' in data[i]:  # bug in CE_DIG_Hydro/2012/..0611..dat
        hdr = data[i][len(data[i-1]):]
        for v in data[i]:
            if v == '0TOA5':
                w = v.replace('0TOA5','0,TOA5').split(',')
                data[i] = data[i][:len(data[i-1])-1]
                data[i].append(w[0])
        hdr.insert(0,w[1])
        idx = i+1
if 'idx' in locals():
    data.insert(idx,hdr)"""

if ["'"] in data:
    data.remove(["'"])

if [] in data:
    data.remove([])

beg_files = []                      # finding the header of each files
for i in range(len(data)):
    if 'TIMESTAMP' in data[i]:
        beg_files.append(i-1)       # we only need the index position of the first line of each header

df = None                           # stating that no DataFrame exists

for i in range(len(beg_files)):     # len(beg_files) stands for 'number of files'
    n = beg_files[i]                # beg_files[i] corresponds to the first line of each file
    if df is None:                  # if no DataFrame exists, we create one
        header = data[n:n+hdl]
        var = [data[n+1][j].lower() for j in range(len(data[n+1]))] # listing variable names from the header that match the calibration file variable names
        if i<len(beg_files)-1:
            df2 = pd.DataFrame(data[n+len(header):beg_files[i+1]], columns=var) # creating another DataFrame so we could add 'df2' to 'df' which allows us to merge all the data files within one standardized DataFrame
            df2['timestamp'] = pd.to_datetime(df2['timestamp']).dt.strftime('%Y %m %d %H %M %S')
            for name in inp:        # if a variable name from the calibration file could not be found in the header of one file, we fill the column with 'NaN'
                if name not in df2.columns:
                    lst = len(df2.columns)
                    df2.insert(lst,name,np.nan)
            df = pd.DataFrame(df2[inp])
        else:
            df2 = pd.DataFrame(data[n+len(header):], columns=var)
            df2['timestamp'] = pd.to_datetime(df2['timestamp']).dt.strftime('%Y %m %d %H %M %S')
            for name in inp:
                if name not in df2.columns:
                    lst = len(df2.columns)
                    df2.insert(lst,name,np.nan)
            df = pd.DataFrame(df2[inp])
    else:
        header = data[n:n+hdl]
        var = [data[n+1][j].lower() for j in range(len(data[n+1]))]
        #units = data[i+2]
        if i<len(beg_files)-1:
            df2 = pd.DataFrame(data[n+len(header):beg_files[i+1]], columns=var)
            df2['timestamp'] = pd.to_datetime(df2['timestamp']).dt.strftime('%Y %m %d %H %M %S')
            for name in inp:
                if name not in df2.columns:
                    lst = len(df2.columns)
                    df2.insert(lst,name,np.nan)
            df = df.append(df2[inp], ignore_index=True)
        else:
            df2 = pd.DataFrame(data[n+len(header):], columns=var)
            df2['timestamp'] = pd.to_datetime(df2['timestamp']).dt.strftime('%Y %m %d %H %M %S')
            for name in inp:
                if name not in df2.columns:
                    lst = len(df2.columns)
                    df2.insert(lst,name,np.nan)
            df = df.append(df2[inp], ignore_index=True)

df.set_index('timestamp', drop=True, inplace=True, verify_integrity=False)
df.index.name = None
df = df[df.index != 'NaT']

# here we remove the ambiguities in the variable names that share the same name
cols = []
count = 1
for column in df.columns:
    if df.columns.tolist().count(column)>1:
        cols.append('{}_{}'.format(column,count))
        count+=1
        continue
    cols.append(column)
df.columns = cols

# here we look if the calibration file precises if some values started later than the beginning dates of the files data
for i in range(len(dates)):
    col = df.iloc[:,i]
    if (col.index<dates[i]).any():
        lst_idx = None
        for j in range(col.index.shape[0]):
            if col.index[j]<dates[i]:
                lst_idx = j        
        col[:lst_idx] = np.nan

df = df.sort_index()
#print(df)
out = df.to_string(index=True, header=False)
print(out)
#sys.stdout.write(out)

