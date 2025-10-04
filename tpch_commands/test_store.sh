#!/bin/bash
export VECTORDB_DIR=/data/Mercury_workloads/vectordb

# Change ownership of the full directory and its contents
sudo chown -R jhlu $VECTORDB_DIR
# Loop through directories tpch_1 to tpch_22
# ./track_pid.sh &

dir="tpch_$i"
  
# clean the server to in case each time the vector first takes all local, there is no waste
sudo $VECTORDB_DIR/clean_server.sh
echo "restart the vector server"
sudo numactl --physcpubind=49-52,105-108 $VECTORDB_DIR/mer_vector_bw_all.sh 1 2>&1 | tee -a $VECTORDB_DIR/client_output.log


