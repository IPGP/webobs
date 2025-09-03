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


class FlowGoRelativeViscosityModelKD(pyflowgo.base.flowgo_base_relative_viscosity_model.
                                     FlowGoBaseRelativeViscosityModel):
    """This methods permits to calculate the effect of crystal cargo on viscosity according to the Krieger-Dougherty (19
    relationship. This relationship considers B (beinstein) and the maximum packing as fit parameters.
    The input parameters include the variable crystal fraction (phi), the maximum packing (phimax) and the Eisntein
    coefition B (beinstein)
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
    Krieger, I.M., (1972) Rheology of monodispersed latices. Adv. Colloid Interface Sci., 3:111-136.

    Krieger, I. M. & Dougherty, T. J. (1959) A mechanism for non-Newtonian flow in suspensions of rigid spheres.
    T. Soc. Rheol. 3, 137–152. (doi:10.1122/1.548848)

    Pabst, W. 2004 Fundamental considerations on suspension rheology. Ceram-Silikaty 48, 6–13.

    """

    def __init__(self) -> None:
        super().__init__()

        self._phimax = 0.641
        self._beinstein = 3.27

    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)
            self._phimax = float(data['relative_viscosity_parameters']['max_packing'])
            self._beinstein = float(data['relative_viscosity_parameters']['einstein_coef'])

    def compute_relative_viscosity(self, state):
        phi = state.get_crystal_fraction()

        relative_viscosity = math.pow((1. - phi/self._phimax), - self._beinstein*self._phimax)

        return relative_viscosity

    def is_notcompatible(self, state):
        phi = state.get_crystal_fraction()

        if 1. < phi/self._phimax:
            return True
        else:
            return False