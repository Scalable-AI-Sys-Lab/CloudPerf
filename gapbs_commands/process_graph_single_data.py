import os
import pandas as pd
import re

# Base directory where the result_log.txt files are located
base_dir = '../results/graph'

# List of graph directories
graph_dirs = ['bc-urand', 'bc-web', 'bfs-urand', 'bfs-web', 'cc-urand', 'cc-web', 'pr-urand','pr-web']

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
        if timestamp_match:
            last_timestamp = timestamp_match[-1]  # Get the last timestamp

        # Find all read times and take the last one
        read_time_match = read_time_pattern.findall(content)
        read_time = read_time_match[-1] if read_time_match else None

        # Find the average time and take the last one
        avg_time_match = avg_time_pattern.findall(content)
        avg_time = avg_time_match[-1] if avg_time_match else None

        # Now split the content by the timestamps to isolate the last block
        blocks = re.split(time_pattern, content)
        if len(blocks) > 1:
            last_block = blocks[-1]  # This should be the last block of data associated with the last timestamp

            # Find all trial times within the last block
            trial_times = trial_pattern.findall(last_block)

            # Store the extracted data in the dictionary
            data[graph_dir] = {
                'timestamp': last_timestamp,
                'trial_times': trial_times,
                'average_time': avg_time,
                'read_time': read_time
            }

# Convert the data into a pandas DataFrame and store it in Excel with each graph on a separate sheet
filename = 'graph_single_summary.xlsx'
with pd.ExcelWriter(filename) as writer:
    for graph, graph_data in data.items():
        df = pd.DataFrame({
            'Timestamp': [graph_data['timestamp']] * len(graph_data['trial_times']),
            'Read Time': [graph_data['read_time']] * len(graph_data['trial_times']),
            'Trial Time': graph_data['trial_times'],
            'Average Time': [graph_data['average_time']] * len(graph_data['trial_times'])
        })
        df.to_excel(writer, sheet_name=graph, index=False)
print(f"data is stored to {filename}")
