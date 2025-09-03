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
import pyflowgo.flowgo_terrain_condition
import pyflowgo.flowgo_material_lava
import pyflowgo.flowgo_yield_strength_model_basic
import pyflowgo.flowgo_material_air
import pyflowgo.flowgo_state
import pyflowgo.flowgo_crust_temperature_model_constant
import json
import pyflowgo.base.flowgo_base_flux


class FlowGoFluxConductionHeat(pyflowgo.base.flowgo_base_flux.FlowGoBaseFlux):

    """
    This method calculate the heat loss due to conduction through the flow base and levees process according to Harris
    and Rowland (2001)

    Input data
    -----------
    Values from json files:

    core_base_distance (in %) that is percentage that represent the base layer to the entire thickness of the channel

    base temperature

    channel_depth

    thermal conductivity = (1.929 - 1.554 * vesicle_fraction) ** 2  in [W m-1 K-1]

    h_base that is the height of thermal boundry layer at flow base
    h_base = core_base_distance / 100. * channel_depth  # Thickness of the basal crust/ field observation [m]

    Variables
    ------------
    core temperature
    vesicle fraction

    Returns
    ------------
    the crystallization rate in fraction of crystals per degree

    References
    ---------

    """

    def __init__(self, material_lava):

        self._base_temperature = 500. + 273.15  # Temperature at the base of the flow [K] .
        self._core_base_distance = 19.  # Core to base distance, as a percentage of the total flow thickness [%]
        self._material_lava = material_lava

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._base_temperature = float(data['conduction_parameters']['basal_temperature'])
            self._core_base_distance = float(data['conduction_parameters']['core_base_distance'])

    def compute_flux(self, state, channel_width, channel_depth):
        core_temperature = state.get_core_temperature()
        vesicle_fraction = self._material_lava.computes_vesicle_fraction(state)
        thermal_conductivity = (1.929 - 1.554 * vesicle_fraction) ** 2  # thermal conductivity [W m-1 K-1]
        h_base = self._core_base_distance / 100. * channel_depth  # Thickness of the basal crust/ field observation [m]

        qconduction = thermal_conductivity * ((core_temperature - self._base_temperature) / h_base) * channel_width

        return qconduction
