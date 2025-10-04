#!/bin/bash

# Script to run ./run_exp.sh five times
export FASTER_DIR=/data/Mercury_workloads/FASTER/cc/build/Release
export RESULT_DIR=/data/Mercury_workloads/results/kv_store/FASTER_UNIFORM_A


for i in {1..5}
do
    echo "Running iteration $i..."
    ./run_exp_native.sh
    echo "Iteration $i completed."
    echo "Iteration $i completed." >> $RESULT_DIR/result_app_perf.txt
done

echo "All iterations are completed."

