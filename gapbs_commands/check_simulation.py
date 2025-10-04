import pandas as pd

# File paths for the base and comparison Excel files
# base_perf_file = "graph_one_time_summary_all_remote_101uncore.xlsx"  # Replace with your actual file path
# comp_file = "graph_one_time_summary_all_remote_818uncore.xlsx"  # Replace with the actual file for the comparison (A or B)

# File paths for the base and comparison Excel files
base_perf_file = "graph_one_time_summary_all_local_101uncore.xlsx"  # Replace with your actual file path
comp_file_tag = "818"
comp_file = f"graph_one_time_summary_all_remote_{comp_file_tag}uncore.xlsx"  # Replace with the actual file for the comparison (A or B)

# Load the base performance file and comparison file (all sheets)
base_sheets = pd.read_excel(base_perf_file, sheet_name=None)  # Load all sheets as a dictionary
comp_sheets = pd.read_excel(comp_file, sheet_name=None)  # Load all sheets as a dictionary

# Prepare a list to store the results for each sheet
slowdown_results = []

# Iterate over each sheet name in the base file
for sheet_name in base_sheets.keys():
    base_df = base_sheets[sheet_name]
    comp_df = comp_sheets.get(sheet_name)

    # Ensure both sheets exist and have the 'Average Time' column
    if comp_df is not None and 'Average Time' in base_df.columns and 'Average Time' in comp_df.columns:
        base_avg_time = base_df['Average Time'].mean()  # Calculate the base average time
        comp_avg_time = comp_df['Average Time'].mean()  # Calculate the comparison average time

        # Calculate the slowdown for the current sheet
        slowdown = (comp_avg_time - base_avg_time) / base_avg_time

        # Append the results to the list, including the sheet name (workload name)
        slowdown_results.append({
            "Workload": sheet_name,
            "Base Avg Latency": base_avg_time,
            "Comp Avg Latency": comp_avg_time,
            "Slowdown": slowdown
        })
    else:
        print(f"Sheet {sheet_name} missing or does not have 'Average Time' column.")

# Convert the results list to a DataFrame
results_df = pd.DataFrame(slowdown_results)

# Save the results to a new Excel file with one sheet
output_file = f"slowdown_results_{comp_file_tag}.xlsx"
results_df.to_excel(output_file, index=False)

print(f"Slowdown results saved to '{output_file}'.")
