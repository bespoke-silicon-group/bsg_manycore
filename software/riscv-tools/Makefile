# ##################################################################
# For CENTOS 7.XX
# ##################################################################
# 1. Make sure you have internet connections because we need to download the automake/autoconf
# 2. Make sure you have wget installed.
#
# #################################################################
# For CENTOS 6.XX
# #################################################################
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
.DEFAULT_GOAL := help

TARGET_ARCH       := rv64imaf
TARGET_ABI        := lp64f
TARGET_CFLAGS     := '-fno-common'

TOOLCHAIN_REPO    := riscv-gnu-toolchain
TOOLCHAIN_URL     := https://github.com/bespoke-silicon-group/$(TOOLCHAIN_REPO)
TOOLCHAIN_VERSION := 656708846d723936eb5ba2648f6f919608a8ccaf

DEPENDS_DIR       := $(CURDIR)/depends

SPIKE_REPO        := riscv-isa-sim
SPIKE_URL         := https://github.com/riscv/riscv-isa-sim.git
SPIKE_PATCH       := spike.patch
SPIKE_GCC_PATCH   := spike-gcc.patch
SPIKE_TAG         := v1.0.0

LLVM_DIR          := $(CURDIR)/llvm
export PATH:=$(DEPENDS_DIR)/bin:$(PATH)

DEPENDS_LIST=autoconf-2.69 automake-1.14
DEPENDS_URL=https://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.xz \
            https://ftp.gnu.org/gnu/automake/automake-1.14.tar.xz 

export RISCV:=$(CURDIR)/riscv-install
export SED=sed
export CC=gcc
export CXX=g++
export SED=sed
export PATH
export SHELL:=$(SHELL)

# Git version
# Usage: $(call git-version,<1 (major), 2 (minor), 3(patch)>)
git-version = $(shell git --version | awk '{print $$3}' | awk -F. '{print $$$(1)}')

help:
	@cat README.md

checkout-repos:
	mkdir -p $(DEPENDS_DIR);	
	mkdir -p $(RISCV);
	@echo "====================================="
	@echo "Downloading depends..."
	@echo "====================================="
	@cd $(DEPENDS_DIR) && 		\
	for dep_url in $(DEPENDS_URL); do 	\
		wget $$dep_url;			\
	done
	@echo "====================================="
	@echo "Cloning riscv-toolchain repo..."
	@echo "====================================="
	@rm -rf $(TOOLCHAIN_REPO);
	git clone $(TOOLCHAIN_URL);
	cd $(TOOLCHAIN_REPO) && git checkout $(TOOLCHAIN_VERSION);

# Checks if git > 2.8
ifeq ($(shell [ $(call git-version,1) -gt 1 ] && \
              [ $(call git-version,1) -gt 2 -o $(call git-version,2) -gt 8 ] && \
              echo 1), 1)
	#cd $(TOOLCHAIN_REPO) && git submodule update --init --recursive -j 16;
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-binutils
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-glibc
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-gcc
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-newlib
else
	#cd $(TOOLCHAIN_REPO) && git submodule update --init --recursive;
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-binutils
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-glibc
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-gcc
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-newlib
endif
	# **** This patch is no longer necessary. Its changes have
	#      been applied in the bsg_manycore_gcc branch of
	#      riscv-gcc.
	# This patch is necessary if target abi is ilp32f because of the issue
	# https://github.com/riscv/riscv-gnu-toolchain/issues/530
	# cd $(TOOLCHAIN_REPO)/riscv-gcc && git apply $(CURDIR)/riscv-gcc.patch


checkout-spike:
	@echo "====================================="
	@echo "Cloning riscv-isa-sim repo..."
	@echo "====================================="
	@rm -rf $(SPIKE_REPO);
	git clone --recursive $(SPIKE_URL);
	cd $(SPIKE_REPO) && git checkout tags/$(SPIKE_TAG)
	cd $(SPIKE_REPO) && git apply ../$(SPIKE_PATCH) && git apply ../$(SPIKE_GCC_PATCH)

checkout-all: 
	$(MAKE) checkout-repos 
	$(MAKE) checkout-spike

build-deps:
	@echo "====================================="
	@echo "Building depends..."
	@echo "====================================="
	cd $(DEPENDS_DIR) && \
	for dep_tool in $(DEPENDS_LIST); do 	\
		tar xf $$dep_tool.tar.xz &&      \
		cd $$dep_tool	&&	\
		./configure --prefix=$(DEPENDS_DIR) && $(MAKE) && $(MAKE) install; \
		cd ..;	\
	done

configure-riscv-gnu-tools:
	@echo "====================================="
	@echo "Configuring toolchain..."
	@echo "====================================="
	cd riscv-gnu-toolchain && \
		./configure --prefix=$(RISCV) --disable-linux --with-arch=$(TARGET_ARCH) --with-abi=$(TARGET_ABI) --disable-gdb --with-tune=bsg_vanilla_2020 --with-cmodel=medany \
			--disable-linux --with-target-cflags="-mstrict-align -mcmodel=medany" \
			--disable-linux --with-target-cxxflags="-mstrict-align -mcmodel=medany"

build-riscv-gnu-tools: configure-riscv-gnu-tools
	@echo "====================================="
	@echo "Building toolchain..."
	@echo "====================================="
	cd riscv-gnu-toolchain && $(MAKE) -j 16 CFLAGS_FOR_TARGET_EXTRA=$(TARGET_CFLAGS)

build-spike:
	@echo "====================================="
	@echo "Building $(SPIKE_REPO)..."
	@echo "====================================="
	cd $(SPIKE_REPO) && ./configure --prefix=$(RISCV) --enable-commitlog
	cd $(SPIKE_REPO) && $(MAKE) && $(MAKE) install

build-llvm:
	@echo "====================================="
	@echo "Building $(LLVM_DIR)..."
	@echo "====================================="
	$(MAKE) -C ../mk/ -f Makefile.llvminstall LLVM_DIR=$(LLVM_DIR) RISCV_INSTALL_DIR=$(RISCV)

build-all: 
	$(MAKE) build-deps 
	$(MAKE) build-riscv-gnu-tools 
	$(MAKE) build-spike
	$(MAKE) build-llvm

rebuild-newlib: PATH:=$(RISCV)/bin:$(PATH)
rebuild-newlib:
	$(MAKE) -C $(TOOLCHAIN_REPO)/build-newlib
	$(MAKE) -C $(TOOLCHAIN_REPO)/build-newlib install

install-with-builds: 
	$(MAKE) checkout-all 
	$(MAKE) build-all

install-clean: 
	$(MAKE) install-with-builds 
	$(MAKE) clean-builds

clean-builds:
	rm -rf $(DEPENDS_DIR) $(TOOLCHAIN_REPO) $(SPIKE_REPO) && \
	$(MAKE) clean-llvm

clean-llvm:
	rm -rf $(LLVM_DIR)/llvm-src $(LLVM_DIR)/llvm-build

clean-install:
	rm -rf riscv-install
	rm -rf $(LLVM_DIR)

clean-all:
	rm -rf $(DEPENDS_DIR) $(TOOLCHAIN_REPO) $(SPIKE_REPO) riscv-install $(LLVM_DIR)

installs:
	sudo apt-get install autoconf automake libtool curl gawk bison flex texinfo gperf \
		sed autotools-dev libmpc-dev libmpfr-dev libgmp-dev build-essential

