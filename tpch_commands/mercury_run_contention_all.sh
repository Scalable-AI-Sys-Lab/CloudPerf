#!/bin/bash
EXPORTS_FILE="../all_config.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

export VECTORDB_DIR=$(realpath ../vectordb)
export MERCURY_EXEC_DIR=$(realpath ../../Mercury_my/src/build)


# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Append new content to vector_contention_output.log instead of overwriting
    cat $VECTORDB_DIR/client_output.log >> vector_contention_output.log


    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        sudo kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi
    sudo pkill -f "log_memory_usage"
    sudo pkill -f "track_pid"
    sudo $VECTORDB_DIR/clean_server.sh
    # pkill -f "mercury"

    # Exit the script
    exit 0
}


# Signal handler for SIGUSR1
handle_sigusr1() {
    echo "Received signal from admission control. Continuing execution."
    signal_received=true
}

# Set the trap for SIGUSR1
trap 'handle_sigusr1' SIGUSR1
# export VECTORDB_DIR=/data/Mercury_workloads/vectordb


# Change ownership of the full directory and its contents
sudo chown -R $(whoami) $VECTORDB_DIR
# Loop through directories tpch_1 to tpch_22

sudo rm -f $VECTORDB_DIR/client_output.log
memory_threshold_GB=5

for i in {2..2}; do
  
  # Construct the directory name
  dir="tpch_$i"
  
  cd $dir
  # Check if the run_exp.sh script exists in the directory
  if [ -f "./run_exp.sh" ]; then

    # clean the server to in case each time the vector first takes all local, there is no waste
    sudo $VECTORDB_DIR/clean_server.sh
    echo "restart the vector server"
    echo "vectordb core is $VECTORDB_CORE"
    sudo rm -f "memory_numastat_log_postgre.csv"
    sudo rm -f "memory_numastat_log_postgre_pid_checker.csv"
    sudo rm -f "latency_log_postgre.csv"

    sudo rm -f "memory_numastat_log_vector.csv"
    sudo rm -f "memory_numastat_log_vector_pid_checker.csv"
    sudo rm -f "latency_log_vector.csv"

    # sudo numactl --physcpubind=$VECTORDB_CORE $VECTORDB_DIR/mer_vector_bw_all_cg2.sh 1

    for run in {1..2}; do
        signal_received=false  # Reset before each iteration
        # config_files=("$VECTORDB_DIR/profile_config.json" "profile_config.json")
        # config_files=("$VECTORDB_DIR/profile_config.json")
        # echo "current dir is $(pwd)"
        config_files=("$VECTORDB_DIR/profile_config.json" "profile_config_${memory_threshold_GB}G.json")
        # config_files=("profile_config_${memory_threshold_GB}G.json")
        # specify the workload memory limit
        

        $MERCURY_EXEC_DIR/mercury "${config_files[@]}" &

        echo "Waiting for admission control to complete..."
        while [ "$signal_received" != true ]; do
            sleep 1  # Poll every second until the signal is received
        done

        # two methods, one is let mercury execute the command,
        # another one is wait for the info, after get the info, launch one app.

        # Continue with the next commands
        echo "Admission control finished. Proceeding with the next steps..."


    #   # Kill any remaining postgres processes
      sudo pkill -f postgres
      sudo pkill -f vector
      sudo pkill -f track_pid
    done
  else
    echo "Script $dir/run_exp.sh not found."
  fi

  # goes back
  cd ..
  sudo bash -c "echo 'Finished $dir/run_exp.sh' >> $VECTORDB_DIR/client_output.log"
  # Stop any running PostgreSQL instances
  # pg_ctl -D /home/jhlu/pgdata10GB stop -m fast

  # Kill any remaining postgres processes
  sudo pkill -f postgres
done

echo "All scripts executed successfully."
# Stop PID tracking

cleanup_and_exit


