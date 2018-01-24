README_create_SoilProperties.txt

Purpose: create_SoilProperties.R is an R script developed for the purpose of creating spatially distributed soil and vegetation
         parameter files for WRF-Hydro based upon the tables provided for NoahMP and WRF-Hydro.  

Authors: NCAR WRF-Hydro team

Date: December 2017

Requirements: R, NCO, and the ncdf4 R package 

Instructions (users need to complete the following prior to running the script): 

1. Update script to point to input geogrid file
2. Update script to point to the required parameter tables or copy these over to the current directory (Note: these are
   distributed with the WRF-Hydro code and are located in the template/HYDRO and template/NoahMP directories)
3. Update script to specify the desired names of the output files
4. Update script to specify the desired soil category value to be used in case of conflicts between
   soil water and land cover water cells (Note: this is the soilFillVal variable)
5. Decide whether or not to show hard-coded urban soil parameters

Usage: Rscript create_SoilProperties.R
