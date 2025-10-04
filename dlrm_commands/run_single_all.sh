#!/bin/bash
EXPORTS_FILE="../all_config.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"


# Array of directories to search for run_exp.sh scripts
directories=("dlrm_rm1_high" "dlrm_rm1_low" "dlrm_rm1_med" "dlrm_rm2_1_high" "dlrm_rm2_1_low" "dlrm_rm2_1_med")
# directories=("dlrm_rm2_1_high")
# Loop through the directories to find and run run_exp.sh scripts
pushd ../general_commands > /dev/null
./track_pid.sh "dlrm" &
popd > /dev/null

for dir in "${directories[@]}"; do
    cd $dir
    script_path="./run_exp.sh"

    # Check if the run_exp.sh script exists before executing it
    if [ -f "$script_path" ]; then
        echo "Running $dir script..."
        
        # Run the run_exp.sh script 3 times
        # todo: change it back to 3
        for i in {1..3}; do
            echo "Execution $i for $script_path..."
            sudo numactl --physcpubind=$WORKLOAD_CORE ./run_exp.sh
            echo "Finished execution $i for $script_path."
        done

        echo "Completed all executions for $script_path."
    else
        echo "Script $script_path not found."
    fi
    cd ..
done

if [ -f /tmp/track_pid_script.pid ]; then
    kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    echo "track pid script is stopped"
fi
pkill -f "track_pid.sh"