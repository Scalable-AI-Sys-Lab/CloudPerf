apt-get update
sudo apt-get install build-essential autoconf automake libpcre3-dev libevent-dev pkg-config zlib1g-dev libssl-dev

yum update
yum install autoconf automake make gcc-c++
yum install pcre-devel zlib-devel libmemcached-devel libevent-devel openssl-devel
yum groupinstall 'Development Tools'


git clone https://github.com/RedisLabs/memtier_benchmark.git
cd memtier_benchmark
autoreconf -ivf
./configure
make
make install