import csv
import matplotlib.pyplot as plt
import math
import numpy as np
import os

def get_run_outs(path_to_folder, flowgo_results, slope_file, lava_name):
    # add row to CSV file
    csv_file_run_outs = os.path.join(path_to_folder, f"run_outs_{lava_name}.csv")

    with open(csv_file_run_outs, 'w') as csvfile:
        heads = ["flow_id", "Effusion_rate", "Depth", "Width_init", "X_init", "Y_init", "Elevation_init",
                 "X_run_out", "Y_run_out", "Elevation_run_out", "Distance_run_out"]
        writer = csv.writer(csvfile)
        writer.writerow(heads)

        for filename in flowgo_results:
            distance_array = []
            slope_array = []
            temperature_array = []
            v_mean_array = []
            viscosity_array = []
            crystal_fraction_array = []
            width_array = []
            depth_array = []
            time_array = []
            yieldstrength_array = []
            effusion_rate = []

            with open(filename, 'r') as csvfile:
                csvreader = csv.DictReader(csvfile, delimiter=',')

                for row in csvreader:
                    distance_array.append(float(row['position']))
                    slope_array.append(float(row['slope']))
                    temperature_array.append(float(row['core_temperature']))
                    v_mean_array.append(float(row['mean_velocity']))
                    viscosity_array.append(float(row['viscosity']))
                    crystal_fraction_array.append(float(row['crystal_fraction']))
                    width_array.append(float(row['channel_width']))
                    depth_array.append(float(row['channel_depth']))
                    effusion_rate.append(float(row['effusion_rate']))
                    yieldstrength_array.append(float(row['tho_0']))

            # Initial effusion rate
            effusion_rate_init = round(effusion_rate[0], 0)   # m3/s
            print("effusion_rate_init_plot = ", effusion_rate_init)

            run_out_distance = max(distance_array)  # m
            print("run_out_distance_plot = ",run_out_distance)
            depth = depth_array[1]  # m
            width_init = width_array[1]  # m

            slope_degrees = []
            for i in range(0, len(slope_array)):
                slope_degrees.append(math.degrees(slope_array[i]))
            #figure = plt.figure()
            #plot_slope = figure.add_subplot(111)
            #plot_slope.plot(distance_array, slope_degrees, '-')
            #plot_slope.set_ylabel('slope (°)')
            #plot_slope.set_xlabel('Distance (m)')
            #plot_slope.grid(True)
            #plt.savefig('slope.png')


            distance = []
            latitude = []  # X
            longitude = []  # Y
            altitude = []

            f_slope = open(slope_file, "r")
            f_slope.readline()
            for line in f_slope:
                split_line = line.strip('\n').split('\t')
                if float(split_line[3]) <= (float(run_out_distance)+float(distance_array[1])):
                    latitude.append(float(split_line[0]))
                    longitude.append(float(split_line[1]))
                    altitude.append(float(split_line[2]))
                    distance.append(float(split_line[3]))
                else:
                    pass
            x_init = round(latitude[0], 2)
            y_init = round(longitude[0], 2)
            alt_init = round(altitude[0], 1)
            x = round(latitude[-1], 2)
            y = round(longitude[-1], 2)
            alt = round(altitude[-1], 1)
            run_out = round(distance[-1], 0)
            run_outs_coordinates = [lava_name, effusion_rate_init, depth, width_init, x_init, y_init, alt_init, x, y, alt, run_out]
            writer.writerow(run_outs_coordinates)

    figure = plt.figure()
    plot = figure.add_subplot(111)
    distance_array = []
    effusion_rate_init_array = []
    folder = os.path.isdir(path_to_folder)

    with open(csv_file_run_outs, 'r') as csvfile:
        csvreader = csv.DictReader(csvfile, delimiter=',')
        for row in csvreader:
            flow_id = str(row['flow_id'])
            effusion_rate_init_array.append(float(row['Effusion_rate']))
            distance_array.append(float(row['Distance_run_out']))

        plot.set_title(str(flow_id))
        plot.plot(distance_array, effusion_rate_init_array, '-', label=flow_id)
        plot.set_ylabel('Effusion rate (m3/s)')
        plot.set_xlabel('Distance (m)')
        # plot1_fig1.set_xlim(xmax=500)
        plot.grid(True)

    plt.savefig(os.path.join(path_to_folder, "effusion_rate_vs_distance.png"))

