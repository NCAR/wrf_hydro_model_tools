#!/bin/bash

# Purpose: Download NLDAS2 forcing files
# Author: K. FitzGerald
# Date: June 2018    

# Instructions here: https://disc.gsfc.nasa.gov/information/howto?title=How%20to%20Download%20Data%20Files%20from%20HTTP%20Service%20with%20wget

wget --load-cookies ~/.urs_cookies --save-cookies ~/.urs_cookies --keep-session-cookies -r -c -nH -nd -np -A '*20170101*grb' "https://hydro1.gesdisc.eosdis.nasa.gov/data/NLDAS/NLDAS_FORA0125_H.002/2017/"

