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

import json
import pyflowgo.base.flowgo_base_vesicle_fraction_model


class FlowGoVesicleFractionModelVariableBimodal(pyflowgo.base.flowgo_base_vesicle_fraction_model.
                                        FlowGoBaseVesicleFractionModel):


    """ This method "variable_bimodal" considers the volume fraction of vesicle (bubbles) to vary linearly with distnace
     from the vent until a critical distance and then it is constant

        %vesicles_fraction_1 = vesicles_fraction init - x * distance
        %vesicles_fraction_2  is constant

        Input data
        -----------
        json file containing the initial vesicle fraction, the decreasing coeficient and the constant vesicle fractio

        variables
        -----------
         distance = 0 in the json file and then is calculated down flow
            if distance < critic distance : new_vesicle = initial vesicle - (coeficient * distance)
           if distance > critic distance : constant
        Returns
        ------------
        new_vesicle fraction

        """
    def __init__(self) -> None:
        super().__init__()
        # this is the Volume fraction considered constant along the flow
        self._critical_distance = 10000.
        self._vesicle_fraction = 0.4
        self._vesicle_coef = 0.01

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)

            if 'vesicle_coef' not in data['lava_state']:
                raise ValueError("Missing ['lava_state']['vesicle_coef'] entry in json")

            if 'critical_distance' not in data['lava_state']:
                raise ValueError("Missing ['lava_state']['critical_distance'] entry in json")

            self._critical_distance = float(data['lava_state']['critical_distance'])
            self._vesicle_fraction = float(data['lava_state']['vesicle_fraction'])
            self._vesicle_coef = float(data['lava_state']['vesicle_coef'])

    def get_vesicle_fraction(self):
        return self._vesicle_fraction

    def set_vesicle_fraction(self, vesicle_fraction):
        self._vesicle_fraction = vesicle_fraction

    def computes_vesicle_fraction(self, state):
        """this function permits to calculate the new vesicle fraction"""
        current_position = state.get_current_position()

        if current_position <= self._critical_distance:
            vesicle_fraction = self._vesicle_fraction - self._vesicle_coef * current_position
            return vesicle_fraction
        else:
            vesicle_fraction = self._vesicle_fraction - self._vesicle_coef * self._critical_distance
            return vesicle_fraction




