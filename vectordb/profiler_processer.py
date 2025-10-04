import os
import pandas as pd
import numpy as np
import json
import math

# Define the parent directory and threshold
memory_threshold = 5 * 1024 * 1024 * 1024  # Example threshold in bytes (5 GB)
print(memory_threshold)

# Function to round up to the nearest GB in bytes
def round_up_to_nearest_gb(bytes_value):
    gb = 1024 ** 3  # 1 GB in bytes
    return math.ceil(bytes_value / gb) * gb

memory_file_path = "memory_numastat_log_15gb.csv"
latency_file_path = "latency_log_15gb.csv"
output_data = {"type": "la"}  # Initialize JSON with the type field

# Process memory log file
if os.path.exists(memory_file_path):
    memory_data = pd.read_csv(memory_file_path, usecols=["App Total Memory (bytes)"])
    limit_data = pd.read_csv(memory_file_path, usecols=["Memory_Limit"])
    # Filter out zero values from App Total Memory (bytes)
    non_zero_memory_data = memory_data[memory_data["App Total Memory (bytes)"] > 0]
    non_zero_limit_data = limit_data[limit_data["Memory_Limit"] > 0]
    if not non_zero_memory_data.empty:
        # Get the maximum value of non-zero App Total Memory (bytes)
        app_total_memory = non_zero_memory_data["App Total Memory (bytes)"].max()
        output_data["total_memory"] = int(app_total_memory)  # Store original total memory in bytes
        
        # record the memory limit
        current_limit = non_zero_limit_data.median()
        output_data["memory_limit"] = int(current_limit) if isinstance(current_limit, (int, float)) else int(current_limit.iloc[0])
        
# Process latency log file
if os.path.exists(latency_file_path):
    latency_data = pd.read_csv(latency_file_path, usecols=["Latency (ns)"])
    valid_latency_data = latency_data["Latency (ns)"].replace([np.nan, -np.nan], np.nan).dropna()
    # Calculate and store median latency if valid data exists
    if not valid_latency_data.empty:
        output_data["median_latency"] = float(valid_latency_data.median())
    else:
        output_data["median_latency"] = None

# Store the absolute path of the output directory
output_data["command_dir"] = os.getcwd()

# Write the output data to a JSON file in the output directory
output_file_path = "profile_config.json"
with open(output_file_path, "w") as json_file:
    json.dump(output_data, json_file, indent=4)
