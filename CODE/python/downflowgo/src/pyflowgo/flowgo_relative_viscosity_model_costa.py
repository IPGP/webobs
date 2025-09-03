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


class FlowGoRelativeViscosityModelCosta(pyflowgo.base.flowgo_base_relative_viscosity_model.
                                        FlowGoBaseRelativeViscosityModel):
    """
     FOR NOW NOT IN USE

    his methods permits to calculate the effect of crystal cargo on viscosity according to Costa et al []
    This relationship considers the strain rate and allows to evautate the effect of high crystal fraction
    (above maximum packing).
    The input parameters include the variable crystal fraction (phi) and other parameters depending on the aspect ratio
    of the crystals.

    This should be used together with MELTS

    References:
    ---------
    """

    def __init__(self) -> None:
        super().__init__()

        self._strain_rate = 1.

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._strain_rate = float(data['relative_viscosity_parameters']['strain_rate'])

    def compute_relative_viscosity(self, state):
        phi = state.get_crystal_fraction()
        if self._strain_rate == 1.0:
            # for spheres, A particles from Cimarelli et al., 2011
            # self.phi_max = 0.61,
            delta_1 = 11.4
            gama_1 = 1.6
            phi_star_1 = 0.67
            epsilon_1 = 0.01

            F = (1. - epsilon_1) * math.erf(min(25., (
                (math.sqrt(math.pi) / (2. * (1. - epsilon_1))) * (phi / phi_star_1) * (
                    1. + (math.pow((phi / phi_star_1), gama_1))))))

            relative_viscosity = (1. + math.pow((phi / phi_star_1), delta_1)) / (
                math.pow((1. - F), (2.5 * phi_star_1)))

            return relative_viscosity

            # needle-like B particles from Cimarelli et al., 2011
            # self.phi_max_2 = 0.44
            # delta_2 = 4.45
            # gama_2 = 8.55
            # phi_star_2 = 0.28
            # epsilon_2 = 0.001
            #
            # F2 = (1. - epsilon_2) * math.erf(min(25., (
            #     (math.sqrt(math.pi) / (2. * (1. - epsilon_2))) * (phi2 / phi_star_2) * (
            #         1. + (math.pow((phi2 / phi_star_2), gama_2))))))
            #
            # visco_relative_costa_2 = (1. + math.pow((phi2 / phi_star_2), delta_2)) / (
            #     math.pow((1. - F2), (2.5 * phi_star_2)))

        if self._strain_rate == 0.0001:
            # spheres A particles from Cimarelli et al., 2011
            # self.phi_max_1 = 0.54,
            delta_1 = 11.48
            gama_1 = 1.52
            phi_star_1 = 0.62
            epsilon_1 = 0.005

            F = (1. - epsilon_1) * math.erf(min(25., (
                (math.sqrt(math.pi) / (2. * (1. - epsilon_1))) * (phi / phi_star_1) * (
                    1. + (math.pow((phi / phi_star_1), gama_1))))))

            relative_viscosity = (1. + math.pow((phi / phi_star_1), delta_1)) / (
                math.pow((1. - F), (2.5 * phi_star_1)))

            # needle-like, B particles from Cimarelli et al., 2011
            # self.phi_max_2 = 0.36
            # delta_2 = 7.5
            # gama_2 = 5.5
            # phi_star_2 = 0.26
            # epsilon_2 = 0.0002
            #
            # F2 = (1. - epsilon_2) * math.erf(min(25., (
            #     (math.sqrt(math.pi) / (2. * (1. - epsilon_2))) * (phi2 / phi_star_2) * (
            #         1. + (math.pow((phi2 / phi_star_2), gama_2))))))
            #
            # visco_relative_costa_2 = (1. + math.pow((phi2 / phi_star_2), delta_2)) / (
            #     math.pow((1. - F2), (2.5 * phi_star_2)))

            return relative_viscosity

    def is_notcompatible(self, state):
        return False