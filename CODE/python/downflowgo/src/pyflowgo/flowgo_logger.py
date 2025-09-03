# Copyright 2017 PyFLOWGO development team (Magdalena Oryaelle Chevrel and Jeremie Labroquere)
#
# This file is part of the PyFLOWGO library.
#
# The PyFLOWGO library is free software: you can redistribute it and/or modify
# it under the terms of the the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# The PyFLOWGO library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received copies of the GNU Lesser General Public License
# along with the PyFLOWGO library.  If not, see https://www.gnu.org/licenses/.


class Singleton(type):
    _instances = {}

    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
        return cls._instances[cls]


class FlowGoLogger(metaclass=Singleton):
    def __init__(self):
        self._variables = []

    def add_variable(self, variable_name, position, value):
        entry_generated = False

        for current_entry in self._variables:
            if position == current_entry.get('position', None):
                current_entry[variable_name] = value
                entry_generated = True

            if entry_generated is True:
                break

        # add a new entry
        if entry_generated is False:
            self._variables.append({'position':position, variable_name:value})

    def write_values_to_file(self, filename):
        import csv

        if len(self._variables) > 0:
            with open(filename, 'w') as csvfile:
                fieldnames = self._variables[0].keys()

                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

                writer.writeheader()

                for row in self._variables:
                    writer.writerow(row)

    def get_values(self, variable_name):
        generated_list = []

        for current_row in self._variables:
            generated_list.append(current_row.get(variable_name, None))

        return generated_list

    def clear(self):
        self._variables = []
