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


class FlowGoRelativeViscosityModelMPMUELLER(pyflowgo.base.flowgo_base_relative_viscosity_model.
                                     FlowGoBaseRelativeViscosityModel):
    """This methods permits to calculate the effect of crystal cargo on viscosity according to the Maron-Pierce []
    relationship. This relationship has one adjustable parameter only :  the maximum packing (phimax, φm) and
    following Mueller et al. (2010)
    Φmax depend on Φm1, b and on the aspect ratio Rp of the particles
    phimax = phim1 * math.exp(-(math.log10(self._Rp) ** 2 / 2 * b ** 2))

    phim1 is the maximum packing fraction for equant particles and given as 0.656 for smooth and 0.55 for rough
     particles(Mader et al. 2013);

    b is a fitting parameter equal to 1.08 and 1 for smooth and rough particles, respectively

    The input parameters include the crystal aspect ratio RP

    """

    def __init__(self) -> None:
        super().__init__()
        self._Rp = 3.2

    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)
            if 'crystal_aspect_ratio' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing 'crystal_aspect_ratio' in 'relative_viscosity_parameters' entry in json")
            self._Rp = float(data['relative_viscosity_parameters']['crystal_aspect_ratio'])

    def compute_relative_viscosity(self, state):
        phi = state.get_crystal_fraction()

        phim1 = 0.55  # 0.656 for smooth particles
        b = 1.0 # 1.08 for smooth particles
        phimax = phim1 * math.exp(-(math.log10(self._Rp) ** 2 / 2 * b ** 2))
        relative_viscosity = math.pow((1. - phi/phimax), - 2)
        print("relative_viscosity",relative_viscosity)
        return relative_viscosity

    def is_notcompatible(self, state):
        phi = state.get_crystal_fraction()
        phim1 = 0.55  # 0.656
        b = 1.0 # 1.08 for smooth particles
        phimax = phim1 * math.exp(-(math.log10(self._Rp) ** 2 / 2 * b ** 2))
        if 1. < phi/phimax:
            return True
        else:
            return False
