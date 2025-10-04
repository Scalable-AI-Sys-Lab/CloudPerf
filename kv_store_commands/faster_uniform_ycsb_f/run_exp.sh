export FASTER_DIR=../../FASTER/cc/build/Release

cd $FASTER_DIR

export RESULT_DIR=../../../../results/kv_store/faster_uniform_ycsb_f
mkdir -p $RESULT_DIR

sudo bash -c "echo 'start:'"
echo "$(date '+%Y-%m-%d %H:%M:%S')" >> $RESULT_DIR/result_time.txt
echo "$(date '+%Y-%m-%d %H:%M:%S')" >> $RESULT_DIR/result_app_perf.txt

# the paramater 60 here specifies the running time
/usr/bin/time -pao $RESULT_DIR/result_time.txt ./pmem_benchmark 5 1 1 0 8000000 1000000000000000 0 60 >> $RESULT_DIR/result_app_perf.txt 2>> $RESULT_DIR/result_app_perf.txt

echo "Process has stopped!"