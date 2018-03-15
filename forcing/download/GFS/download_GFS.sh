#!/bin/bash

# Purpose: Download GFS files for WRF-Hydro forcing
# Author: K. FitzGerald
# Date: March 2018

# Usage: ./download_GFS.sh <YYYYMMDDHH>

if [ "$#" -ne 1 ]; then
   echo "Incorrect number of arguments"
   exit
fi

datetime_str=$1

wget -r -np -nd -A "gfs.t00z.pgrb2.0p25.f00?" http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.${datetime_str}/

