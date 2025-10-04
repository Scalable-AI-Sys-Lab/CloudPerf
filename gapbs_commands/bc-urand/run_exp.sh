# Define variables for commonly used paths

export PRIVATE_POND_DIR=../../Private-Pond
export RESULT_DIR=../../results/graph/bc-urand
export CMD_SCRIPT_PATH=$PRIVATE_POND_DIR/gapbs/bc-urand

# Echo the current time in the desired format (e.g., YYYY-MM-DD HH:MM:SS)
# Create the directory if it doesn't exist
mkdir -p $RESULT_DIR
echo "$(date '+%Y-%m-%d %H:%M:%S')" >> $RESULT_DIR/result_log.txt

sudo rm -f $RESULT_DIR/memory_usage_log.csv
sudo ../../general_commands/log_memory_usage -cg_idx 1 -output_dir $RESULT_DIR &

# Run the command using the defined variables

pushd $CMD_SCRIPT_PATH > /dev/null
/usr/bin/time -pao ../$RESULT_DIR/result_app_perf.txt ./cmd.sh >> ../$RESULT_DIR/result_log.txt 2>> ../$RESULT_DIR/result_err.txt
popd > /dev/null