#!/bin/bash
EXPORTS_FILE="./paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"


# Array of directories to run run_exp.sh
dirs=(
    "602.gcc_s"
    "603.bwaves_s"
    "605.mcf_s"
    "607.cactuBSSN_s"
    "619.lbm_s"
    "631.deepsjeng_s"
    "638.imagick_s"
    "649.fotonik3d_s"
    "654.roms_s"
    "657.xz_s"
)
# dirs=(
#     "603.bwaves_s"
# )
# Loop through each directory and execute run_exp.sh
for dir in "${dirs[@]}"; do
    # Enter the directory
    cd "$dir" || { echo "Failed to enter directory $dir"; exit 1; }

    # Check if run_exp.sh exists and is executable
    if [[ -x "./run_exp.sh" ]]; then
        echo "Executing in $dir:"
        sudo bash -c "numactl --physcpubind=$WORKLOAD_CORE ./run_exp.sh"
    else
        echo "run_exp.sh not found or not executable in $dir"
    fi

    # Go back to the parent directory
    cd ..
done
