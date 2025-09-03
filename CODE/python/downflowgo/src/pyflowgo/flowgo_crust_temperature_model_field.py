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

import json
import math
import pyflowgo.flowgo_state
from scipy import interpolate

import pyflowgo.base.flowgo_base_crust_temperature_model


class FlowGoCrustTemperatureModelField(pyflowgo.base.flowgo_base_crust_temperature_model.
                                            FlowGoBaseCrustTemperatureModel):

    """ This method "field" considers the temperature of the crust as collected by FLIR in the field:
    It reads a look-up table and do a linearisation between the collected pointd along the length from the vent to the
    front

    Input data
    -----------
    txt file containing the crust_temperature and distance (m) from vent to front

    variables
    -----------
    distance and T_crust

    Returns
    ------------
    crust temperature in K

    References
    ---------
    Done for Piton de la Fournace Avril 2018 eruption
        """

    def __init__(self) -> None:
        super().__init__()
        self._crust_temperature = 0 + 273.15
        self._crust_temperature_spline = None

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            if 'crust_temperature_file' not in data['thermal_parameters']:
                raise ValueError("Missing ['thermal_parameters']['crust_temperature_file'] entry in json")
            self._crust_temperature = float(data['thermal_parameters']['crust_temperature'])

    def read_crust_temperature_from_file(self, f_crust_temperature=None):
        if f_crust_temperature == None:
            #TODO here enter the path to the look up table
            f_crust_temperature = 'resources/crust_temperature_profile.txt'

        distance = []
        crust_temperature = []
        # here read the T_crust file (.txt) where each line represent the distance from the vent (first column) and
        # the corresponding T_crust in °C (second column) that is then converted in K
        f_crust_temperature = open(f_crust_temperature, "r")
        f_crust_temperature.readline()
        for line in f_crust_temperature:
            split_line = line.strip('\n').split('\t')
            distance.append(float(split_line[0]))
            crust_temperature.append((float(split_line[1]))+273.15)
        f_crust_temperature.close()

        # build the spline to interpolate the distance (k=1 : it is a linear interpolation)
        self._crust_temperature_spline = interpolate.InterpolatedUnivariateSpline(distance, crust_temperature, k=1.)

    def get_crust_temperature(self, distance):
        if self._crust_temperature_spline is not None:
            return float(self._crust_temperature_spline(distance))
        else:
            return self._crust_temperature

    def compute_crust_temperature(self, state):
        """this function permits to calculate the temperature of the crust"""
        current_position = state.get_current_position()
        crust_temperature = self.get_crust_temperature(current_position)
        return crust_temperature
