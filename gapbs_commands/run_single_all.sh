#!/bin/bash
EXPORTS_FILE="../all_config.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

# Array of graph types and their corresponding search strings
graphs=("bc" "bfs" "cc" "pr")
# graphs=("bc")
# modes=("urand")
# modes=("web")
modes=("web" "urand")

# Path to track_pid.sh script
track_pid_script="../../general_commands/track_pid.sh"
cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        sudo kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi
    sudo pkill -f "log_memory_usage"
    sudo pkill -f "track_pid.sh"
    sudo pkill -f "urand"
    sudo pkill -f "web"

    # Exit the script
    exit 0
}

# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

# Loop through the graph types and modes to run scripts and track PIDs
for graph in "${graphs[@]}"; do
    for mode in "${modes[@]}"; do
        # Build the graph script name
        dir_name="${graph}-${mode}"
        cd $dir_name

        # Check if the script exists before executing it
        if [ -f "run_exp.sh" ]; then
            echo "Running in $dir_name..."

            # Run track_pid.sh with the graph name as the search string
            search_string="$mode"
            pushd ../../general_commands > /dev/null
            ./track_pid.sh "$search_string" &
            popd > /dev/null
            echo "workload core: $WORKLOAD_CORE"
            # Run the graph script sequentially
            sudo numactl --physcpubind=$WORKLOAD_CORE bash "./run_exp.sh"
            

            # Stop tracking after the graph script finishes
            kill -SIGTERM $(cat /tmp/track_pid_script.pid)
            echo "Finished $script_name, tracking stopped."
            sudo pkill -f "log_memory_usage"
        else
            echo "Script $script_name not found."
        fi
        cd ..
    done
done
