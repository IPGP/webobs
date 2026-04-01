import glob
import os
import subprocess
import sys
import time


sys.path.append("/etc/webobs.d/../CODE/python/superprocs/")
from wolib.config import read_config, print_config, WEBOBS


if len(sys.argv) < 2:
    print("Missing Proc name in command line arguments")

prog = sys.argv[0]
PROC = sys.argv[1]

if len(sys.argv) > 2:
    delay = sys.argv[2]
else:
    delay = 60

try:
    delay = int(delay)
except ValueError:
    raise


PROC_FILE = f"{WEBOBS['PATH_PROCS']}/{PROC}/{PROC}.conf"
PROC_CONF = read_config(PROC_FILE)
shakemapROOT = PROC_CONF["RAWDATA"]
if not os.path.exists(shakemapROOT):
    print(f"!! Input directory {shakemapROOT} not found !!")
    print("!! Check config !!")
    sys.exit()

outROOT = f"{WEBOBS['ROOT_OUTG']}/PROC.{PROC}/{WEBOBS['PATH_OUTG_EVENTS']}"
if not os.path.exists(outROOT):
    os.makedirs(outROOT)

options = ["-c", PROC_FILE]
if WEBOBS["MKGRAPH_THUMBNAIL_HEIGHT"]:
    options.extend(["-t", WEBOBS["MKGRAPH_THUMBNAIL_HEIGHT"]])
if WEBOBS["ROOT_CODE"]:
    options.extend(["-w", WEBOBS["ROOT_CODE"]])

# Say when we start
current_time = time.strftime("%m/%d/%Y at %H:%M:%S", time.localtime())
print(f"\n=== {prog} {PROC} {delay} : Process started on {current_time}\n")

event_dat_path = os.path.join(shakemapROOT, "**", "event_dat.xml")
updated_files = glob.glob(event_dat_path, recursive=True)
for dat_file in updated_files:
    m_time = os.path.getmtime(dat_file)
    if time.time() - m_time < 60 * delay:
        current_dir = os.path.dirname(dat_file)
        evt_file = os.path.join(current_dir, "event.xml")
        print(f"--- start processing {current_dir} ---")
        if os.path.isfile(evt_file) and os.path.isfile(dat_file):
            exe = os.path.join(WEBOBS["ROOT_CODE"], "python", "pgamap", "pga_map_processing.py")
            cmd = [WEBOBS["PYTHON_PRGM"], exe, evt_file, dat_file, outROOT]
            cmd.extend(options)
            res = subprocess.call(cmd)
        else:
            print("!! One of the input files is empty, skipping event !!")

# Say when we stop
current_time = time.strftime("%m/%d/%Y at %H:%M:%S", time.localtime())
print(f"\n=== {prog} {PROC} {delay} : Process ended on {current_time}\n")
