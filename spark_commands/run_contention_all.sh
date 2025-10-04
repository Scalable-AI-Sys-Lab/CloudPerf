#!/bin/bash



# Array of directories with commands to run `run_exp.sh`
folders=(
    "spark_als"
    "spark_gbt"
    "spark_sort"
    "spark_wordcount"
    "spark_pca"
    "spark_rf"
    "spark_terasort"
    "spark_linear"

)
# Define directories and paths
export VECTORDB_DIR=/data/Mercury_workloads/vectordb

# Path to track_pid.sh script, since it will enter into each folder to do this
# update_mem_limit_dir="../../general_commands/update_mem_limit"

# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

clean_server() {
  sudo $VECTORDB_DIR/clean_server.sh
}

cleanup_and_exit() {
    echo "Stopping all running processes..."

    clean_server

    # Check if the client_output.log exists before trying to append it
    if [ -f "$VECTORDB_DIR/client_output.log" ]; then
        echo "Appending client_output.log to vector_contention_output.log"
        cat "$VECTORDB_DIR/client_output.log" >> vector_contention_output.log
    else
        echo "client_output.log not found, skipping append."
    fi


    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi

    # Exit the script
    exit 0
}


# Loop through each folder and execute `run_exp.sh` or `prepare_exp.sh` followed by `run_exp.sh` for Memcached
# Remove old client_output.log
sudo rm -f "$VECTORDB_DIR/client_output.log"

for run in {1..3}; do
    for folder in "${folders[@]}"; do
        cd "$folder" || { echo "Failed to enter directory $folder"; exit 1; }

        # Clean the server before each run
        clean_server

        # Start the vector workload in the background (contention workload)
        echo "Restarting the Vector server (Run $run)..."
        sudo numactl --physcpubind=46-55,102-111 $VECTORDB_DIR/mer_vector_bw_all.sh 1


        echo "Running prepare_exp.sh and run_exp.sh in $folder"
        numactl --physcpubind=28-34,84-90 bash prepare_exp.sh  # Run prepare script first

        # Start tracking the workload
        echo "Running ${folder} (Run $run)"
        sudo bash -c "echo 'Running ${folder} (Run $run)' >> $VECTORDB_DIR/client_output.log"

        # Execute run_exp.sh for both memcached and non-memcached folders
        numactl --physcpubind=28-34,84-90 bash run_exp.sh

        # Stop tracking the graph workload PIDs
        sudo kill -SIGTERM $(cat /tmp/track_pid_script.pid)

        # stopped tracking the workload
        echo "Stopped ${folder} (Run $run)"
        sudo bash -c "echo 'Stopped ${folder} (Run $run)' >> $VECTORDB_DIR/client_output.log"

        #Clean the server after each run
        clean_server


        # Go back to the parent directory
        cd ..

    done
done

echo "All workloads executed with Vector contention."

cleanup_and_exit