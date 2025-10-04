#!/bin/bash
# Define variables for commonly used paths
export RESULT_DIR=../../results/tpch/q09
export PG_TPCH_DIR=../../tpch/pg-tpch
# Create result directory if it doesn't exist
sudo mkdir -p $RESULT_DIR

# Change directory to the PG_TPCH_DIR and start the TPC-H query in the background
cd $PG_TPCH_DIR
./tpch_runone 9 &
target_pid=$!

# sudo rm -f $RESULT_DIR/memory_usage_log.csv
# sudo ../../general_commands/log_memory_usage -cg_idx 1 -output_dir $RESULT_DIR &

# Capture the PID of the last background process


# Wait until the target_pid process has stopped
while kill -0 $target_pid 2> /dev/null; do
  echo "Waiting for process $target_pid to finish..."
  sleep 2
done

echo "Process $target_pid has finished."

# Echo the current time in the desired format (e.g., YYYY-MM-DD HH:MM:SS)
sudo bash -c "echo '$(date '+%Y-%m-%d %H:%M:%S')' >> $RESULT_DIR/result_app_perf.txt"

# Now concatenate the execution time results into the final result file
sudo bash -c "cat $PG_TPCH_DIR/perfdata-10GB/q09/exectime.txt >> $RESULT_DIR/result_app_perf.txt"
echo "Execution time appended to $RESULT_DIR/result_app_perf.txt"

sudo pkill -f "log_memory_usage"