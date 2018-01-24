README_convert_LAKEPARM_to_V5.sh

Authors: WRF-Hydro Development Team

Purpose: The v5.0 release version of the code has modifications to several variable names in the LAKEPARM.nc file.
This shell script will update these variables from an older (pre v5.0) version of the LAKEPARM.nc file. Note if you
are still using the LAKEPARM.TBL version, follow these instructions:

The following changes should be made manually if the user prefers to run with the LAKEPARM.TBL file:

1. Update the variable names: 

LkMxH, LkMxE
WeirH,WeirE

2. Add a variable:
A new variable "ifd" should be added.  "ifd" represents the initial fractional depth of the lake water level. This is a ratio that represents the fullness of the lake. If ifd = 0.9 (default), the simulation begins with the lake 90% of capacity.

Requirements: NCO

Usage:
./convert_LAKEPARM_to_V5.sh LAKEPARM_old.nc LAKEPARM_new.nc
