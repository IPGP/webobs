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

import pyflowgo.base.flowgo_base_effective_cover_crust_model


class FlowGoEffectiveCoverCrustModelBimodal(pyflowgo.base.flowgo_base_effective_cover_crust_model.
                                            FlowGoBaseEffectiveCoverCrustModel):


    """ This method allows to compute the effective cover crust  (then used to calculate the radiation)
    as a function of v_mean downslope where "bimodal" allows to change the effective crust cover values after a
    given distance as suggested in Harris and Rowland (2015)
    This method "bimodal" allows to calculate the effective cover fraction (f_crust) as a function of velocity fallowing
    Harris & Rowland (2001):
    f_crust = fc * math.exp(alpha * v_mean)

    where fc is the crust_cover_fraction that is either equals to 1 or is comprise between 0 and 1

    and alpha changes after a given distance, as usggested by Harris & Rowland (2015)
    For For Mauna Loa 1859 before 10 km fc = 0.9023 and alpha = –0.04778 (poorly crusted) and after 10 km
    ,fc =0.9023, alpha = =–0.03652 (more heavily crusted)


    Input data
    -----------
    from the json file:
    the critical distance and the two alpha values


    Returns
    ------------
    the effective crust cover fraction

    References
    -------------
    Harris AJL and Rowland SK (2015) FLOWGO 2012: An updated framework for thermorheological simulations of
    Channel-Contained lava. In Carey R, Cayol V, Poland M, and Weis D, eds., Hawaiian Volcanoes:
    From Source to Surface, Am Geophys Union Geophysical Monograph 208

    """

    def __init__(self, terrain_condition, material_lava):
        self._material_lava = material_lava
        self._terrain_condition = terrain_condition

        # For Mauna Loa 1859
        self._critical_distance = 10000.
        self._alpha_1 = - 0.04778
        self._alpha_2 = - 0.03652

        # MaunaULU
        # critical_distance = 4000.:

        self._alpha = -7.56e-3
        self._crust_cover_fraction = 0.9
        self._crust_cover_fraction_2 = 0.0

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)

            if 'critical_distance' not in data['lava_state']:
                raise ValueError("Missing ['lava_state']['critical_distance'] entry in json")

            if 'alpha_1' not in data['thermal_parameters']:
                raise ValueError("Missing ['thermal_parameters']['alpha_1'] entry in json")

            if 'alpha_2' not in data['thermal_parameters']:
                raise ValueError("Missing ['thermal_parameters']['alpha_2'] entry in json")

            self._critical_distance = float(data['lava_state']['critical_distance'])
            self._alpha_1 = float(data['thermal_parameters']['alpha_1'])
            self._alpha_2 = float(data['thermal_parameters']['alpha_2'])
            self._crust_cover_fraction = float(data['thermal_parameters']['crust_cover_fraction'])
            self._crust_cover_fraction_2 = float(data['thermal_parameters']['crust_cover_fraction_2'])

    def compute_effective_cover_fraction(self, state):
        current_position = state.get_current_position()

        v_mean = self._material_lava.compute_mean_velocity(state, self._terrain_condition)

        if current_position <= self._critical_distance:
            return self._crust_cover_fraction * math.exp(self._alpha_1 * v_mean)
        else:
            return self._crust_cover_fraction_2 * math.exp(self._alpha_2 * v_mean)
