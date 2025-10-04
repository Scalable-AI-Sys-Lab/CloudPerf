#!/bin/bash
while true; do
    numactl --physcpubind=46-48,102-104 ./memtier_benchmark -t 20 -n 100000 --ratio 1:4 -c 40 -x 1 --key-pattern R:R --hide-histogram --distinct-client-seed -d 4000 --pipeline=1000 --authenticate=1234
done
