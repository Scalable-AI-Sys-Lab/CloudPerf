import os
import re
import pandas as pd
import sys

# Path to the base directory where all the YCSB directories are located
base_dir = '../results/kv_store'  # Change this to the actual path where the directories are located

# List of directories to process
ycsb_dirs = [
    'redis_ycsb_a', 'redis_ycsb_b', 'redis_ycsb_c', 'redis_ycsb_d', 'redis_ycsb_e', 'redis_ycsb_f','redis_ycsb_uniform_a',
    'memcached_ycsb_a', 'memcached_ycsb_b', 'memcached_ycsb_c', 'memcached_ycsb_d', 'memcached_ycsb_f','memcached_uniform_ycsb_a',
    'faster_ycsb_a', 'faster_ycsb_b', 'faster_ycsb_c', 'faster_ycsb_f', 'faster_uniform_ycsb_a', 'faster_uniform_ycsb_b', 'faster_uniform_ycsb_c', 'faster_uniform_ycsb_f'
]

# Output file name
output_file = 'interference_kv_workload.xlsx'


# Number of latest entries to store
NUM_LAST_ENTRIES = 4  # Default value, can be changed dynamically

# Allow the user to specify the number of latest entries as an argument
if len(sys.argv) > 1:
    try:
        NUM_LAST_ENTRIES = int(sys.argv[1])
    except ValueError:
        print(f"Invalid number provided for the latest entries, defaulting to {NUM_LAST_ENTRIES}.")

# Define regex patterns for YCSB files
runtime_pattern = re.compile(r'\[OVERALL\], RunTime\(ms\), ([\d.]+)')
throughput_pattern = re.compile(r'\[OVERALL\], Throughput\(ops/sec\), ([\d.]+)')
# timestamp_pattern = re.compile(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')
memcached_timestamp_pattern = re.compile(r'Starting test\.\n(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')

redis_timestamp_pattern = re.compile(r'DBWrapper.*?\n(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')

# Define regex patterns for FASTER files
faster_setup_time_pattern = re.compile(r'Setup time: ([\d.]+) seconds')
faster_throughput_pattern = re.compile(r'Finished benchmark: ([\d.]+) ops/second/thread')
faster_timestamp_pattern = re.compile(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')

# Dictionary to hold DataFrames for each app
app_dataframes = {}

DROP_NUM = 1
# Iterate over each directory
for ycsb_dir in ycsb_dirs:
    result_file_path = os.path.join(base_dir, ycsb_dir, 'result_app_perf.txt')

    if os.path.exists(result_file_path):
        # Read the entire file content as a string
        with open(result_file_path, 'r') as file:
            content = file.read()

        if 'faster' in ycsb_dir:
            # Extract data for FASTER files
            timestamp_matches = faster_timestamp_pattern.findall(content)
            setup_time_matches = faster_setup_time_pattern.findall(content)
            throughput_matches = faster_throughput_pattern.findall(content)

            if len(timestamp_matches) >= NUM_LAST_ENTRIES and len(setup_time_matches) >= NUM_LAST_ENTRIES and len(throughput_matches) >= NUM_LAST_ENTRIES:
                # Get the last NUM_LAST_ENTRIES entries
                last_timestamps = timestamp_matches[-NUM_LAST_ENTRIES:-DROP_NUM]
                last_setup_times = setup_time_matches[-NUM_LAST_ENTRIES:-DROP_NUM]
                last_throughputs = throughput_matches[-NUM_LAST_ENTRIES:-DROP_NUM]

                # Create a DataFrame for the FASTER data
                app_dataframes[ycsb_dir] = pd.DataFrame({
                    'Timestamp': last_timestamps,
                    'Setup Time (s)': last_setup_times,
                    'Throughput (ops/sec)': last_throughputs
                })
            else:
                print(f"Missing data in {result_file_path}")
        elif 'memcached' in ycsb_dir:
            # Extract data for YCSB files
            runtime_matches = runtime_pattern.findall(content)
            throughput_matches = throughput_pattern.findall(content)
            all_timestamps = memcached_timestamp_pattern.findall(content)

            if len(runtime_matches) >= NUM_LAST_ENTRIES and len(throughput_matches) >= NUM_LAST_ENTRIES and len(all_timestamps) >= NUM_LAST_ENTRIES:
                # Get the last NUM_LAST_ENTRIES entries
                last_runtimes = runtime_matches[-NUM_LAST_ENTRIES:-DROP_NUM]
                last_throughputs = throughput_matches[-NUM_LAST_ENTRIES:-DROP_NUM]
                last_timestamps = all_timestamps[-NUM_LAST_ENTRIES:-DROP_NUM]

                # Create a DataFrame for the YCSB data
                app_dataframes[ycsb_dir] = pd.DataFrame({
                    'Timestamp': last_timestamps,
                    'RunTime (ms)': last_runtimes,
                    'Throughput (ops/sec)': last_throughputs
                })
            else:
                print(f"Missing data in {result_file_path}")
        elif 'redis' in ycsb_dir:
            # Extract data for YCSB files
            runtime_matches = runtime_pattern.findall(content)
            throughput_matches = throughput_pattern.findall(content)
            all_timestamps = redis_timestamp_pattern.findall(content)

            if len(runtime_matches) >= NUM_LAST_ENTRIES and len(throughput_matches) >= NUM_LAST_ENTRIES and len(all_timestamps) >= NUM_LAST_ENTRIES:
                # Get the last NUM_LAST_ENTRIES entries
                last_runtimes = runtime_matches[-NUM_LAST_ENTRIES:-DROP_NUM]
                last_throughputs = throughput_matches[-NUM_LAST_ENTRIES:-DROP_NUM]
                last_timestamps = all_timestamps[-NUM_LAST_ENTRIES:-DROP_NUM]

                # Create a DataFrame for the YCSB data
                app_dataframes[ycsb_dir] = pd.DataFrame({
                    'Timestamp': last_timestamps,
                    'RunTime (ms)': last_runtimes,
                    'Throughput (ops/sec)': last_throughputs
                })
            else:
                print(f"Missing data in {result_file_path}")
    else:
        print(f"File not found: {result_file_path}")

# Write each app's data to a separate sheet in the Excel file
with pd.ExcelWriter(output_file) as writer:
    for app_name, df in app_dataframes.items():
        df.to_excel(writer, sheet_name=app_name, index=False)

print(f"Data extraction complete. Results saved to {output_file}.")