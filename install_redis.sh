apt install tcl

wget https://github.com/antirez/redis/archive/6.0.3.zip
unzip 6.0.3.zip
mv redis-6.0.3 redis
cd redis
make distclean # important!
make
make test