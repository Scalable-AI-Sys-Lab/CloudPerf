# Read the log file to extract relevant latency data
log_file_path = 'vector_contention_output.log'  # Assuming the log file is provided here

# Define empty dictionary to store extracted data
graph_data = {}

# Pattern for detecting latency lines and identifying the corresponding graph run
import re
import pandas as pd
import numpy as np  # For median and average calculations

latency_pattern = re.compile(r"Latency:\s*([\d.]+)\s*seconds")
graph_run_pattern = re.compile(r"Running\s+([a-zA-Z\-]+)\.sh\s*\(Run\s*(\d+)\)")  # Capture graph types and run numbers

# Parse the log file
with open(log_file_path, 'r') as log_file:
    current_graph_run = None
    for line in log_file:
        graph_run_match = graph_run_pattern.search(line)
        latency_match = latency_pattern.search(line)
        
        if graph_run_match:
            # Found a new graph run, capture the graph type and run number
            graph_type = graph_run_match.group(1)
            run_number = graph_run_match.group(2)
            current_graph_run = f"{graph_type} (Run {run_number})"
            
            if graph_type not in graph_data:
                graph_data[graph_type] = {"Graph Run": [], "Latency": []}  # Create lists for the graph type
            
            graph_data[graph_type]["Graph Run"].append(current_graph_run)
            graph_data[graph_type]["Latency"].append([])  # Create a list to store latency values for this run
        
        if latency_match:
            # Found a latency value
            latency_value = float(latency_match.group(1))
            if current_graph_run:
                graph_data[graph_type]["Latency"][-1].append(latency_value)

# Now, prepare data for each graph type
with pd.ExcelWriter('interference_vector_sheets.xlsx') as writer:
    for graph_type, data in graph_data.items():
        graph_runs = data["Graph Run"]
        latencies = data["Latency"]
        
        # Prepare the latency stats (median and average)
        median_latencies = []
        average_latencies = []
        
        # Flatten the data for each run
        latency_flat_data = {
            "Graph Run": [],
            "Latency": []
        }

        for i, run in enumerate(graph_runs):
            if latencies[i]:
                median_latencies.append(np.median(latencies[i]))
                average_latencies.append(np.mean(latencies[i]))
                
                # Store all latency values for this run
                for latency_value in latencies[i]:
                    latency_flat_data["Graph Run"].append(run)
                    latency_flat_data["Latency"].append(latency_value)
        
        # Create a DataFrame with the original data
        df_original = pd.DataFrame(latency_flat_data)
        
        # Create a DataFrame with median and average latencies
        df_stats = pd.DataFrame({
            "Graph Run": graph_runs,
            "Median Latency": median_latencies,
            "Average Latency": average_latencies
        })
        
        # Write both DataFrames to separate sheets
        df_original.to_excel(writer, sheet_name=f"{graph_type}_Original", index=False)
        df_stats.to_excel(writer, sheet_name=f"{graph_type}_Stats", index=False)

print("Data has been successfully written to 'interference_vector_sheets.xlsx'")
