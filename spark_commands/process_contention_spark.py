import os
import pandas as pd

# Parent directory containing the subfolders
parent_folder = "../results/spark/"  # Replace with your actual path

# List of folders
folders = [
    "spark_als",
    "spark_gbt",
    "spark_sort",
    "spark_wordcount",
    "spark_pca",
    "spark_rf",
    "spark_terasort",
    "spark_linear"
]

# Number of latest entries to extract
x = 3  # You can adjust this value to the required number of entries

# Output Excel file
output_file = 'contention_spark_workload.xlsx'

# Initialize an empty dictionary to store data for each type
data_by_type = {}

# Function to extract data from a result_app_perf.txt file
def extract_data(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()

    # Filter out rows with actual data (ignore "Type" rows)
    rows = [line.strip().split() for line in lines if not line.startswith('Type')]

    # Create a DataFrame from the extracted rows
    df = pd.DataFrame(rows, columns=['Type', 'Date', 'Time', 'Input_data_size', 'Duration(s)', 'Throughput(bytes/s)', 'Throughput/node'])

    return df

# Loop through each folder to gather data
for folder in folders:
    # Construct the full file path
    file_path = os.path.join(parent_folder, folder, 'result_app_perf.txt')
    
    if os.path.exists(file_path):
        print(f"Processing {file_path}...")

        # Extract the data
        df = extract_data(file_path)

        # Extract the latest x entries for each type of app
        for app_type in df['Type'].unique():
            app_data = df[df['Type'] == app_type].tail(x)

            # Store in the dictionary by type
            if app_type not in data_by_type:
                data_by_type[app_type] = app_data
            else:
                data_by_type[app_type] = pd.concat([data_by_type[app_type], app_data])

# Write each type of app data into separate sheets in an Excel file
with pd.ExcelWriter(output_file) as writer:
    for app_type, data in data_by_type.items():
        data.to_excel(writer, sheet_name=app_type, index=False)

print(f"Data successfully written to {output_file}")
