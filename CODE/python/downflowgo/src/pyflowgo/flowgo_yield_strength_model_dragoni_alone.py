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

import pyflowgo.base.flowgo_base_yield_strength_model


class FlowGoYieldStrengthModelDragoniAlone(pyflowgo.base.flowgo_base_yield_strength_model.FlowGoBaseYieldStrengthModel):

    """
    This methods permits to calculate the yield strength of the lava core as function of the temperature a given
    by Dragoni (1989)

        Input data
        -----------
        Temperature of the liquidus and Temperature of the lava core

        variables
        -----------
        T_core

        Returns
        ------------
        lava yield strength (Pa)

        References
        ---------
      Dragoni, M., 1989. A dynamical model of lava flows cooling by radiation. Bull. Volcanol. 51, 88–95.

    """

    def __init__(self):
        self.logger = pyflowgo.flowgo_logger.FlowGoLogger()
        self._liquidus_temperature = None
        self._eruption_temperature = None

    def read_initial_condition_from_json_file(self, filename):
            # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._liquidus_temperature = float(data['lava_state']['liquidus_temperature'])
            self._eruption_temperature = float(data['eruption_condition']['eruption_temperature'])

    def compute_yield_strength(self, state, eruption_temperature):
        # yield_strength is tho_0
        b = 0.01  # Constant B given by Dragoni, 1989[Pa]
        c = 0.08  # Constant C given by Dragoni, 1989[K-1]
        #liquidus_temperature = 1393.15
        core_temperature = state.get_core_temperature()

        # the new yield strength is calculated using this core T
        tho_0 = b * (math.exp(c * (self._liquidus_temperature - core_temperature) - 1.))
        return tho_0

    def compute_basal_shear_stress(self, state, terrain_condition, material_lava):
        """
        This methods calculates the basal yield strength of the lava flow as function of the bulk density,
        flow thickness, slope and gravity: rho * g * h * sin(alpha)

          Input data
          -----------
          rho * g * h * sin(alpha)

          variables
          -----------
          slope

          Returns
          ------------
          flow basal shear stress (Pa)

          References
          ---------
         Hulme, G., 1974. The interpretation of lava flow morphology. Geophys. J. R. Astron. Soc. 39, 361–383.

         """

        g = terrain_condition.get_gravity(state.get_current_position)
        #print('g =', str(g))
        bulk_density = material_lava.get_bulk_density(state)
        #print('bulk_density =', str(bulk_density))
        channel_depth = terrain_condition.get_channel_depth(state.get_current_position())
        channel_slope = terrain_condition.get_channel_slope(state.get_current_position())

        tho_b = channel_depth * bulk_density * g * math.sin(channel_slope)
        return tho_b

    def yield_strength_notcompatible(self, state, terrain_condition, material_lava):
        tho_0 = self.compute_yield_strength(state, self._eruption_temperature)
        tho_b = self.compute_basal_shear_stress(state, terrain_condition, material_lava)
        if tho_0 >= tho_b:
            return True
        else:
            return False
