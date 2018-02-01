README_create_WRFinput.txt

Purpose: create_Wrfinput.R is an R script developed for the purpose of creating wrfinput files for the WRF-Hydro model.
         This allows users to avoid running the WRF Pre-processing system (WPS) provided they already have a geogrid file 
         for their model domain.  

Authors: NCAR WRF-Hydro team

Date: December 2017

Requirements: R, NCO, the ncdf4 R package, geogrid file 

Output: wrfinput.nc

Instructions (users need to complete the following prior to running the script): 

1. Update script to point to input geogrid file
2. Update script to specify the desired name of the output wrfinput file
3. Update script to specify the desired soil category value to be used in case of conflicts between
   soil water and land cover water cells
4. Update script to specify the desired month to use for leaf area index (LAI) initialization
   (needed for some NoahMP configurations)

Usage: Rscript create_Wrfinput.R
