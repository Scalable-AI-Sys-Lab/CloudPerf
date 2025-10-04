#!/bin/bash
EXPORTS_FILE="../all_config.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

total_memory_byte=$((20 * 1024 * 1024 * 1024))

export VECTORDB_DIR=$(realpath ../vectordb)
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
    sudo pkill -f "track_pid.sh"
    sudo $VECTORDB_DIR/clean_server.sh

    # Exit the script
    exit 0
}

# export VECTORDB_DIR=/data/Mercury_workloads/vectordb

# Change ownership of the full directory and its contents
sudo chown -R $(whoami) $VECTORDB_DIR
# Loop through directories tpch_1 to tpch_22

rm $VECTORDB_DIR/client_output.log
rm vector_contention_output.log
config_file="init_config.json"

for i in {2..22}; do
  # Construct the directory name
  dir="tpch_$i"
  
  cd $dir
  # Check if the run_exp.sh script exists in the directory
  if [ -f "./run_exp.sh" ]; then

    # workload_memory_limit=$(jq -r '.recommend_memory_limit' "$config_file")
    workload_memory_limit=$((5*1024*1024*1024))
    echo "workload memory limit is: $workload_memory_limit"
    sudo ../../general_commands/update_mem_limit -cg_idx 1 -mem_limit_value $workload_memory_limit

    vector_memory_limit=$((total_memory_byte - workload_memory_limit))
    echo "vectordb memory limit is: $vector_memory_limit"
    sudo ../../general_commands/update_mem_limit -cg_idx 2 -mem_limit_value $vector_memory_limit


    # clean the server to in case each time the vector first takes all local, there is no waste
    sudo $VECTORDB_DIR/clean_server.sh
    echo "restart the vector server"
    echo "vectordb core is $VECTORDB_CORE"

    pushd ../../vectordb > /dev/null
    sudo numactl --physcpubind=$VECTORDB_CORE ./mer_vector_bw_all_cg2.sh 1
    popd > /dev/null

    sudo rm -f ./memory_usage_log_vector.csv
    sudo ../../general_commands/log_memory_usage -cg_idx 2 -output_dir "$(pwd)" -output_file "memory_usage_log_vector.csv" &
    # sleep 5


    for run in {1..3}; do
      pushd ../../general_commands > /dev/null
      ./track_pid.sh "postgres" &
      popd > /dev/null

      echo "Executing $dir/run_exp.sh (Run $run)"
      sudo bash -c "echo 'Executing $dir/run_exp.sh (Run $run)' >> ../../vectordb/client_output.log"

      # Run the script
      numactl --physcpubind=$WORKLOAD_CORE bash "./run_exp.sh"
      
      # Check the exit status of the script
      if [ $? -ne 0 ]; then
        echo "Error executing $dir/run_exp.sh on Run $run"
        exit 1  # Exit the loop if any script fails
      fi

      sudo bash -c "echo 'Finished $dir/run_exp.sh (Run $run)' >> $VECTORDB_DIR/client_output.log"
      
      # Stop any running PostgreSQL instances
      # pg_ctl -D /home/jhlu/pgdata10GB stop -m fast

      # Kill any remaining postgres processes
      sudo pkill -f postgres
    done
  else
    echo "Script $dir/run_exp.sh not found."
  fi

  # goes back
  cd ..
  # Stop any running PostgreSQL instances
  # pg_ctl -D /home/jhlu/pgdata10GB stop -m fast
  cat $VECTORDB_DIR/client_output.log >> vector_contention_output.log

  # Kill any remaining postgres processes
  sudo pkill -f postgres
done

echo "All scripts executed successfully."
# Stop PID tracking

cleanup_and_exit


