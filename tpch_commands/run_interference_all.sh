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

# Loop through directories tpch_1 to tpch_22



for query in {2..22}; do
  clean_llama
  # Construct the directory name
  dir="tpch_$query"
  formatted_query=$(printf "%02d" $query)
  
  cd $dir
  # Check if the run_exp.sh script exists in the directory
  if [ -f "./run_exp.sh" ]; then

    # clean the server to in case each time the llama first takes all local, there is no waste
    echo "clean previous log before this run"
    sudo rm -f $RESULT_BASE_DIR/q$formatted_query/llama_output.log

    echo "restart the llama server"
    # sudo $GENERAL_COMMANDS_DIR/clean_llama.sh 
    sudo numactl --physcpubind=$LLAMA_CPP_CORE $GENERAL_COMMANDS_DIR/llama_cpp_all.sh 2>&1 | tee -a $RESULT_BASE_DIR/q$formatted_query/llama_output.log &

    echo "now we are here"
    check_server_ready
    
    for run in {1..1}; do
      
      sudo $GENERAL_COMMANDS_DIR/track_pid.sh "postgres" &
      echo "Executing $dir/run_exp.sh (Run $run)"
      sudo bash -c "echo 'Executing $dir/run_exp.sh (Run $run)' >> $RESULT_BASE_DIR/q$formatted_query/llama_output.log"

      # Run the script
      numactl --physcpubind=$WORKLOAD_CORE bash "./run_exp.sh"
      
      # Check the exit status of the script
      if [ $? -ne 0 ]; then
        echo "Error executing $dir/run_exp.sh on Run $run"
        exit 1  # Exit the loop if any script fails
      fi

      echo "Finished $dir/run_exp.sh (Run $run)" >> $RESULT_BASE_DIR/q$formatted_query/llama_output.log

      # Kill any remaining postgres processes
      sudo pkill -f postgres
    done
  else
    echo "Script $dir/run_exp.sh not found."
  fi

  # goes back
  cd ..
  sudo bash -c "echo 'Finished $dir/run_exp.sh' >> $RESULT_BASE_DIR/q$formatted_query/llama_output.log"

  # Kill any remaining postgres processes
  sudo pkill -f postgres
  clean_llama
done

echo "All scripts executed successfully."
# Stop PID tracking

cleanup_and_exit


