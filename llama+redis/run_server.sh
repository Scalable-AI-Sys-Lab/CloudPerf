numactl --physcpubind=28-45,84-101 ./server -m models/llama-2-70b.Q4_K_M.gguf -n 512 -t 36 &
echo $! > /home/jhlu/cg_test/cg3/cgroup.procs