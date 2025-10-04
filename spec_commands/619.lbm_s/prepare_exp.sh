# cd /home/ubuntu
# rm -f result_*
# cd /home/ubuntu/Private-Pond/cpu2017/619.lbm_s
# sed -i 's|export OMP_NUM_THREADS=.*|export OMP_NUM_THREADS=8|' ./cmd.sh


# cd /home/ubuntu
# rm -f result_*
export private_pond_dir=/data/Mercury_workloads/Private-Pond 
cd $private_pond_dir/cpu2017/619.lbm_s
sed -i 's|export OMP_NUM_THREADS=.*|export OMP_NUM_THREADS=8|' ./cmd.sh

