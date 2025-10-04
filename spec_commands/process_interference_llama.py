import json
import os
import re  # Add the re module for regular expressions
import pandas as pd
from datetime import datetime

# Specify the base directory containing the folders with logs
base_dir = '../results/spec'  # Use the current directory

# Specify the output Excel file
output_file = 'interference_spec_llama.xlsx'

# Regular expression pattern to match "Running ... (Run X)" and extract the run number
run_pattern = re.compile(r'Running.*\(Run (\d+)\)')

def parse_log(file_path):
    requests = []
    current_request = []
    in_execution_block = False  # Flag to check if we are within the execution block
    run_number = None  # To store the run number

    with open(file_path, 'r') as file:
        for line in file:
            # Check if the line matches the pattern "Running ... (Run X)"
            match = run_pattern.search(line)
            if match:
                in_execution_block = True
                # Extract the run number from the regex match
                run_number = int(match.group(1))
                continue  # Skip the "Running" line

            # Check if the line marks the end of an execution block
            if "Finished" in line and "Run" in line:
                in_execution_block = False
                if current_request:
                    requests.append((current_request, run_number))
                    current_request = []
                continue  # Skip the "Finished" line

            # Only parse lines within the execution block
            if in_execution_block:
                try:
                    log_entry = json.loads(line.strip())
                    if log_entry.get("msg") == "next token":
                        current_request.append((log_entry["timestamp"], log_entry["n_decoded"]))
                    elif log_entry.get("msg") == "send new result":
                        if current_request:
                            requests.append((current_request, run_number))
                            current_request = []
                except json.JSONDecodeError:
                    continue

    if current_request:
        requests.append((current_request, run_number))

    return requests

def calculate_average_latency(requests):
    request_latencies = []
    first_timestamp = None  # To store the first timestamp for readable time conversion
    latencies_per_request = []  # To store the latency for each request
    run_numbers = []  # To store the run numbers for each request

    for token_times, run_number in requests:
        if len(token_times) < 2:
            continue  # Skip if there's not enough data to calculate latency

        first_time = token_times[0][0]
        first_token_number = token_times[0][1]

        last_time = token_times[-1][0]
        last_token_number = token_times[-1][1]

        # Store the first timestamp if it's not set yet
        if first_timestamp is None:
            first_timestamp = first_time

        # Calculate average latency per token in milliseconds
        total_time = last_time - first_time
        total_tokens = last_token_number - first_token_number

        if total_time > 0 and total_tokens > 0:
            avg_latency_per_request = (total_time / total_tokens) * 1000  # Convert to milliseconds
            latencies_per_request.append(avg_latency_per_request)
            request_latencies.append(avg_latency_per_request)
            run_numbers.append(run_number)  # Store the corresponding run number

    if request_latencies:
        # Calculate the overall average of the average latencies for all requests
        overall_avg_latency = sum(request_latencies) / len(request_latencies)
        first_readable_time = datetime.fromtimestamp(first_timestamp).strftime('%Y-%m-%d %H:%M:%S')
        return overall_avg_latency, first_readable_time, latencies_per_request, run_numbers
    else:
        return None, None, [], []  # Return None if no valid latencies are found

# Prepare a dictionary to store the results for each application
data_by_app = {}

# Iterate through all directories under the base_dir
# for folder_name in os.listdir(base_dir):
dir_names = ['602.gcc_s','603.bwaves_s','605.mcf_s','607.cactuBSSN_s','619.lbm_s','631.deepsjeng_s','638.imagick_s','649.fotonik3d_s','654.roms_s','657.xz_s']

for folder_name in dir_names:
    folder_path = os.path.join(base_dir, folder_name)

    # Only process directories (ignore files)
    if os.path.isdir(folder_path):
        log_file = os.path.join(folder_path, 'llama_output.log')

        # Check if the log file exists
        if os.path.exists(log_file):
            print(f"Processing {log_file}...")

            requests = parse_log(log_file)
            avg_latency, first_readable_time, latencies_per_request, run_numbers = calculate_average_latency(requests)

            if avg_latency is not None:
                # Store the overall average latency, the first readable time, the latencies for each request, and the run numbers
                data_by_app[folder_name] = {
                    'overall_avg_latency': avg_latency,
                    'first_readable_time': first_readable_time,
                    'latencies_per_request': latencies_per_request,
                    'run_numbers': run_numbers
                }
            else:
                print(f"No valid latencies found in {log_file}")

# Write the data to an Excel file with different sheets for each application
with pd.ExcelWriter(output_file) as writer:
    for app_name, data in data_by_app.items():
        # Create a list of rows where each row contains the overall latency, readable time, per-request latency, and run number
        rows = []
        for latency, run_number in zip(data['latencies_per_request'], data['run_numbers']):
            rows.append([data['overall_avg_latency'], data['first_readable_time'], run_number, latency])

        # Convert the list of rows into a DataFrame
        df = pd.DataFrame(rows, columns=['Overall Average Latency (ms)', 'First Readable Time', 'Run Number', 'Latency per Request (ms)'])

        # Write to the sheet
        df.to_excel(writer, sheet_name=app_name, index=False)

print(f"Data successfully written to {output_file}")
