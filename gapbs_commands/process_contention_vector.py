import re
import pandas as pd
import numpy as np

# Path to the log file
log_file_path = 'client_output.log'

# Define empty dictionary to store extracted data
dlrm_data = {}

# Patterns for detecting the start and end of a run block and latency values
start_pattern = re.compile(r"Execution\s+(\d+)\s+for\s+\./run_exp\.sh")
end_pattern = re.compile(r"Finished\s+(dlrm_[\w_]+)\s+script\s*\(Run\s*(\d+)\),\s*Vector contention stopped")
latency_pattern = re.compile(r"Latency:\s*([\d.]+)\s*seconds")

# Buffer to store latencies temporarily before assigning them to a run
latency_buffer = []

# Parse the log file
with open(log_file_path, 'r') as log_file:
    current_dlrm_run = None
    current_dlrm_type = None
    for line in log_file:
        start_match = start_pattern.search(line)
        end_match = end_pattern.search(line)
        latency_match = latency_pattern.search(line)
        
        if start_match:
            # Start of a new run block
            run_number = start_match.group(1)
            current_dlrm_run = f"Run {run_number}"
            current_dlrm_type = None  # Reset the dlrm type for a new block
            print(f"Start of new run: {current_dlrm_run}")
            
        if latency_match:
            # Capture a latency value and store it in the buffer
            latency_value = float(latency_match.group(1))
            latency_buffer.append(latency_value)
            print(f"Buffered latency: {latency_value}")

        if end_match:
            # End of the run block, capture the dlrm type and run number
            dlrm_type = end_match.group(1)
            run_number = end_match.group(2)
            current_dlrm_run = f"{dlrm_type} (Run {run_number})"
            current_dlrm_type = dlrm_type  # Update current dlrm type
            print(f"End of run: {current_dlrm_run}, DLRM Type: {dlrm_type}")
            
            # Initialize data structure if not already present
            if dlrm_type not in dlrm_data:
                dlrm_data[dlrm_type] = {"DLRM Run": [], "Latency": []}

            # Add the dlrm run and assign buffered latencies
            dlrm_data[dlrm_type]["DLRM Run"].append(current_dlrm_run)
            dlrm_data[dlrm_type]["Latency"].append(latency_buffer.copy())
            latency_buffer.clear()  # Clear the buffer after assigning

# Debug output of the collected data
print("Collected DLRM Data:")
for dlrm_type, data in dlrm_data.items():
    print(f"DLRM Type: {dlrm_type}")
    print(f"Runs: {data['DLRM Run']}")
    print(f"Latencies: {data['Latency']}")

# Now, prepare data for each dlrm type
with pd.ExcelWriter('contention_vector.xlsx') as writer:
    for dlrm_type, data in dlrm_data.items():
        dlrm_runs = data["DLRM Run"]
        latencies = data["Latency"]
        
        # Prepare the latency stats (median and average)
        median_latencies = []
        average_latencies = []
        
        # Flatten the data for each run
        latency_flat_data = {
            "DLRM Run": [],
            "Latency": []
        }

        # Process latency data for each run
        for i, run in enumerate(dlrm_runs):
            if latencies[i]:  # Ensure there are latency values
                median_latencies.append(np.median(latencies[i]))
                average_latencies.append(np.mean(latencies[i]))
                
                # Store all latency values for this run
                for latency_value in latencies[i]:
                    latency_flat_data["DLRM Run"].append(run)
                    latency_flat_data["Latency"].append(latency_value)
            else:
                # Add zero for runs with no latencies
                median_latencies.append(0)
                average_latencies.append(0)
        
        # Create a DataFrame with the original data
        df_original = pd.DataFrame(latency_flat_data)
        print(f"Writing {len(df_original)} rows for {dlrm_type}_Original")
        df_stats = pd.DataFrame({
            "DLRM Run": dlrm_runs,
            "Median Latency": median_latencies,
            "Average Latency": average_latencies
        })
        print(f"Writing {len(df_stats)} rows for {dlrm_type}_Stats")

        # Write both DataFrames to separate sheets
        df_original.to_excel(writer, sheet_name=f"{dlrm_type}_Original", index=False)
        df_stats.to_excel(writer, sheet_name=f"{dlrm_type}_Stats", index=False)

print("Data has been successfully written to 'contention_vector.xlsx'")
