#!/bin/bash

# Script to run ./run_exp.sh five times

for i in {1..3}
do
    echo "Running iteration $i..."
    ./run_exp.sh
    echo "Iteration $i completed."
done

echo "All iterations are completed."

