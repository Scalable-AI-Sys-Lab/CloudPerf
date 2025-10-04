#!/bin/bash

# Infinite while loop to keep checking for the dlrm process
while true; do
  # Get the process ID(s) of any process with "dlrm" in the name
  target_pids=$(pgrep -f "dlrm")

  # Check if the target_pids variable is not empty
  if [ -n "$target_pids" ]; then
    echo "dlrm process found with PID(s): $target_pids"
    
    # Loop through each PID and add it to the cgroup.procs file
    for pid in $target_pids; do
      sudo bash -c "echo $pid >> /home/jhlu/cg_test/cg1/cgroup.procs"
      echo "Added PID $pid to /home/jhlu/cg_test/cg1/cgroup.procs"
    done
    
    # Exit the loop once the dlrm process has been detected and handled
    echo "Track_pid script is done as dlrm process was found."
    break
  else
    echo "No dlrm process found. Checking again..."
  fi
  
#   # Sleep for a few seconds before checking again to avoid rapid looping
#   sleep 5
done
