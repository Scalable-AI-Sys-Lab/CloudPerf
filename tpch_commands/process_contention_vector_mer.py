import re
import pandas as pd
import numpy as np

# Path to the log file
log_file_path = 'vector_contention_output.log'

# Define empty dictionary to store extracted data
workload_data = {}

# Patterns for detecting the start and end of a run block, latency values, and time
start_pattern = re.compile(r"Executing\s+(tpch_[\w_]+)/run_exp\.sh\s+\(Run\s*(\d+)\)")
end_pattern = re.compile(r"Finished\s+(tpch_[\w_]+)/run_exp\.sh\s+\(Run\s*(\d+)\)")
latency_pattern = re.compile(r"Latency:\s*([\d.]+)\s*seconds")
time_pattern = re.compile(r"Time:\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})")

# Buffer to store latencies temporarily before assigning them to a run
latency_buffer = []

# Parse the log file
with open(log_file_path, 'r') as log_file:
    current_workload_run = None
    current_workload_type = None
    run_start_time = None
    for line in log_file:
        start_match = start_pattern.search(line)
        end_match = end_pattern.search(line)
        latency_match = latency_pattern.search(line)
        
        if start_match:
            # Start of a new run block
            workload_type = start_match.group(1)
            run_number = start_match.group(2)
            current_workload_run = f"{workload_type} (Run {run_number})"
            current_workload_type = workload_type  # Update current workload type
            
            # Read the next line to capture the timestamp
            next_line = next(log_file)
            time_match = time_pattern.search(next_line)
            if time_match:
                run_start_time = time_match.group(1)
            print(f"Start of new run: {current_workload_run} at {run_start_time}")
            
        if latency_match:
            # Capture a latency value and store it in the buffer
            latency_value = float(latency_match.group(1))
            latency_buffer.append(latency_value)
            print(f"Buffered latency: {latency_value}")

        if end_match:
            # End of the run block
            workload_type = end_match.group(1)
            run_number = end_match.group(2)
            current_workload_run = f"{workload_type} (Run {run_number})"
            print(f"End of run: {current_workload_run}, Workload Type: {workload_type}")
            
            # Initialize data structure if not already present
            if workload_type not in workload_data:
                workload_data[workload_type] = {"Workload Run": [], "Start Time": [], "Latency": []}

            # Add the workload run, start time, and assign buffered latencies
            workload_data[workload_type]["Workload Run"].append(current_workload_run)
            workload_data[workload_type]["Start Time"].append(run_start_time)
            workload_data[workload_type]["Latency"].append(latency_buffer.copy())
            latency_buffer.clear()  # Clear the buffer after assigning

# Debug output of the collected data
print("Collected Workload Data:")
for workload_type, data in workload_data.items():
    print(f"Workload Type: {workload_type}")
    print(f"Runs: {data['Workload Run']}")
    print(f"Start Times: {data['Start Time']}")
    print(f"Latencies: {data['Latency']}")

output_file = 'mer_contention_tpch_vector.xlsx'
# Now, prepare data for each workload type
with pd.ExcelWriter(output_file) as writer:
    for workload_type, data in workload_data.items():
        workload_runs = data["Workload Run"]
        start_times = data["Start Time"]
        latencies = data["Latency"]
        
        # Prepare the latency stats (median and average)
        median_latencies = []
        average_latencies = []
        
        # Flatten the data for each run
        latency_flat_data = {
            "Workload Run": [],
            "Start Time": [],
            "Latency": []
        }

        # Process latency data for each run
        for i, run in enumerate(workload_runs):
            if latencies[i]:  # Ensure there are latency values
                median_latencies.append(np.median(latencies[i]))
                average_latencies.append(np.mean(latencies[i]))
                
                # Store all latency values for this run
                for latency_value in latencies[i]:
                    latency_flat_data["Workload Run"].append(run)
                    latency_flat_data["Start Time"].append(start_times[i])
                    latency_flat_data["Latency"].append(latency_value)
            else:
                # Add zero for runs with no latencies
                median_latencies.append(0)
                average_latencies.append(0)
        
        # Create a DataFrame with the original data
        df_original = pd.DataFrame(latency_flat_data)
        print(f"Writing {len(df_original)} rows for {workload_type}_Original")
        df_stats = pd.DataFrame({
            "Workload Run": workload_runs,
            "Start Time": start_times,
            "Median Latency": median_latencies,
            "Average Latency": average_latencies
        })
        print(f"Writing {len(df_stats)} rows for {workload_type}_Stats")

        # Write both DataFrames to separate sheets
        df_original.to_excel(writer, sheet_name=f"{workload_type}_Original", index=False)
        df_stats.to_excel(writer, sheet_name=f"{workload_type}_Stats", index=False)

print(f"Data has been successfully written to {output_file}")
