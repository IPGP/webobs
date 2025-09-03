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


class FlowGoMeltViscosityModelShaw(pyflowgo.base.flowgo_base_melt_viscosity_model.FlowGoBaseMeltViscosityModel):

    """ This function calculates the viscosity of teh melt according to Shaw et al. 1972:

    ln viscosity(Poise) = slope*(10000/T(K))-(1.5*slope)-6.4

    where slope is the intercept calculated from the chemical composotion of the silicate liquid

    Input data
    -----------
    json file containing the shaw_slope in melt_viscosity_parameters

    variables
    -----------
    temperature of the lava interior : core_temperature

    Returns
    ------------
    the viscosity of the pure melt in Pa.s

    References
    ---------
    Shaw (1972). Viscosity of magmatic silicate liquids: an empirical method of prediction.
    American Journal of science, Vol. 272, p. 870-893.

    """

    def __init__(self) -> None:
        super().__init__()

        self._shaw_slope = 2.36

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)

            self._shaw_slope = float(data['melt_viscosity_parameters']['shaw_slope'])

    def compute_melt_viscosity(self, state):
        core_temperature = state.get_core_temperature()

        melt_viscosity = 10 ** (((self._shaw_slope * (10000. / core_temperature) - (1.5 * self._shaw_slope) - 6.4) / 2.303) - 1)

        return melt_viscosity
