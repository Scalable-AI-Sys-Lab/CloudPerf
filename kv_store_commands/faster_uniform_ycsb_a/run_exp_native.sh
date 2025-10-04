export FASTER_DIR=/data/Mercury_workloads/FASTER/cc/build/Release
export RESULT_DIR=/data/Mercury_workloads/results/kv_store/FASTER_UNIFORM_A

mkdir -p $RESULT_DIR

cd $FASTER_DIR
# the parameter 60 here specifies the running time
/usr/bin/time -pao $RESULT_DIR/result_time.txt ./pmem_benchmark 0 1 1 0 8000000 1000000000000000 0 60 >> $RESULT_DIR/result_app_perf.txt 2>> $RESULT_DIR/result_app_perf.txt &

# Find the PID of the 'pmem' process based on its name, selecting the last one
bc_pid=$(pgrep -f "pmem" | tail -n 1)

# Check if the process is still running
while kill -0 $bc_pid 2> /dev/null; do
    sleep 2  # Check every 5 seconds
done

# Process has stopped
echo "Process has stopped!"
echo "$(date '+%Y-%m-%d %H:%M:%S') Process has stopped!" >> $RESULT_DIR/process_status.log
