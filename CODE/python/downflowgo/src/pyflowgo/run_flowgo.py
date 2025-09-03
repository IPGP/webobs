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

import pyflowgo.flowgo_terrain_condition
import pyflowgo.flowgo_model_factory
import pyflowgo.flowgo_integrator
import pyflowgo.flowgo_state
import pyflowgo.flowgo_logger
import json
import os
import os.path


class RunFlowgo:

    def __init__(self) -> None:
        super().__init__()

        # logger is a singleton for now, we need to clear it
        logger = pyflowgo.flowgo_logger.FlowGoLogger()
        logger.clear()

    def run(self, json_file, path_to_folder):
        # --------------------------------- LOAD CONFIGURATION FILE AND INPUT PARAMETERS -------------------------------
        configuration_file = json_file
        with open(configuration_file) as data_file:
            data = json.load(data_file)
            effusion_rate_init = data["effusion_rate_init"]

            if 'lava_name' not in data:
                raise ValueError("Missing ['lava_name'] entry in json")
            lava_name = data['lava_name']

            if 'slope_file' not in data:
                raise ValueError("Missing ['slope_file'] entry in json")
            slope_file = data['slope_file']

            if 'step_size' not in data:
                raise ValueError("Missing ['step_size'] entry in json")
            step_size = float(data['step_size'])

            if 'mass_conservation' not in data['terrain_conditions']:
                print('Volume conservation')
                mass_conservation = False
            else:
                mass_conservation = data['terrain_conditions']['mass_conservation']
                print('Mass conservation')

# --------------------------------- READ INITIAL CONFIGURATION FILE AND MODEL FACTORY -----------------------------
        terrain_condition = pyflowgo.flowgo_terrain_condition.FlowGoTerrainCondition()
        terrain_condition.read_initial_condition_from_json_file(configuration_file)
        terrain_condition.read_slope_from_file(slope_file)

        models_factory = pyflowgo.flowgo_model_factory.FlowgoModelFactory(configuration_file, terrain_condition)

        # vesicle_fraction_model = models_factory.get_vesicle_fraction_model()
        # and why not:
        crust_temperature_model = models_factory.get_crust_temperature_model()

        effective_cover_crust_model = models_factory.get_effective_cover_crust_model()
        crystallization_rate_model = models_factory.get_crystallization_rate_model()
        material_lava = models_factory.get_material_lava()
        material_air = models_factory.get_material_air()
        heat_budget = models_factory.get_heat_budget()

# ------------------------------------------ GENERATE THE INTEGRATOR -----------------------------------------------

        integrator = pyflowgo.flowgo_integrator.FlowGoIntegrator(step_size, material_lava=material_lava,
                                                                 material_air=material_air,
                                                                 terrain_condition=terrain_condition,
                                                                 heat_budget=heat_budget,
                                                                 crystallization_rate_model=crystallization_rate_model,
                                                                 crust_temperature_model=crust_temperature_model,
                                                                 effective_cover_crust_model=effective_cover_crust_model,
                                                                 mass_conservation=mass_conservation)
        integrator.read_initial_condition_from_json_file(configuration_file)
        # ------------------------------------------------- LOG THE DATA -----------------------------------------------

        logger = pyflowgo.flowgo_logger.FlowGoLogger()

        state = pyflowgo.flowgo_state.FlowGoState()
        integrator.initialize_state(state, configuration_file)
        # call the effusion rate optimisation
        integrator.init_effusion_rate(state)

        while not integrator.has_finished():
            integrator.single_step(state)
        file_name_results = os.path.join(path_to_folder, f"results_flowgo_{lava_name}_{effusion_rate_init}m3s.csv")
        logger.write_values_to_file(file_name_results)
        print("----------------------------------------- END RUN FLOWGO ---------------------------------------------")

    def get_file_name_results(self, path_to_folder, json_file):
        print("path_to_folder in flowgo before get_file_name_results ",path_to_folder)
        configuration_file = json_file
        with open(configuration_file) as data_file:
            data = json.load(data_file)
            effusion_rate_init = data["effusion_rate_init"]
            if 'lava_name' not in data:
                raise ValueError("Missing ['lava_name'] entry in json")
            lava_name = data['lava_name']
        file_name_results = os.path.join(path_to_folder, f"results_flowgo_{lava_name}_{effusion_rate_init}m3s.csv")
        print("file_name_results in flowgo  ", file_name_results)
        print("path_to_folder in flowgo after get_file_name_results ", path_to_folder)
        return file_name_results
