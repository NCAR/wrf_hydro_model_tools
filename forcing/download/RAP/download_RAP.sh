#!/bin/bash

# Purpose: Download RAP files for WRF-Hydro forcing
# Author: K. FitzGerald
# Date: March 2018

# Usage: ./download_RAP.sh <YYYYMMDD>

if [ "$#" -ne 1 ]; then
   echo "Incorrect number of arguments"
   exit
fi

date_str=$1

wget -r -np -nd -A "rap.t14z.awp130bgrbf??.grib2" http://www.ftp.ncep.noaa.gov/data/nccf/com/rap/prod/rap.${date_str}/

