import fiona
import matplotlib.pyplot as plt
from shapely.geometry import shape
import matplotlib.colors as colors
import rasterio
from PIL import Image
from adjustText import adjust_text
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
from matplotlib.cm import ScalarMappable
from matplotlib.patches import Polygon
import rasterio
import numpy as np

if __name__ == "__main__":
    #def create_map(path_to_folder, flow_id, tiff_file):
        # Chemin vers les fichiers out de downflowgo
    folder = '/Users/chevrel/GoogleDrive/Eruption_PdF/310715/Vent_juillet2015_MNT2010/map/'
    asc_file = folder + "sim_Vent_juillet2015.asc"
    tif_file = folder + "sim_tif_file.tif"
    cropped_asc_file = folder + "cropped_asc_file.asc"  # Chemin vers le nouveau fichier ASC

    #def crop_asc_file():
        # Read the ASC file and extract header information
    with open(asc_file) as file:
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
    # Déterminer les indices des lignes et colonnes non nulles
    nonzero_rows, nonzero_cols = np.nonzero(data)
    # Calculer les limites du recadrage
    min_row, max_row = np.min(nonzero_rows), np.max(nonzero_rows)
    min_col, max_col = np.min(nonzero_cols), np.max(nonzero_cols)
    # Recadrer les valeurs de la matrice de données
    cropped_data = data[min_row:max_row + 1, min_col:max_col + 1]
    # Mettre à jour les informations de la grille du nouveau fichier ASC
    cropped_nrows, cropped_ncols = cropped_data.shape
    cropped_xllcorner = xllcorner + min_col * cellsize
    cropped_yllcorner = yllcorner + (nrows - max_row - 1) * cellsize
    # Écrire les informations de l'en-tête du nouveau fichier ASC
    header_lines = [
        f"ncols {cropped_ncols}\n",
        f"nrows {cropped_nrows}\n",
        f"xllcorner {cropped_xllcorner}\n",
        f"yllcorner {cropped_yllcorner}\n",
        f"cellsize {cellsize}\n",
        f"nodata_value {nodata_value}\n"
    ]
    # Écrire les données recadrées dans le nouveau fichier ASC
    with open(cropped_asc_file, "w") as file:
        file.writelines(header_lines)
        for row in cropped_data:
            line = " ".join(str(value) if value is not None else str(nodata_value) for value in row)
            file.write(line + "\n")

#     convert_to_tiff():
    # Convert to GeoTIFF
    #with rasterio.open(cropped_asc_file) as src:
    #    profile = src.profile.copy()
    #    profile["compress"] = "deflate"  # Use deflate compression
    #    profile["tiled"] = True  # Enable tiling for better performance and compression
    #    profile["blockxsize"] = 128  # Adjust the tile size as needed
    #    profile["blockysize"] = 128
    #    data = src.read(1)
    #    with rasterio.open(tif_file, "w", **profile) as dst:
    #        dst.write(data, 1)
    # Ouvrir le fichier ASC recadré
    with open(asc_file) as file:
        header_lines = [next(file) for _ in range(6)]
        data_lines = [line.strip().split() for line in file]
        data = np.array(data_lines, dtype=float)

    # Définir les paramètres du fichier TIFF
    profile = {
        'driver': 'GTiff',
        'dtype': rasterio.float32,
        'nodata': nodata_value,
        'width': cropped_ncols,
        'height': cropped_nrows,
        'count': 1,
        'crs': rasterio.crs.CRS.from_epsg(4326),
        'transform': rasterio.transform.from_origin(cropped_xllcorner, cropped_yllcorner, cellsize, cellsize),
        'compress': 'deflate',  # Utiliser la compression deflate
        'predictor': 2  # Utiliser la prédiction horizontale
    }

    # Écrire les données recadrées dans le fichier TIFF
    with rasterio.open(tif_file, 'w', **profile) as dst:
        dst.write(data, 1)


    # Load the compressed GeoTIFF file and extract the necessary information and data
    with rasterio.open(tif_file) as src:
        data = src.read(1)
        transform = src.transform

    # Define value intervals and associated colors
    intervals = [0, 1, 10, 100, 1000, 10000]  # color intervals
    colors_list = ['none', 'gold', 'orange', 'orangered', 'red']  # associated colors
    colors_list2 = ['gold', 'orange', 'darkorange', 'orangered', 'red']  # colors for colorbar

    # Create a colormap for the legend colorbar
    cmap = colors.LinearSegmentedColormap.from_list('my_colormap', colors_list, N=256)
    bounds = [v - 0.5 for v in intervals]
    norm = colors.BoundaryNorm(bounds, cmap.N)

    # Create the map figure
    fig, ax = plt.subplots(figsize=(8, 7))

    # Plot the simulation data on the map
    sim = ax.imshow(data, extent=(transform[2], transform[2] + transform[0] * data.shape[1],
                                  transform[5] + transform[4] * data.shape[0], transform[5]),  # Flip the y-axis
                    cmap=cmap, norm=norm)

    # Set the limits of the figure to match the dimensions of the image
    ax.set_xlim(transform[2], transform[2] + transform[0] * data.shape[1])
    ax.set_ylim(transform[5] + transform[4] * data.shape[0], transform[5])  # Flip the y-axis

    # Adjust the position of the legend and colorbar
    # Rotate label of Y and orientate vertically
    ax.set_yticks(ax.get_yticks())
    ax.set_yticklabels(ax.get_yticklabels(), rotation='vertical')
    ax.set_title('Carte de simulation DOWNFLOWGO de l\'éruption \n ')
    # Save the figure
    #plt.savefig(path_to_folder+'/map/map.png', dpi=300, bbox_inches='tight')
    plt.savefig('./map.png', dpi=300, bbox_inches='tight')
    # Show the figure
    plt.show()
