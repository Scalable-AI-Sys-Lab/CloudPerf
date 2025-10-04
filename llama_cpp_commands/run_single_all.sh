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
check_llama_running() {
    pgrep -f llama > /dev/null
    return $?  # Returns 0 if the process is found, non-zero otherwise
}


clean_llama(){
  sudo bash -c "sync; echo 1 > /proc/sys/vm/drop_caches"
  sudo bash -c "sync; echo 2 > /proc/sys/vm/drop_caches"
  sudo bash -c "sync; echo 3 > /proc/sys/vm/drop_caches"
  while check_llama_running; do
    echo "llama.cpp is still running. Attempting to kill it..."
    sudo pkill -f llama
    sudo pkill -f llama
    sleep 1  # Wait 1 second before checking again
  done

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


sudo rm -f llama_output.log
# TODO: change it back to 1..3
for run in {1..3}; do
  clean_llama

  sudo bash -c "echo 'Run $run' >> llama_output.log"

  # clean the server to in case each time the llama first takes all local, there is no waste
  echo "restart the llama server"
  # sudo $GENERAL_COMMANDS_DIR/clean_llama.sh 
  
  sudo bash -c "numactl --physcpubind=$LLAMA_CPP_CORE ./llama_cpp_single.sh 2>&1 | tee -a llama_output.log"

  sudo bash -c "echo 'Finished Run $run' >> llama_output.log"
  
  clean_llama
done

echo "All scripts executed successfully."
# Stop PID tracking

cleanup_and_exit


