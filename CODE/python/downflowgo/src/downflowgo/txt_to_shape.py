#import requires packages
import fiona
import pandas as pd
import csv
import rasterio
import numpy as np
from rasterio.transform import from_origin
from rasterio.crs import CRS
from shapely.geometry import mapping, Point

def get_path_shp(losd_file, shp_losd_file, epsg_code):
    # import points from losd_file
    lineDf = pd.read_csv(losd_file, header=0, sep='\t')
    lineDf.head()
    # define schema for line shape file
    schema = {'geometry': 'LineString', 'properties': [('L', 'str')]}
    # open a fiona object and write shp_losd_file.shp
    lineShp = fiona.open(shp_losd_file, mode='w',
                         driver='ESRI Shapefile', schema=schema, crs=f'epsg:{epsg_code}')

    # get list of points
    xyList = []
    rowName = ''
    for index, row in lineDf.iterrows():
        xyList.append((row.x, row.y))
        rowName = row.L

    # save record and close shapefile
    rowDict = {'geometry': {'type': 'LineString', 'coordinates': xyList}, 'properties': {'L': rowName}, }
    lineShp.write(rowDict)
    # close fiona object
    lineShp.close()
    print(f"++++++++++++++++++ Losd file is saved in shape format at: '{shp_losd_file}'+++++++++++++++++")


def get_runouts_shp(run_outs_file, shp_runouts, epsg_code):

    # import points from slope file
    pointDf = pd.read_csv(run_outs_file, header=0, sep=',')
    pointDf.head()
    # define schema for line shape file
    schema = {'geometry': 'Point', 'properties': [("flow_id", 'str'), ("Effusion_rate", 'int'), ("X_run_out", 'float'),
                                                  ("Y_run_out", 'float'), ("Channel_Depth", 'float'), 
                                                  ("Channel_Width_init", 'float'), ("Elevation_run_out", 'int'), 
                                                  ("Distance_run_out", 'int') ]}
    # open a fiona object
    pointShp = fiona.open(shp_runouts, mode='w',
                         driver='ESRI Shapefile', schema=schema, crs=f'epsg:{epsg_code}')

    # iterate over each row in the dataframe and save record
    for index, row in pointDf.iterrows():
        rowDict = {
            'geometry': {'type': 'Point',
                         'coordinates': (row.X_run_out, row.Y_run_out)},
            'properties': {'flow_id': row.flow_id, 'Effusion_rate': row.Effusion_rate, 'X_run_out': row.X_run_out,
                           'Y_run_out': row.Y_run_out, 'Channel_Depth': row.Depth, 'Channel_Width_init': row.Width_init,
                           'Elevation_run_out': row.Elevation_run_out, 'Distance_run_out': row.Distance_run_out
                           }}
        pointShp.write(rowDict)
    # close fiona object
    pointShp.close()
    print(f"----------- Runouts coordinates are saved as shape file in:'{shp_runouts}'---------------")

def get_vent_shp(csv_vent_file, shp_vent_file, epsg_code):
    # import points from slope file
    with open(csv_vent_file,'r') as file:
        try:
            dialect = csv.Sniffer().sniff(file.read(1024))
            file.seek(0)  # Reset file pointer after sniffing
        except csv.Error:
            print("Could not determine delimiter.")
            return
    if dialect.delimiter == ';':
        pointDf = pd.read_csv(csv_vent_file, header=0, sep=';')
    elif dialect.delimiter == ',':
        pointDf = pd.read_csv(csv_vent_file, header=0, sep=',')

    pointDf.head()
    # define schema for line shape file
    schema = {'geometry': 'Point', 'properties': [("flow_id", 'str')]}
    # open a fiona object

    pointShp = fiona.open(shp_vent_file,
                          mode='w',
                         driver='ESRI Shapefile',
                          schema=schema,
                          crs=f'epsg:{epsg_code}')

    # iterate over each row in the dataframe and save record
    first_coordinates = None
    for index, row in pointDf.iterrows():
        # Check if 'X_init' and 'Y_init' exist in the row
        if 'X_init' in row and 'Y_init' in row:
            coordinates = (row.X_init, row.Y_init)
        else:
            coordinates = (row.X, row.Y)

        # If it's the first iteration, save the coordinates
        if first_coordinates is None:
            first_coordinates = coordinates

        # Skip the row if it has the same coordinates as the first one
        if coordinates == first_coordinates and index > 0:
            continue  # Skip writing the duplicate points

        rowDict = {
            'geometry': {'type': 'Point',
                         'coordinates': coordinates},
            'properties': {'flow_id': row.flow_id
                           }}
        pointShp.write(rowDict)
    # close fiona object
    pointShp.close()
    print(f"----------- Vent file is saved as shape file in:'{shp_vent_file}'---------------")

def write_single_vent_shp(flow_id, long, lat, shp_vent_file, epsg_code):
    schema = {
        'geometry': 'Point',
        'properties': [("flow_id", 'str')],
    }

    with fiona.open(shp_vent_file, mode='w',
                    driver='ESRI Shapefile',
                    schema=schema,
                    crs=f'epsg:{epsg_code}') as shp:
        point_geom = Point(float(long), float(lat))
        record = {
            'geometry': mapping(point_geom),
            'properties': {'flow_id': flow_id}
        }
        shp.write(record)
def crop_asc_file(sim_asc, cropped_asc_file):
    with open(sim_asc) as file:
        header_lines = [next(file) for _ in range(6)]
        ncols = int(header_lines[0].split()[1])
        nrows = int(header_lines[1].split()[1])
        xllcorner = float(header_lines[2].split()[1])
        yllcorner = float(header_lines[3].split()[1])
        cellsize = float(header_lines[4].split()[1])
        nodata_value = float(header_lines[5].split()[1])
        # Read the values from the ASC file
        data_lines = [line.strip().split() for line in file]
        # Convert the data lines to a NumPy array
        data = np.array(data_lines, dtype=float)
    # Determine the index of the non-zeros lines and columns
    nonzero_rows, nonzero_cols = np.nonzero(data)
    # Calculate the limit of the crop
    min_row, max_row = np.min(nonzero_rows), np.max(nonzero_rows)
    min_col, max_col = np.min(nonzero_cols), np.max(nonzero_cols)
    # Defnie the values of the cropped data
    cropped_data = data[min_row:max_row + 1, min_col:max_col + 1]
    # Update the headers of the new cropped asc file
    cropped_nrows, cropped_ncols = cropped_data.shape
    cropped_xllcorner = xllcorner + min_col * cellsize
    cropped_yllcorner = yllcorner + (nrows - max_row - 1) * cellsize

    header_lines = [
        f"ncols {cropped_ncols}\n",
        f"nrows {cropped_nrows}\n",
        f"xllcorner {cropped_xllcorner}\n",
        f"yllcorner {cropped_yllcorner}\n",
        f"cellsize {cellsize}\n",
        f"nodata_value {nodata_value}\n"
    ]
    # write data in the new cropped asc file
    with open(cropped_asc_file, "w") as file:
        file.writelines(header_lines)
        for row in cropped_data:
            line = " ".join(str(value) if value is not None else str(nodata_value) for value in row)
            file.write(line + "\n")

def convert_to_tiff(cropped_asc_file, sim_tif_file):
    with rasterio.open(cropped_asc_file) as src:
        profile = src.profile.copy()
        profile["compress"] = "deflate"  # Use deflate compression
        profile["tiled"] = True  # Enable tiling for better performance and compression
        profile["blockxsize"] = 128  # Adjust the tile size as needed
        profile["blockysize"] = 128
        data = src.read(1)
        with rasterio.open(sim_tif_file, "w", **profile) as dst:
            dst.write(data, 1)


def crop_and_convert_to_tif(sim_asc, cropped_geotiff_file, epsg_code):
    """
    Crops an ASC file and saves it as a GeoTIFF file.

    :param sim_asc: Path to the input ASC file
    :param cropped_geotiff_file: Path to the output GeoTIFF file
    :param epsg_code: EPSG code for the coordinate reference system
    """
    # Read the ASCII file
    with open(sim_asc) as file:
        header_lines = [next(file) for _ in range(6)]
        ncols = int(header_lines[0].split()[1])
        nrows = int(header_lines[1].split()[1])
        xllcorner = float(header_lines[2].split()[1])
        yllcorner = float(header_lines[3].split()[1])
        cellsize = float(header_lines[4].split()[1])
        nodata_value = float(header_lines[5].split()[1])

        # Read the values from the ASC file
        data_lines = [line.strip().split() for line in file]
        # Convert the data lines to a NumPy array
        data = np.array(data_lines, dtype=float)

    # Determine the index of the non-zero rows and columns
    nonzero_rows, nonzero_cols = np.nonzero(data)
    # Calculate the limits of the crop
    min_row, max_row = np.min(nonzero_rows), np.max(nonzero_rows)
    min_col, max_col = np.min(nonzero_cols), np.max(nonzero_cols)

    # Define the values of the cropped data
    cropped_data = data[min_row:max_row + 1, min_col:max_col + 1]

    # Update the headers of the new cropped ASC file
    cropped_nrows, cropped_ncols = cropped_data.shape
    cropped_xllcorner = xllcorner + min_col * cellsize
    cropped_yllcorner = yllcorner + (nrows - max_row - 1) * cellsize

    # Define the transform and metadata for the GeoTIFF
    transform = from_origin(cropped_xllcorner, cropped_yllcorner + cropped_nrows * cellsize, cellsize, cellsize)
    metadata = {
        'driver': 'GTiff',
        'count': 1,
        'dtype': 'float32',
        'width': cropped_ncols,
        'height': cropped_nrows,
        'crs': CRS.from_epsg(epsg_code),
        'transform': transform,
        'nodata': nodata_value
    }


    # Write the data to a GeoTIFF file
    with rasterio.open(cropped_geotiff_file, 'w', **metadata) as dst:
        dst.write(cropped_data, 1)

    print(f" Cropped simulation saved in Geotiff at '{cropped_geotiff_file}'")