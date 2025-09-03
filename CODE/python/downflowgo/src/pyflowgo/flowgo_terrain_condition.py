# Copyright 2017 PyFLOWGO development team (Magdalena Oryaelle Chevrel and Jeremie Labroquere)
#
# This file is part of the PyFLOWGO library.
#
# The PyFLOWGO library is free software: you can redistribute it and/or modify
# it under the terms of the the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# The PyFLOWGO library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received copies of the GNU Lesser General Public License
# along with the PyFLOWGO library.  If not, see https://www.gnu.org/licenses/.

import math
import json

from scipy import interpolate


class FlowGoTerrainCondition:
    """This method permits to extract to slope from a slope file where each line represent the distance from the vent
    (first column) and the corresponding slope in degree (second column) that is then converted in gradiant.
    This method also allows the slope to be smoothed by making a running mean every 10m, this allows to avoid small
    terrain irregularity (slope =<0).

       Input data
       -----------
       txt file with first colomn is the distance from the vent (starting at 0)
       and second column is the corresponding slope in degree.

       Returns
       ------------
       Mean slope (in gradient) every 10m.

       References
       ---------

       """

    def __init__(self) -> None:
        super().__init__()

        # default values that are erased as soon as the slope_file is read
        self._effusion_rate_init = 0.1
        self._channel_depth = 5.5
        self._channel_width = 5.5
        self._gravity = 9.81
        self._default_slope = math.radians(2.657414)
        self._slope_spline = None
        self._max_channel_length = -1
        self._slope_smoothing_active = False
        self._slope_smoothing_number_of_points = -1

    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)
            self._effusion_rate_init = float(data['effusion_rate_init'])
            self._channel_depth = float(data['terrain_conditions']['depth'])
            self._channel_width = float(data['terrain_conditions']['width'])
            self._gravity = float(data['terrain_conditions']['gravity'])
            self._max_channel_length = float(data['terrain_conditions']['max_channel_length'])
            self._slope_smoothing_active = bool(data['terrain_conditions']['slope_smoothing_active'])
            self._slope_smoothing_number_of_points = float(data['terrain_conditions']['slope_smoothing_number_of_points'])

    def read_slope_from_file(self, filename=None):
        if filename == None:
            filename = '../MaunaUlu74/DEM_maunaulu74.txt'

        latitude = []
        longitude = []
        distance = []
        slope = []
        elevation = []

        f_slope = open(filename, "r")
        f_slope.readline()

        # ----------------------------original ----------------------------
        # for line in f_slope:
        #     split_line = line.strip('\n').split('\t')
        #     distance.append(float(split_line[0]))
        #     slope.append(math.radians(float(split_line[1])))
        # f_slope.close()

        # ----------------------------update----------------------------
        # This allow to avoid bugs due to null or negative slope values
        #
        latitude_column_number = 0
        longitude_column_number = 1
        elevation_column_number = 2
        distance_column_number = 3
        slope_column_number = 4

        for line in f_slope:
            split_line = line.strip('\n').split('\t')
            if float(split_line[slope_column_number]) <= 0.1:
                pass
            else:
                slope.append(math.radians(float(split_line[slope_column_number])))
                distance.append(float(split_line[distance_column_number]))
                elevation.append(float(split_line[elevation_column_number]))
                latitude.append(float(split_line[latitude_column_number]))
                longitude.append(float(split_line[longitude_column_number]))

        f_slope.close()

        # smooth the slope

        if self._slope_smoothing_active == True:
            slope = self.running_mean(slope, self._slope_smoothing_number_of_points)

        # build the spline to interpolate the distance (k=1 : it is a linear interpolation)
        self._slope_spline = interpolate.InterpolatedUnivariateSpline(distance, slope, k=1)

    def get_channel_slope(self, position_x):
        if (self._slope_spline is not None):
            return self._slope_spline(position_x)
        else:
            return self._default_slope

    def get_effusion_rate_init(self, current_x):
        return self._effusion_rate_init

    def get_channel_depth(self, current_x):
        return self._channel_depth

    def set_channel_depth(self, channel_depth):
        self._channel_depth = channel_depth

    def get_channel_width(self, current_x):
        return self._channel_width

    def get_gravity(self, current_x):
        return self._gravity

    def get_max_channel_length(self):
        return self._max_channel_length

    def running_mean(self, l, n):
        result = list(0. for x in l)
        for i in range(0, len(l)):

            start_index = max(0, i-int(n/2))
            last_index = min(len(l)-1, int(i+n/2))

            current_list = l[start_index:last_index+1]

            current_average = sum(current_list)
            result[i] = current_average / len(current_list)

        return result
