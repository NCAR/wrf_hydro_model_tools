#!/bin/bash

# Purpose:  Download GFS files for WRF-Hydro forcing
# Author:   K. FitzGerald
# Date:     March 2018
# Updated:  August 2019

# Usage: ./download_GFS.sh <YYYYMMDD>

if [ "$#" -ne 1 ]; then
   echo "Incorrect number of arguments"
   exit
fi

datetime_str=$1

for i in $(seq -f "%02g" 1 10)
do
  wget http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.${datetime_str}/00/gfs.t00z.pgrb2.0p25.f0${i}
done
