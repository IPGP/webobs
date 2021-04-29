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

import sys
import pandas as pd
from os.path import isfile

help = 'Use:' + \
       '\n- arg1: path to shaped catalogue (catalogue needing filtering)' + \
       '\n- arg2: path to filtered catalogue (saved catalogue)' + \
       '\n- arg3: events type array to keep (e.g.["MP","ROCKFAll"])'

def filter_catalogue(path_to_shaped_catalogue, path_to_filtered_catalogue, event_filter):
    # Read from input arg
    df = pd.read_csv(path_to_shaped_catalogue, sep="[;,]", engine='python')

    # Filtered catalogue
    df = df[df['class'].isin(event_filter)]

    # Save filtered catalogue
    df.to_csv(path_to_filtered_catalogue)
    print(path_to_filtered_catalogue.replace('csv','pd'))
    df.to_pickle(path_to_filtered_catalogue.replace('csv','pd'))

if __name__ == '__main__':
    try:
        if len(sys.argv) >= 4:
            path_to_shaped_catalogue = sys.argv[1]
            path_to_filtered_catalogue = sys.argv[2]
            event_filter = sys.argv[3:]
            print(event_filter)
            filter_catalogue(path_to_shaped_catalogue, path_to_filtered_catalogue, event_filter)
        else:
            print(help)
        if not isfile(path_to_shaped_catalogue):
            print('No file at %s'%path_to_shaped_catalogue)
            sys.exit()
    except Exception as inst:
        print(inst)
        print(help)
        print()
        print(sys.argv)
        sys.exit()

