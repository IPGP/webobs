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


class FlowGoYieldStrengthModelRyerson(pyflowgo.base.flowgo_base_yield_strength_model.FlowGoBaseYieldStrengthModel):

    """This methods permits to calculate the yield strength of the lava core as function of the
     crystal cargo according to Ryerson et al. (1988) and as proposed by Pinkerton and Stevenson 1994
      tho_0 = 6500. * (crystal_fraction ** 2.85)

    Input data
    -----------
    crystal fraction

    variables
    -----------
    crystal fraction: phi

    Returns
    ------------
    lava yield strength due to the crystal cargo

    References
    ---------
   Ryerson, F.J., Weed, H.C., Piwinskii, A.J., 1988. Rheology of subliquidus magmas: picritic compositions.
   J. Geophys. Res. 93, 3421–3436.

   Pinkerton, H., Stevenson, R.J., 1992. Methods of determining the rheological properties of magmas at sub-liquidus
   temperatures. J. Volcanol. Geotherm. Res. 53, 47–66

    """

    def __init__(self):
        self.logger = pyflowgo.flowgo_logger.FlowGoLogger()
        self._eruption_temperature = None

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._eruption_temperature = float(data['eruption_condition']['eruption_temperature'])

    def compute_yield_strength(self, state, eruption_temperature):
        # tho_0 is the yield_strength
        crystal_fraction = state.get_crystal_fraction()
        tho_0 = 6500. * (crystal_fraction ** 2.85)
        return tho_0

    def compute_basal_shear_stress(self, state, terrain_condition, material_lava):
        # tho_b is the basal shearstress
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
        bulk_density = material_lava.get_bulk_density(state)
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
