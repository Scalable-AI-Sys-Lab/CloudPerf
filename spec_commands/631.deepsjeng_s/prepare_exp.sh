# cd /home/ubuntu
# rm -f result_*

EXPORTS_FILE="../paths.export"

while read -r LINE
do
    # Check if the line is not empty or a comment
    if [[ -n "$LINE" && ! "$LINE" =~ ^# ]]; then
        export $LINE
    fi
done < "$EXPORTS_FILE"


cd $private_pond_dir/cpu2017/631.deepsjeng_s
sed -i 's|export OMP_NUM_THREADS=.*|export OMP_NUM_THREADS=8|' ./cmd.sh
