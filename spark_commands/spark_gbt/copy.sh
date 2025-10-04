EXPORTS_FILE="../run_paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

# export HIBENCH_DIR=/data/Mercury_workloads/spark_workloads/HiBench
# export HADOOP_DIR=/data/Mercury_workloads/spark_workloads/hadoop
# export HDFS_DIR=/data/Mercury_workloads/spark_workloads/hdfs
# export SPARK_DIR=/data/Mercury_workloads/spark_workloads/spark
# export HADOOP_HDFS_HOME=/data/Mercury_workloads/spark_workloads/hadoop


# export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.422.b05-2.el8.x86_64
#!/bin/bash

export RESULT_DIR=$RESULT_BASE_DIR/spark_gbt
trap 'cleanup_and_exit' SIGINT SIGTERM

cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Stop PID tracking
    if [ -f /tmp/track_pid_script.pid ]; then
        sudo kill -SIGTERM $(cat /tmp/track_pid_script.pid)
    fi
    sudo pkill -f "log_memory_usage"

    # Exit the script
    exit 0
}


# Create result directory if it doesn't exist
mkdir -p $RESULT_DIR

# Change to HiBench directory
cd $HIBENCH_DIR

# Run the gbt workload
echo "start to run the benchmark"

# bin/workloads/ml/gbt/spark/run.sh
sudo bash -c "cat $HIBENCH_DIR/report/hibench.report >> $RESULT_DIR/result_app_perf.txt"

cleanup_and_exit