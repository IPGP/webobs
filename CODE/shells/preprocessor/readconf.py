#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
A module to read configuration files and extracting values of the environment variables.

Functions
---------
read_file(path)
    Read configuration file.
find_path(var_name, path_to_var='')
    Find the absolute path to the variable we are looking for which is contained in the configuration file.
"""

from configparser import ConfigParser

def read_file(path):
    """Read configuration file.
    
    Parameters
    ----------
    path : str
        Absolute path to the configuration file.
    
    Returns
    -------
    parser : A config.ConfigParser object.
    """
    
    parser = ConfigParser(delimiters='|')   # changing the default delimiter for '|' delimiter
    with open(path) as stream:
        parser.read_string('[default]\n' + stream.read())   # setting 'default' section to read sections
        
    return parser

def find_path(parser,var_name,path_to_var=''):
    """Find the absolute path to the variable we are looking for which is contained in the configuration file.
    
    Parameters
    ----------
    parser : configparser.ConfigParser
    var_name : str
        Name of the variable we are looking for.
    path_to_var : str
        Relative path toward the variable we are looking for.
    
    Returns
    -------
     var_name : str
        Absolute or relative path toward the variable we are looking for.
    """
    
    var_name = parser['default'][var_name]  # getting the value of the environment variable
    i = var_name.index('/')                 # looking for the delimiter between environment variable's name and folder name
    path_to_var = var_name[i+1:]+'/'        # extracting the folder name at the right of the environment variable's name
    if '$' in var_name:                     # '$' means it is an environment variable's name
        var_name = find_path(parser,var_name[2:i-1].lower(), path_to_var)+path_to_var   # reconstructing the path to the variable we are looking for
        return var_name
    else:
        return var_name+'/'

# This segment is executed only if the script is ran explicitly
if __name__ == "__main__":
    wo = '/opt/webobs/CONF/WEBOBS.rc'
    parser = read_file(wo)
    path = find_path(parser,'sql_table_producer')
    print(path)
