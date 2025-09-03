import tkinter as tk
from tkinter import filedialog, ttk
import os
import sys
import configparser
import downflowgo.mapping as mapping


def get_folder(entry_var):
    folder_path = filedialog.askdirectory()
    if folder_path:
        entry_var.set(folder_path)


def open_create_map_window(root):
    map_window = tk.Toplevel(root)
    map_window.title("Create Map")
    map_window.geometry("900x300")

    # Check argument 
    if len(sys.argv) < 2:
        print("Usage:  python main_mapping_downflowgo_GUI.py config_downflowgo.ini")
        sys.exit(1)
    config_file = sys.argv[1]

    # Load the INI configuration file
    config = configparser.ConfigParser()
    config.read(config_file)

    if not config.sections():
        print(f"Error : Impossible to read '{config_file}'")
        sys.exit(1)


    if not config.sections():
        print(f"Error : Impossible to read '{config_file}'")
        sys.exit(1)


    language = config["language"]["language"]
    path_to_eruptions = config["paths"]["eruptions_folder"]
    dem = config["paths"]["dem"]
    name_vent = config["downflow"]["name_vent"]
    img_tif_map_background = config["mapping"]["img_tif_map_background_path"]
    monitoring_network_path = config["mapping"]["monitoring_network_path"]
    lava_flow_outline_path = config["mapping"]["lava_flow_outline_path"]
    logo_path = config["mapping"]["logo_path"]
    source_img_tif_map_background = config["mapping"]["source_img_tif_map_background"]
    unverified_data = config["mapping"]["unverified_data"]

    entry_path_to_results_var = tk.StringVar(value=path_to_eruptions)

    folder_frame = tk.Frame(map_window)
    folder_frame.pack(anchor=tk.W)
    label_path_to_results = tk.Label(folder_frame, text="Path to Eruption Results:")
    label_path_to_results.pack(side=tk.LEFT)
    entry_path_to_results = tk.Entry(folder_frame, textvariable=entry_path_to_results_var, width=50)
    entry_path_to_results.pack(side=tk.LEFT)
    button_browse = tk.Button(folder_frame, text="Browse", command=lambda: get_folder(entry_path_to_results_var))
    button_browse.pack(side=tk.LEFT)

    def update_flow_id(*args):
        nonlocal flow_id
        flow_id = os.path.basename(entry_path_to_results_var.get())

    entry_path_to_results_var.trace_add("write", update_flow_id)

    flow_id = ""

    def get_sim_layers():
        return {
            'shp_losd_file': os.path.join(entry_path_to_results_var.get(), 'map', f'losd_{flow_id}.shp'),
            'shp_vent_file': os.path.join(entry_path_to_results_var.get(), 'map', f'vent_{flow_id}.shp'),
            'cropped_geotiff_file': os.path.join(entry_path_to_results_var.get(), 'map', f'sim_{flow_id}.tif'),
            'shp_runouts': os.path.join(entry_path_to_results_var.get(), 'map', f'runouts_{flow_id}.shp'),
        }

    map_layers = {
        'img_tif_map_background': img_tif_map_background,
        'monitoring_network_path': monitoring_network_path,
        'lava_flow_outline_path': lava_flow_outline_path,
        'logo_path': logo_path,
        'source_img_tif_map_background': source_img_tif_map_background,
        'unverified_data': unverified_data
    }

    def create_file_selector(frame, label_text, variable):
        tk.Label(frame, text=label_text).pack(side=tk.LEFT)
        entry = tk.Entry(frame, textvariable=variable, width=60)
        entry.pack(side=tk.LEFT)
        tk.Button(frame, text="Browse", command=lambda: variable.set(filedialog.askopenfilename() or "0")).pack(
            side=tk.LEFT)

    img_tif_var = tk.StringVar(value=img_tif_map_background)
    monitoring_var = tk.StringVar(value=monitoring_network_path)
    lava_outline_var = tk.StringVar(value=lava_flow_outline_path)
    logo_var = tk.StringVar(value=logo_path)

    frames = [("Background Map (.tif):", img_tif_var),
              ("Monitoring Network (.shp): (0 if not)", monitoring_var),
              ("Lava Flow Outline (.shp): (0 if not)", lava_outline_var),
              ("Logo (.png): (0 if not)", logo_var)]

    for label, var in frames:
        frame = tk.Frame(map_window)
        frame.pack(anchor=tk.W)
        create_file_selector(frame, label, var)

    def update_map_layers():
        map_layers.update({
            'img_tif_map_background': img_tif_var.get(),
            'monitoring_network_path': None if monitoring_var.get().strip() == "0" else monitoring_var.get(),
            'lava_flow_outline_path': None if lava_outline_var.get().strip() == "0" else lava_outline_var.get(),
            'logo_path': None if logo_var.get().strip() == "0" else logo_var.get()
        })

    img_tif_var.trace_add("write", lambda *args: update_map_layers())
    monitoring_var.trace_add("write", lambda *args: update_map_layers())
    lava_outline_var.trace_add("write", lambda *args: update_map_layers())
    logo_var.trace_add("write", lambda *args: update_map_layers())

    def create_map():
        mapping.create_map(entry_path_to_results_var.get(), dem, flow_id, map_layers, get_sim_layers(),
                           mode='downflowgo', language=language, display = 'yes')
        map_window.destroy()

    button_frame = tk.Frame(map_window)
    button_frame.pack()
    ttk.Button(button_frame, text="CREATE MAP", command=create_map).pack(side=tk.LEFT)
    ttk.Button(button_frame, text="NO", command=map_window.destroy).pack(side=tk.LEFT)


if __name__ == "__main__":
    root = tk.Tk()
    root.withdraw()
    open_create_map_window(root)
    root.mainloop()
    sys.exit()  