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
    # "spark_terasort",
    "spark_linear"
]

# Mapping between the folder names and the 'Type' values
type_mapping = {
    "spark_als": "ALS",
    "spark_gbt": "GradientBoostingTree",
    "spark_sort": "ScalaSparkSort",
    "spark_wordcount": "ScalaSparkWordcount",
    "spark_pca": "PCA",
    "spark_rf": "RandomForest",
    "spark_terasort": "ScalaSparkTerasort",
    "spark_linear": "LinearRegression"
}

# Number of latest entries to extract
x = 3  # You can adjust this value to the required number of entries

# Output Excel file
output_file = 'spark_single_summary.xlsx'

# Initialize an empty dictionary to store data for each folder
data_by_folder = {}

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

        # Extract the 'Type' value corresponding to the current folder
        app_type = type_mapping[folder]

        # Extract the latest x entries for the current type of app
        app_data = df[df['Type'] == app_type].tail(x)

        # Store the data in the dictionary by folder
        if folder not in data_by_folder:
            data_by_folder[folder] = app_data
        else:
            data_by_folder[folder] = pd.concat([data_by_folder[folder], app_data])

# Write each folder's data into separate sheets in an Excel file
with pd.ExcelWriter(output_file) as writer:
    for folder, data in data_by_folder.items():
        data.to_excel(writer, sheet_name=folder, index=False)

print(f"Data successfully written to {output_file}")
