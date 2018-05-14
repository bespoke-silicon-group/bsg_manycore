# MBT 12-18-15
#
# 1. Ran these commands to get gcc-4.8  (on bb-91/bb-92) CENTOS 6.7
#
# wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
# yum install devtoolset-2-gcc devtoolset-2-binutils
# yum install devtoolset-2-gcc-c++ devtoolset-2-gcc-gfortran
#
# /opt/rh/devtoolset-2/root/usr/bin/gcc --version
#
# did not run: scl enable devtoolset-2 bash
#              source /opt/rh/devtoolset-2/enable

# 2. yum packages
# yum install libmpc
# assumed already installed: autoconf automake libtool curl gmp gawk bison flex texinfo gperf gcc48 gsed
#
#
#
#


export RISCV:=$(PWD)/riscv-install
export SED=sed
#export CC=/opt/rh/devtoolset-2/root/usr/bin/gcc
#export CXX=/opt/rh/devtoolset-2/root/usr/bin/g++
export CC=gcc
export CXX=g++
export SED=sed
export PATH
export SHELL:=$(SHELL)


nothing:

checkout-all:
	git clone git://github.com/ucb-bar/rocket-chip.git
	cd rocket-chip; git checkout 48170fd9aa4de6bf2a443010881d25dd55238941;
	############
	# replace the https:// with git:// because of the SSL update on Github
	sed 's/https:/git:/' -i rocket-chip/.gitmodules
	cd rocket-chip; git submodule init riscv-tools
	cd rocket-chip; git submodule update riscv-tools
	############
	# replace the https:// with git:// because of the SSL update on Github
	sed 's/https:/git:/' -i rocket-chip/riscv-tools/.gitmodules
	cd rocket-chip/riscv-tools; git submodule init riscv-fesvr;         git submodule update riscv-fesvr
	cd rocket-chip/riscv-tools; git submodule init riscv-gnu-toolchain; git submodule update riscv-gnu-toolchain
	cd rocket-chip/riscv-tools; git submodule init riscv-isa-sim;       git submodule update riscv-isa-sim
	cd rocket-chip/riscv-tools; git submodule init riscv-opcodes;       git submodule update riscv-opcodes
	cd rocket-chip/riscv-tools; git submodule init riscv-pk;            git submodule update riscv-pk
	cd rocket-chip/riscv-tools; git submodule init riscv-llvm;          git submodule update riscv-llvm
	cd rocket-chip/riscv-tools; git submodule init riscv-tests;         git submodule update riscv-tests
	sed 's/https:/git:/' -i rocket-chip/riscv-tools/riscv-llvm/.gitmodules
	sed 's/https:/git:/' -i rocket-chip/riscv-tools/riscv-tests/.gitmodules
	cd rocket-chip/riscv-tools/riscv-llvm/;   git submodule update --init --recursive	
	cd rocket-chip/riscv-tools/riscv-tests/;  git submodule update --init --recursive	

build-riscv-tools:
	cd rocket-chip/riscv-tools; sed -i 's/JOBS=16/JOBS=2/' build.common
	cd rocket-chip/riscv-tools; sed -i 's/build_project riscv-gnu-toolchain/build_project riscv-gnu-toolchain --enable-multilib/' build.sh
	cd rocket-chip/riscv-tools; ./build.sh | tee $@.log

clean:
	rm -rf riscv-install

really-clean: clean
	rm -rf rocket-chip


installs:
	sudo apt-get install autoconf automake libtool curl gawk bison flex texinfo gperf sed autotools-dev libmpc-dev libmpfr-dev libgmp-dev build-essential

