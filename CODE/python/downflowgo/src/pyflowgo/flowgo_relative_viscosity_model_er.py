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


class FlowGoRelativeViscosityModelER(pyflowgo.base.flowgo_base_relative_viscosity_model.
                                     FlowGoBaseRelativeViscosityModel):
    """
    This function calculates the effect of crystal cargo on viscosity according to the original FLOWGO
    from Harris and Rowland 2001 who used the Einstein-Roscoe relationship (as first introduced by Shaw, 1965):

    relative_viscosity = math.pow((1. - R * phi), - 2.5)

    where R = 1.51 as suggested by Pinkerton and Stevenson (1992)
    This relationship applies only for spherical solid particles.

    Input data
    -----------
    the inverse of the maximum packing for spherical particles (1/phimax = r = 1.51)

    variables
    -----------
    crystal fraction: phi

    Returns
    ------------
    the relative viscosity due to the crystal cargo

    Reference
    ---------
    Shaw, H.R. (1965) Comments on viscosity, crystal settling, and convection in granitic magmas.
    Am. J. Sci., 263: 120-152.

    Pinkerton and Stevenson (1992)

    """

    def __init__(self) -> None:
        super().__init__()

        self._r = 1.51

    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)

    def compute_relative_viscosity(self, state):
        phi = state.get_crystal_fraction()
        self._r = 1.51
        phimax = 1/self._r
        relative_viscosity = math.pow((1. - self._r * phi), - 2.5)
        return relative_viscosity

    def is_notcompatible(self, state):
        phi = state.get_crystal_fraction()

        if phi >= (1/self._r):
            return True
        else:
            return False
