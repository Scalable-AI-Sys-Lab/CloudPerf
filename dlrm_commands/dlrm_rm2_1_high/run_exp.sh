EXPORTS_FILE="../../dlrm/paths.export"
while read -r LINE
do
    export $LINE
done < "$EXPORTS_FILE"


export CONDA_PREFIX=../../miniconda3/envs/mercury
source ../../miniconda3/etc/profile.d/conda.sh
conda activate mercury


export MALLOC_CONF="oversize_threshold:1,background_thread:true,metadata_thp:auto,dirty_decay_ms:9000000000,muzzy_decay_ms:9000000000"
export KMP_AFFINITY=verbose,granularity=fine,compact,1,0
export KMP_BLOCKTIME=1
export OMP_NUM_THREADS=1
PyGenTbl='import sys; rows,tables=sys.argv[1:3]; print("-".join([rows]*int(tables)))'
PyGetCore='import sys; c=int(sys.argv[1]); print(",".join(str(2*i) for i in range(c)))'
PyGetHT='import sys; c=int(sys.argv[1]); print(",".join(str(2*i + off) for off in (0, 48) for i in range(c)))'

NUM_BATCH=50000
BS=8
# RESULTS_DIR=/data/Mercury_workloads/results/dlrm/$NUM_BATCH-iterations-$BS-batchsize
export RESULT_DIR=../../results/dlrm/dlrm_rm1_med
# RESULTS_NAME=$(date +%m%d)-$(date +%H%M%S)
INSTANCES=1
EXTRA_FLAGS=
GDB='gdb --args'
DLRM_SYSTEMS=$DLRM_SYSTEM

mkdir -p $RESULT_DIR
echo "Result dir is: $RESULT_DIR"
# sleep 5
# pushd ../../general_commands > /dev/null
# ./track_pid.sh "dlrm" &
# popd > /dev/null

# RM2_1, high
BOT_MLP=256-128-128
TOP_MLP=128-64-1
EMBS='128,1000000,60,120'
TEST_NAME="dlrm_rm2_1_high"
for e in $EMBS; do
    IFS=','; set -- $e; EMB_DIM=$1; EMB_ROW=$2; EMB_TBL=$3; EMB_LS=$4; unset IFS;
    # EMB_TBL=$(python -c "$PyGenTbl" "$EMB_ROW" "$EMB_TBL")
    EMB_TBL=$(conda run --prefix $CONDA_PREFIX python -c "$PyGenTbl" "$EMB_ROW" "$EMB_TBL")

    DATA_GEN="prod,$DLRM_SYSTEMS/datasets/reuse_high/table_1M.txt,$EMB_ROW"
    # sudo bash -c "/usr/bin/time -vo $RESULT_DIR/$TEST_NAME.time conda run --prefix $CONDA_PREFIX python -u $MODELS_PATH/models/recommendation/pytorch/dlrm/product/dlrm_s_pytorch.py --data-generation=$DATA_GEN --round-targets=True --learning-rate=1.0 --arch-mlp-bot=$BOT_MLP --arch-mlp-top=$TOP_MLP --arch-sparse-feature-size=$EMB_DIM --max-ind-range=40000000 --numpy-rand-seed=727 --inference-only --num-batches=$NUM_BATCH --data-size 100000000 --num-indices-per-lookup=$EMB_LS --num-indices-per-lookup-fixed=True --arch-embedding-size=$EMB_TBL --print-freq=10 --print-time --mini-batch-size=$BS --share-weight-instance=$INSTANCES $EXTRA_FLAGS 1> $RESULT_DIR/$TEST_NAME.stdout 2> $RESULT_DIR/$TEST_NAME.stderr"
    /usr/bin/time -vo $RESULT_DIR/$TEST_NAME.time conda run --prefix $CONDA_PREFIX python -u $MODELS_PATH/models/recommendation/pytorch/dlrm/product/dlrm_s_pytorch.py --data-generation=$DATA_GEN --round-targets=True --learning-rate=1.0 --arch-mlp-bot=$BOT_MLP --arch-mlp-top=$TOP_MLP --arch-sparse-feature-size=$EMB_DIM --max-ind-range=40000000 --numpy-rand-seed=727 --inference-only --num-batches=$NUM_BATCH --data-size 100000000 --num-indices-per-lookup=$EMB_LS --num-indices-per-lookup-fixed=True --arch-embedding-size=$EMB_TBL --print-freq=10 --print-time --mini-batch-size=$BS --share-weight-instance=$INSTANCES $EXTRA_FLAGS 1> $RESULT_DIR/$TEST_NAME.stdout 2> $RESULT_DIR/$TEST_NAME.stderr
done

# Stop PID tracking
if [ -f /tmp/track_pid_script.pid ]; then
    kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    echo "track pid script is stopped"
fi
pkill -f "track_pid.sh"

echo $(date '+%Y-%m-%d %H:%M:%S') >> $RESULT_DIR/result_app_perf.txt
cat $RESULT_DIR/$TEST_NAME.stdout >> $RESULT_DIR/result_app_perf.txt
# echo "Result dir is: $RESULT_DIR"
cat $RESULT_DIR/result_app_perf.txt