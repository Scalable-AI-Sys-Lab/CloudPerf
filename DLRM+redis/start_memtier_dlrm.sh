numactl --physcpubind=46-48,102-104 ./memtier_benchmark -t 20 -n 100000 --ratio 1:0 -c 20 -x 1 --key-pattern R:R --hide-histogram --distinct-client-seed -d 13000 --pipeline=1000 --authenticate=1234
