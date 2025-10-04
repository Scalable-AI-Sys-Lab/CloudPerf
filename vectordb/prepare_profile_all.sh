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
    sudo ./clean_server.sh

    # Exit the script
    exit 0
}

LOCAL_MEMORY_GB=15
LOCAL_MEMORY_BYTE=$((LOCAL_MEMORY_GB * 1024 * 1024 * 1024))

sudo ./clean_server.sh
# Loop through directories tpch_1 to tpch_22
sudo ../general_commands/update_mem_limit -cg_idx 1 -mem_limit_value $LOCAL_MEMORY_BYTE
sudo numactl --physcpubind=$VECTORDB_CORE ./mer_vector_bw_all.sh 1

# TODO: remember to change the app name
sudo bash -c "../profiler/build/profiler -cg_idx 1 -mem_limit_value $LOCAL_MEMORY_BYTE -process_name vector &"
echo "command name: $../profiler/build/profiler -cg_idx 1 -mem_limit_value $LOCAL_MEMORY_BYTE -process_name vector"
sleep 30
sudo ./clean_server.sh

sudo mv ./latency_log.csv ./latency_log_15gb.csv
sudo mv ./memory_numastat_log.csv ./memory_numastat_log_15gb.csv


echo "All scripts executed successfully."
# Stop PID tracking

cleanup_and_exit


