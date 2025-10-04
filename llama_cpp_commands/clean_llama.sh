# Function to check if llama.cpp is still running
check_llama_running() {
    pgrep -f llama > /dev/null
    return $?  # Returns 0 if the process is found, non-zero otherwise
}

# Try to kill llama.cpp and check if it's still running
while check_llama_running; do
    echo "llama.cpp is still running. Attempting to kill it..."
    pkill -f llama
    pkill -f llama
    sleep 1  # Wait 1 second before checking again
done

echo "llama.cpp has been successfully terminated."


sudo bash -c "sync; echo 1 > /proc/sys/vm/drop_caches"
sudo bash -c "sync; echo 2 > /proc/sys/vm/drop_caches"
sudo bash -c "sync; echo 3 > /proc/sys/vm/drop_caches"

