# I did not put the remove redis part because that will cause conflict with run_contention_all.sh
# So we clean it at the end of run_exp.sh
cd ../../redis
src/redis-server redis.conf > /dev/null 2> /dev/null < /dev/null & 
cd ..
sleep 5

cd YCSB
sed -i 's/recordcount=.*/recordcount=5000000/' workloads/workloada
sed -i 's/operationcount=.*/operationcount=15000000/' workloads/workloada
sed -i 's/requestdistribution=.*/requestdistribution=zipfian/' workloads/workloada

export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))
export PATH=$JAVA_HOME/bin:$PATH

python3 ./bin/ycsb load redis -s -P workloads/workloada -p "redis.host=127.0.0.1" -p "redis.port=6379" -p "threadcount=3"
