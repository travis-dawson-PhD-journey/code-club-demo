#!/bin/bash -login
#
# -----------------------------------------------------------------------------
# Script: gfs_download_single_forecast.sh
# Purpose: Download NOAA Global Forecast System (GFS) wave predictions for a single date, up to 10 days/ 240 hours horizon,
#          from the Public AWS bucket (https://aws.amazon.com/marketplace/pp/prodview-hok7o2o24ktfi#resources) to $MYSCRATCH within the Pawsey HPC environment.
# 
# What it does: 
# - Submits a short slurm job on the debug partion
# - Loads a specific rclone version (available on Setonix)
# - Uses srun to launch a single rclone copy command pulling a subset of files: gfs.20210507/00/wave/gridded/*gfswave.t00z.global.0p25.f{0??,1??,2[0-3]?,240}.grib2
# - Copies the files to: $MYSCRATCH/gfs_sample/
# 
# How to run (HPC)
#   sbatch gfs_download_single_forecast.sh
# 
# Outputs: Downloaded grib2 files under: $MYSCRATCH/gfs/sample/ 
# 
# File selection
# - Directory: gfs.20210507/00/wave/gridded/ (points to a specific forecast date and hour)
# - Files: *gfswave.t00z.global.0p25.fXXX.grib2 where XXX is:
#       - 0??  => 000–099
#       - 1??  => 100–199
#       - 2[0-3]? => 200–239
#       - 240  => exactly 240
#   This grabs hours 0–240 for the 00z cycle on 2021-05-07 at 0.25° resolution.
#
# Notes:
#   - The source “aws-public:noaa-gfs-bdp-pds/” is an rclone remote that must be
#     configured at `.config/rclone/rclone.conf`
#
# DRY_RUN toggle:
#   - Set DRY_RUN="1" to print planned transfers without copying.
#
# Single job analysis (run seff <jobID>):
# Job ID: 
# Array Job ID:
# Cluster: setonix
# User/Group: 
# State: COMPLETED (exit code 0)
# Nodes: 1
# Cores per node: 2
# CPU Utilized: 00:00:22
# CPU Efficiency: 19.64% of 00:01:52 core-walltime
# Job Wall-clock time: 00:00:56
# Memory Utilized: 1.73 GB
# Memory Efficiency: 47.85% of 3.61 GB
# Copy has around 3.6 MB per copy CPU 
# -----------------------------------------------------------------------------

#SBATCH --account=<accountID>
#SBATCH --partition=debug
#SBATCH --job-name=single-gfs-download-2-scratch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:03:00

module load rclone/1.68.1

# Each srun command runs on a separate core/task
srun -N 1 -n 1 -c 1  rclone copy  aws-public:noaa-gfs-bdp-pds/ \
  $MYSCRATCH/gfs_sample/ \
  --include 'gfs.20210507/00/wave/gridded/*gfswave.t00z.global.0p25.f{0??,1??,2[0-3]?,240}.grib2' \
  --progress &