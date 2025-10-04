```shell
git clone https://github.com/yiwenzhang92/linux.git

# get the source code (example is for v6.6-rc6) -> move to another one
# tar -xzf v6.6-rc6.tar.gz -C linux-6.6-rc6-new --strip-components=1

 
# install dependencies for kernel build
yum install ncurses-devel bison flex elfutils-libelf-devel openssl-devel dwarves
 
# use a bigger disk for kernel build on CloudLab -> since original disk is very small
cd linux/
sudo dnf module remove --all nvidia-driver
sudo dnf module reset nvidia-driver
# dkms status  --> nvidia/535.154.05, 4.18.0-513.11.1.el8_9.x86_64, x86_64: installed
dkms remove nvidia/535.154.05 --all

# to solve this problem: dkms autoinstall on 6.6.0-rc6/x86_64 failed for nvidia(10)


make mrproper
make clean
rm /boot/*6.6*

# 'make mrproper' is the 'make clean' in kernel build; note it alsos removes '.config' file
### if you want to make with the old configs, we should use the final, hasan one

cp /boot/config-`uname -r` .config
yes '' | make oldconfig

###
# make menuconfig / xconfig / oldconfig / localmodconfig
# menuconfig will install too many drivers, eating up too much disk space that usual CloudLab node (sda1) can't hold
# thus we use localmodconfig, which only install the existing drivers the current linux has; do the following 2 cmds:
# make olddefconfig
# make localmodconfig
# ^ The above 2 cmds is a combo (to avoid hitting Enter too many times)! (Ref: https://stackoverflow.com/questions/47049230/linux-kernel-build-perform-make-localmodconfig-non-interactive-way) (you may still need to hit Enter a few times)
 
 
# disable SYSTEM_TRUSTED_KEYS and SYSTEM_REVOCATION_KEYS 
# (ref: https://askubuntu.com/questions/1329538/compiling-the-kernel-5-11-11)
# This step is indeed needed
scripts/config --disable SYSTEM_TRUSTED_KEYS
scripts/config --disable SYSTEM_REVOCATION_KEYS
 
#scripts/config --disable CONFIG_DEBUG_INFO_BTF
 
 
# Note: although 'make' as root is not recommended, i encountered permission denied errors;
# so execute everything in root
# Note: might need to hit 'Enter' a few times during make; only hit 'Enter'
make -j56
make headers_install
make modules_install
make install
# make -j32 && make headers_install && make modules_install && make install
reboot
 
# after reboot, use 'uname -r' to check whether the new kernel has been loaded
uname -r

## if after reboot, the kernel is not updated to the new one, try:
# the grub of cloudlab can not work, the original one could work
grubby --default-kernel
grubby --info=ALL

# change to the index of linux you want 
grubby --set-default-index=0
# sudo grubby --set-default /boot/vmlinuz-6.6.0-rc6+
reboot



```


# Places need for modification
first place needs to change:

https://elixir.bootlin.com/linux/v6.6.16/source/mm/vmscan.c#L2798. -> change to 0

```sh
vim vmscan.c
```

.no_demotion = 0

Second:

https://elixir.bootlin.com/linux/v6.6.16/source/mm/memory-tiers.c#L294

```sh
vim memory-tiers.c
```



```cpp
int next_demotion_node(int node)
{
	
  // #slower-tier = 0  <-- this place!
	target = #slower-tier;
	rcu_read_unlock();

	return target;
}
```



Third step:

```sh
vim memory-tiers.c
```



```cpp
	//// Hack with harcoded toptier  -> node 1 as local, so we should set it as 1
	if (node == 1)
		return true;
	else
		return false;
	////
```





# Enable TPP
Everytime after reboot, run the following commands to enable TPP
The cg_test directory is used to adjust the local memory limit for specific apps
```shell

echo 1 > /sys/kernel/mm/numa/demotion_enabled
 
# 2. set numa memory tiering mode
echo 2 > /proc/sys/kernel/numa_balancing
 
# 3 set zone_reclaim_mode
echo 7  > /proc/sys/vm/zone_reclaim_mode

sudo swapoff -a

#sudo modprobe msr 

#sudo wrmsr 0x620 0x0101

# clear caches
sudo -s
sync; echo 1 > /proc/sys/vm/drop_caches
sync; echo 2 > /proc/sys/vm/drop_caches
sync; echo 3 > /proc/sys/vm/drop_caches

mount -t cgroup2 none cg_test

```

