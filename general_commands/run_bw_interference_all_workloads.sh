#!/bin/bash
cd ..  # Initial move to the parent directory (optional, depending on starting location)

# Define the list of directories
dirs=("dlrm_commands" "gapbs_commands" "spark_commands" "spec_commands" "tpch_commands" "kv_store_commands")

# Loop through each directory
for dir in "${dirs[@]}"; do
    echo "Entering directory: $dir"
    cd "$dir" || exit  # Enter the directory, exit if it fails

    # Execute the script
    if [[ -f ./run_interference_all.sh ]]; then
        echo "Running script in $dir"
        ./run_interference_all.sh
    else
        echo "Script run_interference_all.sh not found in $dir"
    fi

    # Return to the original directory
    cd - || exit  # Go back to the previous directory, exit if it fails
    echo "Returned to original directory"
done
