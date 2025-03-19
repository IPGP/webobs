import glob
import os
import re

from dateutil import parser

from calibration import read_clb
from config import NODES, read_config


def list_node_names(nodename):
    root_dir = os.path.join(NODES["PATH_NODES"], "**")
    nodes = []
    for path in glob.glob(root_dir, recursive=False):
        name = os.path.normpath(path).split(os.sep)[-1]
        if os.path.isdir(path) and re.search(nodename, name):
            nodes.append(name)
    return nodes


def get_date_time(clb):
    for k in clb.keys():
        dt = " ".join([clb[k].pop("DATE"), clb[k].pop("TIME")])
        try:
            clb[k]["dt"] = str(parser.parse(dt))
        except ValueError:
            pass
    return clb


def read_node(nodename):
    nodes = {}
    for node in list_node_names(nodename):
        path = os.path.join(NODES["PATH_NODES"], node)
        cnf_file = os.path.join(path, f"{node}.cnf")
        infos = read_config(cnf_file)

        projet = os.path.join(path, NODES["SPATH_INTERVENTIONS"], f"{node}_Projet.txt")
        if os.path.isfile(projet):
            infos["PROJECT"] = 1

        # substitutes possible decimal comma to point for numerics
        infos["LAT_WGS84"] = infos["LAT_WGS84"].replace(",", ".")
        infos["LON_WGS84"] = infos["LON_WGS84"].replace(",", ".")

        # removes escape characters in feature's list
        infos["FILES_FEATURES"] = infos["FILES_FEATURES"].replace("\,", ",")
        infos["FILES_FEATURES"] = infos["FILES_FEATURES"].replace("\|", ",")

        # removes trailing blanks in feature's list
        infos["FILES_FEATURES"] = re.sub("\s", "", infos["FILES_FEATURES"])

        clb_files = glob.glob(os.path.join(path, f"PROC.*{nodename}.clb"))
        clb_file = clb_files[0] if clb_files else os.path.join(path, f"{nodename}.clb")
        infos["CLB"] = {}
        if os.path.isfile(clb_file):
            infos["CLB"] = read_clb(clb_file)
            infos["CLB"] = get_date_time(infos["CLB"])
        nodes[node] = infos
    return nodes


if __name__ == "__main__":
    #    nodes = list_node_names("WDCILAM")
    #    print(nodes)

    #    node_infos = read_node("WDCILAM")
    #    print(node_infos["WDCILAM"])

    node_infos = read_node("GCSBCM1")
    print(node_infos["GCSBCM1"])

#    node_infos = read_node("USGSEQWS")
#    print(node_infos["USGSEQWS"])
