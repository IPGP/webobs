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


import pyflowgo.base.flowgo_base_crust_temperature_model


class FlowGoCrustTemperatureModelConstant(pyflowgo.base.flowgo_base_crust_temperature_model.
                                          FlowGoBaseCrustTemperatureModel):
    """
        This method "constant" considers constant temperature of the crust downflow that is set to be the
        initial_crust_temperature in the json file.

        Input data
        -----------
        json file containing the crust_temperature

        Returns
        ------------
        crust temperature in K

    """

    def __init__(self) -> None:
        super().__init__()

        self._crust_temperature = 425 + 273.15

    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)
            self._crust_temperature = float(data['thermal_parameters']['crust_temperature'])

    def compute_crust_temperature(self, state):
        return self._crust_temperature

