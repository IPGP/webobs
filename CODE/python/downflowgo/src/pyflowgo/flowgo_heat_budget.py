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
import pyflowgo.base.flowgo_base_flux


class FlowGoHeatBudget:

    def __init__(self):
        self._flux_list = []
        self.flowgo_logger = pyflowgo.flowgo_logger.FlowGoLogger()

    def append_flux(self, flux):
        # makes sure the flux is indeed a flux
        assert isinstance(flux, pyflowgo.base.flowgo_base_flux.FlowGoBaseFlux)

        self._flux_list.append(flux)

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        for flux in self._flux_list:
            flux.read_initial_condition_from_json_file(filename)

    def compute_heat_budget(self, state, channel_width, channel_depth):
        heat_budget = 0.

        for flux in self._flux_list:
            heat_budget += flux.compute_flux(state, channel_width, channel_depth)
            self.flowgo_logger.add_variable(str(flux.__class__.__name__).lower(), state.get_current_position(),
                                            flux.compute_flux(state, channel_width, channel_depth))

        self.flowgo_logger.add_variable("heat_budget", state.get_current_position(), heat_budget)

        return heat_budget


