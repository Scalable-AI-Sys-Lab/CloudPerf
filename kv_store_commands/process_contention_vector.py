import re
import pandas as pd
import numpy as np

# Path to the log file
log_file_path = 'vector_contention_output.log'

# Define empty dictionary to store extracted data
benchmark_data = {}

# Patterns for detecting the start of a run, timestamp, and latency values
start_pattern = re.compile(r"Running\s+([\w.]+)\s+\(Run\s+(\d+)\)")
timestamp_pattern = re.compile(r"Time:\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})")
latency_pattern = re.compile(r"Latency:\s*([\d.]+)\s*seconds")

# Parse the log file
with open(log_file_path, 'r') as log_file:
    current_benchmark = None
    current_run = None
    current_start_time = None
    latency_buffer = []
    timestamp_buffer = []

    for line in log_file:
        start_match = start_pattern.search(line)
        timestamp_match = timestamp_pattern.search(line)
        latency_match = latency_pattern.search(line)

        if start_match:
            # If we encounter a new run, save the previous run's data before starting a new one
            if current_benchmark and latency_buffer:
                # Initialize data structure if not already present
                if current_benchmark not in benchmark_data:
                    benchmark_data[current_benchmark] = {"Run": [], "Start Time": [], "Latencies": [], "Timestamps": []}

                # Add the run, start time, and buffered latencies/timestamps
                benchmark_data[current_benchmark]["Run"].append(current_run)
                benchmark_data[current_benchmark]["Start Time"].append(current_start_time)
                benchmark_data[current_benchmark]["Latencies"].append(latency_buffer.copy())
                benchmark_data[current_benchmark]["Timestamps"].append(timestamp_buffer.copy())

            # Clear buffers and start a new run
            latency_buffer.clear()
            timestamp_buffer.clear()

            # Start of a new run block
            benchmark_name = start_match.group(1)
            run_number = start_match.group(2)
            current_run = f"{benchmark_name} (Run {run_number})"
            current_benchmark = benchmark_name
            current_start_time = None  # Reset the start time for a new run
            print(f"Start of new run: {current_run}")

        if timestamp_match and current_start_time is None:
            # Capture the timestamp as the start time for the current run
            current_start_time = timestamp_match.group(1)
            print(f"Captured start time: {current_start_time}")

        if timestamp_match:
            # Capture all timestamps for latency values
            timestamp_buffer.append(timestamp_match.group(1))

        if latency_match:
            # Capture a latency value and store it in the buffer
            latency_value = float(latency_match.group(1))
            latency_buffer.append(latency_value)

    # After the loop, make sure to save the last run's data
    if current_benchmark and latency_buffer:
        if current_benchmark not in benchmark_data:
            benchmark_data[current_benchmark] = {"Run": [], "Start Time": [], "Latencies": [], "Timestamps": []}

        benchmark_data[current_benchmark]["Run"].append(current_run)
        benchmark_data[current_benchmark]["Start Time"].append(current_start_time)
        benchmark_data[current_benchmark]["Latencies"].append(latency_buffer.copy())
        benchmark_data[current_benchmark]["Timestamps"].append(timestamp_buffer.copy())

# Now, prepare data for each benchmark
with pd.ExcelWriter('contention_vector.xlsx') as writer:
    for benchmark_name, data in benchmark_data.items():
        runs = data["Run"]
        start_times = data["Start Time"]
        latencies = data["Latencies"]
        timestamps = data["Timestamps"]

        # Prepare the latency stats (median and average)
        median_latencies = []
        average_latencies = []

        # Flatten the data for each run
        latency_flat_data = {
            "Run": [],
            "Timestamp": [],
            "Latency": []
        }

        # Process latency data for each run
        for i, run in enumerate(runs):
            if latencies[i]:  # Ensure there are latency values
                median_latencies.append(np.median(latencies[i]))
                average_latencies.append(np.mean(latencies[i]))

                # Store all latency values and their timestamps for this run
                for j, latency_value in enumerate(latencies[i]):
                    latency_flat_data["Run"].append(run)
                    latency_flat_data["Latency"].append(latency_value)
                    latency_flat_data["Timestamp"].append(timestamps[i][j] if j < len(timestamps[i]) else None)
            else:
                # Add zero for runs with no latencies
                median_latencies.append(0)
                average_latencies.append(0)

        # Create a DataFrame with the original data
        df_original = pd.DataFrame(latency_flat_data)

        print(f"Writing {len(df_original)} rows for {benchmark_name}_Original")

        # Create a DataFrame with summary statistics
        df_stats = pd.DataFrame({
            "Run": runs,
            "Start Time": start_times,
            "Median Latency": median_latencies,
            "Average Latency": average_latencies
        })

        print(f"Writing {len(df_stats)} rows for {benchmark_name}_Stats")

        # Write both DataFrames to separate sheets
        df_original.to_excel(writer, sheet_name=f"{benchmark_name}_Original", index=False)
        df_stats.to_excel(writer, sheet_name=f"{benchmark_name}_Stats", index=False)

print("Data has been successfully written to 'contention_vector_fixed.xlsx'")
