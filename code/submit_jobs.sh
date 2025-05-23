#!/bin/bash
#SBATCH --job-name=thunder       # Job name
#SBATCH --output=logs/thunder_%A_%a.out  # Standard output and error log
#SBATCH --mem=4G
#SBATCH -n 1
#SBATCH -N 1
#SBATCH -t 0-24:0:0
##SBATCH --array=1-20%5
#SBATCH --array=1-1%1

# Load necessary modules (if any)
#module load cray-hdf5 cray-netcdf cray-R PrgEnv-gnu micromamba
#eval "$(micromamba shell hook --shell bash)"
#micromamba activate cdo_env

ml r
#download="/home/pr_thpi/pr_thunder_scratch/lists/experiments_evaluation_1981-2010.txt"
download="/mnt/storage_3/home/barcze/pl0401-01/project_data/ildi/code/experiments_evaluation_1981-2010.txt"
#ddir="/home/pr_thpi/pr_thunder_scratch/cordex_download"
ddir="/mnt/storage_3/home/barcze/pl0401-01/scratch/cordex_download"

for year in $(seq 1981 1981); do
    awk -F'[/_]' -v start_year=$year '{
        split($NF, dates, "-");
        start_year_file = substr(dates[1], 1, 4);
        end_year_file = substr(dates[2], 1, 4);
        if (start_year_file == start_year) {
            print $0;
        }
    }' "$download" > download_$year.txt

cat download_$year.txt | xargs -n 1 -P 5 -I {} wget -P "$ddir" {} # I think 5 parallel processes is enough
#parallel -j $(wc -l < download_$year.txt) -a download_$year.txt wget -c -P "$ddir" {}

#bash parallel_preproc.sh

#shopt -s nullglob
#nc_files=("$ddir"/*.nc)
#if (( ${#nc_files[@]} )); then
#    rm "${nc_files[@]}"
#    echo "Removed ${#nc_files[@]} .nc files from $ddir"
#else
#    echo "No .nc files found in $ddir"
#fi

#parallel -j $SLURM_CPUS_PER_TASK Rscript thunder.R {} ::: /home/pr_thpi/pr_thunder_scratch/thunder_input/alt_split_*.nc

#mkdir -p /home/pr_thpi/pr_thunder_scratch/pr_thunder/thunder_output
#mv thunder_output/params_split_*.nc /home/pr_thpi/pr_thunder_scratch/pr_thunder/thunder_output/
done
