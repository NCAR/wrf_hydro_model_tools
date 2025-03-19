#!/bin/bash

# Set the start and end dates
start_date="2020-01-01"  # Modify this to your desired start date (YYYY-MM-DD)
end_date="2020-12-31"    # Modify this to your desired end date (YYYY-MM-DD)

# Specify the output directory where the files will be saved
output_dir="/public/home/Shihuaixuan/Data/GLDAS2WRF-Hydro/2020"  # Modify this to your desired output directory
mkdir -p $output_dir

echo "###################################### All Start ##########################################"
gladas_files="./GLDAS_NOAH025_3H.2.1"

# Create working directories
mkdir -p temp_work
rm -rf ./temp_work/*  # Ensure the temp_work directory is empty

# Iterate through the specified date range
current_date="$start_date"
while [[ "$current_date" < "$end_date" ]] || [[ "$current_date" == "$end_date" ]]; do
    # Extract year, month, and day
    year=$(date -d "$current_date" +"%Y")
    month=$(date -d "$current_date" +"%m")
    day=$(date -d "$current_date" +"%d")
    
    echo "######################### Processing Date: $current_date ############################"

    # Calculate the next date
    next_date=$(date -d "$current_date +1 day" +"%Y%m%d")

    # Format the current date
    current_date_str=$(date -d "$current_date" +"%Y%m%d")
    
    echo "Start Merging Files for ${current_date}..."
    cdo mergetime ${gladas_files}/${year}/GLDAS_NOAH025_3H.A${current_date_str}.*.021.nc4 \
                  ${gladas_files}/${year}/GLDAS_NOAH025_3H.A${next_date}.0000.021.nc4 \
                  ./temp_work/merged_3h_${current_date_str}.nc4
    if [[ $? -ne 0 ]]; then
        echo "Error: Merging failed for ${current_date}. Skipping..."
        current_date=$(date -d "$current_date +1 day" +"%Y-%m-%d")
        continue
    fi
    echo "Merging Completed"

    echo "Selecting Required Variables for ${current_date}..."
    cdo selname,Psurf_f_inst,Tair_f_inst,Wind_f_inst,Qair_f_inst,Rainf_f_tavg,SWdown_f_tavg,LWdown_f_tavg \
        ./temp_work/merged_3h_${current_date_str}.nc4 ./temp_work/filtered_3h_${current_date_str}.nc4
    if [[ $? -ne 0 ]]; then
        echo "Error: Variable selection failed for ${current_date}. Skipping..."
        current_date=$(date -d "$current_date +1 day" +"%Y-%m-%d")
        continue
    fi
    echo "Variable Selection Completed"

    # Use the filtered file for interpolation
    echo "Start Interpolating for ${current_date}..."
    cdo inttime,${current_date},00:00:00,1hour ./temp_work/filtered_3h_${current_date_str}.nc4 \
                                               ./temp_work/interp_1h_${current_date_str}.nc4
    if [[ $? -ne 0 ]]; then
        echo "Error: Interpolation failed for ${current_date}. Skipping..."
        current_date=$(date -d "$current_date +1 day" +"%Y-%m-%d")
        continue
    fi
    echo "Interpolation Completed"

    echo "Start Splitting Time Steps for ${current_date}..."
    time_steps=$(cdo showtimestamp ./temp_work/interp_1h_${current_date_str}.nc4 | tr ' ' '\n')
    for time_step in $time_steps; do
	
		echo "Processing time step: $time_step"
        # Generate the output filename
        date_str=$(date -d "$time_step" +"%Y%m%d.%H00")
        output_file="${output_dir}/GLDAS_NOAH025_3H.A${date_str}.021.nc4"
        
        cdo seldate,$time_step ./temp_work/interp_1h_${current_date_str}.nc4 ${output_file}
        if [[ $? -ne 0 ]]; then
            echo "Error: Splitting failed for timestamp ${time_step}. Skipping..."
            continue
        fi

        # Apply final NetCDF4 compression (Level 3) for NCL compatibility
        ncks -4 -L 3 ${output_file} ${output_file}.tmp && mv ${output_file}.tmp ${output_file}
    done
    echo "Splitting Completed"

    # Clean up temporary files
    echo "Cleaning up temporary files for ${current_date}..."
    rm -rf ./temp_work/*
    echo "Cleanup Completed"

    # Move to the next date
    current_date=$(date -d "$current_date +1 day" +"%Y-%m-%d")
    echo "######################### ${current_date} Processing Completed #########################"
done

# Final cleanup of temporary directory
rm -rf temp_work
echo "All processes finished, temporary files cleaned up."
echo "###################################### All Finished ########################################"
