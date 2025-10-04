# cd /home/ubuntu
# rm -f result_*
EXPORTS_FILE="../paths.export"
while read -r LINE
do
    export $LINE
    echo "Exporting: $LINE"  # Debug line
done < "$EXPORTS_FILE"


cd $private_pond_dir/cpu2017/657.xz_s
sed -i 's|export OMP_NUM_THREADS=.*|export OMP_NUM_THREADS=8|' ./cmd.sh
