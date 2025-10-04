#!/bin/bash
EXPORTS_FILE="./paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"


check_llama_running() {
    pgrep -f llama > /dev/null
    return $?  # Returns 0 if the process is found, non-zero otherwise
}


clean_llama(){
  while check_llama_running; do
    echo "llama.cpp is still running. Attempting to kill it..."
    sudo pkill -f llama
    sudo pkill -f llama
    sleep 1  # Wait 1 second before checking again
  done
  sudo bash -c "sync; echo 1 > /proc/sys/vm/drop_caches"
  sudo bash -c "sync; echo 2 > /proc/sys/vm/drop_caches"
  sudo bash -c "sync; echo 3 > /proc/sys/vm/drop_caches"

}

cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        sudo kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi
    sudo pkill -f "urand"
    sudo pkill -f "web"
    sudo pkill -f "log_memory_usage"
    sudo pkill -f "track_pid.sh"
    clean_llama

    # Exit the script
    exit 0
}
# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

check_server() {
  # Replace with your actual server address and port
  server_address="127.0.0.1"
  server_port=8080

  # Query the server health endpoint (replace with your server's health check URL if necessary)
  curl -s --head "http://$server_address:$server_port/health" | grep "200 OK" > /dev/null
  return $?
}

check_server_ready(){
  sleep 5
  attempts=0
  max_attempts=30
  while ! check_server; do
    attempts=$((attempts + 1))
    echo "Waiting for server to be up and ready at $server_address:$server_port... ($attempts/$max_attempts)"
    if [ $attempts -ge $max_attempts ]; then
      echo "Server did not become ready in time. Exiting."
      exit 1
    fi
    sleep 2
  done

  echo "Server is ready at $server_address:$server_port!"

}




# Array of graph types and their corresponding search strings
# graphs=("bfs" "cc" "pr")
# modes=("web")
graphs=("bc" "bfs" "cc" "pr")
modes=("web" "urand")
# graphs=("bc")
# modes=("urand")

# Path to track_pid.sh script
track_pid_script="../general_commands/track_pid.sh"

# Function to run the graph and llama.cpp interference (specifically for bc-urand)
run_graph_with_llama_interference() {
  for graph in "${graphs[@]}"; do
    for mode in "${modes[@]}"; do
      # Build the graph script name
      script_name="${graph}-${mode}.sh"

      search_string="$graph"
      bash "$track_pid_script" "$search_string" &  # Run the PID tracker in the background

      # Clean the server before each run
      clean_llama

      echo "clean previous log before this run"
      sudo rm -f $RESULT_BASE_DIR/"${graph}-${mode}"/llama_output.log

      echo "$RESULT_BASE_DIR/'${graph}-${mode}'/llama_output.log"
      # clean the server to in case each time the llama first takes all local, there is no waste
      echo "restart the llama server"
      # sudo $GENERAL_COMMANDS_DIR/clean_llama.sh 
      sudo bash -c "numactl --physcpubind=$LLAMA_CPP_CORE $GENERAL_COMMANDS_DIR/llama_cpp_all.sh 2>&1 | tee -a $RESULT_BASE_DIR/'${graph}-${mode}'/llama_output.log" &

      check_server_ready

      # Check if the script exists before executing it
      if [ -f "$script_name" ]; then
        for run in {1..3}; do
          
          # Start tracking the graph workload PIDs
 
          echo "Running $script_name (Run $run)"
          sudo bash -c "echo 'Running $script_name (Run $run)' >> $RESULT_BASE_DIR/'${graph}-${mode}'/llama_output.log"

          
          # Run the graph script with numactl for CPU binding
          sudo numactl --physcpubind=$WORKLOAD_CORE bash "./$script_name"


          echo "Finished $script_name (Run $run), interference stopped."
          sudo bash -c "echo 'Finished $script_name (Run $run), interference stopped.' >> $RESULT_BASE_DIR/'${graph}-${mode}'/llama_output.log"
      
          
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

      clean_llama
    done

  done
}



# Main script execution
echo "Starting Graph workloads with llama.cpp interference.."

# Run the graph workloads with llama.cpp interference
run_graph_with_llama_interference
cleanup_and_exit

echo "All graph workloads executed with llama.cpp interference."
