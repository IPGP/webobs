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

class FlowGoCrustTemperatureModelHonBimodal(pyflowgo.base.flowgo_base_crust_temperature_model.
                                            FlowGoBaseCrustTemperatureModel):

    """ This method "bimodal" considers two regimes for calculating the temperature of the crust following
        the suggestions of Harris and Rowland (2015):

         Between the vent and a given distance the crust temperature is calculated as a function of time
         according to Hon et al. (1994) and after this given distance the crust temperature is constant
         and equals to the input value.

         Hon et al. (1994) equation is :

         crust_temperature = a*log(time) + b

         where time is in hours and a (=-140) and b (=303.) are fit parameters. This equation implies implicitly that the initial crust
         temperature is  1070°C.

         Warning, this model should not be used for other cases than Hawaiian cases as the Hon model is an empirical
         relationship determined from Hawaiian flows.

        Input data
        -----------
        json file containing the crust_temperature

        variables
        -----------
         time that must be set as 1s at distance = 0 in the json file and then is calculated down flow
        new_time = time + (step / v_mean)

        Returns
        ------------
        crust temperature in K

        References
        ---------
        Harris AJL and Rowland SK (2015) FLOWGO 2012: An updated framework for thermorheological simulations of
        Channel-Contained lava. In Carey R, Cayol V, Poland M, and Weis D, eds., Hawaiian Volcanoes:
        From Source to Surface, Am Geophys Union Geophysical Monograph 208

        Hon, K., J. Kauahikaua, R. Denlinger, and K. Mackay (1994), Emplacement and inflation of pahoehoe sheet flows:
        Observations and measurements of active lava flows on Kilauea Volcano, Hawaii,
        Geol. Soc. Am. Bull., 106, 351–370

        """
    def __init__(self) -> None:
        super().__init__()

        # T_crust can be set to constant value,
        # or allowed to decrease downflow as a function of time and distance from the vent (Harris & Rowland 2015).
        # crust_temperature = (-140 * math.log(time / 3600) + 303) + 273.15
        # with time given in hours define as distance = 0, time = 1s and then new_time = time + (step / v_mean)
        self._critical_distance = 0.
        self._crust_temperature_1 = 425 + 273.15
        self._crust_temperature_2 = 425

    def read_initial_condition_from_json_file(self, filename):
        """
        This function permits to read the json file that includes all inputs parameters
        """
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)

            if 'critical_distance' not in data['lava_state']:
                raise ValueError("Missing ['lava_state']['critical_distance'] entry in json")

            if 'crust_temperature_1' not in data['thermal_parameters']:
                raise ValueError("Missing ['thermal_parameters']['crust_temperature_1'] entry in json")

            if 'crust_temperature_2' not in data['thermal_parameters']:
                raise ValueError("Missing ['thermal_parameters']['crust_temperature_2'] entry in json")

            self._critical_distance = float(data['lava_state']['critical_distance'])
            self._crust_temperature_1 = float(data['thermal_parameters']['crust_temperature_1'])
            self._crust_temperature_2 = float(data['thermal_parameters']['crust_temperature_2'])

    def compute_crust_temperature(self, state):
        """this function permits to calculate the temperature of the crust"""
        current_time = state.get_current_time()
        current_position = state.get_current_position()
        crust_temperature = 0.

        if current_position <= self._critical_distance:
            return -140. * math.log10(current_time / 3600.) + 303. + 273.15
        else:
            return self._crust_temperature_2
