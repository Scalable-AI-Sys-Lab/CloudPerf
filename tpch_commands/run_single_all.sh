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


cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        sudo kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi
    sudo pkill -f "log_memory_usage"
    sudo pkill -f "track_pid.sh"

    # Exit the script
    exit 0
}



# Loop through directories tpch_1 to tpch_22

for query in {12..12}; do
  # Construct the directory name
  dir="tpch_$query"
  formatted_query=$(printf "%02d" $query)
  
  cd $dir
  # Check if the run_exp.sh script exists in the directory
  if [ -f "./run_exp.sh" ]; then
    for run in {1..1}; do
      pushd ../../general_commands > /dev/null
      ./track_pid.sh "postgres" &
      popd > /dev/null

      echo "Executing $dir/run_exp.sh (Run $run)"

      # Run the script
      numactl --physcpubind=$WORKLOAD_CORE bash "./run_exp.sh"
      
      # Check the exit status of the script
      if [ $? -ne 0 ]; then
        echo "Error executing $dir/run_exp.sh on Run $run"
        exit 1  # Exit the loop if any script fails
      fi

      # Kill any remaining postgres processes
      sudo pkill -f postgres
    done
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


