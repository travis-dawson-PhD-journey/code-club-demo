#!/bin/bash -login
#
# -----------------------------------------------------------------------------
# Script: grib_2_zarr_single.sh
# Purpose: Convert NOAA GFS GRIB2 forecast files (previously downloaded) into
#          Zarr format using a Python processing script.
#          Runs on Pawsey’s HPC (Setonix) within a Slurm job.
#
# Workflow:
#   1. Load required Python and Dask modules from the environment
#   2. Install any additional Python packages from requirements.txt (same directory)
#   3. Run `process_date.py` for a specified forecast date, converting GRIB2
#      data in $MYSCRATCH/gfs_sample into Zarr outputs in $MYSCRATCH/zarr_store
#
# Example:
#   sbatch grib_2_zarr_single.sh
#
# Inputs:
#   - GRIB2 forecast files already stored under: $MYSCRATCH/gfs_sample/
#   - Python requirements file: requirements.txt (in working directory)
#
# Outputs:
#   - Zarr store directory under: $MYSCRATCH/zarr_store/
#     containing data for the given forecast date
#
# Notes:
#   - Job requests 2 CPUs per task: increasing memory allocated for memory intensive task
#   - Walltime is set to 9 minutes (I/O intensive operation)
#   - `pip install --user` ensures packages go to ~/.local without needing root
#   - `-u` flag in Python ensures stdout/stderr are unbuffered (live logs)
#
# Single job analysis (run seff <jobID>):
# Job ID:  ...
# Array Job ID:  ...
# Cluster: setonix
# User/Group:  ...
# State: COMPLETED (exit code 0)
# Nodes: 1
# Cores per node: 4
# CPU Utilized: 00:06:25
# CPU Efficiency: 24.37% of 00:26:20 core-walltime
# Job Wall-clock time: 00:06:35
# Memory Utilized: 2.94 GB
# Memory Efficiency: 81.79% of 3.59 GB
# Nearing the threshold of Memory allocated 
# Work has around 1.79 GB per cpu
# -----------------------------------------------------------------------------

#SBATCH --account=<projectID>
#SBATCH --partition=work
#SBATCH --job-name=single-grib-2-zarr-incr-mem
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:09:00

# Load required modules
module load python/3.11.6 py-pip/23.1.2-py3.11.6
module load py-dask/2023.4.1
echo "Python and dask modules loaded"

# Install additional Python dependencies (user local install)
pip install --user -r requirements.txt
echo "Pip packages installed"

# Run the Python processing script:
srun python -u process_date.py \
  --date 20210414 \
  --input-root "$MYSCRATCH/gfs_sample" \
  --output-root "$MYSCRATCH/zarr_store"
