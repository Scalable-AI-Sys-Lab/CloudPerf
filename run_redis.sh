numactl --physcpubind=46-48,102-104 /home/jhlu/redis/src/redis-server /home/jhlu/redis/redis.conf &
echo $! > /home/jhlu/cg_test/cg1/cgroup.procs
