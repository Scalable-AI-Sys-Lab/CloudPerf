# workloads installment
Please refer to the `install_all_workloads.md`

The commands of all workloads are under the directories of:

| Workload type | Directory          | Original Output Directory (file) |
|---------------|--------------------|----------------------------------|
| vectordb      | vectordb           | vectordb/client_output.log       |
| llama.cpp     | llama_cpp_commands | llama_output.log                 |
| dlrm          | dlrm_commands      | results/dlrm                     |
| tpch          | tpch_commands      | results/tpch                     |
| gapbs         | gapbs_commands     | results/gapbs                    |
| kv_store      | kv_store_commands  | results/kv_store                 |
| spark         | spark_commands     | results/spark                    |
| spec          | spec_commands      | results/spec                     |
| web           | web_commands       | results/web                      |


workload tips:
TPCH needs to run the `prepare.sh` first, since that will first load the file to the file cache, without the prepare, the time difference of round with loading and without loading is very high.

# Linux installment
please install this linux version
```shell
https://github.com/yiwenzhang92/linux
```

After install the new linux
```shell
cd ~/Mercury_workloads
mkdir cg_test
# rerun the code everytime you reboot!
sudo mount -t cgroup2 none cg_test
sudo mkdir cg_test/cg1
sudo mkdir cg_test/cg2
sudo mkdir cg_test/cg3
```
# How to adjust local DRAM capacity
```shell
vim <path_to_you_mounted_dir>/cg_test/cg_x/memory.per_numa_high
# change the corresponding value
```

# Python Env
please install this python env first, since you will utilize this env for multiple workloads
```shell
cd ~/Mercury_workloads
mkdir -p miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
        -O miniconda3/miniconda.sh
/usr/bin/bash miniconda3/miniconda.sh -b -u -p miniconda3
rm -rf miniconda3/miniconda.sh
miniconda3/bin/conda init zsh
miniconda3/bin/conda init bash
miniconda3/bin/conda create --name mercury python=3.9 ipython -y
source ~/.bashrc
```
# Workload info
| Workload type | Importance | cg_index |
|---------------|------------|----------| 
| vectordb      | 1          | 2        | 
| llama.cpp     |            | 3        |
| dlrm          |
| tpch          | 10         | 
| gapbs         |
| kv_store      | 9          | 
| spark         |
| spec          |
| web           |

# Description
In the motivation experiments, we will do four sets of experiments:

## (1) Workload runs alone (baseline)

Run the script
```shell
cd <directory>
./run_single_all.sh
python <analyze_script.py>
```
After the execution of the .sh file, run the .py file to get the result (.xlsx file)

!Attention: 

specify the local memory as **20GB** to get the baseline performance for contention experiment; 

specify the local memory as **500GB** to get the baseline performance for interference experiments.

| Workload type | Directory          | execution script                                          | analyze script                                                                                                                                                              | Output file of py                                                 |
|---------------|--------------------|-----------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------|
| vectordb      | vectordb           | [run_single_all.sh](vectordb/run_single_all.sh)           | [process_vector_single_data.py](vectordb/process_vector_single_data.py)<br/>[process_vector_single_data_20G.py](vectordb/process_vector_single_data_20G.py)                 | vectordb_single.xlsx<br/>vectordb_single_20G.xlsx                 |
| llama.cpp     | llama_cpp_commands | [run_single_all.sh](llama_cpp_commands/run_single_all.sh) | [process_llama_single_data.py](llama_cpp_commands/process_llama_single_data.py)<br/>[process_llama_single_data_20G.py](llama_cpp_commands/process_llama_single_data_20G.py) | llama_single.xlsx<br/>llama_single_20G.xlsx                       | 
| dlrm          | dlrm_commands      | [run_single_all.sh](dlrm_commands/run_single_all.sh)      | [process_dlrm_single_data.py](dlrm_commands/process_dlrm_single_data.py)<br/>[process_dlrm_single_data_20G.py](dlrm_commands/process_dlrm_single_data_20G.py)               | dlrm_single_summary.xlsx<br/> dlrm_single_summary_20G.xlsx        |
| tpch          | tpch_commands      | [run_single_all.sh](tpch_commands/run_single_all.sh)      | [process_tpch_single_data.py](tpch_commands/process_tpch_single_data.py)<br/> [process_tpch_single_data_20G.py](tpch_commands/process_tpch_single_data_20G.py)              | tpch_single_summary.xlsx<br/>tpch_single_summary_20G.xlsx         |
| gapbs         | gapbs_commands     | [run_single_all.sh](gapbs_commands/run_single_all.sh)     | [process_graph_single_data.py](gapbs_commands/process_graph_single_data.py)<br/> [process_graph_single_data_20G.py](gapbs_commands/process_graph_single_data_20G.py)        | graph_single_summary.xlsx<br/>graph_single_summary_20G.xlsx       |
| kv_store      | kv_store_commands  | [run_single_all.sh](kv_store_commands/run_single_all.sh)  | [process_kv_single_data.py](kv_store_commands/process_kv_single_data.py)<br/>[process_kv_single_data_20G.py](kv_store_commands/process_kv_single_data_20G.py)               | kv_store_single_summary.xlsx<br/>kv_store_single_summary_20G.xlsx |
| spark         | spark_commands     | [run_single_all.sh](spark_commands/run_single_all.sh)     | [process_spark_single_data.py](spark_commands/process_spark_single_data.py)<br/> [process_spark_single_data_20G.py](spark_commands/process_spark_single_data_20G.py)        | spark_single_summary.xlsx <br/>spark_single_summary_20G.xlsx      |
| spec          | spec_commands      | run_single_all.sh                                         |                                                                                                                                                                             |
| web           | web_commands       | run_single_all.sh                                         |                                                                                                                                                                             |


## (2) Intra-tier interference: LLaMa.CPP (local) + workloads (local)
In this experiment, there is no local memory capacity contention, there is only bw interference
- Under each <workload>_commands dir, there exist a script: `run_interference_all.sh`, this will run all workloads under this type;
- Please modify the address in the `<workload>_commands/paths.export` file
- Please make the local memory in the cg1 as 500GB

After the script execution of one workload type is done:
```shell
python process_interference_llama.py
python process_interference_<workload_name>.py
```

After the execution of all workload types is done:
```shell
cd general_commands
python process_interference.py
```


## (3) Inter-tier interference: LLaMa.CPP (remote) + workloads (local)

## (4) Local memory capacity contention: vectordb (local) + workloads (local)





