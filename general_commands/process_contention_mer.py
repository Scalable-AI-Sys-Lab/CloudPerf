import pandas as pd
import os

# Define the list of processes to run
process_list = ["tpch"]

# Define file paths for each process with more descriptive names
file_paths = {
    "tpch": {
        "vectordb_contention_file": "../tpch_commands/mer_contention_tpch_vector.xlsx",
        "workload_contention_file": "../tpch_commands/mer_contention_tpch_workload.xlsx",
        "workload_single_summary": "../tpch_commands/tpch_single_summary.xlsx",
        "vectordb_single_file": "../vectordb/vectordb_single.xlsx"
    },
}


# Define the output file
output_file = 'mer_memory_contention.xlsx'
new_output_file = 'mer_memory_contention.xlsx'
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
    vectordb_contention_file = file_paths[process]["vectordb_contention_file"]
    workload_contention_file = file_paths[process]["workload_contention_file"]
    workload_single_summary_file = file_paths[process]["workload_single_summary"]
    vectordb_single_file = file_paths[process]["vectordb_single_file"]

    # Read the vectordb contention file into a DataFrame
    vectordb_contention_df_dict = pd.read_excel(vectordb_contention_file, sheet_name=None)

    # Read the workload contention file into a DataFrame
    workload_contention_df_dict = pd.read_excel(workload_contention_file, sheet_name=None)

    # Read the workload single summary file into a DataFrame
    workload_single_summary_df_dict = pd.read_excel(workload_single_summary_file, sheet_name=None)

    # Read the vectordb single file (latency per token) into a DataFrame
    vectordb_single_df = pd.read_excel(vectordb_single_file)

    # Prepare a list to store combined results
    combined_data = []

    # Define the tag (for example, setting all values to 1)
    tag_value = 0

    # Calculate the median latency from the vectordb single file
    vectordb_original_perf = vectordb_single_df['Median Latency'].median()

    # Combine data from both files
    for sheet_name in workload_contention_df_dict.keys():
        vectordb_contention_df = vectordb_contention_df_dict[f"{sheet_name}_Stats"]
        workload_contention_df = workload_contention_df_dict.get(sheet_name, pd.DataFrame())
        workload_single_summary_df = workload_single_summary_df_dict.get(sheet_name,
                                                                         pd.DataFrame())  # Get the median data

        # Ensure both vectordb and workload data have valid data
        if not vectordb_contention_df.empty and not workload_contention_df.empty:
            # Get the average latency from vectordb contention data
            # avg_latency = vectordb_contention_df['Median Latency'].median()  # Take the first latency value
            avg_latency_df = vectordb_contention_df['Median Latency'].iloc[-3:]

            item_number = 0
            # Handle TPCH and Graph cases separately
            if process == "tpch":
                # Get the median workload performance from the workload single summary data for TPCH
                workload_original_perf = None
                if not workload_single_summary_df.empty:
                    workload_original_perf = workload_single_summary_df['Elapsed Time (seconds)'].median()

                # Use "Elapsed Time (seconds)" for TPCH workloads
                for _, workload_row in workload_contention_df.iterrows():
                    elapsed_time = workload_row['Elapsed Time (seconds)']
                    avg_latency = avg_latency_df.iloc[item_number]
                    item_number += 1

                    # Append the combined data
                    combined_data.append({
                        'workload': sheet_name,
                        'workload_original_perf': workload_original_perf,
                        'workload_contention_perf': elapsed_time,
                        'vectordb_original_perf': vectordb_original_perf,
                        'vectordb_contention_perf': avg_latency,
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
