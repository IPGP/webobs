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


from pathlib import  Path
import sys
path = str(Path(Path(__file__).parent.absolute()).parent.absolute())
sys.path.insert(0,path)


import importlib
read = importlib.import_module("01_CATALOGUE_READING")
filter = importlib.import_module("02_FILTER_CLASSES")

from os.path import isfile



help = 'This usecase can only be used for creating catalogue: \n' + \
        '\n - arg1: path to raw catalogue' + \
        '\n - arg2: path to shaped catalogue (saved catalogue)' + \
        '\n - arg3: path to filtered catalogue (saved catalogue)' + \
        '\n - arg4...: events type to keep (e.g. MP ROCKFALL VTA VTB LF TREMOR TECT TELE TPHASE SOUND ANTHROP GASBURST AWANPANAS TECLOC)'


def make_filtered_catalogue(path_to_raw_catalogue,path_to_shaped_catalogue, path_to_filtered_catalogue, event_filter):
     read.read_catalogue(path_to_raw_catalogue, path_to_shaped_catalogue)
     filter.filter_catalogue(path_to_shaped_catalogue, path_to_filtered_catalogue, event_filter)

if __name__ == '__main__':
    try:
        if len(sys.argv) >= 5:
            path_to_raw_catalogue = sys.argv[1]
            path_to_shaped_catalogue = sys.argv[2]
            path_to_filtered_catalogue = sys.argv[3]
            event_filter = sys.argv[4:]
            make_filtered_catalogue(path_to_raw_catalogue,path_to_shaped_catalogue, path_to_filtered_catalogue, event_filter)
        else:
            print(help)
        if not isfile(path_to_raw_catalogue):
            print('No file at %s'%path_to_shaped_catalogue)
            sys.exit()
    except Exception as inst:
        print(inst)
        print(help)
        print()
        print(sys.argv)
        sys.exit()
