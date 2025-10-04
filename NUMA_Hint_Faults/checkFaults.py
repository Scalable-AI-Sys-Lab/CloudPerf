import time
import sys
import argparse

def read_numa_faults_value(key: str) -> int:
    value = 0
    with open("/proc/vmstat") as file:
        for line in file:
            if key in line:
                parts = line.split()
                if len(parts) > 1:
                    value = int(parts[1])
                break
    return value

def total_increase_remote_numa_faults(duration_in_seconds: int) -> int:
    initial_total_faults = read_numa_faults_value("numa_hint_faults")
    initial_top_tier_faults = read_numa_faults_value("numa_hint_faults_local")

    time.sleep(duration_in_seconds)

    final_total_faults = read_numa_faults_value("numa_hint_faults")
    final_top_tier_faults = read_numa_faults_value("numa_hint_faults_local")

    remote_faults_increase = (final_total_faults - final_top_tier_faults) - (initial_total_faults - initial_top_tier_faults)

    print(f"Total increase in Remote NUMA Faults over {duration_in_seconds} seconds: {remote_faults_increase}")
    return remote_faults_increase

def main():
    parser = argparse.ArgumentParser(description="Compute the total increase in remote NUMA faults over a duration.")
    parser.add_argument("--duration", type=int, required=True, help="Duration in seconds to measure the increase in remote NUMA faults.")
    args = parser.parse_args()

    duration = args.duration
    total_increase_remote_numa_faults(duration)

if __name__ == "__main__":
    main()
