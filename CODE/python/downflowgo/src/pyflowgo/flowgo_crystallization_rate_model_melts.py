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
import csv
from scipy import interpolate
import pyflowgo.base.flowgo_base_crystallization_rate_model


class FlowGoCrystallizationRateModelMelts(pyflowgo.base.flowgo_base_crystallization_rate_model.
                                          FlowGoBaseCrystallizationRateModel):
    """ This method "MELTS" allows to get the crystal fraction at a given temperature
     in order to calculate the crystallization rate according to a look-up table built
     from MELTS as suggsted in Harris and Rowland 2001 and in Riker et al. 2009

        Input data
        -----------
        table built from MELTS

        Returns
        ------------
        the crystallization rate in fraction of crystals per degree

        References
        ---------
        Riker J,Cashman K, Kauahikaua J, Montierth C (2009) The length of channelized lava flows: Insight from the 1859
        eruption of Mauna Loa Volcano, Hawai‘i. Journal of Volcanology and Geothermal Research 183 (2009) 139–156

    """

    def __init__(self) -> None:
        super().__init__()

        self._solid_temperature = 990. + 273.15
        self._crystal_fraction = 0.01
        self._crystals_grown_during_cooling = 0.45
        self._eruption_temperature = 1137. + 273.15
        self._crystal_spline = None

    def read_initial_condition_from_json_file(self, filename):
        """
        This function permits to read the json file that includes all inputs parameters
        """
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)

            if 'melts_look-up_table' not in data:
                raise ValueError("Missing ['melts_look-up_table'] entry in json")

            self._crystal_fraction = float(data['lava_state']['crystal_fraction'])
            self._solid_temperature = float(data['crystals_parameters']['solid_temperature'])
            self._eruption_temperature = float(data['eruption_condition']['eruption_temperature'])

    def read_crystal_from_melts(self, filename=None):
        crystal_fraction = []
        temperature = []

        if filename == None:
            filename = '../pyflowgo/MaunaUlu74/Results-melts_MU74.csv'

        with open(filename) as csvfile:
            f_crystal_fraction = csv.DictReader(csvfile, delimiter=',')
            for row in f_crystal_fraction:
                temperature.append(float(row['temperature'])+273.15)
                crystal_fraction.append(float(row['fraq_microlite']))
        self._crystal_spline = interpolate.InterpolatedUnivariateSpline(temperature, crystal_fraction, k=1.)

    def get_crystal_fraction(self, temperature):
        if self._crystal_spline is not None:
            return self._crystal_spline(temperature)
        else:
            return self._crystal_fraction

    def compute_crystallization_rate(self, state):
        core_temperature = state.get_core_temperature()
        phi_at_temp_plus = self.get_crystal_fraction(core_temperature + 1.)
        phi_at_temp_minus = self.get_crystal_fraction(core_temperature - 1.)
        crystallization_rate = -(phi_at_temp_plus - phi_at_temp_minus) / 2.
        return crystallization_rate

    def get_solid_temperature(self):
        return self._solid_temperature
