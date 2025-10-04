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
        --num_embeddings 2000_000' &

echo $! > /home/jhlu/cg_test/cg4/cgroup.procs