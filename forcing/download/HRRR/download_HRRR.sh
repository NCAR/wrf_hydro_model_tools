#!/bin/bash

# Purpose: Download HRRR files for WRF-Hydro forcing
# Author: K. FitzGerald
# Date: March 2018 

# Usage: ./download_HRRR.sh <YYYYMMDD>

if [ "$#" -ne 1 ]; then
   echo "Incorrect number of arguments"
   exit
fi

date_str=$1

wget -r -np -nd -A "hrrr.t14z.wrfsubhf??.grib2" http://www.ftp.ncep.noaa.gov/data/nccf/com/hrrr/prod/hrrr.${date_str}/

