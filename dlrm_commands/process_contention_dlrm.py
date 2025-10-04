import os
import re
import pandas as pd
from datetime import datetime

# Base directory for the results
base_directory = "../results/dlrm"
subdirectories = {
    "10000-iterations-64-batchsize": ["dlrm_rm1_high", "dlrm_rm1_low", "dlrm_rm1_med"],
    "50000-iterations-8-batchsize": ["dlrm_rm2_1_high", "dlrm_rm2_1_low", "dlrm_rm2_1_med"]
}

# Define the pattern to extract required data from stdout
patterns = {
    "average_latency": re.compile(r"Average latency per example:\s*([\d.]+)ms"),
    "iterations": re.compile(r"Total number of iterations:\s*(\d+)"),
    "iterations_per_second": re.compile(r"Total number of iterations per second \(across all threads\):\s*([\d.]+)"),
    "total_time": re.compile(r"Total time:\s*([\d.]+)s"),
    "throughput": re.compile(r"Throughput:\s*([\d.]+) fps")
}

# Function to extract data from a file using regex patterns
def extract_info_from_file(filepath):
    data = {}
    with open(filepath, 'r') as file:
        content = file.read()
        for key, pattern in patterns.items():
            match = pattern.search(content)
            if match:
                data[key] = float(match.group(1))
    return data

# Dictionary to store extracted data
extracted_data = {}

# Iterate through each subdirectory and extract data for each setting
for subdirectory, settings in subdirectories.items():
    full_path = os.path.join(base_directory, subdirectory)
    
    # List all files in the subdirectory for debugging
    print(f"Listing files in {full_path}:")
    all_files = os.listdir(full_path)
    for f in all_files:
        print(f)

    for setting in settings:
        # Determine the prefix for the files based on the setting
        prefix = "fig14_RM1_" if "rm1" in setting else "fig13_RM2_1_"
        # Determine the part that should match for each setting
        suffix = setting.split('_')[-1]

        # Filter files that match the pattern for the setting
        setting_files = [
            f for f in all_files
            if f.startswith(f"{prefix}{suffix}") and f.endswith('.stdout')
        ]
        
        # Debug: Print found files for each setting
        print(f"Found stdout files for {setting} in {subdirectory}: {setting_files}")
        
        # Sort the files based on the timestamp (assuming timestamp is part of the filename)
        setting_files.sort(key=lambda x: datetime.strptime(x.split('.')[1], "%m%d-%H%M%S"), reverse=True)
        
        # Process the latest 5 files
        latest_files = setting_files[:5]
        if latest_files:
            data_list = []
            for latest_file in latest_files:
                print(f"Extracting data from {latest_file} for {setting} in {subdirectory}")
                latest_file_path = os.path.join(full_path, latest_file)
                data = extract_info_from_file(latest_file_path)
                
                # Get the last modification time of the file and add it to the data
                modification_time = os.path.getmtime(latest_file_path)
                readable_time = datetime.fromtimestamp(modification_time).strftime("%Y-%m-%d %H:%M:%S")
                data['file_modification_time'] = readable_time
                data['file_name'] = latest_file  # Store the file name for reference
                
                # Append the extracted data to the list
                data_list.append(data)
            
            # Store the list of data dictionaries for each setting
            extracted_data[f"{setting}_{subdirectory}"] = data_list
        else:
            print(f"No stdout file found for {setting} in {subdirectory}")

# Create a DataFrame for each setting and save it to an Excel file
output_file = "contention_dlrm.xlsx"
with pd.ExcelWriter(output_file) as writer:
    for setting, data_list in extracted_data.items():
        if data_list:
            # Convert the list of dictionaries to a DataFrame for easier export
            df = pd.DataFrame(data_list)
            # Truncate sheet name to 31 characters to prevent Excel errors
            df.to_excel(writer, sheet_name=setting[:31], index=False)
            print(f"Data for {setting} saved to sheet.")
        else:
            print(f"No data to save for {setting}.")

print(f"Data has been extracted and saved to {output_file}")
