#!/bin/bash
EXPORTS_FILE="./paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM
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
    sudo pkill -f "log_memory_usage"
    sudo pkill -f "track_pid.sh"
    sudo pkill -f "dlrm"
    clean_llama

    # Exit the script
    exit 0
}

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

# Loop through directories
# Array of directories to search for run_exp.sh scripts
directories=("dlrm_rm1_high" "dlrm_rm1_low" "dlrm_rm1_med" "dlrm_rm2_1_high" "dlrm_rm2_1_low" "dlrm_rm2_1_med")

# directories=("dlrm_rm1_low" "dlrm_rm1_med")
# directories=("dlrm_rm2_1_high")
# directories=("dlrm_rm2_1_low" "dlrm_rm2_1_med")

# Function to run dlrm workloads with vector contention
run_dlrm_with_llama_interference() {
  for benchmark in "${directories[@]}"; do
    cd $benchmark
    # Change to the benchmark directory
    clean_llama
  
    # Check if run_exp.sh exists and is executable
    if [[ -x "./run_exp.sh" ]]; then
      echo "clean previous log before this run"
      sudo rm -f $RESULT_BASE_DIR/$benchmark/llama_output.log
      # sudo rm -f $RESULT_BASE_DIR/$benchmark/dlrm_rm1_high.

      echo "restart the llama server"
      sudo $GENERAL_COMMANDS_DIR/clean_llama.sh 
      sudo bash -c "numactl --physcpubind=$LLAMA_CPP_CORE $GENERAL_COMMANDS_DIR/llama_cpp_all.sh 2>&1 | tee -a $RESULT_BASE_DIR/$benchmark/llama_output.log &"

      echo "now we are here"
      check_server_ready

      # Loop through each run (e.g., run 1 to 3)
      for run in {1..3}; do

        # Start tracking the dlrm workload
        echo "Running ${benchmark} (Run $run)"
        sudo bash -c "echo 'Running ${benchmark} (Run $run)' >> $RESULT_BASE_DIR/$benchmark/llama_output.log"

        # Run the dlrm script with numactl for CPU binding
        sudo numactl --physcpubind=$WORKLOAD_CORE ./run_exp.sh

        echo "Finished ${benchmark} (Run $run), llama interference stopped."
        sudo bash -c "echo 'Finished ${benchmark} (Run $run), llama interference stopped.' >> $RESULT_BASE_DIR/$benchmark/llama_output.log"
      done
    else
      echo "run_exp.sh not found or not executable in $benchmark"
    fi

    # Go back to the parent directory after processing the benchmark
    cd ..
  done
}



# Main script execution
echo "Starting DLRM workloads with llama.cpp interference..."

# Run the dlrm workloads with llama.cpp interference
run_dlrm_with_llama_interference
cleanup_and_exit

echo "All dlrm workloads executed with llama.cpp interference."



