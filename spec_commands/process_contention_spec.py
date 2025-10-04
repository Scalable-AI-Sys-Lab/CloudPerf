import os
import re
import pandas as pd

# Base directory where all the folders are located
base_dir = '../results/spec'

# Dictionary mapping the directory names to their full names
dir_map = {
    '602': '602.gcc_s',
    '603': '603.bwaves_s',
    '605': '605.mcf_s',
    '607': '607.cactuBSSN_s',
    '619': '619.lbm_s',
    '631': '631.deepsjeng_s',
    '638': '638.imagick_s',
    '649': '649.fotonik3d_s',
    '654': '654.roms_s',
    '657': '657.xz_s'
}

# Create a dictionary to store the data for each sheet
data = {}

# Pattern to match timestamps (date and time)
timestamp_pattern = re.compile(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')

# Process each directory based on the map
for dir_name, full_name in dir_map.items():
    file_path = os.path.join(base_dir, dir_name, 'result_app_perf.txt')
    if os.path.exists(file_path):
        with open(file_path, 'r') as file:
            content = file.read()
            
            # Find all blocks based on the timestamp pattern
            blocks = re.split(timestamp_pattern, content)
            timestamps = timestamp_pattern.findall(content)
            
            # Ensure there is at least one timestamp and block
            if timestamps and len(blocks) > 1:
                # Get the last three timestamps and their corresponding blocks
                last_three_timestamps = timestamps[-3:]
                last_three_blocks = blocks[-3:]

                # Prepare lists to store the extracted values
                timestamps_list = []
                real_list = []
                user_list = []
                sys_list = []

                # Extract data from each of the last three blocks
                for timestamp, block in zip(last_three_timestamps, last_three_blocks):
                    block = block.strip()
                    real = re.search(r'real (\d+\.\d+)', block)
                    user = re.search(r'user (\d+\.\d+)', block)
                    sys = re.search(r'sys (\d+\.\d+)', block)

                    timestamps_list.append(timestamp)
                    real_list.append(float(real.group(1)) if real else None)
                    user_list.append(float(user.group(1)) if user else None)
                    sys_list.append(float(sys.group(1)) if sys else None)

                # Store the extracted data in a DataFrame for easy conversion to Excel
                data[full_name] = pd.DataFrame({
                    'Timestamp': timestamps_list,
                    'Real': real_list,
                    'User': user_list,
                    'Sys': sys_list
                })
            else:
                print(f"No valid data found in {file_path}.")
    else:
        print(f"File not found: {file_path}")

# Create a single Excel file with multiple sheets
output_file = 'contention_spec.xlsx'
with pd.ExcelWriter(output_file) as writer:
    for sheet_name, df in data.items():
        # Use the full name as the sheet name
        df.to_excel(writer, sheet_name=sheet_name, index=False)

print(f"Data extraction completed. Results saved to {output_file}.")
