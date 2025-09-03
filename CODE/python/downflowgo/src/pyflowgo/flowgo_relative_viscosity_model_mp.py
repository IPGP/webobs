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

import pyflowgo.base.flowgo_base_relative_viscosity_model


class FlowGoRelativeViscosityModelMP(pyflowgo.base.flowgo_base_relative_viscosity_model.
                                     FlowGoBaseRelativeViscosityModel):
    """This methods permits to calculate the effect of crystal cargo on viscosity according to the Maron-Pierce []
    relationship. This relationship has only the maximum packing (phimax, φm) as adjustable parameter.
    This relationship differs from the Krieger-Dougherty [] equation because B (beinstein) is not a fit parameter,
    but is calculated from the relationship Bφm = 2
    The input parameters include the variable crystal fraction (phi) and the maximum packing (phimax)"""

    def __init__(self) -> None:
        super().__init__()
        self._phimax = 0.633

    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)
            if 'max_packing' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing 'max_packing' in 'relative_viscosity_parameters' entry in json")
            self._phimax = float(data['relative_viscosity_parameters']['max_packing'])

    def compute_relative_viscosity(self, state):
        phi = state.get_crystal_fraction()

        relative_viscosity = math.pow((1. - phi/self._phimax), - 2)

        return relative_viscosity

    def is_notcompatible(self, state):
        phi = state.get_crystal_fraction()
        if 1. < phi/self._phimax:
            return True
        else:
            return False
