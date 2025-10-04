#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# 1. Enable NUMA demotion
echo 0 > /sys/kernel/mm/numa/demotion_enabled

# 2. Set NUMA memory tiering mode
echo 1 > /proc/sys/kernel/numa_balancing

# 3. Set zone_reclaim_mode
echo 0 > /proc/sys/vm/zone_reclaim_mode

echo "TPP is disabled"
