# Description
In this set of experiments, you would run the DLRM and Redis together.
We would use the conda environment, and build the model by ourselves. 
But you only need to wait for one iteration while running the command under the `save the model` section,
then you would get the model, whose name is `it_0_crkModel_cpu_num2000_000_bat_2_GBS_524288_dal_2_oal_4.pt`, we would use that to do the inference.
The command under the `Inference infinitely` section will let the dlrm do the inference forever, which may be helpful for you to collect the data.
Others are identical, whether under the Inference infinitely section or the Inference section.

The experiment on simulated experiment, native linux, is shown on the `dlrm+redis-native.png` file

# How to run Redis
Every time you run the redis, you would first start the server by running `run_redis.sh`, then store all the data by running `start_memtier_dlrm.sh`.
If you want to start collecting the data, you would run the `run_memtier_dlrm.sh`
```sh
# start redis
./run_redis.sh

# store all the data into the redis
./start_memtier_dlrm.sh

# keep the memtier-benchmark running
./run_memtier_dlrm.sh
```


# create environment
```shell
conda create --prefix /data/condaenvs/dlrm -y python=3.10
conda activate /data/condaenvs/dlrm
pip install -r requirements.txt

cd /data
git clone https://github.com/JhengLu/dlrm_my.git
cd dlrm_my

# process data
cd torchrec_dlrm
wget http://go.criteo.net/criteo-research-kaggle-display-advertising-challenge-dataset.tar.gz

mkdir criteo-research-kaggle

tar zxvf criteo-research-kaggle-display-advertising-challenge-dataset.tar.gz -C criteo-research-kaggle


mkdir criteo-research-kaggle-output
# Preprocess the dataset to numpy files.
python -m torchrec.datasets.scripts.npy_preproc_criteo --input_dir ./criteo-research-kaggle --output_dir ./criteo-research-kaggle-output --dataset_name criteo_kaggle



```

# Save the model
```shell
cd torchrec_dlrm
mkdir log
mkdir model
bash -c \
   'export PREPROCESSED_DATASET=./criteo-research-kaggle-output && \
    export GLOBAL_BATCH_SIZE=524288 && \
    export WORLD_SIZE=2 && \
    torchx run -s local_cwd dist.ddp -j 1x1 --script dlrm_testonly_savecpu.py -- \
        --in_memory_binary_criteo_path $PREPROCESSED_DATASET \
        --pin_memory \
        --batch_size $((GLOBAL_BATCH_SIZE / WORLD_SIZE)) \
        --learning_rate 1.0 \
        --dataset_name criteo_kaggle \
        --embedding_dim 512 \
        --dense_arch_layer_sizes 10240,512 \
        --over_arch_layer_sizes 4096,4096,4096,1 \
        --model_name crkModel_cpu_num2000_000_bat_2_GBS_524288_dal_2_oal_4.pt \
        --num_embeddings 2000_000 2>&1 | tee log/saveModel.log'

```

# Inference
```shell
numactl --physcpubind=49-55,105-111  bash -c \
   'export PREPROCESSED_DATASET=./criteo-research-kaggle-output && \
    export GLOBAL_BATCH_SIZE=524288 && \
    export WORLD_SIZE=2 && \
    torchx run -s local_cwd dist.ddp -j 1x1 --script dlrm_testonly_display_cpu.py -- \
        --in_memory_binary_criteo_path $PREPROCESSED_DATASET \
        --pin_memory \
        --batch_size $((GLOBAL_BATCH_SIZE / WORLD_SIZE)) \
        --learning_rate 1.0 \
        --dataset_name criteo_kaggle \
        --embedding_dim 512 \
        --dense_arch_layer_sizes 10240,512 \
        --over_arch_layer_sizes 4096,4096,4096,1 \
        --model_name it_0_crkModel_cpu_num2000_000_bat_2_GBS_524288_dal_2_oal_4.pt \
        --num_embeddings 2000_000' 

```
# Inference infinitely
```shell
numactl --physcpubind=49-55,105-111 bash -c \
   'export PREPROCESSED_DATASET=./criteo-research-kaggle-output && \
    export GLOBAL_BATCH_SIZE=524288 && \
    export WORLD_SIZE=2 && \
    torchx run -s local_cwd dist.ddp -j 1x1 --script dlrm_inference_infinity.py -- \
        --in_memory_binary_criteo_path $PREPROCESSED_DATASET \
        --pin_memory \
        --batch_size $((GLOBAL_BATCH_SIZE / WORLD_SIZE)) \
        --learning_rate 1.0 \
        --dataset_name criteo_kaggle \
        --embedding_dim 512 \
        --dense_arch_layer_sizes 10240,512 \
        --over_arch_layer_sizes 4096,4096,4096,1 \
        --model_name it_0_crkModel_cpu_num2000_000_bat_2_GBS_524288_dal_2_oal_4.pt \
        --num_embeddings 2000_000'

```
