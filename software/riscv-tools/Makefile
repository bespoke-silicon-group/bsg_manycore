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

TARGET_ARCH       := rv32imaf
TARGET_ABI        := ilp32f
TARGET_CFLAGS     := '-fno-common'

LLVM_REPO         := llvm-project
LLVM_URL          := https://github.com/bespoke-silicon-group/$(LLVM_REPO)
LLVM_VERSION      := hb-dev # 2c0472120c0c1a3b0b613099e9bc579cf02f6c1c

TOOLCHAIN_REPO    := riscv-gnu-toolchain
TOOLCHAIN_URL     := https://github.com/bespoke-silicon-group/$(TOOLCHAIN_REPO)
TOOLCHAIN_VERSION := bsg_custom_git_modules # 656708846d723936eb5ba2648f6f919608a8ccaf

DEPENDS_DIR       := depends

SPIKE_REPO        := riscv-isa-sim
SPIKE_URL         := https://github.com/riscv/riscv-isa-sim.git
SPIKE_PATCH       := spike.patch
SPIKE_GCC_PATCH   := spike-gcc.patch
SPIKE_TAG         := v1.1.0

# How many thread you want to use compiling tools
UNAME := $(shell uname)
ifeq ($(UNAME),Linux)
        NUMPROC := $(shell grep -c ^processor /proc/cpuinfo)
else ifeq ($(UNAME),Darwin)
        NUMPROC := $(shell sysctl hw.ncpu | awk '{print $$2}')
endif

# Only take half as many processors as available
COMPILING_THREADS ?= $(shell echo "($(NUMPROC)+1)/2" | bc)

export PATH:=$(DEPENDS_DIR)/bin:$(PATH)

DEPENDS_LIST=autoconf-2.69 automake-1.14
DEPENDS_URL=https://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.xz \
            https://ftp.gnu.org/gnu/automake/automake-1.14.tar.xz 

BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
include $(BSG_MANYCORE_DIR)/machines/paths.mk

APPLY_PATCH  ?= git apply --ignore-whitespace --ignore-space-change
CHECK_PATCH  ?= $(APPLY_PATCH) --check --reverse
QUICK_CLONE  ?= git clone -j $(COMPILING_THREADS) --single-branch --recurse-submodules --shallow-submodules --shallow-since=2020-01-01
STABLE_CLONE ?= git clone

# Git version
# Usage: $(call git-version,<1 (major), 2 (minor), 3(patch)>)
git-version = $(shell git --version | awk '{print $$3}' | awk -F. '{print $$$(1)}')

# Checks if git > 2.8
ifeq ($(shell [ $(call git-version,1) -gt 1 ] && \
              [ $(call git-version,1) -gt 2 -o $(call git-version,2) -gt 8 ] && \
              echo 1), 1)
GIT_CLONE ?= $(QUICK_CLONE)
else
GIT_CLONE ?= $(STABLE_CLONE)
endif

define patch_if_new
	$(eval $@_src_root = $(1))
	$(eval $@_patch = $(2))
	$(eval $@_base_patch = $(basename $($@_patch)))
	for p in ${$@_patch}; \
	do \
		echo "Checking if ${$@_base_patch} is applied..."; \
		cd ${$@_src_root}; $(CHECK_PATCH) $$p &> /dev/null && continue; \
		echo "Applying unapplied patch to ${$@_src_root};" \
		cd ${$@_src_root}; $(APPLY_PATCH) $$p &> /dev/null && continue; \
	done
endef

help:
	@cat README.md

checkout-deps: | $(DEPENDS_DIR)
$(DEPENDS_DIR):
	mkdir -p $(RISCV);
	mkdir -p $(DEPENDS_DIR);	
	@echo "====================================="
	@echo "Downloading depends..."
	@echo "====================================="
	@cd $(DEPENDS_DIR) && 		\
	for dep_url in $(DEPENDS_URL); do 	\
		wget $$dep_url;			\
	done

checkout-riscv-gnu-tools: | $(TOOLCHAIN_REPO)
$(TOOLCHAIN_REPO):
	@echo "====================================="
	@echo "Cloning riscv-toolchain repo..."
	@echo "====================================="
	$(GIT_CLONE) -b $(TOOLCHAIN_VERSION) $(TOOLCHAIN_URL) $(TOOLCHAIN_REPO) || \
		echo "riscv-gnu-toolchain already cloned, reusing"
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-binutils
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-glibc
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-gcc
	cd $(TOOLCHAIN_REPO) && git submodule update --init --checkout riscv-newlib

checkout-llvm: | $(LLVM_REPO)
$(LLVM_REPO):
	@echo "====================================="
	@echo "Cloning llvm-project repo..."
	@echo "====================================="
	$(GIT_CLONE) -b $(LLVM_VERSION) $(LLVM_URL) $(LLVM_REPO) || \
		echo "LLVM already cloned, reusing"

checkout-repos:
	$(MAKE) checkout-riscv-gnu-tools
	$(MAKE) checkout-llvm

checkout-spike: | $(SPIKE_REPO)
$(SPIKE_REPO):
	@echo "====================================="
	@echo "Cloning riscv-isa-sim repo..."
	@echo "====================================="
	$(GIT_CLONE) -b $(SPIKE_TAG) $(SPIKE_URL) $(SPIKE_REPO) || \
		echo "riscv-isa-sim already cloned, reusing"
	@$(call patch_if_new,$(SPIKE_REPO),$(abspath $(SPIKE_PATCH)))
	@$(call patch_if_new,$(SPIKE_REPO),$(abspath $(SPIKE_GCC_PATCH)))

checkout-all: 
	$(MAKE) checkout-deps
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
		./configure --prefix=$(abspath $(DEPENDS_DIR)) && $(MAKE) && $(MAKE) install; \
		cd ..;	\
	done

configure-riscv-gnu-tools:
	@echo "====================================="
	@echo "Configuring toolchain..."
	@echo "====================================="
	cd $(TOOLCHAIN_REPO) && \
		./configure --prefix=$(RISCV) --disable-linux --with-arch=$(TARGET_ARCH) --with-abi=$(TARGET_ABI) --disable-gdb --with-tune=bsg_vanilla_2020 SHELL=/bin/bash

build-riscv-gnu-tools: configure-riscv-gnu-tools
	@echo "====================================="
	@echo "Building toolchain..."
	@echo "====================================="
	@# workaround for non-POSIX dependency check
	cd $(TOOLCHAIN_REPO)/riscv-gcc; ./contrib/download_prerequisites
	$(MAKE) -C $(TOOLCHAIN_REPO) -j $(COMPILING_THREADS) CFLAGS_FOR_TARGET_EXTRA=$(TARGET_CFLAGS)
	$(MAKE) -C $(TOOLCHAIN_REPO) install

build-spike:
	@echo "====================================="
	@echo "Building $(SPIKE_REPO)..."
	@echo "====================================="
	cd $(SPIKE_REPO) && \
		./configure --prefix=$(RISCV) --enable-commitlog
	$(MAKE) -C $(SPIKE_REPO)
	$(MAKE) -C $(SPIKE_REPO) install

build-llvm:
	@echo "====================================="
	@echo "Building $(LLVM_REPO)..."
	@echo "====================================="
	$(MAKE) -f ../mk/Makefile.llvminstall llvm-install LLVM_DIR=$(LLVM_REPO) RISCV=$(RISCV) COMPILING_THREADS=$(COMPILING_THREADS) GCC=$(GCC) GXX=$(GXX) CMAKE=$(CMAKE) GENERATOR="$(GENERATOR)"

build-all: checkout-all
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
	rm -rf $(DEPENDS_DIR)
	rm -rf $(TOOLCHAIN_REPO)
	rm -rf $(LLVM_REPO)
	rm -rf $(SPIKE_REPO)

clean-llvm:
	rm -rf $(LLVM_REPO)/llvm-src
	rm -rf $(LLVM_REPO)/llvm-build

clean-install:
	rm -rf $(RISCV)

clean-all:
	$(MAKE) clean-builds
	$(MAKE) clean-install

installs:
	sudo apt-get install autoconf automake libtool curl gawk bison flex texinfo gperf \
		sed autotools-dev libmpc-dev libmpfr-dev libgmp-dev build-essential

