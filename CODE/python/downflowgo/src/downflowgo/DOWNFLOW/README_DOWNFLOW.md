# Welcome to the folder DOWNFLOW

This is a README file for installing and using the stochastic model DOWNFLOW of [Favalli et al. 2005](https://doi.org/10.1029/2004gl021718).
DOWNFLOW provides the most likely lava flow paths, including the LoSD and area of coverage, from a point vent. 
DOWNFLOW must be calibrated (dh and N parameters) for your volcano.

This is not the official release of DOWNFLOW but only a version that can be integrated with [PyFLOWGO](https://github.com/pyflowgo/pyflowgo.git) to make DONWFLOWGO.

To use DOWNFLOW you must cite :
Favalli, M. et al. (2005). “Forecasting lava flow paths by a stochastic approach”. Geophysical Research Letters 32(3). 
issn: 0094- 8276. https://doi.org/10.1029/2004gl021718.

To use DOWNFLOWGO you must cite :

Chevrel MO, Villeneuve N, Grandin R, Froger JL, Coppola D, Massimetti F, Campus A, Hrysiewicz A, Peltier A, (2023) 
Report on the lava flow daily monitoring of the 19 September – 05 October 2022 eruption at Piton de la Fournaise. 
Volcanica 6(2): 391–404. https://doi.org/10.30909/vol.06.02.391404   


## Description of the package 
This folder includes:

-> the source code in c++ of [DOWNFLOW](https://doi.org/10.1029/2004gl021718) 
provided by Massimiliano Favalli (hopefully soon officially available on github).

-> the makefile to compile the c++ code into an executable program for Unix systems.

-> parameters_range_template.txt that contains the input parameters needed for DOWNFLOW.

-> a DEM of Piton de la Fournaise for testing

## Actions:

### 1) Compile DOWNFLOW.cpp on your system

Unix system:

In the terminal, go into the folder DOWNFLOW:

 ```cd DOWNFLOWGO-main\downflowgo\DOWNFLOW```

and type : ```make```
this function will use the file makefile.txt and DOWNFLOW.cpp and will create the executable program. 
Now you should have the new DOWNFLOW executable Unix file and a new code object (DOWNFLOW.o)

Windows:

Use a compiler software to compile the c++ code. 

For exemple you can use : ```MinGW SourceForge``` and select ```mingw32-gcc-g++``` package 
and add ```MinGW``` to ```PATH``` with ```C:\MinGW\bin```.

Then in terminal, go to the folder:

```cd DOWNFLOWGO-main\downflowgo\DOWNFLOW```
 
and type :


```g++ -o DOWNFLOW downflow.cpp```

Now you should have the ```DOWNFLOW.exe``` executable file.

### 2) Run DOWNFLOW

Requiered files:

1) The DEM must be  ```.asc ``` format with UTM in WGS84, with the following header :
```
ncols        3193
nrows        2305
xllcorner    361622.6
yllcorner    7644294.2
cellsize     25.00
NODATA_value  0
 ```
NODATA_value can be 0 or what ever value (like -99999) but avoid « nan » or any letters.
A DEM of Piton de la Fournaise at 25 m (SRTM) is provided for testing.

2) The parameters_range_template.txt must contain the right path to the DEM and the vent coordinates (Xorigine, Yorigine) 


To run DOWNFLOW open your terminal and go to DOWNFLOW Folder and execute:
 ```
./DOWNFLOW parameters_range_template.txt
 ```

you can also use the python function:

 ```
 import os
 
 parameters_range = '/path/to/parameters_range_template.txt'
 path = '/path/to/DOWNFLOW/'
 
 def run_downflow(parameters_range, path):
       os.system(path + '/DOWNFLOW ' + parameters_range)
 
 run_downflow(parameters_range, path)
 ```

## Output files

The following files will be produced :
  1) ```sim.asc ```(a raster with the flow path probabilities)
  2) ```profile_00000.txt``` (coordinates every xx m of the line of steepest descent)

## DOWNFLOWGO

-> to run DOWNFLOWGO and make maps, see README in downflowgo-main

 # Licence:
To use DOWNFLOW, you must contact Massimiliano Favalli.


 # Authors of this readme:
 Dr. Magdalena Oryaëlle Chevrel (oryaelle.chevrel@ird.fr) - Laboratoire Magmas et Volcans
