#!/bin/bash

# Purpose: Download NLDAS2 forcing files
# Author: K. FitzGerald
# Date: March 2018    

# Instructions here: https://disc.gsfc.nasa.gov/information/howto?title=How%20to%20Download%20Data%20Files%20from%20HTTP%20Service%20with%20wget

wget --load-cookies ~/.urs_cookies --save-cookies ~/.urs_cookies --keep-session-cookies --no-check-certificate --auth-no-challenge=on -e robots=off -i filelist_NLDAS.txt

