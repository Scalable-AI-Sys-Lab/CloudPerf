import re
from collections import defaultdict

# Specify the file path
file_path = 'client_output.log'

# Read the file content
with open(file_path, 'r') as file:
    log_text = file.read()

# Regular expressions to capture relevant data
run_exp_pattern = re.compile(r'Executing (tpch_\d+)/run_exp\.sh \(Run (\d+)\)')
latency_pattern = re.compile(r'Latency: (\d+\.\d+) seconds')

# Dictionary to store latencies by tpch and run number
latencies = defaultdict(lambda: defaultdict(list))

# Split the log by lines and process each line
lines = log_text.splitlines()
current_tpch = None
current_run = None

for line in lines:
    run_match = run_exp_pattern.search(line)
    if run_match:
        current_tpch = run_match.group(1)
        current_run = int(run_match.group(2))
    latency_match = latency_pattern.search(line)
    if latency_match and current_tpch and current_run:
        latency = float(latency_match.group(1))
        latencies[current_tpch][current_run].append(latency)

# Calculate and display average latencies for each TPCH and run
average_latencies = []

for tpch, runs in latencies.items():
    for run, latency_list in runs.items():
        average_latency = sum(latency_list) / len(latency_list)
        average_latencies.append([tpch, run, average_latency])

# Display the results in a DataFrame
import pandas as pd
df_latencies = pd.DataFrame(average_latencies, columns=["TPCH", "Run", "Average Latency (seconds)"])

# Print the DataFrame or save it to a CSV file if needed
print(df_latencies)

# Optionally, save to a CSV file
df_latencies.to_csv('vector_single_latencies.csv', index=False)
