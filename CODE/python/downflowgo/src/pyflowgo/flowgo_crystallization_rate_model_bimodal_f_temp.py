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

import pyflowgo.base.flowgo_base_crystallization_rate_model


class FlowGoCrystallizationRateModelBimodalFonctionTemperature(pyflowgo.base.flowgo_base_crystallization_rate_model.
                                                               FlowGoBaseCrystallizationRateModel):


    """
    This model called "bimodal function temperature" allows to change the crystallization rate after a given temperature.

        Input data
        -----------
        write here the two crystallization rates and the temperature at which it changes

        Returns
        ------------
        the crystallization rate in fraction of crystals per degree

       """

    def __init__(self) -> None:
        super().__init__()

        self._crystal_fraction = 0.15
        self._crystals_grown_during_cooling = 0.45
        self._solid_temperature = 990. + 273.15
        self._eruption_temperature = 1137. + 273.15
        self._crystallization_rate_1 = 0.05
        self._crystallization_rate_2 = 0.1
        self._critical_temperature = 10.


    def read_initial_condition_from_json_file(self, filename):
        """
        This function permits to read the json file that includes all inputs parameters
        """
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)

            if 'critical_temperature' not in data['lava_state']:
                raise ValueError("Missing ['lava_state']['critical_temperature'] entry in json")

            if 'crystallization_rate_1' not in data['crystals_parameters']:
                raise ValueError("Missing ['crystals_parameters']['crystallization_rate_1'] entry in json")

            if 'crystallization_rate_2' not in data['crystals_parameters']:
                raise ValueError("Missing ['crystals_parameters']['crystallization_rate_2']entry in json")

            self._crystal_fraction = float(data['lava_state']['crystal_fraction'])
            self._critical_temperature = float(data['lava_state']['critical_temperature'])
            self._crystallization_rate_1 = float(data['crystals_parameters']['crystallization_rate_1'])
            self._crystallization_rate_2 = float(data['crystals_parameters']['crystallization_rate_2'])
            self._solid_temperature = float(data['crystals_parameters']['solid_temperature'])
            self._eruption_temperature = float(data['eruption_condition']['eruption_temperature'])

    def get_crystal_fraction(self,temperature):
        return self._crystal_fraction

    def compute_crystallization_rate(self, state):
        core_temperature = state.get_core_temperature()
        # For Mauna Ulu74,
        #critical_temperature = 1417.15
        #crystallization_rate_1 = 0.003
        #crystallization_rate_2 = 0.025

        if core_temperature >= self._critical_temperature:
            return self._crystallization_rate_1
        else:
            return self._crystallization_rate_2


    def get_solid_temperature(self):
        return self._solid_temperature
