import re
import pandas as pd

# Define the path to the log file and output Excel file
log_file = "llama_output.log"
output_file = "llama_single.xlsx"

# Regular expression to capture the pattern for 'ms per token'
latency_pattern = r'generation eval time =\s+([\d.]+)\s+ms\s+/\s+\d+\s+runs\s+\(\s+([\d.]+)\s+ms\s+per\s+token'

# Initialize a list to store the extracted latencies
latencies = []

# Open the log file and search for the pattern
with open(log_file, 'r') as file:
    for line in file:
        match = re.search(latency_pattern, line)
        if match:
            # Extract and store the latency per token
            latency_per_token = float(match.group(2))  # Extract the second group which is the latency per token
            latencies.append(latency_per_token)

# Check if any latencies were found and store them in an Excel file
if latencies:
    # Create a DataFrame from the latencies
    df = pd.DataFrame(latencies, columns=['Latency per Token (ms)'])
    
    # Save to an Excel file
    df.to_excel(output_file, index=False)
    
    print(f"Latencies successfully saved to {output_file}")
else:
    print("No latencies found in the log file.")
