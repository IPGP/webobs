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
import pyflowgo.flowgo_melt_viscosity_model_shaw
import pyflowgo.flowgo_relative_viscosity_model_kd

import pyflowgo.base.flowgo_base_relative_viscosity_model
import pyflowgo.flowgo_material_lava

class FlowGoRelativeViscosityModelBLL(pyflowgo.base.flowgo_base_relative_viscosity_model.
                                     FlowGoBaseRelativeViscosityModel):
    """
    This function calculates the effect of crystal and bubble cargo on viscosity using the model of Birnbaum,
    Lev, and Llewellin (2021):
    this implies that crystal and bubble fraction are calculated in respect to the whole suspension :
            φsolid = Vsolid/(Vsolid + Vliquid) and φgas = Vgas/(Vgas + Vsolid + Vliquid),
            
    on the basis of analogue experiments they found :
    phicrit = 0.39; phimax = 0.56, Bsolid = 2.74, Bgas = 1.98:
    and
    Eq. 4.1 a :
    relative_viscosity = (1. - (phi/self._phimax)) ** (-self._Bsolid) * \
                             (1. - vesicle_fraction) ** (-self._Bgas) * ((strain_rate) ** (n - 1))
        where if  self._phimax*(1. - vesicle_fraction) + vesicle_fraction > phicrit
          Eq.4.1c
             n = 1 + (0.7 - 0.55 * Ca) * (self._phicrit - phi(1-vesicle_fraction) - vesicle_fraction)
        and
            if not; n=1


        and Ca is the capillary number:
        Ca = self._vesicle_radius*strain_rate*melt_viscosity/self._surfacetension



    Equation alternative given by J. Birnbaum
    relative_viscosity = (1. - (phi / (self._phimax * (1. - vesicle_fraction)))) ** (-self._Bsolid) * \
                            (1. - vesicle_fraction) ** (-self._Bgas) * ((strain_rate) ** (n - 1))


    Input data
    -----------
    maximum packing for particles (phimax)
    einstein exponent for particles (Bsolid)
    einstein exponent for bubbles (Bgas)
    critical packing fractions for particles and bubbles (phicrit)
    bubble radius (vesicle_radius)
    surface tension of vapor bubbles in melt (surfacetension)

    variables
    -----------
    crystal fraction: phi
    vesicle fraction: vesicle_fraction
    strain rate: strain_rate
    melt viscosity: melt_viscosity

    Returns
    ------------
    the relative viscosity due to the crystal and bubble cargo

    Reference
    ---------

    Birnbaum, J., Lev, E., Llewellin, E. W. (2021) Rheology of three-phase suspensions determined
    via dam-break experiments. Proc. R. Soc. A 477 (20210394): 1-16.
     https://zenodo.org/records/4707969

    """

    def __init__(self, vesicle_fraction_model=None, melt_viscosity_model=None):
        super().__init__()

        if vesicle_fraction_model == None:
            self._vesicle_fraction_model = pyflowgo.flowgo_vesicle_fraction_model_constant.FlowGoVesicleFractionModelConstant()
        else:
            self._vesicle_fraction_model = vesicle_fraction_model

        if melt_viscosity_model == None:
            self._melt_viscosity_model = pyflowgo.flowgo_melt_viscosity_model_shaw.FlowGoMeltViscosityModelShaw()
        else:
            self._melt_viscosity_model = melt_viscosity_model


    def read_initial_condition_from_json_file(self, filename):
        with open(filename) as data_file:
            data = json.load(data_file)
            if 'max_packing' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing ['relative_viscosity_parameters']['max_packing']entry in json")
            if 'Bsolid' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing ['relative_viscosity_parameters']['Bsolid']entry in json")
            if 'Bgas' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing ['relative_viscosity_parameters']['Bgas']entry in json")
            if 'vesicle_radius' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing ['relative_viscosity_parameters']['vesicle_radius']entry in json")
            if 'surface_tension' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing ['relative_viscosity_parameters']['surface_tension']entry in json")
            if 'crit_packing' not in data['relative_viscosity_parameters']:
                raise ValueError("Missing ['relative_viscosity_parameters']['crit_packing']entry in json")

            self._phimax = float(data['relative_viscosity_parameters']['max_packing'])
            self._Bsolid = float(data['relative_viscosity_parameters']['Bsolid'])
            self._Bgas = float(data['relative_viscosity_parameters']['Bgas'])
            self._vesicle_radius = float(data['relative_viscosity_parameters']['vesicle_radius'])
            self._surfacetension = float(data['relative_viscosity_parameters']['surface_tension'])
            self._phicrit = float(data['relative_viscosity_parameters']['crit_packing'])

    def compute_relative_viscosity(self, state):
        phi = state.get_crystal_fraction()
        strain_rate = state.get_strain_rate()
        print("strain_rate", strain_rate )
        vesicle_fraction = self._vesicle_fraction_model.computes_vesicle_fraction(state)
        melt_viscosity = self._melt_viscosity_model.compute_melt_viscosity(state)
        relaxation_time = self._vesicle_radius * melt_viscosity / self._surfacetension
        Ca = relaxation_time * strain_rate

        phi_effective = phi * (1 - vesicle_fraction) + vesicle_fraction

        if phi_effective > self._phicrit:
            print(f"{phi_effective:.4f} > {self._phicrit:.4f}")
            if Ca>10:
                Ca=10
            n = 1 + (0.7 - 0.55 * Ca) * (self._phicrit - phi*(1. - vesicle_fraction) - vesicle_fraction) # Eq.4.1c
            n = min(1.2, max(0.2, n))  # n between 0.2 and 1.2
            # equation alternative : n = 1 + (0.7 - 0.55 * Ca) * (self._phicrit - phi - vesicle_fraction)
            print(f"Ca = {Ca:.4e}, n = {n:.4f}")
            relative_viscosity = (1. - (phi / self._phimax)) ** (-self._Bsolid) * \
                                 (1. - vesicle_fraction) ** (-self._Bgas) * ((strain_rate) ** (n - 1)) # Eq.4.1a

        else:
            n = 1
            relative_viscosity = (1. - (phi / self._phimax)) ** (-self._Bsolid) * \
                                 (1. - vesicle_fraction) ** (-self._Bgas) # Eq.4.1a
            print("n = 1 (Newtonian regime)")

        if strain_rate <= 0:
            raise ValueError("strain_rate <= 0")

        #relative_viscosity = (1. - phi / (self._phimax * (1. - vesicle_fraction))) ** (-self._Bsolid) * \
        #                     (1. - vesicle_fraction) ** (-self._Bgas) * ((strain_rate) ** (n - 1))


        return relative_viscosity


    def is_notcompatible(self, state):
        phi = state.get_crystal_fraction()
        vesicle_fraction = self._vesicle_fraction_model.computes_vesicle_fraction(state)
        if phi > (self._phimax * (1 - vesicle_fraction)):
            return True
        else:
            return False
