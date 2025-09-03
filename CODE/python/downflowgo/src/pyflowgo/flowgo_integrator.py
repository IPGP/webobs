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

import pyflowgo.flowgo_logger
import numpy as np
import json
import math

class FlowGoIntegrator:

    """ The integrator allows to make the flow front advancing
    It is here that the differential equation of the flow advance is solved
    and here where the limits are fixed"""

    def __init__(self, dx, material_lava, material_air, terrain_condition, heat_budget,
                 crystallization_rate_model, crust_temperature_model, effective_cover_crust_model,
                 mass_conservation):
        """ this function allows to set the initial parameters"""
        self.logger = pyflowgo.flowgo_logger.FlowGoLogger()
        self.dx = dx  # in m
        self._has_finished = False
        self.effusion_rate = 0.
        self.iteration = 0.
        self.crystallization_rate_model = crystallization_rate_model
        self.crust_temperature_model = crust_temperature_model
        self.effective_cover_crust_model = effective_cover_crust_model
        self.material_lava = material_lava
        self.material_air = material_air
        self.terrain_condition = terrain_condition
        self.heat_budget = heat_budget
        self.mass_conservation = mass_conservation

    def init_effusion_rate(self, current_state):

        if self.terrain_condition.get_effusion_rate_init(current_state.get_current_position()) == 0.:
            pass
        else:
            for channel_depth in np.arange(0.01, 50.0, 0.001):

                self.terrain_condition.set_channel_depth(channel_depth)
                v_mean = self.material_lava.compute_mean_velocity(current_state, self.terrain_condition)

                channel_width = self.terrain_condition.get_channel_width(current_state.get_current_position())
                self.effusion_rate = v_mean * channel_width * channel_depth
                self.flux_rate = self.effusion_rate * self.material_lava.get_bulk_density(current_state)
                effusion_rate_init = self.terrain_condition.get_effusion_rate_init(current_state.get_current_position())
                if self.effusion_rate >= effusion_rate_init:

                    print('channel_depth =' + str(channel_depth))
                    break


    def single_step(self, current_state):
        """This function makes the flow advancing it takes the velocity that was calculated in material lava and check
        whether it is positif and then calculate the heat budget in order to get the new temperature and new crystal
        content in order to get the new viscosity and therefore with this new viscosity it calculates the new velocity
        as a function of the slope at this current location (that is given by the slope_distance file or by
        interpolation of it)"""

        v_mean = self.material_lava.compute_mean_velocity(current_state, self.terrain_condition)

        if v_mean <= 0.:
            self._has_finished = True
            return
        print('Vmean (m/s)=', v_mean)

        # computes the quantities at this current state from the terrain condition
        channel_depth = self.terrain_condition.get_channel_depth(current_state.get_current_position())
        # Here we set the initial condition (iteration = 0) and calculate the effusion rate
        #TODO: verifier si c'est bon en enlevant cette iteration
        if self.iteration == 0.:
            channel_width = self.terrain_condition.get_channel_width(current_state.get_current_position())
        # TODO: verifier si c'est bon en enlevant ce calcul
            self.effusion_rate = v_mean * channel_width * channel_depth

        # Here we start the loop
        # Base on mass conservation, the effusion rate and the depth channel are kept fixed, so the width can
        # be calculated at each step :
        print('distance from vent (m) =', current_state.get_current_position())

        # Switch between volume and mass conservation
        bulk_density = self.material_lava.get_bulk_density(current_state)
        if self.mass_conservation:
            channel_width = self.flux_rate / (v_mean * channel_depth) / bulk_density
        else: 
            channel_width = self.effusion_rate / (v_mean * channel_depth)

        #TODO: Here I add the slope:ASK MIMI TO MOVE IT FROM HERE
        channel_slope = self.terrain_condition.get_channel_slope(current_state.get_current_position())
        # print("slope=",channel_slope)

        # ------------------------------------------------- HEAT BUDGET ------------------------------------------------
        # Here the right hand side (rhs) from Eq. 7b, Harris and Rowland (2001)
        # rhs = dT/dx

        rhs = -self.heat_budget.compute_heat_budget(current_state, channel_width, channel_depth)

        # ------------------------------------------------ COOLING RATE ------------------------------------------------
        # 4) now we calculate the temperature variation
        # first we need the crystallization_rate = dphi_dtemp this will be changed by looking directly into pyMELTS,
        # to get the right amount of crystals at this new temperature.
        # crystallization rate model
        dphi_dtemp = self.crystallization_rate_model.compute_crystallization_rate(current_state) # je rajoute current state 23 dec

        # Cooling per unit of distance is calculated
        # from Eq. 7b HR01 / Eq. 21 HR14 / Eq. 15 Harris et al. 2015 / Eq. 21 HR14
        latent_heat_of_crystallization = self.material_lava.get_latent_heat_of_crystallization()

        # Here we solve the differential equation
        dtemp_dx = (rhs / (self.effusion_rate * bulk_density * latent_heat_of_crystallization * dphi_dtemp))
        dtemp_dt=-dtemp_dx*v_mean*60.0
        #print(dphi_dtemp)
        # ------------------------------------------ CRYSTALLIZATION PER METER -----------------------------------------
        dphi_dx = dtemp_dx * (-dphi_dtemp)

        # ------------------------- NEW CRYSTAL FRACTION AND NEW TEMPERATURE USED FOR NEXT STEP ------------------------
        # the new cristal fraction due to the temperature decrease for the current step is
        # (Euler step for solving differential equation) :

        phi = current_state.get_crystal_fraction()
        new_phi = phi + (dphi_dx * self.dx)
        print('phi=',new_phi)
        if new_phi <= phi:
            self._has_finished = True
            return

        # ------------------------------------------ NOW WE JUMP TO THE NEXT STEP --------------------------------------
        # we calculate the new core temperature in K for the the next line, using Euler as well

        temp_core = current_state.get_core_temperature()
        new_temp_core = temp_core + dtemp_dx * self.dx
        print('Tcore=',new_temp_core)
        # ------------------------------------- LOG ALL THE VALUES INTO THE LOGGER -------------------------------------
        self.logger.add_variable("channel_width", current_state.get_current_position(), channel_width)
        self.logger.add_variable("crystal_fraction", current_state.get_current_position(),
                                 current_state.get_crystal_fraction())
        self.logger.add_variable("core_temperature", current_state.get_current_position(),
                                 current_state.get_core_temperature())
        self.logger.add_variable("strain_rate", current_state.get_current_position(),
                                 current_state.get_strain_rate())
        self.logger.add_variable("vesicle_fraction", current_state.get_current_position(),
                                 self.material_lava.computes_vesicle_fraction(current_state))
        self.logger.add_variable("viscosity", current_state.get_current_position(),
                                 self.material_lava.computes_bulk_viscosity(current_state))
        self.logger.add_variable("density", current_state.get_current_position(),
                                 self.material_lava.get_bulk_density(current_state))
        self.logger.add_variable("mean_velocity", current_state.get_current_position(), v_mean)
        self.logger.add_variable("crust_temperature", current_state.get_current_position(),
                                 self.crust_temperature_model.compute_crust_temperature(current_state))
        self.logger.add_variable("effective_cover_fraction", current_state.get_current_position(),
                                 self.effective_cover_crust_model.compute_effective_cover_fraction(current_state))
        self.logger.add_variable("dphi_dx", current_state.get_current_position(), dphi_dx)
        self.logger.add_variable("dtemp_dx", current_state.get_current_position(), dtemp_dx)
        # self.logger.add_variable("latent_heat_of_crystallization", current_state.get_current_position(),
                                 # latent_heat_of_crystallization)
        self.logger.add_variable("dphi_dtemp", current_state.get_current_position(), dphi_dtemp)
        # self.logger.add_variable("current_time", current_state.get_current_position(),
        # current_state.get_current_time())
        self.logger.add_variable("dtemp_dt", current_state.get_current_position(),dtemp_dt)
        self.logger.add_variable("slope", current_state.get_current_position(), channel_slope)
        self.logger.add_variable("effusion_rate", current_state.get_current_position(), str(self.effusion_rate))
        self.logger.add_variable("channel_depth", current_state.get_current_position(),channel_depth)
        self.logger.add_variable("tho_0", current_state.get_current_position(),
                                 self.material_lava.get_yield_strength(current_state))
        self.logger.add_variable("tho_b", current_state.get_current_position(),
                                 self.material_lava.get_basal_shear_stress(current_state, self.terrain_condition))

        # -------------------------- UPDATE THE STATE WITH NEW CRYSTAL FRACTION AND NEW TEMPERATURE ----------------
        current_state.set_crystal_fraction(new_phi)
        current_state.set_core_temperature(new_temp_core)

        current_state.set_current_position(current_state.get_current_position() + self.dx)
        current_state.set_current_time(current_state.get_current_time() + self.dx / v_mean)

        current_state.set_strain_rate(3*v_mean/channel_depth)

        self.iteration += 1.

        if (new_temp_core <= self.crystallization_rate_model.get_solid_temperature()) \
                or (self.material_lava.is_notcompatible(current_state)) \
                or (self.material_lava.yield_strength_notcompatible(current_state, self.terrain_condition)) \
                or (current_state.get_current_position() >= self.terrain_condition.get_max_channel_length()):
            self._has_finished = True
            return
    # ------------------------------------------------ FINISH THE LOOP -------------------------------------------------

    def has_finished(self):
        return self._has_finished

    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)
        self._effusion_rate_init = float(data['effusion_rate_init'])
        self._width = float(data['terrain_conditions']['width'])
        self._depth = float(data['terrain_conditions']['depth'])

    # ------------------------------------------------ INITIALIZE THE STATE --------------------------------------------

    def initialize_state(self, current_state, filename):

        current_state.read_initial_condition_from_json_file(filename)

        # retrieve other values from external
        initial_temperature = self.material_lava.get_eruption_temperature()
        initial_crystal_fraction = self.crystallization_rate_model.get_crystal_fraction(initial_temperature)

        current_state.set_crystal_fraction(initial_crystal_fraction)
        current_state.set_core_temperature(initial_temperature)
        current_state.set_strain_rate(3*self._effusion_rate_init/math.pow(self._depth,2)/self._width)