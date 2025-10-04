EXPORTS_FILE="../paths.export"
while read -r LINE
do
    export $LINE
done < "$EXPORTS_FILE"


cd $private_pond_dir/cpu2017/638.imagick_s
sed -i 's|export OMP_NUM_THREADS=.*|export OMP_NUM_THREADS=8|' ./cmd.sh
