#!/bin/bash

# Define variables for commonly used paths
export PG_TPCH_DIR=/data/Mercury_workloads/tpch/pg-tpch
export RESULT_DIR=/data/Mercury_workloads/results/tpch/q01

# Create result directory if it doesn't exist
mkdir -p $RESULT_DIR

# Change directory to the PG_TPCH_DIR and start the TPC-H query in the background
cd $PG_TPCH_DIR
./tpch_runone 1 &

# Initialize variables
target_pid_count=8
bc_pid=""

# Wait for the eighth 'postgres' process to start
while true; do
  # Get the current list of postgres PIDs
  current_pids=$(pgrep -f "postgres")
  current_pid_count=$(echo "$current_pids" | wc -l)

  echo "Current postgres process count: $current_pid_count"

  # Check if we have reached the target number of processes
  if [ "$current_pid_count" -ge "$target_pid_count" ]; then
    bc_pid=$(echo "$current_pids" | tail -n 1)
    echo "Target process count reached. Final PID: $bc_pid"
    break
  fi

  # Sleep before the next check
  # sleep 1
done

# Check if the final PID was found
if [ -z "$bc_pid" ]; then
  echo "Final Postgres process not found. Exiting."
  exit 1
else
  echo "bc pid is: $bc_pid"
  # Write the PID to the cgroup file
  sudo bash -c "echo $bc_pid > /home/jhlu/cg_test/cg1/cgroup.procs"
fi

# Wait until the bc_pid process has stopped
while kill -0 $bc_pid 2> /dev/null; do
  echo "Waiting for process $bc_pid to finish..."
  sleep 2
done

echo "Process $bc_pid has finished."

# Now concatenate the execution time results into the final result file
cat $PG_TPCH_DIR/perfdata-10GB/q01/exectime.txt >> $RESULT_DIR/result_app_perf.txt
echo "Execution time appended to $RESULT_DIR/result_app_perf.txt"
