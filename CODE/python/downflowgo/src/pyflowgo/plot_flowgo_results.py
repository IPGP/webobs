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
import matplotlib.pyplot as plt
import numpy as np
import csv
import os.path
import json

def plot_all_results(path_to_folder, filename_array, json_file):
    
    with open(json_file, "r") as file:
        json_data = json.load(file)
        slope_file = json_data.get('slope_file')
    
    with open(slope_file, "r") as f_slope:
        distance_original = []
        latitude = []  # X
        longitude = []  # Y
        altitude = []
        slope_original = []
        latitude_column_number = 0
        longitude_column_number = 1
        elevation_column_number = 2
        distance_column_number = 3
        slope_column_number = 4
        # slope_file = path_to_folder + "profile_00000.txt"
        f_slope.readline()
        for line in f_slope:
            split_line = line.strip('\n').split('\t')
            distance_original.append(float(split_line[distance_column_number]))
            slope_original.append(float(split_line[slope_column_number]))
            altitude.append(float(split_line[elevation_column_number]))



    # plot figure 1: here define the positions of the graphs in figure 1
    lava_properties = plt.figure(figsize=(8, 8))
    plot_core_temperature = lava_properties.add_subplot(321)
    plot_v_mean = lava_properties.add_subplot(322)
    plot_viscosity = lava_properties.add_subplot(323)
    plot_yield_strength = lava_properties.add_subplot(324)
    plot_width = lava_properties.add_subplot(325)
    plot_crystal = lava_properties.add_subplot(326)

    # plot figure 2: here define the positions of the graphs in figure 2
    heat_fluxes = plt.figure(figsize=(8, 8))
    plot_Q_forced_conv = heat_fluxes.add_subplot(311)
    plot_Q_cond = heat_fluxes.add_subplot(312)
    plot_Q_rad = heat_fluxes.add_subplot(313)
    # plot_Q_rain = crustal_conditions.add_subplot(514)
    # plot_Q_visc = crustal_conditions.add_subplot(515)


    # plot figure 3: here define the positions of the graphs in figure 3
    crustal_conditions = plt.figure(figsize=(8, 8))
    plot_eff_cov_frac = crustal_conditions.add_subplot(411)
    plot_T_crust = crustal_conditions.add_subplot(412)
    plot_T_eff_rad = crustal_conditions.add_subplot(413)
    plot_T_surf_conv = crustal_conditions.add_subplot(414)

    # plot figure 4: here define the positions of the graphs in figure 4

    slope = plt.figure()
    plot_slope = slope.add_subplot(111)
    plot_slope.plot(distance_original, slope_original, '-k', label="Original")

    flow_id = os.path.abspath(path_to_folder)
    title = os.path.basename(flow_id)

    for filename in filename_array:

       # label = filename.replace(path_to_folder+"results_flowgo_","").strip(".csv")
        label = filename.replace(os.path.join(path_to_folder, "results_flowgo_"), "")
        if label.endswith(".csv"):
            label = label[:-4]  # Remove last 4 characters (".csv")
        distance_array = []
        slope_array = []
        temperature_array = []
        v_mean_array = []
        viscosity_array = []
        crystal_fraction_array = []
        vesicle_fraction_array = []
        width_array = []
        depth_array = []
        effusion_rate = []
        yield_strength_array = []
        shear_stress_array = []
        crust_temperature_array = []
        effective_cover_fraction_array = []
        crystallization_rate_array = []
        crystallization_down_flow_array = []
        characteristic_surface_temperature_array = []
        effective_radiation_temperature_array = []
        flowgofluxforcedconvectionheat_array = []
        flowgofluxconductionheat_array = []
        flowgofluxradiationheat_array = []
        flowgofluxheatlossrain_array = []
        flowgofluxviscousheating_array = []

        with open(filename, 'r') as csvfile:
            csvreader = csv.DictReader(csvfile, delimiter=',')

            for row in csvreader:
                distance_array.append(float(row['position']))
                slope_array.append(float(row['slope']))
                temperature_array.append(float(row['core_temperature']))
                v_mean_array.append(float(row['mean_velocity']))
                viscosity_array.append(float(row['viscosity']))
                yield_strength_array.append(float(row['tho_0']))
                shear_stress_array.append(float(row['tho_b']))
                crystal_fraction_array.append(float(row['crystal_fraction']))
                vesicle_fraction_array.append(float(row['vesicle_fraction']))
                width_array.append(float(row['channel_width']))
                depth_array.append(float(row['channel_depth']))
               # time_array.append(float(row['current_time']))
                effusion_rate.append(float(row['effusion_rate']))
                crust_temperature_array.append(float(row['crust_temperature']))
                effective_cover_fraction_array.append(float(row['effective_cover_fraction']))
                crystallization_rate_array.append(float(row['dphi_dtemp']))
                crystallization_down_flow_array.append(float(row['dphi_dx']))
                characteristic_surface_temperature_array.append(float(row['characteristic_surface_temperature']))
                effective_radiation_temperature_array.append(float(row['effective_radiation_temperature']))
                flowgofluxforcedconvectionheat_array.append(float(row['flowgofluxforcedconvectionheat']))
                flowgofluxconductionheat_array.append(float(row['flowgofluxconductionheat']))
                flowgofluxradiationheat_array.append(float(row['flowgofluxradiationheat']))
                #flowgofluxheatlossrain_array.append(float(row['flowgofluxheatlossrain']))
                #flowgofluxviscousheating_array.append(float(row['flowgofluxviscousheating']))

        run_out_distance = (max(distance_array) / 1000.0)
        step_size = distance_array[1]

        # convert radians to degree
        slope_degrees =[]
        for i in range(0,len(slope_array)):
            slope_degrees.append(math.degrees(slope_array[i]))

       # convert time to minutes
       # duration = (max(time_array)/ 60.)
       # time_minutes= []
       # for i in range (0,len(time_array)):
       #     time_minutes.append(time_array[i] / 60.0)

        #convert Kelvin to celcius
        temperature_celcius = []
        for i in range (0,len(temperature_array)):
            temperature_celcius.append(temperature_array[i]-273.15)

        crust_temperature_celcius = []
        for i in range(0, len(crust_temperature_array)):
            crust_temperature_celcius.append(crust_temperature_array[i] - 273.15)

        characteristic_surface_temperature_celcius = []
        for i in range(0, len(characteristic_surface_temperature_array)):
            characteristic_surface_temperature_celcius.append(characteristic_surface_temperature_array[i] - 273.15)

        effective_radiation_temperature_celcius = []
        for i in range(0, len(crust_temperature_array)):
            effective_radiation_temperature_celcius.append(effective_radiation_temperature_array[i] - 273.15)

        # Initial effusion rate
        effusion_rate_init =[]
        for i in range (0,len(effusion_rate)):
            effusion_rate_init.append(effusion_rate[0])

        plot_core_temperature.plot(distance_array, temperature_celcius, '-', label=label)

        plot_core_temperature.set_ylabel('Core Temperature (°C)')
        # plot_core_temperature.set_xlim(xmax=500)
        plot_core_temperature.grid(True)
        plot_core_temperature.get_yaxis().get_major_formatter().set_useOffset(False)

        # text_run_out ="The run out distance is {:3.2f} km in {:3.2f} min".format(float(run_out_distance),float(duration))
        # axis2_f1.text(100, 0.8, text_run_out)

        plot_v_mean.plot(distance_array, v_mean_array, '-', label=label)
        # plot_v_mean.set_xlim(xmax=1000)
        # plot_v_mean.legend(loc=3, prop={'size': 8})
        plot_v_mean.set_ylabel('Mean velocity (m/s)')
        plot_v_mean.grid(True)
        # title2 = "Solution for a constant effusion rate of {:3.2f} m\u00b3/s and \n at-source channel width of
        # {:3.1f} m and {:3.2f} deep".format(float(effusion_rate[0]), width_array[0], 0.)
        # plot_v_mean.set_title(title2, ha='center')
        # plot_v_mean.set_xlim(xmin=0)
        # plot_v_mean.set_ylim(ymin=0, ymax=100)

        plot_viscosity.plot(distance_array, viscosity_array, '-', label=label)
        # plot_viscosity.set_xlabel('Distance (m)')
        plot_viscosity.set_ylabel('Viscosity (Pa s)')
        plot_viscosity.set_ylim(ymin=1, ymax=1000000)
        # plot_viscosity.set_xlim(xmax=4000)
        plot_viscosity.set_yscale('log')
        plot_viscosity.grid(True)

        plot_yield_strength.plot(distance_array, yield_strength_array, '-',  label= label)
        # plot_yield_strength.set_xlabel('Distance (m)')
        plot_yield_strength.set_ylabel('Yield strength (Pa)')
        plot_yield_strength.set_yscale('log')
        plot_yield_strength.grid(True)

        plot_width.plot(distance_array, width_array, '-',  label=label)
        plot_width.set_xlabel('Distance (m)')
        plot_width.set_ylabel('Width (m)')
        plot_width.grid(True)
        plot_width.set_ylim(ymin=0, ymax=200)

        plot_crystal.plot(distance_array, crystal_fraction_array, '-', label=label)
        #plot_crystal.legend(loc=2, prop={'size': 8})
        plot_crystal.set_xlabel('Distance (m)')
        plot_crystal.set_ylabel('Crystal fraction')
        plot_crystal.grid(True)

        plot_vesicle = plot_crystal.twinx()
        plot_vesicle.plot(distance_array, vesicle_fraction_array, '--', label='Vesicle fraction')
        plot_vesicle.set_ylabel('Vesicle fraction')
        plot_vesicle.tick_params(axis='y')

        # plot_crystal.set_ylim(ymin=0, ymax=0.6)
        # plot_crystal.set_xlim(xmax=500)

        # figure 2

        plot_Q_forced_conv.plot(distance_array, flowgofluxforcedconvectionheat_array, '-', label=label)
        plot_Q_forced_conv.set_xlabel('Distance (m)')
        plot_Q_forced_conv.set_ylabel('Qconv (W/m)')
        plot_Q_forced_conv.set_yscale('log')
        plot_Q_forced_conv.legend()
        plot_Q_forced_conv.grid(True)

        plot_Q_cond.plot(distance_array, flowgofluxconductionheat_array, '-', label=label)
        plot_Q_cond.set_xlabel('Distance (m)')
        plot_Q_cond.set_ylabel('Qcond (W/m)')
        plot_Q_cond.set_yscale('log')
        plot_Q_cond.grid(True)

        plot_Q_rad.plot(distance_array, flowgofluxradiationheat_array, '-', label=label)
        plot_Q_rad.set_xlabel('Distance (m)')
        plot_Q_rad.set_ylabel('Qrad (W/m)')
        plot_Q_rad.set_yscale('log')
        plot_Q_rad.grid(True)

        # plot_Q_rain.plot(distance_array, flowgofluxheatlossrain_array, '-', label=label)
        # plot_Q_rain.set_xlabel('Distance (m)')
        # plot_Q_rain.set_ylabel('Qrain (W/m)')
        # plot_Q_rain.set_yscale('log')
        # plot_Q_rain.set_ylim(ymin=0, ymax=100000000)
        # plot_Q_rain.grid(True)
        #
        # plot_Q_visc.plot(distance_array, flowgofluxviscousheating_array, '-', label=label)
        # plot_Q_visc.set_xlabel('Distance (m)')
        # plot_Q_visc.set_ylabel('Qvisc (W/m)')
        # plot_Q_visc.set_yscale('log')
        # plot_Q_visc.set_ylim(ymin=0, ymax=100000000)
        # plot_Q_visc.grid(True)

        plot_eff_cov_frac.plot(distance_array, effective_cover_fraction_array, '-', label=label)
        plot_eff_cov_frac.set_xlabel('Distance (m)')
        plot_eff_cov_frac.set_ylabel('f crust')
        #plot1_slope.set_xlim(xmax=1000)

        plot_T_crust.plot(distance_array, crust_temperature_celcius, '-', label=label)
        plot_T_crust.set_xlabel('Distance (m)')
        plot_T_crust.set_ylabel(' T crust (°C)')
        #plot_eff_cov_frac.set_xlim(xmax=1000)

        plot_T_eff_rad.plot(distance_array, effective_radiation_temperature_celcius, '-', label=label)
        plot_T_eff_rad.set_xlabel('Distance (m)')
        plot_T_eff_rad.set_ylabel('T eff (°C)')
        #plot_eff_cov_frac.set_xlim(xmax=1000)

        plot_T_surf_conv.plot(distance_array, characteristic_surface_temperature_celcius, '-', label=label)
        plot_T_surf_conv.set_xlabel('Distance (m)')
        plot_T_surf_conv.set_ylabel('T conv(°C)')
        #plot_eff_cov_frac.set_xlim(xmax=1000)

        plot_slope.plot(distance_array, slope_degrees, '-', label=label)
        plot_slope.set_ylabel('slope (°)')
        #plot_slope.set_xlim(xmin=0, xmax=max(distance_array)+1000)
        plot_slope.grid(True)

    plot_core_temperature.set_title(str(title))
    plot_v_mean.legend(loc=1, prop={'size': 8})
    plot_Q_forced_conv.legend(loc=0, prop={'size': 8})
    plot_Q_forced_conv.set_title("Heat fluxes for " + str(title))
    plot_eff_cov_frac.legend(loc=0, prop={'size': 8})
    plot_eff_cov_frac.set_title("Crustal and surface conditions for " + str(title))
    plot_slope.legend(loc=0, prop={'size': 8})


    lava_properties.tight_layout()
    lava_properties.savefig(path_to_folder+"/lava_properties.png")

    heat_fluxes.tight_layout()
    heat_fluxes.savefig(path_to_folder+"/heat_fluxes.png")

    crustal_conditions.tight_layout()
    crustal_conditions.savefig(path_to_folder+"/crustal_conditions.png")

    slope.savefig(path_to_folder+"/slope.png")

