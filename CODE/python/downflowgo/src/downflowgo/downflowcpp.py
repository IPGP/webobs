import os.path
import csv
import os
#import downflowgo.txt_to_shape as txt_to_shape
import numpy as np

def run_downflow(parameter_file_downflow, path):
    # Run DOWNFLOW
    #os.system(path + '/DOWNFLOW/DOWNFLOW ' + parameter_file_downflow)
    os.system(os.path.join(path, 'DOWNFLOW', f'DOWNFLOW {parameter_file_downflow}'))
    #os.system(f'"{os.path.join(path, "DOWNFLOW", "DOWNFLOW")}" {parameter_file_downflow}')
def get_downflow_probabilities(long, lat, dem, path, parameter_file_downflow, DH, n):
    """    # Run DOWNFLOW and create a raster file 'sim.asc' with the probability of trajectories for a given dem (dem)
    and a given parameter file"""

    with open(parameter_file_downflow) as f:
        l = list(f)
    with open(parameter_file_downflow, 'w') as output:
        for line in l:
            if line.startswith('input_DEM'):
                output.write(f'input_DEM {dem}\n')
            elif line.startswith('Xorigine'):
                output.write(f'Xorigine {long}\n')
            elif line.startswith('Yorigine'):
                output.write(f'Yorigine {lat}\n')
            elif line.startswith('DH'):
                output.write(f'DH {DH}\n')
            elif line.startswith('n_path'):
                output.write(f'n_path {n}\n')
            elif line.startswith('New_h_grid_name'):
                output.write(f'#New_h_grid_name\n')
            elif line.startswith('write_profile'):
                output.write(f'#write_profile\n')
            elif line.startswith('#output_L_grid_name '):
                output.write(f'output_L_grid_name sim.asc\n')
            else:
                output.write(line)
    # Run DOWNFLOW
    #os.system(path + '/DOWNFLOW/DOWNFLOW ' + parameter_file_downflow)
    os.system(os.path.join(path, 'DOWNFLOW', f'DOWNFLOW {parameter_file_downflow}'))

def get_downflow_filled_dem(long, lat, dem, path, parameter_file_downflow):

    """ Execute DOWNFLOW and create a new DEM where the pit are filled with a thin layer of 1 mm"""

    n_path = "1000"
    DH= "0.001"

    with open(parameter_file_downflow) as f:
        l = list(f)
    with open(parameter_file_downflow, 'w') as output:
        for line in l:
            if line.startswith('input_DEM'):
                output.write(f'input_DEM {dem}\n')
            elif line.startswith('Xorigine'):
                output.write(f'Xorigine {long}\n')
            elif line.startswith('Yorigine'):
                output.write(f'Yorigine {lat}\n')
            elif line.startswith('DH'):
                output.write(f'DH {DH}\n')
            elif line.startswith('n_path'):
                output.write(f'n_path {n_path}\n')
            elif line.startswith('output_L_grid_name '):
                output.write(f'#output_L_grid_name  sim.asc\n')
            elif line.startswith('#New_h_grid_name'):
                output.write(f'New_h_grid_name  dem_filled_DH0.001_N1000.asc\n')
            elif line.startswith('write_profile'):
                output.write(f'#write_profile\n')
            else:
                output.write(line)
    # Run DOWNFLOW
    #os.system(path + '/DOWNFLOW/DOWNFLOW ' + parameter_file_downflow)
    os.system(os.path.join(path, 'DOWNFLOW', f'DOWNFLOW {parameter_file_downflow}'))

def get_downflow_losd(long, lat, filled_dem, path,parameter_file_downflow, slope_step):
    """ Execute DOWNFLOW and create the profile.txt """
    n_path = "1"
    DH= "0.001"

    with open(parameter_file_downflow) as f:
        l = list(f)
    with open(parameter_file_downflow, 'w') as output:
        for line in l:
            if line.startswith('input_DEM'):
                output.write(f'input_DEM {filled_dem}\n')
            elif line.startswith('Xorigine'):
                output.write(f'Xorigine {long}\n')
            elif line.startswith('Yorigine'):
                output.write(f'Yorigine {lat}\n')
            elif line.startswith('DH'):
                output.write(f'DH {DH}\n')
            elif line.startswith('n_path'):
                output.write(f'n_path {n_path}\n')
            elif line.startswith('#output_L_grid_name '):
                output.write('output_L_grid_name sim.asc\n')
            elif line.startswith('New_h_grid_name'):
                output.write('#New_h_grid_name  dem_filled_DH0.001_N1000.asc\n')
            elif line.startswith('#write_profile'):
                output.write(f'write_profile {slope_step}\n')
            else:
                output.write(line)
    # Run DOWNFLOW
    #os.system(path + '/DOWNFLOW/DOWNFLOW ' + parameter_file_downflow)
    os.system(os.path.join(path, 'DOWNFLOW', f'DOWNFLOW {parameter_file_downflow}'))


def check_dem(long, lat, dem):
    """ to check dem headers and data lines as well as vent position within the dem"""
    long = float(long)
    lat = float(lat)
    expected_headers = ['ncols', 'nrows', 'xllcorner', 'yllcorner', 'cellsize', 'nodata_value']

    with open(dem) as file:
        header_lines = [next(file) for _ in range(6)]
        # Check that header keys match expected ones
        for i, line in enumerate(header_lines):
            key = line.split()[0].strip().lower()
            if key != expected_headers[i]:
                raise ValueError(
                    f"Unexpected header at line {i + 1} in your DEM '{dem}': got '{key}', expected "
                    f"'{expected_headers[i]}'")

        ncols = int(header_lines[0].split()[1])
        nrows = int(header_lines[1].split()[1])
        xllcorner = float(header_lines[2].split()[1])
        yllcorner = float(header_lines[3].split()[1])
        cellsize = float(header_lines[4].split()[1])
        nodata_value = float(header_lines[5].split()[1])

        # Read the values from the ASC file
        data_lines = [line.strip().split() for line in file]
        data = np.array(data_lines, dtype=float)

        # Check that the data exists
        if data.size == 0:
            raise ValueError(f"The ASC file '{dem}' contains no data after the header.")

        # Check that the data shape matches the header info
        if data.shape != (nrows, ncols):
            raise ValueError(
                f"Inconsistent dimensions in the dem :'{dem}': expected {nrows}x{ncols}, got {data.shape}.")

        # Check that (long, lat) is inside the DEM extent
        x_max = xllcorner + ncols * cellsize
        y_max = yllcorner + nrows * cellsize

        if not (xllcorner <= long <= x_max and yllcorner <= lat <= y_max):
            raise ValueError(
                f"The coordinates of the vent (long={long}, lat={lat}) is outside the DEM extent:\n"
                f"x: [{xllcorner}, {x_max}], y: [{yllcorner}, {y_max}]")

    # Optional: return useful values if needed
    return True
