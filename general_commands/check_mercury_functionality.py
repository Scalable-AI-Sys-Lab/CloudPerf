import os
import pandas as pd

# Base directory containing all subdirectories
base_dir = "../results/graph"

# Define the error margin in bytes (500 MB)
error_margin_bytes = 500 * 1024 * 1024  # Convert MB to bytes

# Iterate over all subdirectories in the base directory
for dir_name in os.listdir(base_dir):
    dir_path = os.path.join(base_dir, dir_name)

    # Check if it's a directory
    if os.path.isdir(dir_path):
        # Define the path to the memory_usage_log.csv file
        csv_file = os.path.join(dir_path, 'memory_usage_log.csv')

        # Check if the CSV file exists in the directory
        if os.path.exists(csv_file):
            # Read the CSV file into a DataFrame
            try:
                df = pd.read_csv(csv_file)

                # Check if both 'Top_Tier_Memory' and 'Memory_Limit' columns exist in the DataFrame
                if 'Top_Tier_Memory' in df.columns and 'Memory_Limit' in df.columns:
                    # Check if any Top_Tier_Memory exceeds Memory_Limit + error_margin
                    errors = df[df['Top_Tier_Memory'] > (df['Memory_Limit'] + error_margin_bytes)]

                    # If any errors are found, print the directory and the specific rows
                    if not errors.empty:
                        print(f"Memory limit exceeded in {dir_name}:")
                        print(errors[['Timestamp', 'Top_Tier_Memory', 'Memory_Limit']])
                    else:
                        print(f"All memory usage within limits for {dir_name}.")
                else:
                    print(f"Columns missing in {csv_file} for {dir_name}.")
            except Exception as e:
                print(f"Error reading {csv_file}: {e}")
        else:
            print(f"File {csv_file} does not exist in {dir_name}.")
