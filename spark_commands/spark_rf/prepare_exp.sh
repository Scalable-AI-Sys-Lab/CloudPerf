export HADOOP_HOME=$(realpath ../../spark_workloads/hadoop) 
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HADOOP_HOME/share/hadoop/hdfs/*

export DATANODE_DIR=../../spark_workloads/hdfs/datanode
sudo chmod -R 755 $DATANODE_DIR

export HIBENCH_DIR=$(realpath ../../spark_workloads/HiBench)
# cd $HIBENCH_DIR
rm -f ../../spark_workloads/HiBench/report/hibench.report
rm -rf ../../spark_workloads/hdfs/datanode/*

pushd ../../spark_workloads/hadoop > /dev/null
./sbin/stop-all.sh
popd > /dev/null

pushd ../../spark_workloads/spark > /dev/null
./sbin/stop-all.sh
popd > /dev/null

# PID tracking in the background
# echo "start to track pid"

# sudo $GENERAL_COMMANDS_DIR/track_pid.sh "spark" &
# sudo $GENERAL_COMMANDS_DIR/log_memory_usage -cg_idx $CGROUG_NUMBER -output_dir $RESULT_DIR &

pushd ../../spark_workloads/hadoop > /dev/null

yes "Y" | ./bin/hdfs namenode -format
echo "now run the start-dfs.sh"
./sbin/start-dfs.sh

echo "now run the start-yarn.sh"
./sbin/start-yarn.sh

# Leave safe mode explicitly
./bin/hdfs dfsadmin -safemode leave

popd > /dev/null


pushd ../../spark_workloads/spark > /dev/null

echo "now run the start-master.sh"
./sbin/start-master.sh

popd > /dev/null


source ../../miniconda3/etc/profile.d/conda.sh
conda activate spark

pushd ../../spark_workloads/HiBench > /dev/null

echo "now run the prepare.sh"
bin/workloads/ml/rf/prepare/prepare.sh

popd > /dev/null