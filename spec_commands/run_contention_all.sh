#!/bin/bash

EXPORTS_FILE="./paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"

# Define directories and paths
export VECTORDB_DIR=/data/Mercury_workloads/vectordb

# Function to clean the server
clean_server() {
  sudo $VECTORDB_DIR/clean_server.sh
}

# Change ownership of the full directory and its contents
sudo chown -R jhlu $VECTORDB_DIR

# Array of SPEC benchmarks
# spec_benchmarks=("602.gcc_s" "603.bwaves_s" "605.mcf_s" "607.cactuBSSN_s" "619.lbm_s" "631.deepsjeng_s" "638.imagick_s" "649.fotonik3d_s" "654.roms_s" "657.xz_s")
# spec_benchmarks=("603.bwaves_s" "605.mcf_s" "607.cactuBSSN_s" "619.lbm_s")
# spec_benchmarks=("631.deepsjeng_s" "638.imagick_s" "649.fotonik3d_s" "654.roms_s" "657.xz_s")

# spec_benchmarks=("605.mcf_s" "607.cactuBSSN_s")  # For testing specific benchmarks
spec_benchmarks=("602.gcc_s")
# Function to run SPEC workloads with vector contention
run_spec_with_vector_contention() {
  for benchmark in "${spec_benchmarks[@]}"; do
    # Change to the benchmark directory
    cd "$benchmark" || { echo "Failed to enter directory $benchmark"; exit 1; }

    # Check if run_exp.sh exists and is executable
    if [[ -x "./run_exp.sh" ]]; then
      # Loop through each run (e.g., run 1 to 3)
      for run in {1..3}; do
        # Clean the server before each run
        clean_server

        # Start the vector workload in the background (contention workload)
        echo "Restarting the Vector server (Run $run)..."
        sudo numactl --physcpubind=$LLAMA_CPP_CORE $VECTORDB_DIR/mer_vector_bw_all.sh 1

        # Capture the PID of the vector server to ensure it can be stopped later
        vector_pid=$!

        # Start tracking the SPEC workload
        echo "Running ${benchmark} (Run $run)"
        sudo bash -c "echo 'Running ${benchmark} (Run $run)' >> $VECTORDB_DIR/client_output.log"

        # Run the SPEC script with numactl for CPU binding
        sudo numactl --physcpubind=$WORKLOAD_CORE ./run_exp.sh

        # Stop the vector server after the SPEC workload finishes
        kill -9 $vector_pid
        wait $vector_pid 2>/dev/null  # Ensure background process is stopped

        echo "Finished ${benchmark} (Run $run), Vector contention stopped."
        echo "Finished ${benchmark} (Run $run), Vector contention stopped." >> $VECTORDB_DIR/client_output.log
      done
    else
      echo "run_exp.sh not found or not executable in $benchmark"
    fi

    # Go back to the parent directory after processing the benchmark
    cd ..
  done
}

# Trap SIGINT and SIGTERM to stop all child processes gracefully
trap 'cleanup_and_exit' SIGINT SIGTERM

cleanup_and_exit() {
    echo "Stopping all running processes..."

    # Stop vector workload
    clean_server

    # Append new content to vector_contention_output.log instead of overwriting
    cat $VECTORDB_DIR/client_output.log >> vector_contention_output.log

    # Exit the script
    exit 0
}

# Main script execution
echo "Starting SPEC workloads with Vector contention..."
rm $VECTORDB_DIR/client_output.log

# Run the SPEC workloads with vector contention
run_spec_with_vector_contention
cleanup_and_exit

echo "All SPEC workloads executed with Vector contention."
