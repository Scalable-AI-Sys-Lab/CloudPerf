#!/bin/bash

# Define directories and paths
export VECTORDB_DIR=/data/Mercury_workloads/vectordb

# Function to clean the server
clean_server() {
  sudo $VECTORDB_DIR/clean_server.sh
}

# pay attention to memcached, it may still be there, 
# Array of directories with commands to run `run_exp.sh`
folders=(
    # "faster_uniform_ycsb_a"
    # "faster_uniform_ycsb_b"
    # "faster_uniform_ycsb_c"
    # "faster_uniform_ycsb_f"
    # "faster_ycsb_a"
    # "faster_ycsb_b"
    # "faster_ycsb_c"
    # "faster_ycsb_f"
    # "redis_ycsb_a"
    # "redis_ycsb_b"
    # "redis_ycsb_c"
    # "redis_ycsb_d"
    # "redis_ycsb_e"
    # "redis_ycsb_f"
    # "redis_ycsb_uniform_a"
    "memcached_ycsb_a"
    # "memcached_ycsb_b"
    # "memcached_ycsb_c"
    # "memcached_ycsb_d"
    # "memcached_ycsb_f"
    # "memcached_uniform_ycsb_a"

)

# Path to track_pid.sh script, since it will enter into each folder to do this
track_pid_script="../../general_commands/track_pid.sh"

# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi

    # Stop vector workload
    clean_server

    pkill -f "pmem"

    # Append new content to vector_contention_output.log instead of overwriting
    cat $VECTORDB_DIR/client_output.log >> vector_contention_output.log


    # Exit the script
    exit 0
}

sudo rm $VECTORDB_DIR/client_output.log

sudo bash -c "echo 'start:'"
# Loop through each folder and execute `run_exp.sh` or `prepare_exp.sh` followed by `run_exp.sh` for Memcached
for folder in "${folders[@]}"; do
    cd "$folder" || { echo "Failed to enter directory $folder"; exit 1; }

    for run in {1..2}; do
        # Clean the server before each run
        clean_server

        # Start the vector workload in the background (contention workload)
        echo "Restarting the Vector server (Run $run)..."
        sudo numactl --physcpubind=46-55,102-111 $VECTORDB_DIR/mer_vector_bw_all.sh 1

        # Capture the PID of the vector server to ensure it can be stopped later
        vector_pid=$!
        # Start tracking the workload
        echo "Running ${folder} (Run $run)"
        sudo bash -c "echo 'Running ${folder} (Run $run)' >> $VECTORDB_DIR/client_output.log"

        # Check if this is a memcached folder
        if [[ "$folder" == memcached* ]]; then
            bash "$track_pid_script" "memcached" &  # Run the PID tracker in the background
            echo "Running prepare_exp.sh and run_exp.sh in $folder"
            numactl --physcpubind=28-34,84-90 bash prepare_exp.sh  # Run prepare script first
        elif [[ "$folder" == redis* ]]; then  # Fix: Changed to `elif`
            while [ ! -z "$(pgrep -nf redis)" ]; do
                sudo kill $(pgrep -fn redis)
                sleep 1
            done

            bash "$track_pid_script" "redis" &  # Run the PID tracker in the background
            echo "Running prepare_exp.sh and run_exp.sh in $folder"
            numactl --physcpubind=28-34,84-90 bash prepare_exp.sh  # Run prepare script first
        else
            echo "Running run_exp.sh in $folder"
        fi


        # Execute run_exp.sh for both memcached and non-memcached folders
        numactl --physcpubind=28-34,84-90 bash run_exp.sh

        # Stop tracking the workload PIDs
        kill -SIGTERM $(cat /tmp/track_pid_script.pid)

        echo "Finished ${folder} (Run $run), Vector contention stopped."
        echo "Finished ${folder} (Run $run), Vector contention stopped." >> $VECTORDB_DIR/client_output.log
          
    done

    # Go back to the parent directory
    cd ..

done

echo "All workloads executed with Vector contention."

# Run the workloads with vector contention
cleanup_and_exit

