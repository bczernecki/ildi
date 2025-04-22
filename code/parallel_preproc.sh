#!/bin/bash

# Directory containing the input files
input_dir="/home/pr_thpi/pr_thunder_scratch/cordex_download"

# Output directory
output_dir="/home/pr_thpi/pr_thunder_scratch/thunder_input"

# Create output directory if it doesn't exist
mkdir -p $output_dir

# Array to hold td, alt, ta, wd, and ws files for merging
td_files=()
alt_files=()
ta_files=()
wd_files=()
ws_files=()

# Function to process hus files
process_hus() {
    husfile=$1
    base_name=$(basename $husfile)
    level=$(echo $base_name | grep -oE 'hus[0-9]+' | grep -oE '[0-9]+')
    extracted_part=$(echo "$base_name" | sed -n 's/^.*\(.*EUR-11_.*\)/\1/p')
    e_file="${output_dir}/${base_name/hus${level}/e${level}}"
    td_file="${output_dir}/${base_name/hus${level}/td${level}}"
    
    cdo expr,"e_$level=hus$level*$level/(0.622+0.378*hus$level)" $husfile $e_file
    cdo expr,"td=(243.5*ln(e_$level/6.112))/(17.67-ln(e_$level/6.112))" $e_file $td_file
    rm $e_file

    # Add td file to the array for merging
    td_files+=("$td_file")
    echo "Processed $husfile to $td_file"
}

# Function to process zg files
process_zg() {
    zgfile=$1
    base_name=$(basename $zgfile)
    level=$(echo $base_name | grep -oE 'zg[0-9]+' | grep -oE '[0-9]+')
    extracted_part=$(echo "$base_name" | sed -n 's/^.*\(.*EUR-11_.*\)/\1/p')
    alt_file="${output_dir}/${base_name/zg${level}/alt${level}}"

    cdo chname,zg${level},alt $zgfile $alt_file
    alt_files+=("$alt_file")
    echo "Processed $zgfile to $alt_file"
}

# Function to process ta files
process_ta() {
    tafile=$1
    base_name=$(basename $tafile)
    level=$(echo $base_name | grep -oE 'ta[0-9]+' | grep -oE '[0-9]+')
    extracted_part=$(echo "$base_name" | sed -n 's/^.*\(.*EUR-11_.*\)/\1/p')
    ta_output_file="${output_dir}/${base_name/ta${level}/taC${level}}"

    cdo chname,ta${level},ta -subc,273.15 $tafile $ta_output_file
    ta_files+=("$ta_output_file")
    echo "Processed $tafile to $ta_output_file"
}

# Function to process va and ua files
process_va_ua() {
    va_file=$1
    base_name=$(basename $va_file)
    level=$(echo $base_name | grep -oE 'va[0-9]+' | grep -oE '[0-9]+')
    extracted_part=$(echo "$base_name" | sed -n 's/^.*\(.*EUR-11_.*\)/\1/p')
    ua_file="${input_dir}/${base_name/va/ua}"
    
    wd_file="${output_dir}/wd${level}_${extracted_part}"
    ws_file="${output_dir}/ws${level}_${extracted_part}"

    cdo expr,"wd=mod(270-atan2(va${level},ua${level})*(180/3.141592653589793)+360,360)" -merge $va_file $ua_file $wd_file
    cdo expr,"ws=sqrt(ua${level}*ua${level}+va${level}*va${level})*1.94384" -merge $va_file $ua_file $ws_file

    wd_files+=("$wd_file")
    ws_files+=("$ws_file")

    echo "Processed $va_file and $ua_file to $wd_file and $ws_file"
}

export -f process_hus
export -f process_zg
export -f process_ta
export -f process_va_ua

# Run processes in parallel using GNU parallel
find $input_dir -name "hus*.nc" | parallel process_hus
find $input_dir -name "zg*.nc" | parallel process_zg
find $input_dir -name "ta*.nc" | parallel process_ta
find $input_dir -name "va*.nc" | parallel process_va_ua

# Merging td files
merged_td_file="${output_dir}/td_all_${extracted_part}"
cdo -z zip merge ${td_files[@]} $merged_td_file
for td_file in ${td_files[@]}; do rm $td_file; done

# Merging alt files
merged_alt_file="${output_dir}/alt_all_${extracted_part}"
cdo -z zip merge ${alt_files[@]} $merged_alt_file
for alt_file in ${alt_files[@]}; do rm $alt_file; done

# Merging ta files
merged_ta_file="${output_dir}/ta_all_${extracted_part}"
cdo -z zip merge ${ta_files[@]} $merged_ta_file
for ta_file in ${ta_files[@]}; do rm $ta_file; done

# Merging wd and ws files
merged_wd_file="${output_dir}/wd_all_${extracted_part}"
merged_ws_file="${output_dir}/ws_all_${extracted_part}"
cdo -z zip merge ${wd_files[@]} $merged_wd_file
cdo -z zip merge ${ws_files[@]} $merged_ws_file

# Remove individual wd and ws files
for wd_file in ${wd_files[@]}; do rm $wd_file; done
for ws_file in ${ws_files[@]}; do rm $ws_file; done

# Split the merged files by date
cdo splitdate $merged_td_file "${output_dir}/td_split_"
cdo splitdate $merged_alt_file "${output_dir}/alt_split_"
cdo splitdate $merged_ta_file "${output_dir}/ta_split_"
cdo splitdate $merged_wd_file "${output_dir}/wd_split_"
cdo splitdate $merged_ws_file "${output_dir}/ws_split_"

# Remove the merged files after splitting
rm $merged_td_file
rm $merged_alt_file
rm $merged_ta_file
rm $merged_wd_file
rm $merged_ws_file

# Print a message indicating the split operations are completed
echo "Split all merged files by date and removed merged files!"
