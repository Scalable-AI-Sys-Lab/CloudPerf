export RESULT_DIR=/data/Mercury_workloads/results/web/finagle-http
mkdir -p $RESULT_DIR

java -jar '../renaissance-gpl-0.14.2.jar' finagle-http -t 60 >> $RESULT_DIR/result_app_perf.txt 2>> $RESULT_DIR/result_app_perf.txt &

target_pid=$(pgrep -f "java")
echo $target_pid > /home/jhlu/cg_test/cg1/cgroup.procs

# Monitor the my_test process
while kill -0 $target_pid 2> /dev/null; do
    # If the process is still running, wait for a bit
    sleep 3
done

cat $RESULT_DIR/result_app_perf.txt

