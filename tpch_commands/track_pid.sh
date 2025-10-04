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

echo "started to track the pid"
# Continuous monitoring for new Spark PIDs
while true; do
    # Get current Spark PIDs
    current_pids=$(pgrep -f "postgre")

    # Iterate over each PID
    for pid in $current_pids; do
        # Check if the PID is already tracked
        if ! grep -q "^$pid$" <<< "$tracked_pids"; then
        # Append the new PID to the file
        echo "new pid: $pid" 
        sudo bash -c "echo $pid >> /home/jhlu/cg_test/cg1/cgroup.procs"
        # Update the tracked PIDs set
        tracked_pids="${tracked_pids}${pid}"$'\n'
        echo "New PID detected and added: $pid"
        # Increment the PID counter
        pid_count=$((pid_count + 1))
        fi
    done

    # # Check if the counter has reached 6
    # if [ "$pid_count" -ge 2000 ]; then
    #     echo "Detected 2000 new Spark PIDs. Exiting loop."
    #     break
    # fi

# # Sleep for a short time before checking again
# sleep 2
done