#!/bin/bash

# Purpose:  Download CMORPH files for WRF-Hydro forcing
# Author:   K. FitzGerald
# Date:     August 2019

# Usage: ./download_CMORPH.sh <YYYY> <MM>

if [ "$#" -ne 2 ]; then
   echo "Incorrect number of arguments"
   exit
fi

YEAR=$1
MONTH=$2

wget ftp://ftp.cpc.ncep.noaa.gov/precip/CMORPH_V1.0/CRT/8km-30min/${YEAR}/CMORPH_V1.0_ADJ_8km-30min_${YEAR}${MONTH}.tar
