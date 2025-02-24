import sys
import subprocess

sys.path.append("/etc/webobs.d/../CODE/python/")
from libwebobs.config import read_config, print_config, WEBOBS


PROC = sys.argv[1]

PROC_FILE = f"{WEBOBS['PATH_PROCS']}/{PROC}/{PROC}.conf"
PROC_CONF = read_config(PROC_FILE)
options = PROC_FILE

shakemapROOT = PROC_CONF["RAWDATA"]
evt_file = shakemapROOT + "/event.xml"
dat_file = shakemapROOT + "/event_dat.xml"
outROOT = f"{WEBOBS['ROOT_OUTG']}/PROC.{PROC}/{WEBOBS['PATH_OUTG_EVENTS']}"

res = subprocess.call(
    [WEBOBS["PYTHON_PRGM"], "pga_map.py", evt_file, dat_file, outROOT, "-c", options]
)
