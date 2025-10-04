#!/bin/bash

# Check if the user provided an input string
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <search_string>"
    exit 1
fi

# Extract the input string from command-line argument
search_string="$1"

# Initialize an empty set of tracked PIDs
tracked_pids=""
pid_count=0  # Counter to track the number of new PIDs

# Create a PID file to store the PID of this script
pidfile="/tmp/track_pid_script.pid"
echo $$ > "$pidfile"

# Define a function to clean up and exit gracefully
cleanup() {
    echo "Stopping script and cleaning up..."
    exit 0  # Exit the script
}

# Trap SIGINT (Ctrl+C) and SIGTERM to run the cleanup function
trap cleanup SIGINT SIGTERM

echo "Started to track the PID for processes matching: '$search_string'"

# Continuous monitoring for new PIDs based on the search string
while true; do
    # Get current PIDs matching the search string
    current_pids=$(pgrep -f "$search_string")

    # Iterate over each PID
    for pid in $current_pids; do
        # Check if the PID is already tracked
            # Append the new PID to the cgroup.procs file
            # echo "New PID detected: $pid" 
        sudo bash -c "echo $pid >> /home/jhlu/cg_test/cg1/cgroup.procs"
        
        # Update the tracked PIDs set
        tracked_pids="${tracked_pids}${pid}"$'\n'
        
    done


done
