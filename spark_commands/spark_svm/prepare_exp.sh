EXPORTS_FILE="../paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HADOOP_HOME/share/hadoop/hdfs/*
export RESULT_DIR=$RESULT_BASE_DIR/spark_svm
# Create result directory if it doesn't exist
mkdir -p $RESULT_DIR

# Capture the current working directory
current_script_dir=$(pwd)
echo "current script dir: $current_script_dir"

sudo chown -R jhlu:jhlu $DATANODE_DIR
sudo chmod -R 755 $DATANODE_DIR

cd $HIBENCH_DIR
rm -f report/hibench.report
rm -rf $HDFS_DIR/datanode/*

$HADOOP_DIR/sbin/stop-all.sh
$SPARK_DIR/sbin/stop-all.sh

# PID tracking in the background
echo "start to track pid"

sudo $GENERAL_COMMANDS_DIR/track_pid.sh "spark" &
sudo $GENERAL_COMMANDS_DIR/log_memory_usage -cg_idx $CGROUG_NUMBER -output_dir $RESULT_DIR &

yes "Y" | $HADOOP_DIR/bin/hdfs namenode -format


echo "now run the start-dfs.sh"
$HADOOP_DIR/sbin/start-dfs.sh

echo "now run the start-yarn.sh"
$HADOOP_DIR/sbin/start-yarn.sh

# Leave safe mode explicitly
$HADOOP_DIR/bin/hdfs dfsadmin -safemode leave

echo "now run the start-master.sh"
$SPARK_DIR/sbin/start-master.sh

echo "now run the prepare.sh"
$HIBENCH_DIR/bin/workloads/ml/svm/prepare/prepare.sh