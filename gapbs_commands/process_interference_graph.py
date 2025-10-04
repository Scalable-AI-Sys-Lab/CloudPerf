import os
import pandas as pd
import re

# Base directory where the result_log.txt files are located
base_dir = '../results/graph'

# List of graph directories
graph_dirs = ['bc-urand', 'bc-web', 'bfs-urand', 'bfs-web', 'cc-urand', 'cc-web', 'pr-urand', 'pr-web']

# Dictionary to store the extracted data
data = {}

# Regular expressions to match the necessary information
time_pattern = re.compile(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')
trial_pattern = re.compile(r'Trial Time:\s+([0-9.]+)')
avg_time_pattern = re.compile(r'Average Time:\s+([0-9.]+)')
read_time_pattern = re.compile(r'Read Time:\s+([0-9.]+)')

# Loop through the graph directories and extract data from result_log.txt
for graph_dir in graph_dirs:
    log_file = os.path.join(base_dir, graph_dir, 'result_log.txt')
    
    if os.path.exists(log_file):
        with open(log_file, 'r') as file:
            content = file.read()

        # Find all timestamps
        timestamp_match = time_pattern.findall(content)
        
        # Split the content into blocks based on timestamps
        blocks = re.split(time_pattern, content)

        # Initialize lists to store data for this graph
        trial_times_list = []
        timestamps_list = []
        read_times_list = []
        avg_times_list = []

        # For bc-urand, store the last five blocks of data
        if graph_dir == 'bc-urand':
            # Ensure there are enough blocks for processing
            # num_blocks = min(5, len(timestamp_match))
            # for block_index in [-9, -7, -5, -3, -1]:  # Get the last five blocks

            num_blocks = min(3, len(timestamp_match))
            for block_index in [-5, -3, -1]:  # Get the last five blocks
                timestamp = timestamp_match[int(block_index/2) - 1]
                print(timestamp)
                print("block index: " + str(block_index))
                block = blocks[block_index]  # Data blocks are in odd indices
                print(block)

                # Extract trial times, read times, and average times from the block
                trial_times = trial_pattern.findall(block)
                trial_times = [float(t) for t in trial_times]

                read_time_match = read_time_pattern.search(block)
                read_time = float(read_time_match.group(1)) if read_time_match else None

                avg_time_match = avg_time_pattern.search(block)
                avg_time = float(avg_time_match.group(1)) if avg_time_match else None

                # Append the extracted data
                trial_times_list.extend(trial_times)
                timestamps_list.extend([timestamp] * len(trial_times))
                read_times_list.extend([read_time] * len(trial_times))
                avg_times_list.extend([avg_time] * len(trial_times))

        # For other graph directories, store only the last block of data
        else:
            if len(timestamp_match) > 0:
                last_timestamp = timestamp_match[-1]
                last_block = blocks[-1]  # This should be the last block of data associated with the last timestamp
                # print(last_block)
                trial_times = trial_pattern.findall(last_block)
                trial_times = [float(t) for t in trial_times]  # Convert to float values

                read_time_match = read_time_pattern.search(last_block)
                read_time = float(read_time_match.group(1)) if read_time_match else None

                avg_time_match = avg_time_pattern.search(last_block)
                avg_time = float(avg_time_match.group(1)) if avg_time_match else None

                # Append the data for other graphs
                trial_times_list.extend(trial_times)
                timestamps_list.extend([last_timestamp] * len(trial_times))
                read_times_list.extend([read_time] * len(trial_times))
                avg_times_list.extend([avg_time] * len(trial_times))

        # Store the extracted data in the dictionary
        data[graph_dir] = {
            'timestamps': timestamps_list,
            'trial_times': trial_times_list,
            'average_times': avg_times_list,
            'read_times': read_times_list
        }

# Convert the data into a pandas DataFrame and store it in Excel with each graph on a separate sheet
with pd.ExcelWriter('interference_graph_workload.xlsx') as writer:
    for graph, graph_data in data.items():
        df = pd.DataFrame({
            'Timestamp': graph_data['timestamps'],
            'Read Time': graph_data['read_times'],
            'Trial Time': graph_data['trial_times'],
            'Average Time': graph_data['average_times']
        })
        df.to_excel(writer, sheet_name=graph, index=False)
    print("the data has been saved to interference_graph_sheets.xlsx")