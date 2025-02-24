from calibration import read_clb
from config import read_config, print_config, WEBOBS


# print_config(WEBOBS)

print("--------------------  GRIDS.rc -------------------- ")
filename = WEBOBS["CONF_GRIDS"]
grids = read_config(filename)
print_config(grids)

print("\n-------------------- NODES.rc -------------------- ")
filename = WEBOBS["CONF_NODES"]
nodes = read_config(filename)
print_config(nodes)

clb = read_clb("PROC.GEOSCOPE.ISBFDFM.clb")
print(clb)
