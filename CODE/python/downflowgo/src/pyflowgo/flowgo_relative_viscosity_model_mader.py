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

import pyflowgo.flowgo_vesicle_fraction_model_constant
import pyflowgo.flowgo_melt_viscosity_model_shaw

import pyflowgo.base.flowgo_base_relative_viscosity_model
import pyflowgo.flowgo_material_lava

class FlowGoRelativeViscosityModelMADER(pyflowgo.base.flowgo_base_relative_viscosity_model.
                                     FlowGoBaseRelativeViscosityModel):
    """ This method permits to calculate the effect of crystals on viscosity according to the algorithm
    given in Mader et al. (2013), Figure 14
    Phimax is calculated with Mueller et al 2010: eq. X
    is Phi.Phimax > 0.5, the flow index n is calculated and if n < 0.9 : visco depends on strain rate
    if not: relative viscosity is calculated with Maron Pierce equation, using mueller et la. 2010

        Input data
        -----------
        Crystal fraction
        Crystal aspect ratio
        Strain rate

        Variables
        -----------


        Returns
        ------------
        The effect of crystals on viscosity

        References
        ---------
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
        strain_rate = state.get_strain_rate()
        phim1 = 0.55  # 0.656 for smooth particles
        b = 1 # 1.08 for smooth particles

        phimax = phim1 * math.exp(-(math.log10(self._Rp) ** 2 / 2 * b ** 2)) # eq. 49
        n = 1 - 0.2 * self._Rp * (phi / phimax) ** 4  # eq. 50

        print(f"phi = {phi:.4f}, phimax = {phimax:.4f}, phi/phimax = {phi / phimax:.4f}, n = {n:.4f}")

        if phi / phimax >= 0.5:
            if n < 0.9:  # strain rate dependance of relarive viscosity
                if strain_rate <= 0:
                    raise ValueError("strain_rate must be > 0 when n < 1 (non-Newtonian case)")
                # implicteley phi_critique (when strain-rate dependency start) = 0.27 that is 50% of phi max; relative_viscosity is not relative consistency :
                relative_viscosity = math.pow((1. - phi/phimax), - 2) * strain_rate**(n-1) #eq 51
                print("Non-Newtonian regime: relative_viscosity depends on strain_rate")
            else:
                relative_viscosity = math.pow((1. - phi / phimax), - 2)  # eq 46 Maron-Pierce equation
                print("Newtonian regime (n>1) at high phi: Maron-Pierce equation applied")

        else:  # relative_viscosity = relative consistency
            relative_viscosity = math.pow((1. - phi / phimax), - 2)  # eq 46 Maron-Pierce equation
            print("Newtonian regime at low phi: Maron-Pierce equation applied")

        return relative_viscosity
    
    def is_notcompatible(self, state):
        phi = state.get_crystal_fraction()
        phim1 = 0.55  # 0.656 for smooth particles
        b = 1 # 1.08 for smooth particles
        phimax = phim1 * math.exp(-(math.log10(self._Rp) ** 2 / 2 * b ** 2)) # eq. 49
        if phi / phimax == 1:
            return True
        else:
            return False
