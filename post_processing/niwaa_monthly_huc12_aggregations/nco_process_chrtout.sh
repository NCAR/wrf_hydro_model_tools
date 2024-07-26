#!/bin/bash
############################################################################
# Bash shell script to create monthly aggregates of WRF-Hydro CHRTOUT files.
# Requirements: NCO (tested with version 5.1.4)
#               https://nco.sourceforge.net/
# Usage: Call shell script with a single argument specifying the 4-digit
#        year to process
#        e.g., ./nco_process_chrtout.sh 2009
# Developed: 06/11/2024, A. Dugger
# Updated: 
############################################################################

############################################################################
# USER-SPECIFIED INPUTS:

# Specify WRF-Hydro output directory:
# (assumes files are organized by water year)
indir_base="/path/to/input/files/"

# Specify output directory where monthly files should be written:
# (output files will be named chrt_YYYYMM.nc)
outdir="/path/to/monthly/output/files/"

############################################################################

############################################################################
# MAIN CODE. Probably no need to update anything below here.
############################################################################

# Initial setup.
shopt -s nullglob
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

  # Setup input directory and output filename.
  indir="${indir_base}/WY${wy_yr}/"
  outfile="${outdir}/chrt_${YYYY}${MM}.nc"

  # Grab the processing start time so we can track how long this takes.
  start_time=`date -u +%s`

  # Compiling list of files
  # e.g., 200506150500.CHRTOUT_DOMAIN1.comp
  infiles=(${indir}/${YYYY}${MM}*.CHRTOUT_DOMAIN1.comp)
  count=${#infiles[@]}
  echo "      Found $count files"

  # Check if we found files. Otherwise skip.
  if [ ${count} -gt 0 ]; then
    echo "      Processing sums and means"
    echo "      first ${infiles[0]}"
    echo "      last ${infiles[-1]}"
    echo "      output $outfile"

    infiles_list=`echo "${infiles[*]}"`

    # Create totals and averages.
    ncea -h -y ttl -v streamflow,qSfcLatRunoff,qBucket ${infiles_list} ${outfile}
    ncap2 -O -s "streamflow=float(streamflow*3600)" ${outfile} ${outfile}
    ncap2 -O -s "qSfcLatRunoff=float(qSfcLatRunoff*3600)" ${outfile} ${outfile}
    ncap2 -O -s "qBucket=float(qBucket*3600)" ${outfile} ${outfile}
    ncrename -h -v streamflow,totStreamflow ${outfile}
    ncrename -h -v qSfcLatRunoff,totqSfcLatRunoff ${outfile}
    ncrename -h -v qBucket,totqBucket ${outfile}

    # Cleanup names and attributes.
    ncatted -O -h -a valid_range,,d,, ${outfile} ${outfile}
    ncatted -O -h -a cell_methods,,d,, ${outfile} ${outfile}
    ncatted -O -h -a long_name,totStreamflow,m,c,"Total streamflow volume over momth" ${outfile} ${outfile}
    ncatted -O -h -a long_name,totqSfcLatRunoff,m,c,"Total surface flow volume over momth" ${outfile} ${outfile}
    ncatted -O -h -a long_name,totqBucket,m,c,"Total baseflow volume over month" ${outfile} ${outfile}
    ncatted -O -h -a units,totStreamflow,m,c,"m^3" ${outfile}
    ncatted -O -h -a units,totqSfcLatRunoff,m,c,"m^3" ${outfile}
    ncatted -O -h -a units,totqBucket,m,c,"m^3" ${outfile}

    # Wrap up the month.
    end_time=`date -u +%s`
    elapsed=`echo "$end_time - $start_time" | bc`
    echo "      Done aggregating hourly values : "${YYYY}"-"${MM}"  "$elapsed" seconds since start time."

  else
    # We didn't find any files for this year+month.
    echo "      Missing files. Skipping month."

  fi

done

