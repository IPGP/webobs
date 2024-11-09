import re, fcntl
from Config import WEBOBS, readCfg
from string import Template

GRIDS={}

GRIDS=readCfg(WEBOBS['CONF_GRIDS'])

