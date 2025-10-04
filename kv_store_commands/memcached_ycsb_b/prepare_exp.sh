EXPORTS_FILE="../paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"


# cd YCSB
sed -i 's/recordcount=.*/recordcount=5000000/' $YCSB_DIR/workloads/workloadb
sed -i 's/operationcount=.*/operationcount=5000000/' $YCSB_DIR/workloads/workloadb
sed -i 's/requestdistribution=.*/requestdistribution=zipfian/' $YCSB_DIR/workloads/workloadb

sudo sed -i 's/^CACHESIZE="[0-9]*"/CACHESIZE="8192"/' /etc/sysconfig/memcached
sudo systemctl restart memcached.service

# Find the PID of the 'bc' process based on its name, selecting the last one
# bc_pid=$(pgrep -f "memcached" | tail -n 1)
# # Write the PID to the file
# sudo bash -c "echo $bc_pid > $CGROUP_DIR/cgroup.procs"

# we have to use cd, otherwise there would be some problem because of the maven mechanism
cd $YCSB_DIR
# insert data
python3 ./bin/ycsb load memcached -s -P ./workloads/workloadb -p "memcached.hosts=127.0.0.1" -p "threadcount=2"
