import configparser
import os
import random
import shutil
import string
import subprocess
import sys
from datetime import datetime

from PIL import Image

sys.path.insert(0, "/etc/webobs.d/../CODE/python/superprocs/")
from wolib.config import WEBOBS
from wolib.config import read_config

if len(sys.argv) < 2:
    print("Missing Proc name in command line arguments")

procname = sys.argv[1]
print(procname)

OUTDIR = None
RANDOM_ID_CHOICE = string.ascii_lowercase + string.digits
RANDOM_ID_LENGTH = 6
THUMB_SIZE = 256
TIMEOUT = 600

if len(sys.argv) == 4:
    proc_path = os.path.join(sys.argv[3], "REQUEST")
    conf = read_config(proc_path + ".rc")
    OUTDIR = os.path.join(sys.argv[3], f"PROC.{procname}")
    results_dir = os.path.join(OUTDIR, conf[f"PROC.{procname}.DOWNFLOW_NAME_VENT"])
else:
    proc_path = os.path.join(WEBOBS["PATH_PROCS"], procname, procname)
    conf = read_config(proc_path + ".conf")
    OUTDIR = os.path.join(WEBOBS["ROOT_OUTG"], f"PROC.{procname}")
    print(OUTDIR)
    results_dir = os.path.join(OUTDIR, conf["DOWNFLOW_NAME_VENT"])

if OUTDIR:
    os.makedirs(OUTDIR, exist_ok=True)
else:
    print("No valid output directory!")
    exit()

config_dict = {}
keys = ["CONFIG--GENERAL", "PATHS", "DOWNFLOW", "PYFLOWGO", "MAPPING", "LANGUAGE"]

for k, v in conf.items():
    k = k.replace("PROC." + procname + ".", "")
    if "_" in k and any(k.startswith(key) for key in keys):
        section, item = k.lower().split("_", 1)
        section = section.replace("--", "_")
        if section not in config_dict:
            config_dict[section] = {}
        config_dict[section][item] = v

config_dict["config_general"]["use_gui"] = "no"
config_dict["config_general"]["mapping_display"] = "no"
config_dict["paths"]["eruptions_folder"] = OUTDIR

config = configparser.ConfigParser()
for section, kv_pairs in config_dict.items():
    config[section] = kv_pairs

config_file = proc_path + ".ini"
with open(config_file, "w") as fp:
    config.write(fp)

working_dir = os.path.join(WEBOBS["ROOT_CODE"], "python", "downflowgo", "src")
cmd = [WEBOBS["PYTHON_PRGM"], "main_downflowgo.py", config_file]

env = os.environ.copy()
env["DISPLAY"] = ":0.0"

try:
    process = subprocess.Popen(cmd, env=env, cwd=working_dir)
    process.wait(timeout=TIMEOUT)
except subprocess.TimeoutExpired:
    process.kill()
    print("Process was killed (timeout expired)!")

year = datetime.now().year
date = datetime.now().strftime("%Y/%m/%d")
time = datetime.now().strftime("%Y%m%dT%H%M%S")
rid = "".join(random.choice(RANDOM_ID_CHOICE) for _ in range(RANDOM_ID_LENGTH))
events_dir = os.path.join(OUTDIR, "events", date, f"dfg{year}{rid}")
os.makedirs(events_dir, exist_ok=True)
results_flowgo = os.path.join(results_dir, "results_flowgo")
map_dir = os.path.join(results_dir, "map")
shutil.make_archive(os.path.join(events_dir, f"{time}_shapefiles"), "zip", map_dir)

for directory in [results_dir, results_flowgo]:
    for filename in os.listdir(directory):
        if filename.lower().endswith((".csv", "json", ".png")):
            output = f"{time}_{filename}"
            fullpath = os.path.join(directory, filename)
            dest = os.path.join(events_dir, output)
            if not os.path.exists(dest):
                shutil.copy(fullpath, dest)

            if filename.lower().endswith(".png"):
                jpgname = filename[:-3] + "jpg"
                jpgpath = os.path.join(events_dir, jpgname)
                with Image.open(dest) as img:
                    img = img.convert("RGB")
                    img.thumbnail((THUMB_SIZE, THUMB_SIZE))
                    img.save(jpgpath)

                linkname = os.path.join(events_dir, f"link_{jpgname}")
                if not os.path.islink(linkname) and "map" in jpgname:
                    os.symlink(jpgpath, linkname)

                linkname = os.path.join(events_dir, f"{filename}")
                if not os.path.islink(linkname):
                    os.symlink(output, linkname)
