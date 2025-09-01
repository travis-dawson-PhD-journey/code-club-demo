#!/bin/bash -login
#
# -----------------------------------------------------------------------------
# Script: gfs_download_multi_forecast.sh
# Purpose: Download 00Z NOAA GFS wave GRIB2 files (global 0.25°) for multiple
#          days—one date per Slurm array task—into $MYSCRATCH/gfs_sample/.
#
# What to set (before sbatch):
#   START_DATE   -> first calendar date to fetch (YYYY-MM-DD)
#   --array      -> number of days (task 0 = START_DATE; task N = START_DATE+N)
#                   examples:
#                     --array=0-0   (1 day)
#                     --array=0-9   (10 days)
#                     --array=0-29  (30 days)
#
# How to run:
#   sbatch --account=<accountID> --array=0-9 gfs_download_multi_forecast.sh
#
# Source / Destination:
#   SRC: aws-public:noaa-gfs-bdp-pds/         (rclone remote; configure in rclone.conf)
#   DST: $MYSCRATCH/gfs_sample/               (ensure exists/writable)
#
# Files selected (per task’s date, 00Z cycle):
#   gfs.YYYYMMDD/00/wave/gridded/*gfswave.t00z.global.0p25.f{0??,1??,2[0-3]?,240}.grib2
#   → Forecast hours: 0–240
#
# Optional:
#   DRY_RUN="1"    # preview transfers only
#   Add --progress to CMD for live progress in logs
# -----------------------------------------------------------------------------

#SBATCH --account=<accountID>
#SBATCH --partition=debug
#SBATCH --job-name=gfs-request-2021-04-21-to-2021-05-01-dry-run-0
#SBATCH --nodes=1
#SBATCH --ntasks=1          
#SBATCH --cpus-per-task=1   
#SBATCH --time=00:03:00      
#SBATCH --array=0-9      
#SBATCH --output=array-%j.out

# ---- Input specifications ----
START_DATE="2021-04-21"
SRC="aws-public:noaa-gfs-bdp-pds/"
DST="$MYSCRATCH/gfs_sample/"
DRY_RUN="0"

# Load tools
module load rclone/1.68.1

# Compute per-array date at runtime
TASK_DATE=$(date +%Y-%m-%d -d "$START_DATE + ${SLURM_ARRAY_TASK_ID} day")

# Calculate the stripped date (YYYYMMDD) for use in filer
STRIPPED_DATE=$(date -d "$TASK_DATE" +%Y%m%d)

# Per-day include filter (00Z global wave 0p25 f000..f240)
INCLUDE=( --include "gfs.${STRIPPED_DATE}/00/wave/gridded/*gfswave.t00z.global.0p25.f{0??,1??,2[0-3]?,240}.grib2" )

# Build rclone command: put flags before paths; expand arrays correctly
CMD=( rclone copy --stats=10s "${INCLUDE[@]}" "$SRC" "$DST" )
[[ "$DRY_RUN" == "1" ]] && CMD+=( --dry-run )

# Run
srun -N 1 -n 1 -c 1 "${CMD[@]}"
