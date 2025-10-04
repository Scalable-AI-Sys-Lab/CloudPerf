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

clear_cache(){
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
    sudo pkill -f "profiler"

    # Exit the script
    exit 0
}




# Load JSON data
memory_threshold_gb=5
config_file="init_config_${memory_threshold_gb}G.json"


for query in {2..22}; do
  # Construct the directory name
  dir="tpch_$query"
  formatted_query=$(printf "%02d" $query)
  
  cd $dir
  sudo rm -f ./latency_log.csv
  sudo rm -f ./latency_log.txt
  sudo rm -f ./memory_numastat_log.csv

  sudo rm -f ../../results/tpch/q$formatted_query/memory_usage_log.csv
  sudo rm -f ../../results/tpch/q$formatted_query/latency_log_profile.csv
  sudo rm -f ../../results/tpch/q$formatted_query/memory_numastat_log_profile.csv

  # Check if the run_exp.sh script exists in the directory
  if [ -f "./run_exp.sh" ]; then
    for run in {1..3}; do
      pushd ../../general_commands > /dev/null
      ./track_pid.sh "postgres" &
      popd > /dev/null

      echo "Executing $dir/run_exp.sh (Run $run)"

      # set the memory limit before doing the prepare should be better
      memory_limit=$(jq -r '.recommend_memory_limit' "$config_file")
      echo "memory limit is: $memory_limit"
      sudo ../../general_commands/update_mem_limit -cg_idx 1 -mem_limit_value $memory_limit

      # Run the script
      numactl --physcpubind=$WORKLOAD_CORE bash "./run_exp.sh" &
      
      indicator_pid=$!
      sleep 3
      clear_cache

      
      sudo bash -c "../../profiler/build/profiler -cg_idx 1 -mem_limit_value $memory_limit -process_name postgres &"
      echo "command name: ../../profiler/build/profiler -cg_idx 1 -mem_limit_value $memory_limit -process_name postgres"

      # Check if the process is running
      while kill -0 $indicator_pid 2>/dev/null; do
          # echo "Process $indicator_pid is still running"
          sleep 1  # Wait for a second before checking again
      done
      echo "Process $indicator_pid has stopped"
      # Kill any remaining postgres processes
      sudo pkill -f postgres
      sudo pkill -f profiler
    done
    sudo mv ./latency_log.csv ../../results/tpch/q$formatted_query/latency_log_profile.csv
    sudo mv ./memory_numastat_log.csv ../../results/tpch/q$formatted_query/memory_numastat_log_profile.csv
  else
    echo "Script $dir/run_exp.sh not found."
  fi

  # goes back
  cd ..

  # Kill any remaining postgres processes
  sudo pkill -f postgres

done

echo "All scripts executed successfully."
# Stop PID tracking

cleanup_and_exit


