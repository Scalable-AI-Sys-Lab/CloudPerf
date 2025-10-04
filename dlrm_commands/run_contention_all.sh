#!/bin/bash

# Define directories and paths
export VECTORDB_DIR=/data/Mercury_workloads/vectordb

# Function to clean the server
clean_server() {
  sudo $VECTORDB_DIR/clean_server.sh
}

# Change ownership of the full directory and its contents
sudo chown -R jhlu $VECTORDB_DIR

# Array of directories to search for run_exp.sh scripts
directories=("dlrm_rm1_high" "dlrm_rm1_low" "dlrm_rm1_med" "dlrm_rm2_1_high" "dlrm_rm2_1_low" "dlrm_rm2_1_med")


# Function to run DLRM workloads with VectorDB contention
run_dlrm_with_vector_contention() {
  for dir in "${directories[@]}"; do
    cd $dir
    script_path="./run_exp.sh"

    # Check if the run_exp.sh script exists before executing it
    if [ -f "$script_path" ]; then
      echo "Running $dir script..."
      
      for run in {1..3}; do
        # Clean the server before each run
        clean_server

        # Start the vector workload in the background (contention workload)
        echo "Restarting the Vector server (Run $run)..."
        sudo numactl --physcpubind=49-52,105-108 $VECTORDB_DIR/mer_vector_bw_all.sh 1

        # Run the DLRM experiment script with numactl for CPU binding
        echo "Execution $run for $dir $script_path..."
        sudo bash -c "echo 'Execution $run for $dir $script_path...' >> $VECTORDB_DIR/client_output.log"

        numactl --physcpubind=28-41,84-97 bash "$script_path"
        # echo "Finished execution $run for $script_path."

        # Stop the vector server after the DLRM workload finishes
        killall -9 mer_vector_bw_all.sh  # Ensure vector server is stopped
        echo "VectorDB server stopped after $dir script (Run $run)."
        echo "Finished $dir script (Run $run), Vector contention stopped." >> $VECTORDB_DIR/client_output.log
      
        
        # Stop tracking the DLRM workload PIDs
        if [ -f /tmp/track_pid_script.pid ]; then
          kill -SIGTERM $(cat /tmp/track_pid_script.pid)
        fi

      done

      echo "Completed all executions for $script_path."
    else
      echo "Script $script_path not found."
    fi

    # Return to the parent directory
    cd ..
  done
}

# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

cleanup_and_exit() {
  echo "Stopping all running processes..."

  # Stop vector workload
  clean_server

  pkill -f "dlrm"

  # Stop PID tracking
  if [ -f /tmp/track_pid_script.pid ]; then
    kill -SIGTERM $(cat /tmp/track_pid_script.pid)
  fi


  # Append new content to vector_contention_output.log instead of overwriting
  cat $VECTORDB_DIR/client_output.log >> vector_contention_output.log

  # Exit the script
  exit 0
}

# Main script execution
echo "Starting DLRM workloads with VectorDB contention..."
rm $VECTORDB_DIR/client_output.log

# Run the DLRM workloads with vector contention
run_dlrm_with_vector_contention
cleanup_and_exit

echo "All DLRM workloads executed with VectorDB contention."
