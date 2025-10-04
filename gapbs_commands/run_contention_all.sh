#!/bin/bash

# Define directories and paths
export VECTORDB_DIR=/data/Mercury_workloads/vectordb

# Function to clean the server
clean_server() {
  sudo $VECTORDB_DIR/clean_server.sh
}

# Change ownership of the full directory and its contents
sudo chown -R jhlu $VECTORDB_DIR

# Array of graph types and their corresponding search strings
# graphs=("bc" "bfs" "cc" "pr")
# modes=("web" "urand")
graphs=("bc")
modes=("urand")

# Path to track_pid.sh script
track_pid_script="../general_commands/track_pid.sh"

# Function to run the graph and vector workload with contention (specifically for bc-urand)
run_graph_with_vector_contention() {
  for graph in "${graphs[@]}"; do
    for mode in "${modes[@]}"; do
      # Build the graph script name
      script_name="${graph}-${mode}.sh"

      search_string="$graph"
      bash "$track_pid_script" "$search_string" &  # Run the PID tracker in the background

      # Clean the server before each run
      clean_server

      # Start the vector workload in the background (contention workload)
      echo "Restarting the Vector server (Run $run)..."
      sudo numactl --physcpubind=46-55,102-111 $VECTORDB_DIR/mer_vector_bw_all.sh 1  # Run vector server
          
      # Check if the script exists before executing it
      if [ -f "$script_name" ]; then
        for run in {1..5}; do
          
          # Start tracking the graph workload PIDs
 
          echo "Running $script_name (Run $run)"
          sudo bash -c "echo 'Running $script_name (Run $run)' >> $VECTORDB_DIR/client_output.log"

          
          # Run the graph script with numactl for CPU binding
          sudo numactl --physcpubind=28-41,84-97 bash "./$script_name"

          # Stop the vector server after the graph workload finishes
          killall -9 mer_vector_bw_all.sh  # Ensure vector server is stopped

          
          echo "Finished $script_name (Run $run), Vector contention stopped."
          echo "Finished $script_name (Run $run), Vector contention stopped." >> $VECTORDB_DIR/client_output.log
      
          
          # Break if the graph is not "bc" and mode is not "urand"
          if [[ "$graph" != "bc" || "$mode" != "urand" ]]; then
            break
          fi

        done
        # Stop tracking the graph workload PIDs
        kill -SIGTERM $(cat /tmp/track_pid_script.pid)

      else
        echo "Script $script_name not found."
      fi
    done
  done
}

# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Stop vector workload
    clean_server

    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi

    mv $VECTORDB_DIR/client_output.log vector_contention_output.log

    # Exit the script
    exit 0
}


# Main script execution
echo "Starting Graph workloads with Vector contention..."
rm $VECTORDB_DIR/client_output.log

# Run the graph workloads with vector contention
run_graph_with_vector_contention
cleanup_and_exit

echo "All graph workloads executed with Vector contention."
