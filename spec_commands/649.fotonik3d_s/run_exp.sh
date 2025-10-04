EXPORTS_FILE="../paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

 
cd $private_pond_dir/cpu2017/649.fotonik3d_s

export RESULT_DIR=$BASE_RESULT_DIR/649.fotonik3d_s
mkdir -p $RESULT_DIR


# /usr/bin/time -pao $RESULT_DIR/result_app_perf.txt ./run_with_glibc.sh >> $RESULT_DIR/result_log.txt 2>> $RESULT_DIR/result_err.txt

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


