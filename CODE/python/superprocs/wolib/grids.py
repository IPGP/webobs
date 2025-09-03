import glob
import os
import re

from wolib.config import NODES
from wolib.config import read_clb
from wolib.config import read_config
from wolib.utils import safe_eval


def find_nodes(nodename):
    root_dir = os.path.join(NODES["PATH_NODES"], "**")
    nodes = []
    for path in glob.glob(root_dir, recursive=False):
        name = os.path.normpath(path).split(os.sep)[-1]
        if os.path.isdir(path) and re.search(nodename, name):
            nodes.append(name)
    return nodes


class Node:
    def __init__(self, fullid):
        self.fullid = fullid
        self.read_node()

    def read_node(self):
        nodeparts = self.fullid.split(".")
        if len(nodeparts) != 3:
            print("Incorrect NODEFULLID argument")
            exit()

        self.gridtype = nodeparts[0]
        self.gridname = nodeparts[1]
        self.nodeid = nodeparts[2]
        self.path = os.path.join(NODES["PATH_NODES"], self.nodeid)
        self.cnf_file = os.path.join(self.path, f"{self.nodeid}.cnf")

        keyproc = f"{self.gridtype}.{self.gridname}."
        for k, v in read_config(self.cnf_file).items():
            if k.startswith(f"{self.gridtype}.") and not k.startswith(keyproc):
                continue
            if isinstance(v, str) and re.match(r"\d/\d", v):
                v = safe_eval(v) * 86400
            k = k.replace(keyproc, "")
            setattr(self, k, v)

        self.clb_file = os.path.join(self.path, f"{self.fullid}.clb")
        if os.path.exists(self.clb_file):
            setattr(self, "CLB", read_clb(self.clb_file))
        else:
            print(f"{self.clb_file} not found!")
            setattr(self, "CLB", {})

    def __repr__(self):
        attrs = ", ".join(f"\n  {k}={repr(v)}" for k, v in self.__dict__.items())
        return f"Node({attrs}\n)"


class Grid:
    def __init__(self, name, nodes=None):
        self.name = name
        self.nodes = []
        if nodes is not None:
            for node in nodes:
                self.add_node(node)

    def add_node(self, node):
        self.nodes.append(node)

    def delete_node(self, id):
        for i, node in enumerate(self.nodes):
            if node.fullid == id:
                del self.nodes[i]

    def find_node(self, id):
        for node in self.nodes:
            if node.fullid == id:
                return node

    def __repr__(self):
        attrs = ", ".join(f"\n  {k}={repr(v)}" for k, v in self.__dict__.items())
        return f"Grid({attrs}\n)"


class View(Grid):
    def __init__(self, name, nodes=None):
        super().__init__(name, nodes)

    def __repr__(self):
        attrs = ", ".join(f"\n  {k}={repr(v)}" for k, v in self.__dict__.items())
        return f"View({attrs}\n)"


if __name__ == "__main__":
    # cd ~/webobs/CODE/python/superprocs
    # python3 -m wolib.grids

    node1 = Node("PROC.GEOSCOPE.ISBFDFM")
    node2 = Node("PROC.GEOSCOPE.ISBFDF0")
    # print(node1)

    view = View("PROC.GEOSCOPE")
    view.add_node(node1)
    view.add_node(node2)
    print(view)
