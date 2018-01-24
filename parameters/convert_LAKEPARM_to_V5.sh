#!/bin/bash
inFile=$1
outFile=$2

ncap2 -s 'ifd[$nlakes]=0.9' ${inFile} tmp.nc
ncatted -O -a long_name,ifd,c,c,Initial_Fractional_Depth tmp.nc 
ncrename -O -v LkMxH,LkMxE tmp.nc 
ncrename -O -v WeirH,WeirE tmp.nc 
ncatted -O -a units,ifd,c,c,ratio tmp.nc 
ncks -O -x -v alt tmp.nc tmp2.nc 
ncks -O -x -v Discharge tmp2.nc ${outFile} 
rm tmp2.nc tmp.nc
