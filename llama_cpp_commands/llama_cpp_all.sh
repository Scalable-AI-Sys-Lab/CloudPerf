# Function to check if the server is ready by querying the health check endpoint

../llama.cpp/server -m ../llama.cpp/models/llama-2-70b.Q4_K_M.gguf -v -n 512 -t 32 &
sudo bash -c "echo $! > ../cg_test/cg1/cgroup.procs"


# Wait until the server is ready by checking the health endpoint

python3 ./llama_cpp_client.py &
echo "client is running"


