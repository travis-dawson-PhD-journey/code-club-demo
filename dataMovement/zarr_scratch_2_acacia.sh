#!/bin/bash -login

#SBATCH --account=<AccountID>
#SBATCH --partition=debug
#SBATCH --job-name=zarr-scratch-2-acacia
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=00:05:00

module load rclone/1.68.1

rclone copy $MYSCRATCH/zarr_store/ acacia:tdawson-wavepop/gfs/ --checkers=8 --transfers=16 --progress
