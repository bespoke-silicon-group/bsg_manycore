#/bin/bash

VERILATOR_DIR=$1
SURELOG_DIR=$2
GNU_DIR=$3
LLVM_DIR=$4
NUM_CORES=${5:-5}

echo "Cloning verilator..."
git clone -j$NUM_CORES https://github.com/verilator/verilator $VERILATOR_DIR
git -C $VERILATOR_DIR checkout v5.036
git -C $VERILATOR_DIR submodule update --jobs=$NUM_CORES --init --recursive

echo "Building verilator..."
cd $VERILATOR_DIR && autoconf && ./configure --prefix=$RISCV_INSTALL_DIR && cd -
make -j$NUM_CORES -C $VERILATOR_DIR all >> verilator.log 2>&1
make -j$NUM_CORES -C $VERILATOR_DIR install >> verilator.log 2>&1
make -j$NUM_CORES -C $VERILATOR_DIR install-all >> verilator.log 2>&1

echo "Cloning Surelog..."
git clone -j$NUM_CORES https://github.com/chipsalliance/Surelog $SURELOG_DIR
git -C $SURELOG_DIR checkout 9ab2176efa1508f06b46f621a5eb3873294b7a23
git -C $SURELOG_DIR submodule update --jobs=$NUM_CORES --init --recursive

echo "Building Surelog..."
mkdir -p $SURELOG_DIR/build
cmake -B$SURELOG_DIR/build -S$SURELOG_DIR -DCMAKE_INSTALL_PREFIX=$RISCV_INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS="-s -Wl,--gc-sections" >> surelog.log 2>&1
make -C Surelog/build -j$NUM_CORES install >> surelog.log 2>&1

echo "Cloning riscv-gnu-toolchain..."
git clone -j$NUM_CORES https://github.com/bespoke-silicon-group/riscv-gnu-toolchain $GNU_DIR
git -C $GNU_DIR checkout bsg_custom_git_modules
git -C $GNU_DIR submodule update --jobs=$NUM_CORES --init riscv-binutils
git -C $GNU_DIR submodule update --jobs=$NUM_CORES --init riscv-glibc
git -C $GNU_DIR submodule update --jobs=$NUM_CORES --init riscv-gcc
git -C $GNU_DIR submodule update --jobs=$NUM_CORES --init riscv-newlib
git -C $GNU_DIR config submodule.qemu.update none

echo "Building riscv-gnu-toolchain..."
make -j$NUM_CORES -C software/riscv-tools build-deps >> gcc.log 2>&1
make -j$NUM_CORES -C software/riscv-tools build-riscv-gnu-tools >> gcc.log 2>&1

echo "Building llvm..."
git clone -j$NUM_CORES https://github.com/bespoke-silicon-group/llvm-project $LLVM_DIR
git -C $LLVM_DIR checkout hb-dev
git -C $LLVM_DIR submodule update --jobs=$NUM_CORES --init --recursive
make -j$NUM_CORES -C software/riscv-tools build-llvm

