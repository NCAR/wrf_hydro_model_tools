#!/bin/bash
############################################################################
# Bash shell script to create monthly aggregates of WRF-Hydro GWOUT files.
# Requirements: NCO (tested with version 5.1.4)
#               https://nco.sourceforge.net/
# Usage: Call shell script with a single argument specifying the 4-digit
#        year to process
#        e.g., ./nco_process_gwout.sh 2009
# Developed: 06/11/2024, A. Dugger
# Updated: 
############################################################################

############################################################################
# USER-SPECIFIED INPUTS:

# Specify WRF-Hydro output directory:
# (assumes files are organized by water year)
indir_base="/path/to/input/files/"

# Specify output directory where monthly files should be written:
# (output files will be named gw_YYYYMM.nc)
outdir="/path/to/monthly/output/files/"

############################################################################

############################################################################
# MAIN CODE. Probably no need to update anything below here.
############################################################################

# Initial setup.
shopt -s nullglob
uniqid=`uuidgen`
tmpfile=tmp${uniqid}.nc

mkdir $outdir

# Get the year to process from the command line argument.
# This setup is useful for scripting loops by year.
yr=${1}
echo "Processing year ${yr}"
YYYY=`printf %04d ${yr}`

# Loop through months
for mo in $(seq 1 1 12); do
  echo "  Processing month ${mo}"
  MM=`printf %02d ${mo}`

  # Calculate water year for finding folder name.
  wy_yr=${yr}
  if [ "${mo}" -ge 10 ]; then
     wy_yr=`echo "${wy_yr} + 1" | bc`
  fi

  # Calculate next year and month for diff calculations
  next_yr=${yr}
  next_mo=`echo "${mo} + 1" | bc`
  if [ "${next_mo}" -eq 13 ]; then
     next_mo=1
     next_yr=`echo "${yr} + 1" | bc`
  fi

  # Calculate next water year
  next_wy_yr=${wy_yr}
  if [ "${mo}" -eq 9 ]; then
     next_wy_yr=`echo "${next_wy_yr} + 1" | bc`
  fi

  # Setup some print variables
  MM2=`printf %02d ${next_mo}`
  YYYY2=`printf %04d ${next_yr}`

  # Setup input directory and output filename.
  indir="${indir_base}/WY${wy_yr}/"
  indir_next="${indir_base}/WY${next_wy_yr}/"
  outfile="${outdir}/gw_${YYYY}${MM}.nc"
  rm $outfile

  # Grab the processing start time so we can track how long this takes.
  start_time=`date -u +%s`

  # Processing accumulated flux and state diffs
  firstfile=`echo ${indir}/${YYYY}${MM}010100.GWOUT_DOMAIN1.comp`
  lastfile=`echo ${indir_next}/${YYYY2}${MM2}010000.GWOUT_DOMAIN1.comp`

  echo "      $firstfile $lastfile"

  if [ -f "${firstfile}" -a -f "${lastfile}" ]; then
    echo "      Processing diffs"
    echo "        first $firstfile"
    echo "        last $lastfile"
    echo "        output $outfile"
    ncdiff $lastfile $firstfile $tmpfile
    ncks -h -A -v depth ${tmpfile} ${outfile}
    rm ${tmpfile}
    ncrename -h -v depth,deltaDepth ${outfile}

    # Compiling list of files
    # e.g., 200506150500.GWOUT_DOMAIN1.comp
    infiles=(${indir}/${YYYY}${MM}*.GWOUT_DOMAIN1.comp)
    infiles_list=`echo "${infiles[*]}"`
    count=${#infiles[@]}
    echo "      Processing sums and means"
    echo "        found $count files"
    echo "        first ${infiles[0]}"
    echo "        last ${infiles[-1]}"
    # Create totals and averages.
    echo "      Processing flow totals"
    ncea -h -y ttl -v inflow,outflow ${infiles_list} ${tmpfile}
    ncks -h -A -v inflow,outflow ${tmpfile} ${outfile}
    rm ${tmpfile}
    echo "      Processing depth average"
    #ncra -O -y avg -v depth ${infiles_list} tmpavg_gw.nc # does not work since no record dim
    ncea -h -y avg -v depth ${infiles_list} ${tmpfile}
    ncks -h -A -v depth ${tmpfile} ${outfile}
    rm ${tmpfile}
    ncap2 -O -s "inflow=float(inflow*3600)" ${outfile} ${outfile}
    ncap2 -O -s "outflow=float(outflow*3600)" ${outfile} ${outfile}
    ncrename -h -v inflow,totInflow ${outfile}
    ncrename -h -v outflow,totOutflow ${outfile}
    ncrename -h -v depth,avgDepth ${outfile}

    # Cleanup names and attributes.
    ncatted -O -h -a valid_range,,d,, ${outfile} ${outfile}
    ncatted -O -h -a cell_methods,,d,, ${outfile} ${outfile}
    ncatted -O -h -a long_name,totInflow,o,c,"Total inflow volume over momth" ${outfile} ${outfile}
    ncatted -O -h -a long_name,totOutflow,o,c,"Total outflow volume over momth" ${outfile} ${outfile}
    ncatted -O -h -a long_name,deltaDepth,o,c,"Change in baseflow bucket storage (month end minus month start)" ${outfile} ${outfile}
    ncatted -O -h -a long_name,avgDepth,o,c,"Average baseflow bucket storage over month" ${outfile} ${outfile}
    ncatted -O -h -a units,totInflow,m,c,"m^3" ${outfile}
    ncatted -O -h -a units,totOutflow,m,c,"m^3" ${outfile}
    ncatted -O -h -a units,deltaDepth,m,c,"mm" ${outfile}
    ncatted -O -h -a units,avgDepth,m,c,"mm" ${outfile}

    # Wrap up the month.
    end_time=`date -u +%s`
    elapsed=`echo "$end_time - $start_time" | bc`
    echo "      Done aggregating hourly values : "${YYYY}"-"${MM}"  "$elapsed" seconds since start time."

  else
    # We didn't find any files for this year+month.
    echo "      Missing files. Skipping month."

  fi

done

