import os
import re
import pandas as pd
from datetime import datetime

# Base directory for the results
base_directory = "../results/dlrm"

# Subdirectories to process
subdirectories = ["dlrm_rm1_high", "dlrm_rm1_low", "dlrm_rm1_med", "dlrm_rm2_1_high", "dlrm_rm2_1_low", "dlrm_rm2_1_med"]

# Dictionary to store the data
data = {}

# Define patterns to extract relevant data from the result_app_perf.txt files
patterns = {
    "average_latency": re.compile(r"Average latency per example:\s*([\d.]+)ms"),
    "total_time": re.compile(r"Total time:\s*([\d.]+)s"),
    "throughput": re.compile(r"Throughput:\s*([\d.]+)\s*fps")
}
# Pattern to match timestamps (date and time)
timestamp_pattern = re.compile(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')

number_of_blocks = 2

# Process each directory based on the map
for dir_name in subdirectories:
    full_name = dir_name
    file_path = os.path.join(base_directory, dir_name, 'result_app_perf.txt')
    
    if os.path.exists(file_path):
        with open(file_path, 'r') as file:
            content = file.read()
            
            # Find all blocks based on the timestamp pattern
            blocks = re.split(timestamp_pattern, content)
            timestamps = timestamp_pattern.findall(content)
            
            # Ensure there is at least one timestamp and block
            if timestamps and len(blocks) > 1:
                # Get the last few timestamps and their corresponding blocks
                last_three_timestamps = timestamps[-min(number_of_blocks, len(timestamps)):]
                last_three_blocks = blocks[-min(number_of_blocks, len(blocks)):]

                # Prepare lists to store the extracted values
                timestamps_list = []
                latency_list = []
                total_time_list = []
                throughput_list = []

                # Extract data from each of the last three blocks
                for timestamp, block in zip(last_three_timestamps, last_three_blocks):
                    block = block.strip()
                    latency = re.search(patterns['average_latency'], block)
                    total_time = re.search(patterns['total_time'], block)
                    throughput = re.search(patterns['throughput'], block)

                    timestamps_list.append(timestamp)
                    latency_list.append(float(latency.group(1)) if latency else None)
                    total_time_list.append(float(total_time.group(1)) if total_time else None)
                    throughput_list.append(float(throughput.group(1)) if throughput else None)

                # Store the extracted data in a DataFrame for easy conversion to Excel
                data[full_name] = pd.DataFrame({
                    'Timestamp': timestamps_list,
                    'Latency (ms)': latency_list,
                    'Total Time (s)': total_time_list,
                    'Throughput (fps)': throughput_list
                })
            else:
                print(f"No valid data found in {file_path}.")
    else:
        print(f"File not found: {file_path}")

# Create a single Excel file with multiple sheets
output_file = 'dlrm_single_summary_20G.xlsx'
with pd.ExcelWriter(output_file) as writer:
    for sheet_name, df in data.items():
        # Use the full name as the sheet name
        df.to_excel(writer, sheet_name=sheet_name[:31], index=False)

print(f"Data extraction completed. Results saved to {output_file}.")
