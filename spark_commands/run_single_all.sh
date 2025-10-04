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
    sudo systemctl stop memcached.service
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

# pay attention to memcached, it may still be there, 
# Array of directories with commands to run `run_exp.sh`
folders=(
    # "spark_als"
    # "spark_gbt"
    # "spark_sort"
    # "spark_wordcount"
    # "spark_pca"
    # "spark_rf"
    "spark_terasort"
    # "spark_linear"

)


# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM


sudo bash -c "echo 'start:'"
# Loop through each folder and execute `run_exp.sh` or `prepare_exp.sh` followed by `run_exp.sh` for Memcached
for folder in "${folders[@]}"; do
    cd "$folder" || { echo "Failed to enter directory $folder"; exit 1; }
    # Change to the benchmark directory

    
    echo "clean previous log before this run"
    # sudo rm -f $RESULT_BASE_DIR/$folder/llama_output.log
    # sudo rm -f $RESULT_BASE_DIR/$folder/memory_usage_log.csv
    pushd ../../general_commands > /dev/null
    ./track_pid.sh "spark" &
    popd > /dev/null

    # todo: change it to three times
    for run in {1..1}; do
        
        echo "Running prepare_exp.sh and run_exp.sh in $folder"
        # Attention! Do not use sudo to run the spark workload
        numactl --physcpubind=$WORKLOAD_CORE bash prepare_exp.sh  # Run prepare script first

        # Execute run_exp.sh for both memcached and non-memcached folders
        numactl --physcpubind=$WORKLOAD_CORE bash run_exp.sh

        # Stop tracking the workload PIDs
        kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    done

    # Go back to the parent directory
    cd ..

done

echo "All workloads executed with run single all."

# Run the workloads with llama interference
cleanup_and_exit

