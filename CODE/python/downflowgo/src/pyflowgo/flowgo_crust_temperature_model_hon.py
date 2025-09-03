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


class FlowGoCrustTemperatureModelHon(pyflowgo.base.flowgo_base_crust_temperature_model.
                                     FlowGoBaseCrustTemperatureModel):

    """
    This method  "hon" allows the crust temperature to decrease downflow as a function of time via the model of Hon et al.
        (1994) and as suggested by Harris and Rowland (2015):

        crust_temperature = -140 * math.log(time) + 303 where time is in hours

         where time is in hours. This equation implies implicitly that
         the initial crust temperature is 1070°C.

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

        self._crust_temperature = 425 + 273.15

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._crust_temperature = float(data['thermal_parameters']['crust_temperature'])

    def compute_crust_temperature(self, state):

        current_time = state.get_current_time()
        crust_temperature = 0.

        #if (current_time / 3600 >= 0.00001):
        self._crust_temperature = -140. * math.log10(current_time / 3600.) + 303. + 273.15
        #else:
            #crust_temperature = -140. * math.log10(0.01)+303. + 273.
        #print('crust_temperature  =' + str(crust_temperature))
        return self._crust_temperature


