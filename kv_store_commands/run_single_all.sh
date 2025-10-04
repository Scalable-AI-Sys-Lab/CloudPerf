#!/bin/bash
EXPORTS_FILE="../all_config.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        sudo kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi
    sudo pkill -f "log_memory_usage"
    sudo pkill -f "track_pid.sh"
    sudo pkill -f "pmem"
    sudo pkill -f "redis"
    sudo systemctl stop memcached.service

    # Exit the script
    exit 0
}


# pay attention to memcached, it may still be there, 
# Array of directories with commands to run `run_exp.sh`
folders=(
    "faster_uniform_ycsb_a"   
    "faster_uniform_ycsb_b"
    "faster_uniform_ycsb_c"
    "faster_uniform_ycsb_f"
    "faster_ycsb_a"
    "faster_ycsb_b"
    "faster_ycsb_c"
    "faster_ycsb_f"
    "redis_ycsb_a"
    "redis_ycsb_b"
    "redis_ycsb_c"
    "redis_ycsb_d"
    "redis_ycsb_e"
    "redis_ycsb_f"
    "redis_ycsb_uniform_a"
    # "memcached_ycsb_a"
    # "memcached_ycsb_b"
    # "memcached_ycsb_c"
    # "memcached_ycsb_d"
    # "memcached_ycsb_f"
    # "memcached_uniform_ycsb_a"
)



# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM


sudo bash -c "echo 'start:'"
# Loop through each folder and execute `run_exp.sh` or `prepare_exp.sh` followed by `run_exp.sh` for Memcached
for folder in "${folders[@]}"; do
    cd "$folder" || { echo "Failed to enter directory $folder"; exit 1; }
    # Change to the benchmark directory
    
    echo "clean previous log before this run"
 

    for run in {1..3}; do
        # Start tracking the workload
        echo "Running ${folder} (Run $run)"
        # Check if this is a memcached folder
        if [[ "$folder" == memcached* ]]; then
            pushd ../../general_commands > /dev/null
            ./track_pid.sh "memcached" &
            popd > /dev/null

            echo "Running prepare_exp.sh and run_exp.sh in $folder"
            sudo numactl --physcpubind=$WORKLOAD_CORE bash prepare_exp.sh  # Run prepare script first
        elif [[ "$folder" == redis* ]]; then  # Fix: Changed to `elif`
            pushd ../../general_commands > /dev/null
            ./track_pid.sh "redis" &
            popd > /dev/null

            echo "Running prepare_exp.sh and run_exp.sh in $folder"
            sudo numactl --physcpubind=$WORKLOAD_CORE bash prepare_exp.sh  # Run prepare script first
        else
            pushd ../../general_commands > /dev/null
            ./track_pid.sh "pmem" &
            popd > /dev/null
            echo "Running run_exp.sh in $folder"
        fi


        # Execute run_exp.sh for both memcached and non-memcached folders
        sudo numactl --physcpubind=$WORKLOAD_CORE bash run_exp.sh

        # Stop tracking the workload PIDs
        kill -SIGTERM $(cat /tmp/track_pid_script.pid)

    done

    # Go back to the parent directory
    cd ..

done

echo "All workloads executed."

# Run the workloads with llama interference
cleanup_and_exit

