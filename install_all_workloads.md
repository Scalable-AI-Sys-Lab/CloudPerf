# What you should modify
please modify the `all_config.export` to fit your machine

- WORKLOAD_CORE for all workloads in the table
- LLAMA_CPP_CORE for llama.cpp
- VECTORDB_CORE for vectordb
# Private-pond (includes the gapbs and spec)


```sh
cd ~/Mercury_workloads
pip install gdown                            
python3 -m gdown https://drive.google.com/uc?id=11QP5AV3SHCYZJflz5YESrbhdy4H5Zj9A
tar -xvzf Private-Pond.tar.gz

```

# Graph data resides in the Private-pond dir

```sh
cd ~/Mercury_workloads/Private-pond
cd Private-Pond/gapbs/gapbs/benchmark/graphs
```



# tpc-h

**Install**

```sh
# tpc-h
sudo yum install -y postgresql-devel readline-devel zlib-devel openssl-devel libxslt-devel
sudo yum install -y wxBase3 wxGTK3 wxGTK3-devel wxGTK3-media

cd ~/Mercury_workloads
mkdir tpch
cd tpch
wget http://ftp.postgresql.org/pub/source/v9.3.0/postgresql-9.3.0.tar.gz
tar zxvf postgresql-9.3.0.tar.gz
cd postgresql-9.3.0/
CFLAGS="-fno-omit-frame-pointer -rdynamic -O2" ./configure --prefix=/usr/local --enable-debug
make -j$(grep -c ^processor /proc/cpuinfo)
sudo make install

cd .. # now you are under Mercury_workloads/tpch
git clone https://github.com/pgadmin-org/pgadmin3.git
cd pgadmin3
./bootstrap
CXXFLAGS="-Wno-narrowing" ./configure --prefix=/usr --with-wx-version=3.0 --with-openssl=no
sudo sed -i "s|protected:||" /usr/include/wx-3.0/wx/unix/stdpaths.h
make -j$(grep -c ^processor /proc/cpuinfo)
sudo make install

cd .. # now you are under Mercury_workloads/tpch
git clone https://github.com/JhengLu/pg-tpch.git

sudo chown -R $(whoami) pg-tpch/

cd ../..
sudo chown -R $(whoami) Mercury_workloads/

cd ~/Mercury_workloads/tpch/pg-tpch
./tpch_prepare
# Attention! after it generates the pgdata10GB folder (typically in /home/user_name), check the shared_buffers line in postgresql.conf
```

**clean**
```shell
pkill -f tpch
```








# Mercury_wordloads

```sh
# remember to give the ownership
sudo chown -R $(whoami) <dir_to_Mercury_workloads>/Mercury_workloads/
```



# KV_store

## Redis

```sh
# redis
cd ~/Mercury_workloads
wget https://github.com/redis/redis/archive/refs/tags/7.2.3.tar.gz
tar -xzvf 7.2.3.tar.gz
mv redis-7.2.3 redis
cd redis
make -j8
sudo bash -c "echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf"
sed -i -e '$a save ""' redis.conf

```



## Faster

**install**

```sh
sudo yum install tbb-devel
sudo yum install libaio-devel
sudo yum install numactl-devel

cd ~/Mercury_workloads
git clone https://github.com/yuhong-zhong/FASTER.git
cd FASTER/cc
mkdir -p build/Release
cd build/Release
cmake -DCMAKE_BUILD_TYPE=Release ../..
make pmem_benchmark

```

## Memcached

**install**

```sh
sudo yum install memcached -y
```
## YCSB

**install**

```sh
cd ~/Mercury_workloads
git clone https://github.com/brianfrankcooper/YCSB.git
cd YCSB
sudo yum install -y java-11-openjdk-devel

export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))
export PATH=$JAVA_HOME/bin:$PATH

mvn -pl site.ycsb:redis-binding -am clean package
mvn -pl site.ycsb:memcached-binding -am clean package

```




# Spark

## hadoop
**Install**



```sh
cd Mercury_workloads
mkdir spark_workloads
cd spark_workloads


sudo bash -c "echo 'export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))' >> /etc/environment"
source /etc/environment



wget https://dlcdn.apache.org/hadoop/common/hadoop-3.2.4/hadoop-3.2.4.tar.gz
tar -xzvf hadoop-3.2.4.tar.gz
mv hadoop-3.2.4 hadoop
rm hadoop-3.2.4.tar.gz


cd hadoop

# core-site.xml
sed -i "s|<configuration>||" etc/hadoop/core-site.xml
sed -i "s|</configuration>||" etc/hadoop/core-site.xml
echo "<configuration>" >> etc/hadoop/core-site.xml
echo "<property>" >> etc/hadoop/core-site.xml
echo "<name>fs.defaultFS</name>" >> etc/hadoop/core-site.xml
echo "<value>hdfs://localhost:8020</value>" >> etc/hadoop/core-site.xml
echo "</property>" >> etc/hadoop/core-site.xml
echo "</configuration>" >> etc/hadoop/core-site.xml

# hdfs-site.xml
mkdir -p ../hdfs/datanode
chmod -R 777 ../hdfs/datanode
datanode_dir="$(realpath ../hdfs/datanode)"

sed -i "s|<configuration>||" etc/hadoop/hdfs-site.xml
sed -i "s|</configuration>||" etc/hadoop/hdfs-site.xml
cat >> etc/hadoop/hdfs-site.xml <<- End
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>$datanode_dir</value>
    </property>
</configuration>
End


ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys


# Formate the filesystem
bin/hdfs namenode -format

echo 'export PDSH_RCMD_TYPE=ssh' >> ~/.bashrc
source ~/.bashrc

# mapred-site.xml

sed -i "s|<configuration>||" etc/hadoop/mapred-site.xml
sed -i "s|</configuration>||" etc/hadoop/mapred-site.xml


HADOOP_MAPRED_HOME="$HADOOP_MAPRED_HOME"
HADOOP_INSTALL_DIR="$(pwd)"
cat >> etc/hadoop/mapred-site.xml <<- End
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_INSTALL_DIR</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_INSTALL_DIR</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_INSTALL_DIR</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*,$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/common/*,$HADOOP_MAPRED_HOME/share/hadoop/common/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/yarn/*,$HADOOP_MAPRED_HOME/share/hadoop/yarn/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/hdfs/*,$HADOOP_MAPRED_HOME/share/hadoop/hdfs/lib/*</value>
    </property>
</configuration>
End


# yarn-site.xml

sed -i "s|<configuration>||" etc/hadoop/yarn-site.xml
sed -i "s|</configuration>||" etc/hadoop/yarn-site.xml
cat >> etc/hadoop/yarn-site.xml <<- End
<configuration>
    <property>
        <name>yarn.nodemanager.disk-health-checker.max-disk-utilization-per-disk-percentage</name>
        <value>97</value> <!-- Set to 99 or another appropriate value -->
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
    </property>
</configuration>
End
```



[//]: # (enable the calling hadoop command anywhere)

[//]: # (# TODO)

[//]: # (```sh)

[//]: # (echo 'export HADOOP_HOME=/data/Mercury_workloads/spark_workloads/hadoop' >> ~/.bashrc)

[//]: # (echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop' >> ~/.bashrc)

[//]: # (echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> ~/.bashrc)

[//]: # (source ~/.bashrc)

[//]: # ()
[//]: # (```)



## Spark

```sh
cd Mercury_workloads/spark_workloads
wget https://archive.apache.org/dist/spark/spark-2.4.0/spark-2.4.0-bin-hadoop2.7.tgz
tar -xzvf spark-2.4.0-bin-hadoop2.7.tgz
mv spark-2.4.0-bin-hadoop2.7 spark
cd spark
echo "export SPARK_HOME=$(pwd)" >> ~/.bashrc
echo 'export PATH=$PATH:$SPARK_HOME/bin' >> ~/.bashrc
source ~/.bashrc
```



## Maven

```shell
cd Mercury_workloads/spark_workloads
wget https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.6.3/apache-maven-3.6.3-bin.tar.gz
tar -xzvf apache-maven-3.6.3-bin.tar.gz
mv apache-maven-3.6.3 apache-maven
cd apache-maven
echo "export M2_HOME=$(pwd)" >> ~/.bashrc
echo 'export PATH=$PATH:$M2_HOME/bin' >> ~/.bashrc
source ~/.bashrc

```





## hibench

```sh
cd Mercury_workloads
miniconda3/bin/conda create --name spark python=2.7 ipython -y

cd spark_workloads
sudo yum install bc scala 

wget https://github.com/Intel-bigdata/HiBench/archive/refs/tags/v7.1.1.tar.gz
tar -xzvf v7.1.1.tar.gz
mv HiBench-7.1.1 HiBench
cd HiBench

cp hadoopbench/mahout/pom.xml hadoopbench/mahout/pom.xml.bak
cat hadoopbench/mahout/pom.xml \
    | sed 's|<repo2>http://archive.cloudera.com</repo2>|<repo2>https://archive.apache.org</repo2>|' \
    | sed 's|cdh5/cdh/5/mahout-0.9-cdh5.1.0.tar.gz|dist/mahout/0.9/mahout-distribution-0.9.tar.gz|' \
    | sed 's|aa953e0353ac104a22d314d15c88d78f|09b999fbee70c9853789ffbd8f28b8a3|' \
    > ./pom.xml.tmp
mv ./pom.xml.tmp hadoopbench/mahout/pom.xml

mvn -Phadoopbench -Psparkbench -Dspark=2.4 -Dscala=2.11 clean package

HADOOP_INSTALL_DIR="$(realpath ../hadoop)"
cp conf/hadoop.conf.template conf/hadoop.conf
sed -i "s|^hibench.hadoop.home.*|hibench.hadoop.home $HADOOP_INSTALL_DIR|" conf/hadoop.conf
echo "hibench.hadoop.examples.jar $HADOOP_INSTALL_DIR/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.4.jar" >> conf/hadoop.conf

cp conf/spark.conf.template conf/spark.conf
SPARK_INSTALL_DIR="$(realpath ../spark)"
sed -i "s|hibench.spark.home.*|hibench.spark.home $SPARK_INSTALL_DIR|" conf/spark.conf
sed -i "s|hibench.yarn.executor.num.*|hibench.yarn.executor.num 2|" conf/spark.conf
sed -i "s|hibench.yarn.executor.cores.*|hibench.yarn.executor.cores 2|" conf/spark.conf
sed -i "s|spark.executor.memory.*|spark.executor.memory 2g|" conf/spark.conf
sed -i "s|spark.driver.memory.*|spark.driver.memory 2g|" conf/spark.conf

echo "hibench.masters.hostnames localhost" >> conf/spark.conf
echo "hibench.slaves.hostnames localhost" >> conf/spark.conf

sed -i "s|hibench.scale.profile.*|hibench.scale.profile large|" conf/hibench.conf

```





```sh

```


# glibc, spec (Private-pond)


SPEC CPU

```sh
cd <dir>/Mercury_workloads/Private-Pond/cpu2017

```

```shell
wget http://ftp.gnu.org/gnu/libc/glibc-2.29.tar.gz
tar -xzvf glibc-2.29.tar.gz
cd glibc-2.29

# if there is some error, use this one
unset LD_LIBRARY_PATH


mkdir build
cd build
../configure --prefix=/opt/glibc-2.29
make -j$(nproc)
make install



#after this installment, use this line in the Private-Pond:
/opt/glibc-2.29/lib/ld-linux-x86-64.so.2 --library-path /opt/glibc-2.29/lib:/usr/lib64 ./fotonik3d_s_base.mytest-m64 > fotonik3d_s.log 2>> fotonik3d_s.err


#this part is critical
/opt/glibc-2.29/lib/ld-linux-x86-64.so.2 --library-path /opt/glibc-2.29/lib:/usr/lib64

```





**Gcc, libstdc++**

```sh
# gcc version with libstdc++ version

https://gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html


# downloand url
https://rpmfind.net/linux/rpm2html/search.php?query=libstdc%2B%2B(x86-64)



```



install the gcc from source to provide the libstdc++.so.6

```sh
cd <dir>/Mercury_workloads
wget https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.gz
tar -xzf gcc-12.2.0.tar.gz
cd gcc-12.2.0
./contrib/download_prerequisites
mkdir build
cd build

../configure --prefix=/opt/gcc-12.2 --enable-languages=c,c++ --disable-multilib

make -j$(nproc)

sudo make install
```



# (Web) renaissance

```sh
cd ~/Mercury_workloads
cd web_commands
wget https://github.com/renaissance-benchmarks/renaissance/releases/download/v0.14.2/renaissance-gpl-0.14.2.jar
```




# DLRM

```sh
# DLRM
cd <dir>/Mercury_workloads
#sudo apt-get install linux-tools-common linux-tools-generic linux-tools-`uname -r` -y
BASE_DIRECTORY_NAME="dlrm"

rm -rf $BASE_DIRECTORY_NAME
mkdir -p $BASE_DIRECTORY_NAME
cd $BASE_DIRECTORY_NAME
export BASE_PATH=$(pwd)
echo "DLRM-SETUP: FINISHED SETTING UP BASE DIRECTORY"

echo BASE_PATH=$BASE_PATH >> $BASE_PATH/paths.export


conda activate mercury
# export PYTHONNOUSERSITE=1 to avoid affect from ~/.local
conda install astunparse cffi cmake dataclasses future mkl mkl-include ninja \
        pyyaml requests setuptools six typing_extensions -y
conda install -c conda-forge jemalloc gcc=12.1.0 -y
pip install git+https://github.com/mlperf/logging
pip install onnx lark-parser hypothesis tqdm scikit-learn

# specify version is
pip install psutil==6.1.0
pip install torch==2.4.1+cpu torchvision==0.19.1+cpu torchaudio==2.4.1+cpu --index-url https://download.pytorch.org/whl/cpu

echo "DLRM-SETUP: FINISHED SETTING UP CONDA ENV"



# Set up DLRM inference test.
cd $BASE_PATH
git clone https://github.com/rishucoding/reproduce_isca23_cpu_DLRM_inference
cd reproduce_isca23_cpu_DLRM_inference
export DLRM_SYSTEM=$(pwd)
echo DLRM_SYSTEM=$DLRM_SYSTEM >> $BASE_PATH/paths.export
git clone https://github.com/IntelAI/models.git

cd models
# this version can work, in this dir models/recommendation/pytorch/dlrm/product should have the data_utils.py file
git checkout v2.11.0  

export MODELS_PATH=$(pwd)
echo MODELS_PATH=$MODELS_PATH >> $BASE_PATH/paths.export
mkdir -p models/recommendation/pytorch/dlrm/product

cp $BASE_PATH/../dlrm_commands/dlrm_patches/dlrm_data_pytorch.py \
    models/recommendation/pytorch/dlrm/product/dlrm_data_pytorch.py
cp $BASE_PATH/../dlrm_commands/dlrm_patches/dlrm_s_pytorch.py \
    models/recommendation/pytorch/dlrm/product/dlrm_s_pytorch.py
echo "DLRM-SETUP: FINISHED SETTING UP DLRM TEST"


```


# make sudo simpler

```sh
sudo visudo

jhlu     ALL=(ALL)      NOPASSWD: ALL

```


# Vectordb
```shell
sudo yum install nc

conda activate mercury
cd ~/Mercury_workloads/vectordb
pip install -r requirements.txt
python createIndexFlat.py


```


# llama.cpp
Install

```shell
cd ~/Mercury_workloads
source ~/.bashrc
conda activate mercury

git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
git checkout 1debe72737ea131cb52975da3d53ed3a835df3a6
# download
pip3 install -U "huggingface_hub[cli]"

cd models
huggingface-cli download TheBloke/Llama-2-70B-GGUF llama-2-70b.Q4_K_M.gguf --local-dir . --local-dir-use-symlinks False

cd ..
# build
make

```
please also modify the dir address in the files of `<dir>/Mercury_workloads/general_commands/llama_cpp_all.sh`


# Tools
```shell
cd <dir>/Mercury_workloads/general_commands
./compile.sh

```


# Interact it with Mercury

```shell
# Allows all users to access only user-space events (i.e., metrics that exclude kernel activity).
# So we do not need to use sudo to run mercury, since some app execution do not want sudo
echo 0 | sudo tee /proc/sys/kernel/perf_event_paranoid
echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
sudo chown -R $(whoami) /sys/fs/cgroup/
sudo chown -R $(whoami) ~/Mercury_workloads

```

# memtier_benchmark
```shell
sudo yum install autoconf automake pcre-devel

cd ~/Mercury_workloads
git clone https://github.com/JhengLu/memtier_benchmark_my.git
cd memtier_benchmark_my/
autoreconf -ivf
./configure
make 
sudo make install 

```

# pqos
```shell
cd ~/Mercury_workloads
git clone https://github.com/intel/intel-cmt-cat.git
cd intel-cmt-cat
git checkout b567f717b24ea63b6fa48eae5f96cd03efa06bfa
make
sudo make install

# to interact with the mercury, you should know which python it is using while making it.
# for example, the make output says this: -- Found Python3: /bin/python3.11 (found version "3.11.9") found components: Interpreter Development Development.Module Development.Embed
/bin/python3.11 -m ensurepip --upgrade
/bin/python3.11 -m pip install pqos==4.3.0
pip3 install pqos==4.3.0

```


# Colloid

```shell
cd ~
git clone https://github.com/JhengLu/colloid.git
sudo yum install ncurses-devel bison flex elfutils-libelf-devel openssl-devel dwarves
cd colloid
cd tpp/linux-6.3
sed -i 's/^#*CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-colloid"/' .config
scripts/config --disable SYSTEM_TRUSTED_KEYS
scripts/config --disable SYSTEM_REVOCATION_KEYS
sudo make -j32 bzImage
sudo make -j32 modules
sudo make modules_install
sudo make install


```