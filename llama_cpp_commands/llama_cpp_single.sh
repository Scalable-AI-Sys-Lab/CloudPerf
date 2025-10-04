#!/bin/bash
EXPORTS_FILE="../all_config.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

echo "llama.cpp dir is $LLAMA_CPP_DIR"
echo "llama.cpp core is $LLAMA_CPP_CORE"

check_server() {
  # Replace with your actual server address and port
  server_address="127.0.0.1"
  server_port=8080

  # Query the server health endpoint (replace with your server's health check URL if necessary)
  curl -s --head "http://$server_address:$server_port/health" | grep "200 OK" > /dev/null
  return $?
}

check_llama_running() {
    pgrep -f llama > /dev/null
    return $?  # Returns 0 if the process is found, non-zero otherwise
}

clean_llama(){
  sudo bash -c "sync; echo 1 > /proc/sys/vm/drop_caches"
  sudo bash -c "sync; echo 2 > /proc/sys/vm/drop_caches"
  sudo bash -c "sync; echo 3 > /proc/sys/vm/drop_caches"
  while check_llama_running; do
    echo "llama.cpp is still running. Attempting to kill it..."
    sudo pkill -f llama
    sudo pkill -f llama
    sleep 1  # Wait 1 second before checking again
  done

}

check_server_ready(){
  sleep 5
  attempts=0
  max_attempts=30
  while ! check_server; do
    attempts=$((attempts + 1))
    echo "Waiting for server to be up and ready at $server_address:$server_port... ($attempts/$max_attempts)"
    if [ $attempts -ge $max_attempts ]; then
      echo "Server did not become ready in time. Exiting."
      exit 1
    fi
    sleep 2
  done

  echo "Server is ready at $server_address:$server_port!"

}


# Function to check if the server is ready by querying the health check endpoint
if ! check_server; then
    numactl --physcpubind=$LLAMA_CPP_CORE ../llama.cpp/server -m ../llama.cpp/models/llama-2-70b.Q4_K_M.gguf -n 512 -t 32 &
    sudo bash -c "echo $! > ../cg_test/cg1/cgroup.procs"
fi

# Wait until the server is ready by checking the health endpoint

numactl --physcpubind=$LLAMA_CPP_CORE python3 llama_cpp_client_for_single.py
echo "finished client one time"

clean_llama






