
import os
import sys
import configparser
import argparse
import csv
import subprocess
import datetime
import time
import json
import downflowgo.mapping as mapping
import downflowgo.downflowcpp as downflowcpp
import downflowgo.txt_to_shape as txt_to_shape
import shutil
import pandas as pd
import pyflowgo.run_flowgo_effusion_rate_array as run_flowgo_effusion_rate_array
import pyflowgo.run_flowgo as run_flowgo
import pyflowgo.run_outs as run_outs
import pyflowgo.plot_flowgo_results as plot_flowgo_results
import editor_configuration_file_downflowgo

if __name__ == "__main__":
    # Start the timer
    start_time = time.time()

    # Check argument 
    if len(sys.argv) < 2:
        print("Usage:  python main_downflowgo.py config_downflowgo.ini")
        sys.exit(1)
    config_file = sys.argv[1]

    # Load the INI configuration file
    config = configparser.ConfigParser()
    config.read(config_file)

    if not config.sections():
        print(f"Error : Impossible to read '{config_file}'")
        sys.exit(1)
        
    # Check if GUI is enabled in the config
    use_GUI = config['config_general']['use_gui'] 

    # Launch GUI if enabled
    if use_GUI == 'yes':
        modified_config = editor_configuration_file_downflowgo.launch_editor(config_file, gui_option=1)

    elif use_GUI == 'short':
        modified_config = editor_configuration_file_downflowgo.launch_editor(config_file, gui_option=2)

        # Reload the updated config if a new one was saved
        if modified_config:
            config.read(modified_config)
            config_file = modified_config # Update path to point to new config
            
    # General Config
    mode = config.get('config_general', 'mode', fallback='downfowgo')
    mapping_display = config.get('config_general', 'mapping_display', fallback='no')
    # Paths
    dem = config["paths"]["dem"] 
    path_to_eruptions = config["paths"]["eruptions_folder"]
    csv_vent_file = config["paths"]["csv_vent_file"] 

    # Define the map_layers dictionary for the mapping
    map_layers = None
    if mapping_display:

        map_layers = {
            "img_tif_map_background": config.get("mapping", "img_tif_map_background_path", fallback=None),
            "monitoring_network_path": config.get("mapping", "monitoring_network_path", fallback=None),
            "lava_flow_outline_path": config.get("mapping", "lava_flow_outline_path", fallback=None),
            "logo_path": config.get("mapping", "logo_path", fallback=None),
            "source_img_tif_map_background": config.get("mapping", "source_img_tif_map_background", fallback=None),
            "unverified_data": config.get("mapping", "unverified_data", fallback=None)
        }
        language = config.get('language', 'language', fallback='En')

    # Executing DOWNFLOW
    name_vent = config["downflow"]["name_vent"]
    easting = config["downflow"]["easting"] 
    northing = config["downflow"]["northing"] 
    DH = config["downflow"]["DH"] 
    n = config["downflow"]["n_path"] 
    slope_step = config["downflow"]["slope_step"] 
    epsg_code = config["downflow"]["epsg_code"] 

    # ------------>    load downflow and the parameter file  <------------
    path_to_downflow = os.path.join(os.path.abspath(''), 'downflowgo')
    parameter_file_downflow = os.path.join(path_to_downflow, 'DOWNFLOW', 'parameters_range.txt')

    # If csv_vent_file is 0, we create a new one
    if csv_vent_file == "0":
        csv_vent_file = os.path.join(path_to_eruptions, 'csv_vent_file.csv')
        if os.path.exists(csv_vent_file):
            os.remove(csv_vent_file)
        with open(csv_vent_file, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile, delimiter=';')
            writer.writerow(['flow_id', 'X', 'Y'])
            writer.writerow([name_vent, easting, northing])
        print(f"[INFO] New csv created : {csv_vent_file}")
    else:
        # If an absolute path is given in the config file
        csv_vent_file = os.path.abspath(csv_vent_file)
        print(f"[INFO] Csv file used : {csv_vent_file}")
        if not os.path.exists(csv_vent_file):
            raise FileNotFoundError(f"[ERREUR] File CSV do not exist : {csv_vent_file}")


    with open(csv_vent_file, 'r') as csvfile:
        csvreader = csv.DictReader(csvfile, delimiter=';')
        for row in csvreader:
            flow_id = str(row['flow_id'])
            long = str(row['X'])
            lat = str(row['Y'])

            path_to_folder = os.path.join(path_to_eruptions, flow_id)
            print("path_to_folder =", path_to_folder)

            delete_existing = config['paths'].get('delete_existing_results', 'yes').lower() == 'yes'
            if delete_existing and os.path.exists(path_to_folder):
                shutil.rmtree(path_to_folder)
            os.makedirs(path_to_folder, exist_ok=True)
            os.chdir(path_to_folder)

            # Check if dem format is ok and if vent coordinates are within the DEM
            downflowcpp.check_dem(long, lat, dem)
            print("************* DEM ok *********")

            # Returns an asc file with new (filled) DEM
            downflowcpp.get_downflow_filled_dem(long, lat, dem, path_to_downflow, parameter_file_downflow)
            print("************************ DOWNFLOW filled DEM done *********")

            # Returns the profile.txt
            filled_dem = 'dem_filled_DH0.001_N1000.asc'
            downflowcpp.get_downflow_losd(long, lat, filled_dem, path_to_downflow, parameter_file_downflow, slope_step)

            print("************************ DOWNFLOW LoSD done *********")
            os.remove(os.path.join(path_to_folder, "dem_filled_DH0.001_N1000.asc"))

            # Returns an asc file with the lava flow path probabilities using the given DH and n
            downflowcpp.get_downflow_probabilities(long, lat, dem, path_to_downflow, parameter_file_downflow, DH, n)
            print("******************* DOWNFLOW probability executed: sim.asc created **************************")

            # create map folder with layers in it
            map_folder = os.path.join(path_to_folder, "map")
            os.mkdir(map_folder)
            sim_asc = os.path.join(path_to_folder, "sim.asc")
            cropped_geotiff_file = os.path.join(map_folder, f'sim_{flow_id}.tif')
            txt_to_shape.crop_and_convert_to_tif(sim_asc, cropped_geotiff_file, epsg_code)
            os.remove(sim_asc)
            print('*********** simulation paths saved in:', cropped_geotiff_file, '*********')

            losd_file = os.path.join(path_to_folder, "profile_00000.txt")
            shp_losd_file = os.path.join(map_folder, f'losd_{flow_id}.shp')
            txt_to_shape.get_path_shp(losd_file, shp_losd_file, epsg_code)
            shp_vent_file = os.path.join(map_folder, f'vent_{flow_id}.shp')
            #txt_to_shape.get_vent_shp(csv_vent_file, shp_vent_file, epsg_code)
            txt_to_shape.write_single_vent_shp(flow_id, long, lat, shp_vent_file, epsg_code)


            print("**************** End of DOWNFLOW ", flow_id, '*********')

            if mode == "downflow":
                # Define the map_layers dictionary initially
                sim_layers = {
                    'losd_file': losd_file,
                    'shp_losd_file': shp_losd_file,
                    'shp_vent_file': shp_vent_file,
                    'cropped_geotiff_file': cropped_geotiff_file,
                }
                mapping.create_map(path_to_folder, dem, flow_id, map_layers, sim_layers, mode="downflow",
                                   language=language, display=mapping_display)

            if mode == "downflowgo":
                print("************************ Start FLOWGO for FLOW ID =", flow_id, '*********')

                json_input = config["pyflowgo"]["json"]
                effusion_rates_input = config["pyflowgo"]["effusion_rates_input"]
                path_to_flowgo_results = os.path.join(path_to_folder, 'results_flowgo')
                if not os.path.exists(path_to_flowgo_results):
                    os.makedirs(path_to_flowgo_results)

                # get losd from DOWNFLOW and clean it if necessary
                losd_file = os.path.join(path_to_folder, "profile_00000.txt")
                slope_file = losd_file
                df = pd.read_csv(slope_file, sep=r'\s+')
                df = df.dropna()
                df_cleaned = df[df['L'].diff().fillna(1) > 0]
                assert all(df_cleaned['L'].diff().dropna() > 0), "L is still not strictly increasing"
                df_cleaned.to_csv(slope_file, sep="\t", index=False)

                # Parse effusion rates
                effusion_rates_input = config["pyflowgo"]["effusion_rates_input"].strip()

                if effusion_rates_input == "0":
                    effusion_rates_tuple = None  # None signals "auto mode"
                    print("Effusion rates input is taken from channel dimension in json (auto mode)")
                else:
                    try:
                        rates = [int(r.strip()) for r in effusion_rates_input.split(',')]
                        if len(rates) == 1:
                            effusion_rates_tuple = {
                                "first_eff_rate": rates[0],
                                "last_eff_rate": rates[0],
                                "step_eff_rate": rates[0]
                            }
                        elif len(rates) == 3:
                            effusion_rates_tuple = {
                                "first_eff_rate": rates[0],
                                "last_eff_rate": rates[1],
                                "step_eff_rate": rates[2]
                            }
                        else:
                            raise ValueError
                    except ValueError:
                        raise ValueError(
                            "Effusion rates input should be '0', a single integer, or three comma-separated integers (e.g., '5' or '5,20,5').")

                    # Run FLOWGO for json defined effusion rate
                if effusion_rates_tuple is None:
                    # when effusion rate = 0,  flowgo calculates the effusion rate base on the channel dimensions
                    json_file_new = os.path.join(path_to_flowgo_results, f'parameters_{flow_id}.json')
                    with open(json_input, "r") as data_file:
                        read_json_data = json.load(data_file)
                    read_json_data["slope_file"] = slope_file
                    read_json_data["effusion_rate_init"] = 0.0
                    read_json_data["lava_name"] = flow_id

                    with open(json_file_new, "w") as data_file:
                        json.dump(read_json_data, data_file)

                    flowgo = run_flowgo.RunFlowgo()
                    flowgo.run(json_file_new, path_to_flowgo_results)
                    filename = flowgo.get_file_name_results(path_to_flowgo_results, json_file_new)
                    filename_array = [filename]
                    plot_flowgo_results.plot_all_results(path_to_flowgo_results, filename_array, json_file_new)

                    with open(json_file_new, "r") as data_file:
                        data = json.load(data_file)
                    lava_name = data["lava_name"]
                    run_outs.get_run_outs(path_to_flowgo_results, filename_array, slope_file, lava_name)
                    print('****** FLOWGO results are saved:', filename, '***********')

                else:
                    # Run FLOWGO for several effusion rates
                    simulation = run_flowgo_effusion_rate_array.StartFlowgo()
                    json_file_new = os.path.join(path_to_flowgo_results, f'parameters_{flow_id}.json')
                    simulation.make_new_json(json_input, flow_id, slope_file, json_file_new)
                    simulation.run_flowgo_effusion_rate_array(json_file_new, path_to_flowgo_results, slope_file,
                                                              effusion_rates_tuple)

                run_outs_file = os.path.join(path_to_flowgo_results, f'run_outs_{flow_id}.csv')
                shp_runouts = os.path.join(map_folder, f'runouts_{flow_id}.shp')
                txt_to_shape.get_runouts_shp(run_outs_file, shp_runouts, epsg_code)
                # move(losd_file)
                os.rename(losd_file, os.path.join(map_folder, f'losd_{flow_id}_profile_00000.txt'))

                print('*********** FLOWGO executed and results stored in:', path_to_flowgo_results, '***********')

                sim_layers = {
                    'losd_file': losd_file,
                    'shp_losd_file': shp_losd_file,
                    'shp_vent_file': shp_vent_file,
                    'cropped_geotiff_file': cropped_geotiff_file,
                    'shp_runouts': shp_runouts
                }

                # Make the map
                mapping.create_map(path_to_folder, dem, flow_id, map_layers, sim_layers, mode="downflowgo",
                                   language=language, display=mapping_display)

            print("************************************** THE END *************************************")
    # End the timer
    end_time = time.time()

    # Calculate the duration
    execution_time = end_time - start_time

    # Format the execution time
    if execution_time >= 60:
        minutes = int(execution_time // 60)
        seconds = int(execution_time % 60)
        print(f"The code took {minutes} minutes and {seconds} seconds to execute.")
    else:
        print(f"The code took {int(execution_time)} seconds to execute.")