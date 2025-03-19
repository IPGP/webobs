import re
from io import StringIO

import polars as pl

from calibration import read_clb
from config import GRIDS, NODES, print_config
from grids import read_node

# print_config(WEBOBS)

print("---------------------- GRIDS.rc -------------------- \n")
print_config(GRIDS)

print("\n-------------------- NODES.rc -------------------- \n")
print_config(NODES)

clb = read_clb("PROC.GEOSCOPE.ISBFDFM.clb")
print(clb)

df = pl.from_dicts(clb)
print(df)

content = ""
with open("PROC.GEOSCOPE.ISBFDFM.clb", encoding="ISO-8859-1") as fp:
    for line in fp:
        if re.match(r"\w+|=", line):
            content += line

data = StringIO(content)
df_csv = pl.read_csv(
    data,
    encoding="ISO-8859-1",
    separator="|",
    comment_prefix="#",
    try_parse_dates=True,
    truncate_ragged_lines=True,
)
print(df_csv)

node = read_node("ISBFDFM")
N = node["ISBFDFM"]
print(N)
print(N["NAME"])
print(N["CLB"]["1"])
print(N["CLB"]["1"]["lc"])
