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

""" This is a model the calculated the heat loss from the surface of the lava in channel following Snyder 2002 
where radiative heat and convective heat are merged (equation extracted from Fig 4 in Snyder 2002 ) 
and used in Flynn et al. submitted to JGR, 

References:

Snyder, D. (2002). Cooling of lava flows on Venus: The coupling of radiative and convective heat transfer. 
Journal of Geophysical Research E: Planets, 107(10), 1–8. https://doi.org/10.1029/2001je001501

Flynn, Chevrel and Ramsey. Adaptation of a thermorheological lava flow model for Venus conditions 
manuscript submitted to JGR Planets

"""

class FlowGoFluxSnyderHeat(pyflowgo.base.flowgo_base_flux.FlowGoBaseFlux):

    def __init__(self, terrain_condition, material_lava, crust_temperature_model, effective_cover_crust_model):

        self._material_lava = material_lava
        self._terrain_condition = terrain_condition
        self._crust_temperature_model = crust_temperature_model
        self._effective_cover_crust_model = effective_cover_crust_model
        self.logger = pyflowgo.flowgo_logger.FlowGoLogger()

        self._air_temperature = 0

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._air_temperature = float(data['convection_parameters']['air_temperature'])

    def compute_effective_temperature_snyder(self, state, terrain_condition):

        """ This computes the effective surface temperature that is the temperature of the surface lava in the chanel
        that depends on the proportion of crust and hot material. Equation 10 from Flynn et al. """

        crust_temperature = self._crust_temperature_model.compute_crust_temperature(state)
        effective_cover_fraction = self._effective_cover_crust_model.compute_effective_cover_fraction(state)
        molten_material_temperature = self._material_lava.computes_molten_material_temperature(state)

        effective_temperature_snyder = effective_cover_fraction * crust_temperature + (1. - effective_cover_fraction) * molten_material_temperature

        #effective_temperature_snyder = effective_cover_fraction * (crust_temperature - air_temperature) + (1. - effective_cover_fraction) * (molten_material_temperature- air_temperature)

        self.logger.add_variable("effective_temperature_snyder", state.get_current_position(),
                                 effective_temperature_snyder)

        return effective_temperature_snyder


    def compute_flux(self, state, channel_width, channel_depth):
        # here is the equation that represent the curve of figure 4 from Snyder 2002:

        effective_temperature_snyder = self.compute_effective_temperature_snyder(state, self._terrain_condition)

        effective_radiation_temperature = 0

        qsnyder = (1.07*10**-13 * effective_temperature_snyder**4.85 * channel_width)*1000

        # set other flux to zero so I log them all
        flowgofluxforcedconvectionheat = 0
        flowgofluxradiationheat = 0
        characteristic_surface_temperature = 0

        self.logger.add_variable("characteristic_surface_temperature", state.get_current_position(),
                                 characteristic_surface_temperature)
        self.logger.add_variable("effective_radiation_temperature", state.get_current_position(),
                                 effective_radiation_temperature)
        self.logger.add_variable("flowgofluxforcedconvectionheat", state.get_current_position(), flowgofluxforcedconvectionheat)
        self.logger.add_variable("flowgofluxradiationheat", state.get_current_position(),
                                 flowgofluxradiationheat)

        return qsnyder
