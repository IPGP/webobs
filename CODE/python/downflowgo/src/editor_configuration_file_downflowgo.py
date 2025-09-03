import configparser
import tkinter as tk
from tkinter import filedialog, messagebox
from configupdater import ConfigUpdater


# Keys to edit from the INI file
def configure_gui_options(gui_option):
    global CONFIG_KEYS_TO_EDIT, BROWSE_PATH_KEYS, DIRECTORY_KEYS, HELP_TEXTS

    if gui_option == 1:
        CONFIG_KEYS_TO_EDIT = {
            'config_general': ['mode', 'mapping_display'],
            'paths': ['eruptions_folder', 'dem', 'csv_vent_file', 'delete_existing_results'],
            'downflow': ['name_vent','easting', 'northing', 'DH', 'n_path', 'slope_step', 'epsg_code'],
            'pyflowgo': ['json', 'effusion_rates_input'],
            'mapping': ['img_tif_map_background_path', 'monitoring_network_path', 'lava_flow_outline_path','logo_path', 'source_img_tif_map_background', 'unverified_data'],
            'language': ['language']
        }

        BROWSE_PATH_KEYS = {
            'paths': ['eruptions_folder', 'dem', 'csv_vent_file'],
            'pyflowgo': ['json'],
            'mapping': ['img_tif_map_background_path', 'monitoring_network_path', 'lava_flow_outline_path','logo_path']
        }

        DIRECTORY_KEYS = {
            'paths': ['eruptions_folder']
        }

        HELP_TEXTS = {
            ('downflow', 'easting'): "UTM",
            ('downflow', 'northing'): "UTM",
            ('paths', 'dem'): "ASCII grid format",
            ('pyflowgo', 'json'): "Path to PyFLOWGO input JSON file",
            ('pyflowgo', 'effusion_rates_input'): "one value or a range (first, last, step)",
            ('paths', 'csv_vent_file'): "0 or load CSV file",
            ('config_general', 'mode'): "downflow or downflowgo",
            ('config_general', 'mapping_display'): "yes or no",
            ('paths','delete_existing_results'): "yes or no",
        }

    elif gui_option == 2:
        CONFIG_KEYS_TO_EDIT = {
            'paths': ['eruptions_folder'],
            'downflow': ['name_vent','easting', 'northing']
        }

        BROWSE_PATH_KEYS = {
            'paths': ['eruptions_folder'],
        }

        DIRECTORY_KEYS = {
            'paths': ['eruptions_folder']
        }

        HELP_TEXTS = {
            ('downflow', 'easting'): "UTM",
            ('downflow', 'northing'): "UTM",
        }

# Global storage
config_entries = {}
modified_config = None


def load_ini_config(config_file):
    config = configparser.ConfigParser()
    config.read(config_file)
    for section, keys in CONFIG_KEYS_TO_EDIT.items():
        for key in keys:
            var = config_entries.get((section, key))
            if var and config.has_option(section, key):
                var.set(config.get(section, key))


def save_ini_config(config_file, save_as=False):
    updater = ConfigUpdater()
    updater.read(config_file)

    for (section, key), var in config_entries.items():
        if not updater.has_section(section):
            updater.add_section(section)
        if not updater.has_option(section, key):
            updater[section][key] = ''
        updater[section][key].value = var.get()

    if save_as:
        new_path = filedialog.asksaveasfilename(defaultextension='.ini', filetypes=[('INI files', '*.ini')])
        if new_path:
            updater.update_file(new_path)
            messagebox.showinfo("Save as", f"File saved at: {new_path}")
    else:
        updater.update_file(config_file)

def browse_path(section, key, var):
    if section in DIRECTORY_KEYS and key in DIRECTORY_KEYS[section]:
        folder = filedialog.askdirectory()
        if folder:
            var.set(folder)
    else:
        file_path = filedialog.askopenfilename()
        if file_path:
            var.set(file_path)


def has_browse_button(section, key):
    return section in BROWSE_PATH_KEYS and key in BROWSE_PATH_KEYS[section]


def launch_editor(config_file, gui_option=1):
    configure_gui_options(gui_option)

    root = tk.Tk()
    root.title("Configuration File Editor for DOWNFLOWGO")

    ini_frame = tk.LabelFrame(root, padx=10, pady=10)
    ini_frame.pack(anchor=tk.W, fill="x", pady=10)

    config = configparser.ConfigParser()
    config.read(config_file)

    current_config_file = [config_file]
    save_button = None  # Defined below

    # Save current config
    def save_only():
        path = save_ini_config(current_config_file[0])
        save_button.config(state=tk.DISABLED)

    # Save as...
    def save_as_only():
        new_path = save_ini_config(current_config_file[0], save_as=True)
        if new_path:
            current_config_file[0] = new_path
            save_button.config(state=tk.DISABLED)

    def run_and_exit():
        root.destroy()

    # Create editable entries
    for section, keys in CONFIG_KEYS_TO_EDIT.items():
        # Section label (bold)
        section_label = tk.Label(ini_frame, text=f"[{section}]", font=('Arial', 12, 'bold'))
        section_label.pack(anchor=tk.W, pady=(10, 2))

        for key in keys:
            row = tk.Frame(ini_frame)
            row.pack(fill='x', pady=2)

            label_frame = tk.Frame(row)
            label_frame.pack(side=tk.LEFT)

            # Key label normal black, same font & size for all
            key_label = tk.Label(label_frame, text=f"{key}:", fg='black', font=('Arial', 12))
            key_label.pack(side=tk.LEFT)

            # Help text immediately after key, no space, same font & size, but gray color
            help_text = HELP_TEXTS.get((section, key), "")
            if help_text:
                help_label = tk.Label(label_frame, text=help_text, fg='gray', font=('Arial', 10))
                help_label.pack(side=tk.LEFT)

            var = tk.StringVar()
            config_entries[(section, key)] = var

            entry = tk.Entry(row, textvariable=var, width=50)
            entry.pack(side=tk.LEFT, fill='x', expand=True)

            if section in BROWSE_PATH_KEYS and key in BROWSE_PATH_KEYS[section]:
                browse_btn = tk.Button(row, text="Browse", command=lambda s=section, k=key, v=var: browse_path(s, k, v))
                browse_btn.pack(side=tk.LEFT, padx=5)

    # Bottom buttons
    btn_row = tk.Frame(ini_frame)
    btn_row.pack(anchor=tk.W, pady=10)

    save_button = tk.Button(btn_row, text="Save", command=save_only, state=tk.DISABLED)
    save_button.pack(side=tk.LEFT, padx=5)

    save_as_button = tk.Button(btn_row, text="Save as...", command=save_as_only)
    save_as_button.pack(side=tk.LEFT, padx=5)

    run_button = tk.Button(btn_row, text="RUN", command=run_and_exit)
    run_button.pack(side=tk.LEFT, padx=5)

    # Enable save when change occurs
    def on_change(*args):
        save_button.config(state=tk.NORMAL)

    for var in config_entries.values():
        var.trace_add("write", on_change)

    load_ini_config(config_file)
    root.mainloop()

    return current_config_file[0]
