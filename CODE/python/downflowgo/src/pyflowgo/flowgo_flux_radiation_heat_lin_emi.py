# This module was developed by James O. Thompson (Copyright 2021). 
# The module is based on MMT-Cam data acquired on the Puu Oo lava field (Kīlauea 
# voclano, HI) at 05:27-06:19 UTC on February 3, 2018 (Thompson & Ramsey 2021,2020a,b).
# This file is based on the PyFLOWGO library. Copyright 2017 PyFLOWGO development 
# team (Magdalena Oryaelle Chevrel and Jeremie Labroquere). Many thanks to the PyFLOWGO team.
#
# The PyFLOWGO library is free software: you can redistribute it and/or modify
# it under the terms of the the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version. Please see The PyFLOWGO library for more information. 
# 
# This module is currently being incorporated into the PyFLOWGO library and will be 
# available at https://github.com/pyflowgo/pyflowgo



import math
import pyflowgo.flowgo_terrain_condition
import pyflowgo.flowgo_material_lava
import pyflowgo.flowgo_yield_strength_model_basic
import pyflowgo.flowgo_material_air
import pyflowgo.flowgo_state
import pyflowgo.flowgo_crust_temperature_model_constant
import pyflowgo.flowgo_effective_cover_crust_model_basic
import pyflowgo.flowgo_logger
import json

import pyflowgo.base.flowgo_base_flux

""" This is a model from Thompson and Ramsey 2021 where radiative heat flux is calculated from a temperature-dependent 
emissivity :

epsilon_effective = 1.0463014 + (effective_radiation_temperature * -0.000148144)

References:

Thompson, J. O., & Ramsey, M. S. (2021). The influence of variable emissivity on lava flow propagation modeling. 
Bulletin of Volcanology, 83(6), 1–19. https://doi.org/10.1007/s00445-021-01462-3


"""

class FlowGoFluxRadiationHeat(pyflowgo.base.flowgo_base_flux.FlowGoBaseFlux):

    #def __init__(self, terrain_condition, material_lava, crust_temperature_model):
    def __init__(self, terrain_condition, material_lava, material_air, crust_temperature_model, effective_cover_crust_model):
        self._material_lava = material_lava
        self._material_air = material_air
        self._crust_temperature_model = crust_temperature_model
        self._terrain_condition = terrain_condition
        self._effective_cover_crust_model = effective_cover_crust_model
        self.logger = pyflowgo.flowgo_logger.FlowGoLogger()
        self._sigma = 0.0000000567  # Stefan-Boltzmann [W m-1 K-4]


    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)
            self._sigma = float(data['radiation_parameters']['stefan-boltzmann_sigma'])

    def _compute_effective_radiation_temperature(self, state, terrain_condition):
        """" the effective radiation temperature of the surface (Te) is given by
        Pieri & Baloga 1986; Crisp & Baloga, 1990; Pieri et al. 1990)
        Equation A.6 Chevrel et al. 2018"""

        # The user is free to adjust the model, for example, f_crust (effective_cover_fraction)
        # can be set as a constant or can be varied
        # downflow as a function of velocity (Harris & Rowland 2001).
        # the user is also free to choose the temperature of the crust (crust_temperature_model)

        effective_cover_fraction = self._effective_cover_crust_model.compute_effective_cover_fraction(state)
        crust_temperature = self._crust_temperature_model.compute_crust_temperature(state)
        molten_material_temperature = self._material_lava.computes_molten_material_temperature(state)
        air_temperature = self._material_air.get_temperature()

        #effective_radiation_temperature = math.pow(effective_cover_fraction * crust_temperature ** 4. +
        #                                          (1. - effective_cover_fraction) * molten_material_temperature ** 4.,0.25)

        effective_radiation_temperature = math.pow(
            effective_cover_fraction * (crust_temperature ** 4. - air_temperature ** 4.) +
            (1. - effective_cover_fraction) * (molten_material_temperature ** 4. - air_temperature ** 4.),
            0.25)

        self.logger.add_variable("effective_radiation_temperature", state.get_current_position(),
                                 effective_radiation_temperature)
        return effective_radiation_temperature

    def _compute_emissivity_crust(self, state, terrain_condition):
        crust_temperature = self._crust_temperature_model.compute_crust_temperature(state)
        emissivity_crust = 1.0463014 + (crust_temperature * -0.000148144)
        return emissivity_crust

    def _compute_emissivity_molten(self, state, terrain_condition):
        molten_material_temperature = self._material_lava.computes_molten_material_temperature(state)
        emissivity_molten = 1.0463014 + (molten_material_temperature * -0.000148144)
        return emissivity_molten


    def _compute_epsilon_effective(self, state, terrain_condition):

        effective_radiation_temperature = self._compute_effective_radiation_temperature \
            (state, self._terrain_condition)

        epsilon_effective = 1.0463014 + (effective_radiation_temperature * -0.000148144)

        self.logger.add_variable("epsilon_effective", state.get_current_position(),
                                 epsilon_effective)
        return epsilon_effective


    def _compute_spectral_radiance (self, state, terrain_condition, channel_width):
        effective_cover_fraction = self._effective_cover_crust_model.compute_effective_cover_fraction(state)
        crust_temperature = self._crust_temperature_model.compute_crust_temperature(state)
        molten_material_temperature = self._material_lava.computes_molten_material_temperature(state)
        background_temperature = 258  # K
        # crust_temperature = 273.15

        emissivity_crust = self._compute_emissivity_crust(state, self._terrain_condition)
        emissivity_molten = self._compute_emissivity_molten(state, self._terrain_condition)

        # area per pixel
        #Lpixel = 30.0 #I changed this
        Lpixel = 0.100
        A_pixel = Lpixel * Lpixel
        A_lava = Lpixel * channel_width
        Ahot = A_lava * (1 - effective_cover_fraction)
        Acrust = A_lava * effective_cover_fraction
        # portion of pixel cover by molten lava
        Phot = Ahot / A_pixel
        print("Phot",Phot)
        Pcrust = Acrust / A_pixel
        atmospheric_transmissivity = 0.8

        # emissivity of snow
        epsilon_3 = 0.1

        lamda = 0.8675 * 10 ** (-6)  # micro
        h = 6.6256 * 10 ** (-34)  # Js
        c = 2.9979 * 10 ** 8  # ms-1
        C1 = 2 * math.pi * h * c ** 2  # W.m^2

        kapa = 1.38 * 10 ** (-23)  # JK-1
        C2 = h * c / kapa  # m K
        print("c2", C2)
        # crust component
        crust_spectral_radiance = (C1 * lamda ** (-5)) / (math.exp(C2 / (lamda * crust_temperature)) - 1)
        print("crust_spectral_radiance",crust_spectral_radiance)
        # molten component
        molten_spectral_radiance = C1 * lamda ** (-5) / (math.exp(C2 / (lamda * molten_material_temperature)) - 1)
        print("molten_spectral_radiance", molten_spectral_radiance)
        # background component
        background_spectral_radiance = C1 * lamda ** (-5) / (math.exp(C2 / (lamda * background_temperature)) - 1)
        print("background_spectral_radiance",background_spectral_radiance)
        # equation radiance W/m2/m

        spectral_radiance_m = atmospheric_transmissivity * (emissivity_molten * Phot * molten_spectral_radiance +
                                                            emissivity_crust * Pcrust * crust_spectral_radiance +
                                                            (1 - Phot - Pcrust) * epsilon_3 * background_spectral_radiance)

        # equation radiance W/m2/micro
        spectral_radiance = spectral_radiance_m * 10 ** (-6)

        self.logger.add_variable("spectral_radiance", state.get_current_position(), spectral_radiance)

        return spectral_radiance


    def compute_flux(self, state, channel_width, channel_depth):
        effective_radiation_temperature = self._compute_effective_radiation_temperature \
            (state, self._terrain_condition)

        epsilon_effective = self._compute_epsilon_effective(state, self._terrain_condition)

        qradiation = self._sigma * epsilon_effective * (effective_radiation_temperature ** 4.) * channel_width

        # TODO: add on AUG 29_ compute spectral_radiance
        spectral_radiance = self._compute_spectral_radiance(state, self._terrain_condition, channel_width)

        return qradiation
