inputs=./testbenches/common/inputs
hex2bin=./testbenches/common/py/hex2binascii.py
bsg_rom_gen=../bsg_ip_cores/bsg_mem/bsg_ascii_to_rom.py

mkdir -p $inputs/bin
mkdir -p $inputs/rom

for file in $inputs/hex/*.hex;
do
	name=${file##*/};
	echo generating... ${name%.*}.bin;
	python $hex2bin $file 32 > $inputs/bin/${name%.*}.bin;
done;

for file in $inputs/bin/*.bin;
do
	origname=${file##*/};
	name=${origname//-/_};
	progname=${name%.*};
	echo generating... bsg_rom_$progname.v
	python $bsg_rom_gen $file bsg_rom_${progname} zero > $inputs/rom/bsg_rom_${progname}.v;
done;

echo removing binaries...
rm -rf $inputs/bin
