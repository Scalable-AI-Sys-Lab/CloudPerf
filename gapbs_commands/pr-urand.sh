# Define variables for commonly used paths
EXPORTS_FILE="./paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

export GAPBS_GRAPH_DIR=$GAPBS_DIR/benchmark/graphs
export RESULT_DIR=$RESULT_BASE_DIR/pr-urand
export CMD_SCRIPT_PATH=$PRIVATE_POND_DIR/gapbs/pr-urand

mkdir -p $RESULT_DIR

# Echo the current time in the desired format (e.g., YYYY-MM-DD HH:MM:SS)
echo "$(date '+%Y-%m-%d %H:%M:%S')" >> $RESULT_DIR/result_log.txt

sudo rm -f $RESULT_DIR/memory_usage_log.csv
sudo $GENERAL_COMMANDS_DIR/log_memory_usage -cg_idx $CGROUG_NUMBER -output_dir $RESULT_DIR &

# Run the command using the defined variables
/usr/bin/time -pao $RESULT_DIR/result_app_perf.txt $CMD_SCRIPT_PATH/cmd.sh >> $RESULT_DIR/result_log.txt 2>> $RESULT_DIR/result_err.txt &

# Get the PID of the backgrounded 'bc' process (the last background process)
check_pid=$!


# Find the PID of the 'pr' process based on its name, selecting the last one
bc_pid=$(pgrep -f "pr" | tail -n 1)

# Write the PID to the file
# echo $bc_pid > /home/jhlu/cg_test/cg1/cgroup.procs


# Wait for the process to finish
wait $check_pid

# After the process finishes, echo a message and log the time
echo "Process $check_pid has stopped."

sudo pkill -f "log_memory_usage"

