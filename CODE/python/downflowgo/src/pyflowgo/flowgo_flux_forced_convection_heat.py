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
import pyflowgo.flowgo_logger

import pyflowgo.base.flowgo_base_flux


class FlowGoFluxForcedConvectionHeat(pyflowgo.base.flowgo_base_flux.FlowGoBaseFlux):

    def __init__(self, terrain_condition, material_air, material_lava, crust_temperature_model, effective_cover_crust_model):
        self._material_air = material_air
        self._material_lava = material_lava
        self._terrain_condition = terrain_condition
        self._crust_temperature_model = crust_temperature_model
        self._effective_cover_crust_model = effective_cover_crust_model
        self.logger = pyflowgo.flowgo_logger.FlowGoLogger()

    def compute_characteristic_surface_temperature(self, state, terrain_condition):
        """ This is Tconv of Harris and Rowland"""
        crust_temperature = self._crust_temperature_model.compute_crust_temperature(state)
        effective_cover_fraction = self._effective_cover_crust_model.compute_effective_cover_fraction(state)
        molten_material_temperature = self._material_lava.computes_molten_material_temperature(state)
        characteristic_surface_temperature = math.pow((effective_cover_fraction * crust_temperature **
                                                       1.333 + (1. - effective_cover_fraction) *
                                                       molten_material_temperature ** 1.333),0.75)
        self.logger.add_variable("characteristic_surface_temperature", state.get_current_position(),
                                 characteristic_surface_temperature)
        return characteristic_surface_temperature

    def compute_flux(self, state, channel_width, channel_depth):
        conv_heat_transfer_coef = self._material_air.compute_conv_heat_transfer_coef()
        air_temperature = self._material_air.get_temperature()

        characteristic_surface_temperature = self.compute_characteristic_surface_temperature \
            (state, self._terrain_condition)
            # For convection, we use a calculation of the convective heat transfer coefficient
            # taken from Keszthelyi & Denlinger (1996), whereby: h_c = C_H * rho_air * C_p_air * U
        qforcedconv = conv_heat_transfer_coef * (
            characteristic_surface_temperature - air_temperature) * channel_width

        #log Snyder flux to zero
        effective_temperature_snyder = 0
        flowgofluxsnyderheat = 0
        self.logger.add_variable("effective_temperature_snyder", state.get_current_position(),
                                 effective_temperature_snyder)
        self.logger.add_variable("flowgofluxsnyderheat", state.get_current_position(), flowgofluxsnyderheat)

        return qforcedconv

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
