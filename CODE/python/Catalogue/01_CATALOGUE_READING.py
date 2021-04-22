#!/home/osboxes/anaconda3/bin/python

# -*-coding:Utf-8 -*

# Webobs - 2012-2021 - Institut de Physique du Globe Paris
# 
# Autor(s): Lucie Van Nieuwenhuyze
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


import pandas as pd
from os.path import isfile
import sys


help = 'Use: ' + \
       '\n - arg1: path to raw catalogue (catalogue needing shaping)' + \
       '\n - arg2: path to shaped catalogue (saved catalogue)' 


def read_catalogue(path_to_raw_catalogue, path_to_shaped_catalogue):
    # Read from input arg
    cat = pd.read_csv(path_to_raw_catalogue,header=1, sep='[;,]', engine='python')

    # Shape catalogue
    cat['year'] = cat.apply(lambda x:int(x['#YYYYmmdd HHMMSS.ss'].split(' ')[0][:4]), axis=1)
    cat['month'] = cat.apply(lambda x:int(x['#YYYYmmdd HHMMSS.ss'].split(' ')[0][4:6]), axis=1)
    cat['day'] = cat.apply(lambda x:int(x['#YYYYmmdd HHMMSS.ss'].split(' ')[0][6:8]), axis=1)
    cat['hour'] = cat.apply(lambda x:int(x['#YYYYmmdd HHMMSS.ss'].split(' ')[1][:2]), axis=1)
    cat['minute'] = cat.apply(lambda x:int(x['#YYYYmmdd HHMMSS.ss'].split(' ')[1][2:4]), axis=1)
    cat['second'] = cat.apply(lambda x:float(x['#YYYYmmdd HHMMSS.ss'].split(' ')[1][4:]), axis=1)
    cat['length'] = cat['Duration']
    cat['class'] = cat['Type']
    cat['f0'] = None
    cat['f1'] = None
    cat['path'] = None

    cat=cat.sort_values(['year','month','day'])
    cat.index = range(0,len(cat))

    cat = cat[['class','year','month','day','hour','minute','second','length', 'f0', 'f1', 'path']]

    #pickle.dump(cat, open(path_to_shaped_catalogue,'wb'))
    cat.to_csv(path_to_shaped_catalogue)

if __name__ == '__main__':
    try:
        if len(sys.argv) == 3:
            path_to_raw_catalogue = sys.argv[1]
            path_to_shaped_catalogue = sys.argv[2]
            read_catalogue(path_to_raw_catalogue, path_to_shaped_catalogue)
        else:
            print(help)
        if not isfile(path_to_raw_catalogue):
            print('No file at %s'%path_to_raw_catalogue)
            sys.exit()
    except Exception as inst:
        print(inst)
        print(help)
        print()
        print(sys.argv)
        sys.exit()
