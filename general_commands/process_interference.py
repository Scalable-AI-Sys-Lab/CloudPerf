import pandas as pd
import os

# Define the list of processes to run
process_list = ["spark", "graph", "tpch", "dlrm", "spec", "kv_store"]

# Define file paths for each process with more descriptive names
file_paths = {
    "graph": {
        "llama_interference_file": "../gapbs_commands/interference_graph_llama.xlsx",
        "workload_interference_file": "../gapbs_commands/interference_graph_workload.xlsx",
        "workload_single_summary": "../gapbs_commands/graph_one_time_summary.xlsx",
        "llama_single_file": "../llama_cpp_commands/llama_single.xlsx"
    },
    "tpch": {
        "llama_interference_file": "../tpch_commands/interference_tpch_llama.xlsx",
        "workload_interference_file": "../tpch_commands/interference_tpch_workload.xlsx",
        "workload_single_summary": "../tpch_commands/tpch_single_summary.xlsx",
        "llama_single_file": "../llama_cpp_commands/llama_single.xlsx"
    },
    "dlrm": {
        "llama_interference_file": "../dlrm_commands/interference_dlrm_llama.xlsx",
        "workload_interference_file": "../dlrm_commands/interference_dlrm_workload.xlsx",
        "workload_single_summary": "../dlrm_commands/dlrm_single_summary.xlsx",
        "llama_single_file": "../llama_cpp_commands/llama_single.xlsx"

    },
    "spec": {
        "llama_interference_file": "../spec_commands/interference_spec_llama.xlsx",
        "workload_interference_file": "../spec_commands/interference_spec_workload.xlsx",
        "workload_single_summary": "../spec_commands/run_single_summary.xlsx",
        "llama_single_file": "../llama_cpp_commands/llama_single.xlsx"

    },
    "kv_store":{
        "llama_interference_file": "../kv_store_commands/interference_kv_llama.xlsx",
        "workload_interference_file": "../kv_store_commands/interference_kv_workload.xlsx",
        "workload_single_summary": "../kv_store_commands/kv_store_single_summary.xlsx",
        "llama_single_file": "../llama_cpp_commands/llama_single.xlsx"

    },
    "spark":{
        "llama_interference_file": "../spark_commands/interference_spark_llama.xlsx",
        "workload_interference_file": "../spark_commands/interference_spark_workload.xlsx",
        "workload_single_summary": "../spark_commands/spark_single_summary.xlsx",
        "llama_single_file": "../llama_cpp_commands/llama_single.xlsx"

    },
}


# Define the output file
output_file = 'bandwidth_interference.xlsx'
new_output_file = 'bandwidth_interference.xlsx'
# Check if the output file already exists
if os.path.exists(output_file):
    # Load the existing data
    existing_df = pd.read_excel(output_file)
else:
    # Create an empty DataFrame if the file doesn't exist
    existing_df = pd.DataFrame()

# Loop through each process in the process list
for process in process_list:
    print(f"Processing {process}...")

    # Load the relevant files for the process
    llama_interference_file = file_paths[process]["llama_interference_file"]
    workload_interference_file = file_paths[process]["workload_interference_file"]
    workload_single_summary_file = file_paths[process]["workload_single_summary"]
    llama_single_file = file_paths[process]["llama_single_file"]

    # Read the llama interference file into a DataFrame
    llama_interference_df_dict = pd.read_excel(llama_interference_file, sheet_name=None)

    # Read the workload interference file into a DataFrame
    workload_interference_df_dict = pd.read_excel(workload_interference_file, sheet_name=None)

    # Read the workload single summary file into a DataFrame
    workload_single_summary_df_dict = pd.read_excel(workload_single_summary_file, sheet_name=None)

    # Read the llama single file (latency per token) into a DataFrame
    llama_single_df = pd.read_excel(llama_single_file)

    # Prepare a list to store combined results
    combined_data = []

    # Define the tag (for example, setting all values to 1)
    tag_value = 0

    # Calculate the median latency from the llama single file
    llama_original_perf = llama_single_df['Latency per Token (ms)'].median()

    # Combine data from both files
    for sheet_name in llama_interference_df_dict.keys():
        llama_interference_df = llama_interference_df_dict[sheet_name]
        workload_interference_df = workload_interference_df_dict.get(sheet_name, pd.DataFrame())
        workload_single_summary_df = workload_single_summary_df_dict.get(sheet_name,
                                                                         pd.DataFrame())  # Get the median data

        # Ensure both llama and workload data have valid data
        if not llama_interference_df.empty and not workload_interference_df.empty:
            # Get the average latency from llama interference data
            avg_latency = llama_interference_df['Latency per Request (ms)'].median()  # Take the first latency value

            # Handle TPCH and Graph cases separately
            if process == "tpch":
                # Get the median workload performance from the workload single summary data for TPCH
                workload_original_perf = None
                if not workload_single_summary_df.empty:
                    workload_original_perf = workload_single_summary_df['Elapsed Time (seconds)'].median()

                # Use "Elapsed Time (seconds)" for TPCH workloads
                for _, workload_row in workload_interference_df.iterrows():
                    elapsed_time = workload_row['Elapsed Time (seconds)']

                    # Append the combined data
                    combined_data.append({
                        'workload': sheet_name,
                        'workload_original_perf': workload_original_perf,
                        'workload_interference_perf': elapsed_time,
                        'llama_original_perf': llama_original_perf,
                        'llama_interference_perf': avg_latency,
                        'tag': tag_value
                    })

            elif process == "graph":
                # Get the median workload performance from the workload single summary data for Graph
                workload_original_perf = None
                if not workload_single_summary_df.empty:
                    workload_original_perf = workload_single_summary_df['Average Time'].median()

                # Use "Average Time" for Graph workloads
                iteration_limit = 3  # Define the maximum number of iterations
                iteration_count = 0  # Initialize the counter

                for _, workload_row in workload_interference_df.iterrows():
                    if iteration_count >= iteration_limit:
                        break  # Exit the loop after reaching the iteration limit
                    avg_time = workload_row['Average Time']

                    # Append the combined data
                    combined_data.append({
                        'workload': sheet_name,
                        'workload_original_perf': workload_original_perf,
                        'workload_interference_perf': avg_time,
                        'llama_original_perf': llama_original_perf,
                        'llama_interference_perf': avg_latency,
                        'tag': tag_value
                    })
                    iteration_count += 1  # Increment the counter

            elif process == "dlrm":
                tag_value = 1
                # Get the median workload performance from the workload single summary data for Graph
                workload_original_perf = None
                if not workload_single_summary_df.empty:
                    workload_original_perf = workload_single_summary_df['Throughput (fps)'].median()

                for _, workload_row in workload_interference_df.iterrows():
                    
                    avg_time = workload_row['Throughput (fps)']

                    # Append the combined data
                    combined_data.append({
                        'workload': sheet_name,
                        'workload_original_perf': workload_original_perf,
                        'workload_interference_perf': avg_time,
                        'llama_original_perf': llama_original_perf,
                        'llama_interference_perf': avg_latency,
                        'tag': tag_value
                    })
            
            elif process == "spec":
                tag_value = 0
                # Get the median workload performance from the workload single summary data for Graph
                workload_original_perf = None
                if not workload_single_summary_df.empty:
                    workload_original_perf = workload_single_summary_df['Real'].median()

                for _, workload_row in workload_interference_df.iterrows():
                    
                    avg_time = workload_row['Real']

                    # Append the combined data
                    combined_data.append({
                        'workload': sheet_name,
                        'workload_original_perf': workload_original_perf,
                        'workload_interference_perf': avg_time,
                        'llama_original_perf': llama_original_perf,
                        'llama_interference_perf': avg_latency,
                        'tag': tag_value
                    })
            elif process == "kv_store":
                tag_value = 1
                # Get the median workload performance from the workload single summary data for Graph
                workload_original_perf = None
                # print(workload_single_summary_df.columns)
                if not workload_single_summary_df.empty:
                    workload_original_perf = workload_single_summary_df['Throughput (ops/sec)'].median()

                for _, workload_row in workload_interference_df.iterrows():
                    
                    avg_time = workload_row['Throughput (ops/sec)']

                    # Append the combined data
                    combined_data.append({
                        'workload': sheet_name,
                        'workload_original_perf': workload_original_perf,
                        'workload_interference_perf': avg_time,
                        'llama_original_perf': llama_original_perf,
                        'llama_interference_perf': avg_latency,
                        'tag': tag_value
                    })
            elif process == "spark":
                tag_value = 1
                # Get the median workload performance from the workload single summary data for Graph
                workload_original_perf = None
                # print(workload_single_summary_df.columns)
                if not workload_single_summary_df.empty:
                    workload_original_perf = workload_single_summary_df['Throughput(bytes/s)'].median()

                for _, workload_row in workload_interference_df.iterrows():
                    
                    avg_time = workload_row['Throughput(bytes/s)']

                    # Append the combined data
                    combined_data.append({
                        'workload': sheet_name,
                        'workload_original_perf': workload_original_perf,
                        'workload_interference_perf': avg_time,
                        'llama_original_perf': llama_original_perf,
                        'llama_interference_perf': avg_latency,
                        'tag': tag_value
                    })

    # Convert the combined data to a DataFrame
    combined_df = pd.DataFrame(combined_data)
    # print(combined_df)
    # Update or append the data in the existing DataFrame
    if not existing_df.empty:
        # Remove rows with the same workloads in the existing dataframe
        existing_df = existing_df[~existing_df['workload'].isin(combined_df['workload'])]

        # Append the new data
        updated_df = pd.concat([existing_df, combined_df], ignore_index=True)
    else:
        # If the existing DataFrame is empty, just assign the new data
        updated_df = combined_df

    # Save the updated data to the same output file
    updated_df.to_excel(new_output_file, index=False)

    print(f"Data successfully updated and written to {new_output_file}")
