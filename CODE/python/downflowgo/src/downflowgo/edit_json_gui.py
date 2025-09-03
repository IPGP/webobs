import tkinter as tk
from tkinter import filedialog
from tkinter import ttk
import json


def open_json_file():
    global rows
    canvas.delete("all")
    canvas_frame.update_idletasks()

    file_path = filedialog.askopenfilename(filetypes=[("JSON Files", "*.json")])
    if file_path:
        with open(file_path, "r") as json_file:
            data = json.load(json_file)

            # Process individual entries of interest
            for key, value in data.items():
                if key in ["lava_name", "slope_file", "step_size", "effusion_rate_init"]:
                    label = tk.Label(canvas, text=key)
                    canvas.create_window(10, rows, anchor="w", window=label)
                    if isinstance(value, (int, float)):
                        entry_var = tk.DoubleVar()
                        entry_var.set(value)
                        entry = tk.Entry(canvas, textvariable=entry_var, width=20)
                    else:
                        entry = tk.Entry(canvas, width=20)
                        entry.insert(0, value)
                    canvas.create_window(200, rows, anchor="w", window=entry)
                    labels[key] = entry
                    rows += 25

                elif key == "slope_smoothing_active":
                    label = tk.Label(canvas, text=key)
                    canvas.create_window(10, rows, anchor="w", window=label)
                    entry_var = tk.BooleanVar(value=value)
                    entry = tk.Checkbutton(canvas, variable=entry_var)
                    canvas.create_window(200, rows, anchor="w", window=entry)
                    labels[key] = entry
                    rows += 25
                else:
                    label = tk.Label(canvas, text=key, font=("Helvetica", 12, "bold"))
                    canvas.create_window(10, rows, anchor="w", window=label)
                    rows += 25
                    if isinstance(value, dict):
                        for subkey, subvalue in value.items():
                            label = tk.Label(canvas, text=subkey)
                            canvas.create_window(10, rows, anchor="w", window=label)
                            if isinstance(subvalue, (int, float)):
                                entry_var = tk.DoubleVar()
                                entry_var.set(subvalue)
                                entry = tk.Entry(canvas, textvariable=entry_var, width=20)
                            else:
                                entry = tk.Entry(canvas, width=20)
                                entry.insert(0, subvalue)
                            canvas.create_window(200, rows, anchor="w", window=entry)
                            labels[(key, subkey)] = entry
                            rows += 25
                    else:
                        label = tk.Label(canvas, text=str(value))
                        canvas.create_window(10, rows, anchor="w", window=label)
                        rows += 25

            canvas.config(scrollregion=canvas.bbox("all"))
            save_button.config(state=tk.NORMAL)


def save_json_file():
    new_data = {}

    for key, entry in labels.items():
        if key in ["lava_name", "slope_file", "step_size", "effusion_rate_init"]:
            new_data[key] = entry.get()
        elif isinstance(entry, tk.Entry):
            section, subkey = key
            if section not in new_data:
                new_data[section] = {}
            new_data[section][subkey] = entry.get()
        elif isinstance(entry, tk.Entry) and entry.cget("textvariable"):
            section, subkey = key
            if section not in new_data:
                new_data[section] = {}
            new_data[section][subkey] = entry.cget("textvariable").get()
        elif isinstance(entry, bool):  # Convert bool values to "true" or "false"
            new_data[key] = "true" if entry else "false"

    file_path = filedialog.asksaveasfilename(defaultextension=".json", filetypes=[("JSON Files", "*.json")])
    if file_path:
        with open(file_path, "w") as json_file:
            json.dump(new_data, json_file, indent=4)
        app.quit()  # Close application after being saved

labels = {}
rows = 5

app = tk.Tk()
app.title("JSON Editor")

frame = tk.Frame(app)
frame.pack(padx=20, pady=20)

open_button = tk.Button(frame, text="Open JSON File", command=open_json_file)
open_button.grid(row=0, column=0, padx=10, pady=10)

save_button = tk.Button(frame, text="Save JSON File", command=save_json_file, state=tk.DISABLED)
save_button.grid(row=0, column=1, padx=10, pady=10)

canvas_frame = tk.Frame(app)  # Define canvas_frame
canvas_frame.pack(fill="both", expand=True)

canvas = tk.Canvas(canvas_frame, bg="white")
canvas.pack(side="left", fill="both", expand=True)

scrollbar = ttk.Scrollbar(canvas_frame, orient="vertical", command=canvas.yview)
scrollbar.pack(side="right", fill="y")
canvas.configure(yscrollcommand=scrollbar.set)

canvas.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))

app.mainloop()

