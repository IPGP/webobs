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

import pyflowgo.flowgo_vesicle_fraction_model_constant
import pyflowgo.flowgo_vesicle_fraction_model_bimodal

import pyflowgo.base.flowgo_base_relative_viscosity_bubbles_model


class FlowGoRelativeViscosityBubblesModelDefo(pyflowgo.base.flowgo_base_relative_viscosity_bubbles_model.
                                              FlowGoBaseRelativeViscosityBubblesModel):
    """This methods permits to calculate the effect of bubbles on viscosity according to Llewelin and Manga (2005).
        In this model bubbles are deformable and hence can be elongated and lower viscosity

    Input data
    -----------
    The vesicle fraction in the json file containing

    Variables
    -----------
    The vesicle fraction

    Returns
    ------------
    The effect of elongated bubbles on viscosity

    References
    ---------
    Llewellin, E.W., Manga, M., 2005. Bubble suspension rheology and implications for conduit flow.
    Journal of Volcanology and Geothermal Research 143, 205–217. http:// dx.doi.org/10.1016/j.jvolgeores.2004.09.018.
    """

    def __init__(self, vesicle_fraction_model=None):
        super().__init__()

        if vesicle_fraction_model == None:
            self._vesicle_fraction_model = pyflowgo.flowgo_vesicle_fraction_model_constant.\
                FlowGoVesicleFractionModelConstant()
        else:
            self._vesicle_fraction_model = vesicle_fraction_model

    def read_initial_condition_from_json_file(self, filename):
        # read json parameters file
        with open(filename) as data_file:
            data = json.load(data_file)

    def compute_relative_viscosity_bubbles(self, state):
        vesicle_fraction = self._vesicle_fraction_model.computes_vesicle_fraction(state)

        relative_viscosity_bubbles = math.pow((1. - vesicle_fraction), (5. / 3.))
        return relative_viscosity_bubbles
