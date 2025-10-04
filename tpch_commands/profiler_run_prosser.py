import os
import pandas as pd
import numpy as np
import json
import math

# Define the parent directory and threshold
parent_directory = "../results/tpch"  # Replace with your actual parent folder name
folders = [f"q{str(i).zfill(2)}" for i in range(2, 23)]
memory_threshold_GB = 5
memory_threshold = memory_threshold_GB * 1024 * 1024 * 1024  # Example threshold in bytes (5 GB)
print(memory_threshold)

# Function to round up to the nearest GB in bytes
def round_up_to_nearest_gb(bytes_value):
    gb = 1024 ** 3  # 1 GB in bytes
    return math.ceil(bytes_value / gb) * gb

def read_workload_core(filename):
    workload_core = ""
    with open(filename, 'r') as file:
        for line in file:
            # Check if the line starts with 'WORKLOAD_CORE'
            if line.startswith("WORKLOAD_CORE="):
                # Split on '=' and take the part after it
                workload_core = line.split("=", 1)[1].strip()
                break
    return workload_core


# Iterate through each folder within the parent directory
for folder in folders:
    memory_file_path = os.path.join(parent_directory, folder, "memory_numastat_log_profile.csv")
    latency_file_path = os.path.join(parent_directory, folder, "latency_log_profile.csv")
    output_data = {
        "type": "la",
        "importance": 10,           # Example value for importance
        "name": "postgre",      # Example value for name
        "launch_time": 10,
        "core_range": read_workload_core("../all_config.export"),
        "cg_idx": 1       # Use cg_idx from paths.export
    }

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
            
            # Record the memory limit
            current_limit = non_zero_limit_data["Memory_Limit"].median()
            output_data["profile_memory_limit"] = int(current_limit) if isinstance(current_limit, (int, float)) else int(current_limit.iloc[0])
            
    # Process latency log file
    if os.path.exists(latency_file_path):
        latency_data = pd.read_csv(latency_file_path, usecols=["Latency (ns)"])
        valid_latency_data = latency_data["Latency (ns)"].replace([np.nan, -np.nan], np.nan).dropna()
        # Calculate and store median latency if valid data exists
        if not valid_latency_data.empty:
            output_data["median_latency"] = float(valid_latency_data.median())
        else:
            output_data["median_latency"] = None

    # Define the output directory without leading zeros and ensure it exists
    folder_number = int(folder[1:])  # Convert to int to remove leading zero, e.g., "q02" -> 2
    output_dir = f"tpch_{folder_number}"
    os.makedirs(output_dir, exist_ok=True)

    # Store the absolute path of the output directory
    output_data["command_dir"] = os.path.abspath(output_dir)

    output_data["output_file"] = os.path.abspath(os.path.join(parent_directory, folder))
    # Write the output data to a JSON file in the output directory
    # remove the wrong file
    # os.remove(os.path.join(output_dir, f"profile_config_{memory_threshold}G.json"))
    output_file_path = os.path.join(output_dir, f"profile_config_{memory_threshold_GB}G.json")
    with open(output_file_path, "w") as json_file:
        json.dump(output_data, json_file, indent=4)
