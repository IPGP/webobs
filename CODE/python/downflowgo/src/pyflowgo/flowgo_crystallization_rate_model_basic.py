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

import pyflowgo.base.flowgo_base_crystallization_rate_model


class FlowGoCrystallizationRateModelBasic(pyflowgo.base.flowgo_base_crystallization_rate_model.
                                          FlowGoBaseCrystallizationRateModel):
    """
        This model called "basic" calculates the amount of crystal (in fraction) as a function of the amount of cooling
        as suggested by Harris and Rowland (2001).
        It take into account the amount of crystallization during the eruption that occurred between the eruption
        temperature and the solid temperature (temperature at which the material cannot flow anymore)

        Input data
        -----------
        json file containing:
        initial crystal_fraction,
        crystals_grown_during_cooling,
        solid_temperature
        eruption_temperature

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

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._crystal_fraction = float(data['lava_state']['crystal_fraction'])
            self._crystals_grown_during_cooling = float(data['crystals_parameters']['crystals_grown_during_cooling'])
            self._solid_temperature = float(data['crystals_parameters']['solid_temperature'])
            self._eruption_temperature = float(data['eruption_condition']['eruption_temperature'])

    def get_crystal_fraction(self, temperature):
        return self._crystal_fraction

    def compute_crystallization_rate(self, state):
        crystallization_rate = self._crystals_grown_during_cooling / (self._eruption_temperature -
                                                                      self._solid_temperature)
        return crystallization_rate

    def get_solid_temperature(self):
        return self._solid_temperature
