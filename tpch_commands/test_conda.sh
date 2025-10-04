#!/bin/bash

# Source the Conda environment
source /data/anaconda3/etc/profile.d/conda.sh
conda activate /data/anaconda3/env39

# Print Python version to verify the Conda environment is active
echo "Checking Python version in Conda environment:"
python --version

# Get the full path to the Conda environment's Python
python_path=$(which python)
echo $python_path
# Test running a simple echo command with numactl
echo "Running a simple numactl command with the full path to Python:"
sudo numactl --physcpubind=49-52,105-108 $python_path --version

# Deactivate the Conda environment at the end
conda deactivate
