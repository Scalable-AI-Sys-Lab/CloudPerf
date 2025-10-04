EXPORTS_FILE="../paths.export"
# while read -r LINE
# do
#     export $LINE
# done < "$EXPORTS_FILE"

while read -r LINE; do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        echo "Exporting: $LINE"  # Debug line
        export $LINE
    fi
done < "$EXPORTS_FILE"

cd $private_pond_dir/cpu2017/638.imagick_s

export RESULT_DIR=$BASE_RESULT_DIR/638.imagick_s
sudo mkdir -p $RESULT_DIR

date +"%Y-%m-%d %H:%M:%S" >> $RESULT_DIR/result_app_perf.txt
/usr/bin/time -pao $RESULT_DIR/result_app_perf.txt ./cmd.sh >> $RESULT_DIR/result_log.txt 2>> $RESULT_DIR/result_err.txt &


mytest_pid=$(pgrep -f "mytest")
sudo bash -c "echo $mytest_pid > $CGROUP_DIR/cgroup.procs"




#Monitor the my_test process
while kill -0 $mytest_pid 2> /dev/null; do
    # If the process is still running, wait for a bit
    sleep 3
done

cat $RESULT_DIR/result_app_perf.txt
