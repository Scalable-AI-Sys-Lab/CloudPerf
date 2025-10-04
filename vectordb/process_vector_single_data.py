import re
import pandas as pd
import numpy as np

# Path to the log file
log_file_path = 'client_output.log'

# Define patterns for detecting time and latency values
time_pattern = re.compile(r"Time:\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})")
latency_pattern = re.compile(r"Latency:\s*([\d.]+)\s*seconds")

# Lists to store extracted data
time_entries = []
latencies = []

# Parse the log file
with open(log_file_path, 'r') as log_file:
    for line in log_file:
        # Match the time pattern
        time_match = time_pattern.search(line)
        if time_match:
            time_entries.append(time_match.group(1))
        
        # Match the latency pattern
        latency_match = latency_pattern.search(line)
        if latency_match:
            latencies.append(float(latency_match.group(1)))

# Calculate median and average latencies
average_latency = np.mean(latencies) if latencies else 0
median_latency = np.median(latencies) if latencies else 0

# Create a DataFrame to store the results
df = pd.DataFrame({
    "Time": time_entries,
    "Latency": latencies,
    "Average Latency": [average_latency] * len(latencies),
    "Median Latency": [median_latency] * len(latencies)
})

# Save data to an Excel file
output_file = 'vectordb_single.xlsx'
df.to_excel(output_file, sheet_name="Latency Data", index=False)

print(f"Data has been successfully written to {output_file}")
