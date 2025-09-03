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


class FlowGoYieldStrengthModelBLL(pyflowgo.base.flowgo_base_yield_strength_model.FlowGoBaseYieldStrengthModel):

    """This methods permits to calculate the effect of crystal and bubble cargo on yield strength according to
    Birnbaum, Lev, and Llewellin 2021, equation 4a,b. They propose a treatment for the viscosity of a three‐phase mixture
    comprising a suspension of rigid particles and bubbles based on analogue experiments.
    The input parameters include the crystal fraction (phi) and the bubbles fraction (vesicle_fraction retrieved
    from the vesicle_fraction_model)

    Input data
    -----------
    crystal fraction
    vesicle fraction

    variables
    -----------
    crystal fraction: phi
    vesicle fraction: vesicle_fraction

    Returns
    ------------
    lava yield strength due to the crystal and bubble cargo: Eq. 4.1b
    τy = 10 ^ C1(φsolid −φc,τy ) + 10^ C2 (φsolid +φgas −φc,τy )

    Reference
    ---------

    Birnbaum, J., Lev, E., Llewellin, E. W. (2021) Rheology of three-phase suspensions determined
    via dam-break experiments. Proc. R. Soc. A 477 (20210394): 1-16.

        https://zenodo.org/records/4707969

    """
    #  TODO: here I add the log
    def __init__(self, vesicle_fraction_model=None):
        self.logger = pyflowgo.flowgo_logger.FlowGoLogger()

        if vesicle_fraction_model == None:
            self._vesicle_fraction_model = pyflowgo.flowgo_vesicle_fraction_model_constant.FlowGoVesicleFractionModelConstant()
        else:
            self._vesicle_fraction_model = vesicle_fraction_model

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._eruption_temperature = float(data['eruption_condition']['eruption_temperature'])

    def compute_yield_strength(self, state, eruption_temperature):
        # yield_strength is tho_0
        phi = state.get_crystal_fraction()
        vesicle_fraction = self._vesicle_fraction_model.computes_vesicle_fraction(state)

        phi_crit_ys = 0.35
        tho_0 = math.pow(10,80.0*(phi - phi_crit_ys)) + math.pow(10,1.98*(phi + vesicle_fraction - phi_crit_ys))

        # with  respect to 3 phase
        #tho_0 = math.pow(10, 80 * (phi / (1 - vesicle_fraction) - phi_crit_ys)) + math.pow(10,
        #    1.98 * (phi / (1 - vesicle_fraction) + vesicle_fraction - phi_crit_ys))
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
