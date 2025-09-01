#!/bin/bash -login
#
# -----------------------------------------------------------------------------
# Script: grib_2_zarr_multi_array.sh
# Purpose: Convert multiple days of NOAA GFS GRIB2 forecasts to Zarr by running
#          one date per Slurm array task using process_date.py (with Dask).
#
# Requirements:
#   - GRIB2 inputs at: $MYSCRATCH/gfs_sample/
#   - Writable output root: $MYSCRATCH/zarr_store/
#   - requirements.txt present in the working directory
#
# How to run:
#   1) Set BASE_DATE below (YYYYMMDD). Task 0 will use this date.
#   2) Choose the number of days via --array:
#        --array=0-9    → 10 days  (BASE_DATE .. BASE_DATE+9)
#        --array=0-29   → 30 days  (BASE_DATE .. BASE_DATE+29)
#        --array=0-0    → 1 day    (BASE_DATE only)
#   3) Submit:
#        sbatch grib_2_zarr_multi_array.sh
#
# Notes:
#   - DATE is computed per task: DATE = BASE_DATE + SLURM_ARRAY_TASK_ID days.
#   - 2 CPUs per task are requested primarily to meet memory usage thresholds,
#     not for parallel speedup. Adjust walltime/partition as needed for dataset size.
# -----------------------------------------------------------------------------

#SBATCH --account=<projectID>
#SBATCH --partition=work
#SBATCH --job-name=multi-grib-2-zarr-work-April-p3
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:09:00
#SBATCH --array=0-9 

# -------------------------------
# Base date in YYYYMMDD format
# -------------------------------
BASE_DATE="20210421"

# Compute DATE = BASE_DATE + SLURM_ARRAY_TASK_ID days
DATE=$(date -d "${BASE_DATE} +${SLURM_ARRAY_TASK_ID} days" +%Y%m%d)

module load python/3.11.6 py-pip/23.1.2-py3.11.6
module load py-dask/2023.4.1
echo "Python and dask modules loaded"

pip install --user -r requirements.txt
echo "Pip packages installed"

srun python -u process_date.py \
  --date "$DATE" \
  --input-root "$MYSCRATCH/gfs_sample" \
  --output-root "$MYSCRATCH/zarr_store"
