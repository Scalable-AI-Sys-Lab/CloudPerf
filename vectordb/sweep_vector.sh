#!/bin/bash
# Source the Conda environment
EXPORTS_FILE="../all_config.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

source ../miniconda3/etc/profile.d/conda.sh
conda activate mercury

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
    sudo pkill -f "track_pid.sh"
    sudo $VECTORDB_DIR/clean_server.sh

    # Exit the script
    exit 0
}

# Function to check if the server is running on the given address and port
check_server() {
  # Replace with your actual server address and port
  server_address="127.0.0.1"
  server_port=5000

  # Try to connect to the server
  nc -z -w 2 $server_address $server_port
  return $?
}

sudo ./clean_server.sh

# Define the log file to append all outputs
log_file="sweep_vector.log"

# sudo rm $log_file

for memory_size in {12..20}; do
  sudo ./clean_server.sh
  vectordb_memory_limit=$((memory_size * 1024 * 1024 * 1024))
  sudo ../general_commands/update_mem_limit -cg_idx 1 -mem_limit_value $vectordb_memory_limit
  echo "command is: ../general_commands/update_mem_limit -cg_idx 1 -mem_limit_value $vectordb_memory_limit"
  # Check if the server is not running
  if ! check_server; then
    # Start the server
    numactl --physcpubind=$VECTORDB_CORE python ./vector-server.py &
    server_pid=$!
    sudo bash -c "echo $server_pid > ../cg_test/cg1/cgroup.procs"
  fi

  # Wait until the server is up
  attempts=0
  max_attempts=30
  while ! check_server; do
    attempts=$((attempts + 1))
    echo "Waiting for server to be up at $server_address:$server_port... ($attempts/$max_attempts)"
    if [ $attempts -ge $max_attempts ]; then
      echo "Server did not start in time. Exiting."
      exit 1
    fi
    sleep 2
  done

  echo "Server is running at $server_address:$server_port!"

  # Get the number of instances from the command line argument
  num_instances=1


  sudo bash -c "echo 'Executing local momory limit is $memory_size GB' >> $log_file"
  # Loop to start the specified number of instances
  for ((i = 0; i < num_instances; i++)); do
    # numactl --physcpubind=49-52,105-108 python /data/Mercury_my/apps/vectorDB/client.py >> "$log_file" 2>&1 &
    sudo chown $(whoami) $log_file
    numactl --physcpubind=$VECTORDB_CORE python client.py 2>&1 | tee -a $log_file &
  done

  echo "Started $num_instances instances of client.py"

  sleep 15

  sudo ./clean_server.sh
  sudo bash -c "echo 'Finished local momory limit is $memory_size GB' >> $log_file"

done