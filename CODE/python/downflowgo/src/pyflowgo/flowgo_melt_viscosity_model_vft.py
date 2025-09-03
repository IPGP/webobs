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

import pyflowgo.base.flowgo_base_melt_viscosity_model


class FlowGoMeltViscosityModelVFT(pyflowgo.base.flowgo_base_melt_viscosity_model.FlowGoBaseMeltViscosityModel):
    """ This function calculates the viscosity of the melt according to Giordano et al. 2008:

    log viscosity(Pa.s) = A + B / (T(K) - C),

    where A, B and C are adjustable parameters depending of the melt chemical composition<
    here the reads the A, B, C from the json file

    Input data
    -----------
    json file containing the A, B, C parameters (a_vft, b_vft, c_vft) in melt_viscosity_parameters

    variables
    -----------
    temperature of the lava interior : core_temperature

    Returns
    ------------
    the viscosity of the pure melt in Pa.s

    Reference
    ---------
    Giordano, D., Russell, J. K., & Dingwell, D. B. (2008). Viscosity of magmatic liquids: a model.
    Earth and Planetary Science Letters, 271(1), 123-134.

    """
    def __init__(self) -> None:
        super().__init__()

        self._a = -4.7
        self._b = 5429.7
        self._c = 595.5

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            if 'a_vft' not in data['melt_viscosity_parameters']:
                raise ValueError("a_vft' in 'melt_viscosity_parameters' entry in json")
            if 'b_vft' not in data['melt_viscosity_parameters']:
                raise ValueError("b_vft' in 'melt_viscosity_parameters' entry in json")
            if 'c_vft' not in data['melt_viscosity_parameters']:
                raise ValueError("c_vft' in 'melt_viscosity_parameters' entry in json")
            self._a = float(data['melt_viscosity_parameters']['a_vft'])
            self._b = float(data['melt_viscosity_parameters']['b_vft'])
            self._c = float(data['melt_viscosity_parameters']['c_vft'])

    def compute_melt_viscosity(self, state):
        core_temperature = state.get_core_temperature()

        melt_viscosity = 10 ** (self._a + self._b / (core_temperature - self._c))

        return melt_viscosity
