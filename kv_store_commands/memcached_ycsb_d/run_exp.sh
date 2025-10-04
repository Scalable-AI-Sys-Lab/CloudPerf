EXPORTS_FILE="../paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"


export RESULT_DIR=$BASE_KV_RESULT_DIR/memcached_ycsb_d

# remember, you should run the prepare_exp.sh first, that will do the load first, this is run command
mkdir -p $RESULT_DIR
cd $YCSB_DIR

sudo $GENERAL_COMMANDS_DIR/log_memory_usage -cg_idx $CGROUG_NUMBER -output_dir $RESULT_DIR &

python3 ./bin/ycsb run memcached -s -P ./workloads/workloadd -p "memcached.hosts=127.0.0.1" -p "threadcount=2" >> $RESULT_DIR/result_app_perf.txt 2>> $RESULT_DIR/result_app_perf.txt
sudo pkill -f "log_memory_usage"
sudo systemctl stop memcached.service
