#!/bin/bash
# Define variables for commonly used paths
export PG_TPCH_DIR=../../tpch/pg-tpch

# Change directory to the PG_TPCH_DIR and start the TPC-H query in the background
cd $PG_TPCH_DIR
./tpch_runone 1
target_pid=$!


