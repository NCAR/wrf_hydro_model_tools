#!/bin/bash
############################################################################
# Bash shell script to create daily aggregates of WRF-Hydro LDASOUT files.
# Requirements: NCO (tested with version 5.1.4)
#               https://nco.sourceforge.net/
# Usage: Call shell script with two arguments specifying the 4-digit start
#        and end years to process
#        e.g., ./nco_process_ldasout_daily.sh 2009 2012
# Developed: 09/06/2024, A. Dugger
# Updated: 
############################################################################

############################################################################
# USER-SPECIFIED INPUTS:

# Specify WRF-Hydro output directory:
# (assumes files are organized by water year)
indir_base="/path/to/input/files/"
soilparm="/path/to/soil_properties_file.nc"

# Specify output directory where daily files should be written:
# (daily output files will be named land_YYYYMMDD.nc)
# (daily files concatenated by calendar year will be named land_YYYY_daily.nc)
outdir="/path/to/write/daily/output/files/"
outdir_yr="/path/to/write/daily/output/files/grouped/by/year/"

############################################################################

############################################################################
# MAIN CODE. Probably no need to update anything below here.
############################################################################

# Grab the start and end years to process
yrstart=$1
yrend=$2

# Initial setup.
shopt -s nullglob
uniqid=`uuidgen`
tmpfile=tmp${uniqid}.nc
smcfile=smcparams${uniqid}.nc

mkdir -p $outdir
mkdir -p $outdir_yr

# Process porosity and wilting point parameters for use in soilsat calculations.
# These parameters are currently uniform over depth layers.
rm ${smcfile}
ncks -A -v smcmax,smcwlt $soilparm ${smcfile}
ncrename -O -d south_north,y ${smcfile} ${smcfile}
ncrename -O -d west_east,x ${smcfile} ${smcfile}
ncrename -O -d Time,time ${smcfile} ${smcfile}
ncpdq -O -a time,y,soil_layers_stag,x ${smcfile} ${smcfile}

for yr in $(seq ${yrstart} 1 ${yrend}); do
  echo "Processing year ${yr}"
  YYYY=`printf %04d ${yr}`
  yrfiles=()

  for mo in $(seq 1 1 12); do
    echo "  Processing month ${mo}"
    MM=`printf %02d ${mo}`

    # Calculate water year for finding folder name.
    wy_yr=${yr}
    if [ "${mo}" -ge 10 ]; then
      wy_yr=`echo "${wy_yr} + 1" | bc`
    fi
    wy_yr_next=`echo "${wy_yr} + 1" | bc`

    # Setup input directory and output filename.
    indir="${indir_base}/WY${wy_yr}/"
    indir_next_wy="${indir_base}/WY${wy_yr_next}/"

    for dy in $(seq 1 1 31); do
      echo "    Processing day ${dy}"
      DD=`printf %02d ${dy}`

      start_time=`date -u +%s`
      outfile="${outdir}/land_${YYYY}${MM}${DD}.nc"
      rm $outfile

      # Processing flux sum
      # 200506150500.LDASIN_DOMAIN1.comp
      infiles=(${indir}/${YYYY}${MM}${DD}*.LDASOUT_DOMAIN1.comp)
      count=${#infiles[@]}
      echo "      Found $count files"
      if [ ${count} -gt 0 ]; then

        nextday=$(date -u +%Y%m%d -d "${YYYY}/${MM}/${DD} + 1 day")
        if [ "${MM}" = "09" -a "${DD}" = "30" ]; then
          # 10/1 03Z file has resets, 00Z is still accum from previous WY
          nextdayfile="${indir_next_wy}/${nextday}0000.LDASOUT_DOMAIN1.comp"
        else
          nextdayfile="${indir}/${nextday}0000.LDASOUT_DOMAIN1.comp"
        fi

        firstfile="${infiles[0]}"

        echo "      Processing sums and means"
        echo "      first $firstfile"
        echo "      last ${infiles[-1]}"
        echo "      nextday $nextdayfile"
        echo "      output $outfile"

        yrfiles+=("$outfile")
        infiles_list=`echo "${infiles[*]}"`

        # Create diffs
        # Reset happens on 10/01 00Z but this file gets replaced with previous WY.
        # So assume 10/02 00Z is first day's accumulation.
        if [ "${MM}" = "10" -a "${DD}" = "01" ]; then
          ncpdq --unpack ${nextdayfile} ${tmpfile}
        else
          ncdiff ${nextdayfile} ${firstfile} ${tmpfile}
        fi
        ncks -h -A -v ACCET ${tmpfile} ${outfile}
        rm -f ${tmpfile}
        ncrename -h -v ACCET,deltaACCET ${outfile}

        # Create averages
        ncra -O -y avg -v SOIL_M,SNEQV ${infiles_list} ${tmpfile}
        # Bring in porosity and wilting point and calculate soilsat
        # Note that porosity and wilting point are uniform with depth, so it doesn't matter what layer we use
        ncks -A -v smcmax ${smcfile} ${tmpfile}
        ncks -A -v smcwlt ${smcfile} ${tmpfile}
        # Calculate new wilting point adjusted variables requested by USGS
        ncap2 -O -F -s "avgSOILSAT_wltadj_top1=float((SOIL_M(:,:,1,:)-smcwlt(:,:,1,:))/(smcmax(:,:,1,:)-smcwlt(:,:,1,:)))" ${tmpfile} ${tmpfile}
        # Combine average file with delta file
        ncrename -h -v SNEQV,avgSNEQV ${tmpfile}
        ncks -h -A -v avgSNEQV,avgSOILSAT_wltadj_top1 ${tmpfile} ${outfile}
        rm ${tmpfile}

        # Update time dimension
        dayval=$(( (`date -u +%s -d "${YYYY}/${MM}/${DD}"` - `date -u +%s -d 1970-01-01`) / 86400)) 
        ncap2 -O -s "time[time]=$dayval" ${outfile} ${outfile}

        # Cleanup some attributes
        echo "Cleaning up attributes"
        ncatted -O -h -a valid_range,,d,, ${outfile} ${outfile}
        ncatted -O -h -a cell_methods,,d,, ${outfile} ${outfile}

        ncatted -O -h -a long_name,deltaACCET,o,c,"Change in accumulated evapotranspiration (day end minus day start)" ${outfile} ${outfile}
        ncatted -O -h -a long_name,avgSNEQV,o,c,"Average snow water equivalent over day" ${outfile} ${outfile}
        ncatted -O -h -a long_name,avgSOILSAT_wltadj_top1,o,c,"Average fractional soil saturation above wilting point (soil moisture minus wilting point divided by maximum water content minus wilting point) over top layer (top 10cm) over day" ${outfile} ${outfile}
        ncatted -O -h -a units,avgSOILSAT_wltadj_top1,o,c,"fraction (0-1)" ${outfile} ${outfile}

        ncatted -O -h -a units,time,o,c,"days since 1970-01-01 00:00:00 UTC" ${outfile} ${outfile}
        ncatted -O -h -a long_name,time,o,c,"valid output day" ${outfile} ${outfile}

        end_time=`date -u +%s`
        elapsed=`echo "$end_time - $start_time" | bc`
        echo "      Done with summing up hourly values : "${YYYY}"-"${MM}-${DD}"  "$elapsed" seconds since start time."
      else
        echo "      Missing files. Skipping month."
      fi

    done

  done

  # Create annual file
  yrfiles_list=`echo "${yrfiles[*]}"` 
  ncrcat -O $yrfiles_list ${outdir_yr}/land_${YYYY}_daily.nc

done

rm ${smcfile}

