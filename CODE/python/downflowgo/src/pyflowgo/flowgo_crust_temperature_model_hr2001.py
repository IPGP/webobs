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

import pyflowgo.base.flowgo_base_crust_temperature_model


class FlowGoCrustTemperatureModelHR2001(pyflowgo.base.flowgo_base_crust_temperature_model.
                                     FlowGoBaseCrustTemperatureModel):
    """
    This method  "HR2001" allows the crust temperature to decrease down flow in the same way as the core temperature is
    decreasing as applied by Harris and Rowland (2001):

    crust_temperature = core_temperature - 712


    Input data
    -----------
    json file containing the crust_temperature

    variables
    -----------

    Returns
    ------------
    crust temperature in K

    References
    ---------


    """

    def __init__(self) -> None:
        super().__init__()

        self._crust_temperature = 425 + 273.15

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._crust_temperature = float(data['thermal_parameters']['crust_temperature'])

    def compute_crust_temperature(self, state):

        crust_temperature = 0.

        #if (current_time / 3600 >= 0.00001):

        core_temperature = state.get_core_temperature()
        #for COLD ML84
        self._crust_temperature = core_temperature - 712.0

        # for HOT ML84
        #self._crust_temperature = core_temperature - 468.0

        return self._crust_temperature


