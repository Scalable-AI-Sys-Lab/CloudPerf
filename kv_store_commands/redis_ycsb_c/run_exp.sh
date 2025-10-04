# remember, you should run the prepare_exp.sh first, that will do the load first, this is run command

cd ../../YCSB
export RESULT_DIR=../results/kv_store/redis_ycsb_c

mkdir -p $RESULT_DIR
# sudo $GENERAL_COMMANDS_DIR/log_memory_usage -cg_idx $CGROUG_NUMBER -output_dir $RESULT_DIR &

export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))
export PATH=$JAVA_HOME/bin:$PATH

python3 ./bin/ycsb run redis -s -P workloads/workloadc -p "redis.host=127.0.0.1" -p "redis.port=6379" -p "threadcount=3" >> $RESULT_DIR/result_app_perf.txt 2>> $RESULT_DIR/result_app_perf.txt

while [ ! -z "$(pgrep -nf redis)" ]; do
    sudo kill $(pgrep -fn redis)
    sleep 1
done
sudo pkill -f "log_memory_usage"
