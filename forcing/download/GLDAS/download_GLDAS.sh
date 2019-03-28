#!/bin/bash

# Purpose: Download GLDAS v2.1 files
# Author: K. FitzGerald
# Date: March 2019    

# Instructions here: https://disc.gsfc.nasa.gov/information/howto?title=How%20to%20Download%20Data%20Files%20from%20HTTP%20Service%20with%20wget

wget --load-cookies ~/.urs_cookies --save-cookies ~/.urs_cookies --keep-session-cookies -r -c -nH -nd -np -A 'GLDAS*nc4' "https://hydro1.gesdisc.eosdis.nasa.gov/data/GLDAS/GLDAS_NOAH025_3H.2.1/2000/001/"

