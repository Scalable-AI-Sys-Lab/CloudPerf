# cd /home/ubuntu/Private-Pond/cpu2017/619.lbm_s
# /usr/bin/time -pao /home/ubuntu/result_app_perf.txt ./cmd.sh >> /home/ubuntu/result_log.txt 2>> /home/ubuntu/result_err.txt



# there is no good way to fully track all of its memory, its speed is too fast. If use the track pid script, it will fail.
EXPORTS_FILE="../paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

# export private_pond_dir=/data/Mercury_workloads/Private-Pond 
cd $private_pond_dir/cpu2017/619.lbm_s

export RESULT_DIR=$BASE_RESULT_DIR/619.lbm_s
mkdir -p $RESULT_DIR

date +"%Y-%m-%d %H:%M:%S" >> $RESULT_DIR/result_app_perf.txt
/usr/bin/time -pao $RESULT_DIR/result_app_perf.txt ./cmd.sh >> $RESULT_DIR/result_log.txt 2>> $RESULT_DIR/result_err.txt &

mytest_pid=$(pgrep -f "mytest")
echo $mytest_pid > /home/jhlu/cg_test/cg1/cgroup.procs



#Monitor the my_test process
while kill -0 $mytest_pid 2> /dev/null; do
    # If the process is still running, wait for a bit
    sleep 3
done

cat $RESULT_DIR/result_app_perf.txt


