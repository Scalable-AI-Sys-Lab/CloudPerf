#!/bin/bash

# Check if the user provided an input for the log file name
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <log_file_name>"
    exit 1
fi

# Get the log file name from the first argument
LOG_FILE="$1"

# Path to the memory.numa_stat file
NUMA_STAT_FILE="/home/jhlu/cg_test/cg1/memory.numa_stat"  # Replace with the correct path

# Create a PID file to store the PID of this script
pidfile="/tmp/numa_stat_tracker.pid"
echo $$ > "$pidfile"

# Define a function to clean up and exit gracefully
cleanup() {
    echo "Stopping script and cleaning up..."
    rm -f "$pidfile"
    exit 0
}

# Trap SIGINT (Ctrl+C) and SIGTERM to run the cleanup function
trap cleanup SIGINT SIGTERM

# Check if the NUMA stat file exists
if [[ ! -f "$NUMA_STAT_FILE" ]]; then
    echo "File $NUMA_STAT_FILE not found!"
    exit 1
fi

# Function to track the data and append it to the log file
track_numa_stat() {
    while true; do
        # Get the current timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        # Extract only the lines containing anon and file
        anon_data=$(grep "^anon " "$NUMA_STAT_FILE")
        file_data=$(grep "^file " "$NUMA_STAT_FILE")

        # Extract the values for anon and file on N0 and N1
        anon_n0=$(echo "$anon_data" | awk '{for (i=1; i<=NF; i++) if ($i ~ /N0=/) print $i}' | cut -d'=' -f2)
        anon_n1=$(echo "$anon_data" | awk '{for (i=1; i<=NF; i++) if ($i ~ /N1=/) print $i}' | cut -d'=' -f2)
        file_n0=$(echo "$file_data" | awk '{for (i=1; i<=NF; i++) if ($i ~ /N0=/) print $i}' | cut -d'=' -f2)
        file_n1=$(echo "$file_data" | awk '{for (i=1; i<=NF; i++) if ($i ~ /N1=/) print $i}' | cut -d'=' -f2)

        # Log the data with the timestamp, including only anon and file data
        # echo "$timestamp anon N0=$anon_n0 N1=$anon_n1 file N0=$file_n0 N1=$file_n1" >> "$LOG_FILE"
        echo "$timestamp anon N0=$anon_n0 N1=$anon_n1 file N0=$file_n0 N1=$file_n1" | tee -a "$LOG_FILE" > /dev/null


        sleep 3

    done
}

# Start tracking
echo "Tracking memory.numa_stat data and logging to $LOG_FILE..."
track_numa_stat
