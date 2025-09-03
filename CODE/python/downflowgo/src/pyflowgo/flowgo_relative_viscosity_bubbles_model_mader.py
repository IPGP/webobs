# Copyright 2017 PyFLOWGO development team (Magdalena Oryaelle Chevrel and Jeremie Labroquere)
#
# This file is part of the PyFLOWGO library.
#
# The PyFLOWGO library is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
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
import pyflowgo.flowgo_melt_viscosity_model_shaw
import pyflowgo.flowgo_relative_viscosity_model_kd
import pyflowgo.base.flowgo_base_relative_viscosity_bubbles_model
import pyflowgo.flowgo_material_lava

class FlowGoRelativeViscosityBubblesModelMader(pyflowgo.base.flowgo_base_relative_viscosity_bubbles_model.
    FlowGoBaseRelativeViscosityBubblesModel):
    """This methods permits to calculate the effect of bubbles on viscosity according to the algorithme of Mader et al.
   (2013), Figure 15, but without calculating the dynamic capilarity
       Determination of:
        1) shear conditions
        2) relaxation time, Eq. (3). λ = melt * radius/surface tension
        2) the capillary number Ca is caclulated with Eq. (2), 〈Ca〉= λ * strain rate


    Input data
    -----------
    The vesicle fraction obtained from the vesicle fraction model
    Strain rate obtained from

    Variables
    -----------
    The vesicle fraction
    melt phase (or melt + crystal phase)

    Returns
    ------------
    The effect of bubbles on viscosity

    References
    ---------
    """
    def __init__(self, vesicle_fraction_model=None, melt_viscosity_model=None, relative_viscosity_model = None):
        super().__init__()

        if vesicle_fraction_model == None:
            self._vesicle_fraction_model = pyflowgo.flowgo_vesicle_fraction_model_constant.FlowGoVesicleFractionModelConstant()
        else:
            self._vesicle_fraction_model = vesicle_fraction_model

        if melt_viscosity_model == None:
            self._melt_viscosity_model = pyflowgo.flowgo_melt_viscosity_model_shaw.FlowGoMeltViscosityModelShaw()
        else:
            self._melt_viscosity_model = melt_viscosity_model

        if relative_viscosity_model == None:
            self._relative_viscosity_model = pyflowgo.flowgo_relative_viscosity_model_kd.FlowGoRelativeViscosityModelKD()
        else:
            self._relative_viscosity_model = relative_viscosity_model

    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)

            if 'vesicle_radius' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing vesicle_radius in ['relative_viscosity_parameters'] entry in json")
            if 'surface_tension' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing 'surface_tension' in ['relative_viscosity_parameters'] entry in json")

            self._vesicle_radius = float(data['relative_viscosity_parameters']['vesicle_radius'])
            self._surfacetension = float(data['relative_viscosity_parameters']['surface_tension'])

    def compute_relative_viscosity_bubbles(self, state):
        strain_rate = state.get_strain_rate()
        print("strain_rate", strain_rate)
        vesicle_fraction = self._vesicle_fraction_model.computes_vesicle_fraction(state)
        melt_viscosity = self._melt_viscosity_model.compute_melt_viscosity(state)

        relative_viscosity_crystals = self._relative_viscosity_model.compute_relative_viscosity(state)

        effective_medium_viscosity = melt_viscosity * relative_viscosity_crystals

        relaxation_time = self._vesicle_radius * effective_medium_viscosity / self._surfacetension
        Ca = relaxation_time * strain_rate
        print("Ca", Ca)
        if Ca < 1:
            print("bubbles are solid like")
            relative_viscosity_bubbles = (1. - vesicle_fraction) ** - 1.0

        else:
            print("bubbles are deformable")
            relative_viscosity_bubbles = (1. - vesicle_fraction) ** (5. / 3.)

        return relative_viscosity_bubbles
