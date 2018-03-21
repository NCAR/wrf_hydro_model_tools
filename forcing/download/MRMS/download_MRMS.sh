#!/bin/bash

# Purpose: Download recent MRMS gauge corrected QPE files
# Author: K. FitzGerald
# Date: March 2018  

# Usage: ./download_MRMS.sh 

wget -r -np -nd -A "*grib2.gz" http://mrms.ncep.noaa.gov/data/2D/GaugeCorr_QPE_01H/

for i in *gz
do
   gunzip $i
done
