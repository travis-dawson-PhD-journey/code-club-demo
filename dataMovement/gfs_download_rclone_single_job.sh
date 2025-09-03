#!/bin/bash -login

# I recently adjusted the GFS download to use a single rclone job with multiple transfers/ checkers.
# This option is easier to use that the array jobs, and additionally the Setonix copy partion seems to be build for this.
# As opposed to the array job, but limiting the number of concurrent jobs.
# Below is the seff command of a month GFS download
# Job ID: 
# Cluster: setonix
# User/Group: 
# State: COMPLETED (exit code 0)
# Nodes: 1
# Cores per node: 32
# CPU Utilized: 00:08:21
# CPU Efficiency: 4.51% of 03:05:04 core-walltime
# Job Wall-clock time: 00:05:47
# Memory Utilized: 54.15 GB
# Memory Efficiency: 93.67% of 57.81 GB


#SBATCH --account=<projectID>
#SBATCH --partition=copy
#SBATCH --job-name=single-job-gfs-download
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=00:10:00

module load rclone/1.68.1

# -----------------------------
# Change this filter as needed
# FILTER='gfs.20210531/00/wave/gridded/*gfswave.t00z.global.0p25.f{0??,1??,2[0-3]?,240}.grib2'


# Examples:
# For July–December 2021 (months 07 to 12):
FILTER='gfs.2021{07}??/00/wave/gridded/*gfswave.t00z.global.0p25.f{0??,1??,2[0-3]?,240}.grib2'
#
# For May 2021 (month):
# FILTER='gfs.202105??/00/wave/gridded/*gfswave.t00z.global.0p25.f{0??,1??,2[0-3]?,240}.grib2'
#
# For all of 2021 (year):
# FILTER='gfs.2021????/00/wave/gridded/*gfswave.t00z.global.0p25.f{0??,1??,2[0-3]?,240}.grib2'
# -----------------------------

# Each srun command runs on a separate core/task
srun rclone copy  aws-public:noaa-gfs-bdp-pds/ \
  $MYSCRATCH/gfs_sample/ \
  --include "$FILTER" \
  --stats=15s \
  --transfers=16 \
  --checkers=8 \
  --progress
