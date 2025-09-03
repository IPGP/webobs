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


class FlowGoMaterialAir:

    def __init__(self) -> None:
        super().__init__()

        self._temp_air = 10. + 273.15  # temperature of the air [K]
        self._wind_speed = 5.0  # Wind speed [m/s]
        self._ch_air = 0.0036  # value from Greeley and Iverson (1987) C_H= (U'/U)^2 where U' is the fraction of wind speed according to Kesztheleyi and Denlinger (1996)
        self._rho_air = 0.4412  # density of the air [kg/m3]
        self._cp_air = 1099.  # Air specific heat capacity [J kg-1 K-1]

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._temp_air = float(data['convection_parameters']['air_temperature'])
            self._wind_speed = float(data['convection_parameters']['wind_speed'])
            self._ch_air = float(data['convection_parameters']['ch_air'])
            self._rho_air = float(data['convection_parameters']['air_density'])
            self._cp_air = float(data['convection_parameters']['air_specific_heat_capacity'])

    def compute_conv_heat_transfer_coef(self):
        #return 35
        return self._ch_air * self._rho_air * self._cp_air * self._wind_speed

    def get_temperature(self):
        return self._temp_air
