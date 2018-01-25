#!/bin/sh
# Script to convert grib files to netcdf using 'ncl_convert2nc'
# Usage: ./grib2nc.sh
# Developed: 1/31/2007, D. Gochis

homedir="/scratch/WEEKLY/gochis/Fourmile_forcing_prep/data_acquisition/"
gribdir="./"
netcdfdir="./"


#cd $gribdir

ls -1 *.grb > filelist.txt
#ls -1 *.GRB  > filelist.txt

for i in `cat filelist.txt`
do
  echo $i
  ncl_convert2nc $i
done

mv *.nc $netcdfdir

#cd $homedir
