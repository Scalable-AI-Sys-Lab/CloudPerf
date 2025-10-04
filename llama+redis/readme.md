# Prerequisite
```sh
# The following packages should be installed:
pip3 
numactl
huggingface-cli
```

# Adjustment
```
(1) "numactl --physcpubind=28-45,84-101" in run_server.sh file
Explaination:

In the run_server.sh file, please adjust the "numactl --physcpubind=28-45,84-101" based on your specific core number, please remember to use different physical cores with other apps. Here, I use 18 physical cores to avoid the core contention.


(2) "echo $! > /home/jhlu/cg_test/cg3/cgroup.procs" in run_server.sh 
Explaination:

please specify the location where you mount your cgroup, here my location is /home/jhlu/cg_test, the cgroup number is cg3

```


# Run the experiments
## llama part
```sh
# load the server first
run_server.sh
# start request for llama
run_client.sh
```

Every time you run the redis, you would first start the server by running `run_redis.sh`, then store all the data by running `start_memtier_llama.sh`.
If you want to start collecting the data, you would run the `run_memtier_llama.sh`
# How to run Redis
```sh
# start redis
./run_redis.sh

# store all the data into the redis
./start_memtier_llama.sh

# keep the memtier-benchmark running
./run_memtier_llama.sh
```


# Experiment details
```
Here are three sets of experiments:
(1) 100% memory of Redis on local DRAM; 100% memory of LLaMa.CPP on local DRAM
Results on the simulated environment for reference: llama+redis-1.png

(2) 100% memory of Redis on local DRAM; 50% memory of LLaMa.CPP on local DRAM, 50% memory of LLaMa.CPP on CXL
Results on the simulated environment for reference: llama+redis-2.png

(3) 100% memory of Redis on local DRAM; 0% memory of LLaMa.CPP on local DRAM, 100% memory of LLaMa.CPP on CXL
Results on the simulated environment for reference: llama+redis-3.png
```
