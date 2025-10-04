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



# The target of pre profile is to get the memory usage



for query in {12..12}; do
  # Construct the directory name
  dir="tpch_$query"
  formatted_query=$(printf "%02d" $query)
  
  cd $dir
  sudo rm -f ./latency_log.csv
  sudo rm -f ./latency_log.txt
  sudo rm -f ./memory_numastat_log.csv
  export LOCAL_MEMORY_GB=5
  sudo rm -f ../../results/tpch/q$formatted_query/memory_usage_log.csv
  sudo rm -f ../../results/tpch/q$formatted_query/latency_log_${LOCAL_MEMORY_GB}gb.csv
  sudo rm -f ../../results/tpch/q$formatted_query/memory_numastat_log_${LOCAL_MEMORY_GB}gb.csv

  # Check if the run_exp.sh script exists in the directory
  if [ -f "./run_exp.sh" ]; then
    # please do not change the round number here, we only need one round
    for run in {1..1}; do
      pushd ../../general_commands > /dev/null
      ./track_pid.sh "postgres" &
      popd > /dev/null

      echo "Preparing $dir/run_exp.sh (Run $run)"

      numactl --physcpubind=$WORKLOAD_CORE bash "./prepare_exp.sh"

      echo "Executing $dir/run_exp.sh (Run $run)"
      # Run the script
      numactl --physcpubind=$WORKLOAD_CORE bash "./run_exp.sh" &
      
      indicator_pid=$!
      echo "run exp process started with PID: $indicator_pid"

      LOCAL_MEMORY_BYTE=$((LOCAL_MEMORY_GB * 1024 * 1024 * 1024))
     
      # Start the profiler process
      sudo ../../profiler/build/profiler -cg_idx 1 -mem_limit_value $LOCAL_MEMORY_BYTE -process_name postgres -memory_only &
      
      pid_file="/tmp/profiler_pid"
      # Wait until the PID file exists
      while [ ! -f $pid_file ]; do
          sleep 0.1
      done

      # Read the PID from the file
      profiler_pid=$(cat $pid_file)

      echo "Profiler process started with PID: $profiler_pid"



      

      # Check if the indicator process is running
      while kill -0 $indicator_pid 2>/dev/null; do
          sleep 1  # Wait for a second before checking again
      done

      # Send the signal to the profiler process to write results
      echo "Indicator process $indicator_pid has stopped. Sending signal to profiler $profiler_pid"
      # Send the signal to the profiler process
      sudo kill -SIGUSR1 $profiler_pid

      # Wait for the profiler process to finish
      while ps -p $profiler_pid > /dev/null 2>&1; do
          sleep 1
      done

      # Clean up
      sudo rm -f $pid_file

      # Kill any remaining postgres processes
      sudo pkill -f postgres
      sudo pkill -f profiler
    done
    # sudo mv ./latency_log.csv ../../results/tpch/q$formatted_query/latency_log_${LOCAL_MEMORY_GB}gb.csv
    sudo mv ./memory_numastat_log.csv ../../results/tpch/q$formatted_query/memory_numastat_log_${LOCAL_MEMORY_GB}gb.csv
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


