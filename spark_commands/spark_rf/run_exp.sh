#!/bin/bash


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




# Change to HiBench directory
cd ../../spark_workloads/HiBench

# Create result directory if it doesn't exist
export RESULT_DIR=../../results/spark/spark_rf
mkdir -p $RESULT_DIR

# Run the rf workload
echo "start to run the benchmark"

source ../../miniconda3/etc/profile.d/conda.sh
conda activate spark

bin/workloads/ml/rf/spark/run.sh
sudo bash -c "cat ./report/hibench.report >> $RESULT_DIR/result_app_perf.txt"


cleanup_and_exit

