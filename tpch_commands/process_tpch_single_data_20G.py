import os
import re
import pandas as pd

# Specify the path to the base directory
base_dir = '../results/tpch/'

# Prepare a dictionary to store the results for each application
data_by_app = {}

# Number of last entries to extract
x = 3

# Pattern to match date and elapsed time
date_pattern = re.compile(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
elapsed_time_pattern = re.compile(r'(\d+\.\d+)elapsed')

# Iterate through the q02 to q22 folders
for i in range(2, 23):
    folder_name = f"q{i:02d}"
    file_path = os.path.join(base_dir, folder_name, 'result_app_perf.txt')

    # Check if the file exists
    if os.path.exists(file_path):
        with open(file_path, 'r') as file:
            lines = file.readlines()

            # Prepare a list to store the current folder's results
            folder_entries = []

            for j in range(len(lines)):
                # Find date
                if date_pattern.match(lines[j]):
                    date = lines[j].strip()

                    # Find elapsed time in the next lines
                    if j + 2 < len(lines) and elapsed_time_pattern.search(lines[j + 2]):
                        elapsed_time_match = elapsed_time_pattern.search(lines[j + 2])
                        elapsed_time = elapsed_time_match.group(1)

                        # Store the extracted info
                        folder_entries.append({
                            'Date': date,
                            'Elapsed Time (seconds)': elapsed_time,
                            'Additional Info': lines[j + 2].strip()
                        })

            # Take the last `x` entries from the folder
            folder_entries = folder_entries[-x:]

            # Store the entries in the dictionary by application (folder name)
            data_by_app[f"tpch_{i}"] = folder_entries

# Write the data to an Excel file with different sheets for each application
output_file = 'tpch_single_summary_20G.xlsx'
with pd.ExcelWriter(output_file) as writer:
    for app_name, entries in data_by_app.items():
        # Convert the list of dictionaries to a DataFrame
        df = pd.DataFrame(entries)
        # Write the DataFrame to a sheet named after the application (e.g., tpch_2, tpch_3, etc.)
        df.to_excel(writer, sheet_name=app_name, index=False)

print(f"Data successfully written to {output_file}")
