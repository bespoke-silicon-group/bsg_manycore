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

TOOLCHAIN_REPO=riscv-gnu-toolchain
TOOLCHAIN_URL=https://github.com/riscv/$(TOOLCHAIN_REPO)
TOOLCHAIN_VERSION=a03290eab661e2aa58288ad164f908bbbcc2169c
DEPENDS_DIR=$(CURDIR)/depends

BSG_NEWLIB_URL=https://github.com/bespoke-silicon-group/bsg_newlib_dramfs.git
BSG_NEWLIB_BRANCH=dramfs
BSG_NEWLIB_PATCH=newlib.patch

SPIKE_REPO=riscv-isa-sim
SPIKE_URL=https://github.com/riscv/riscv-isa-sim.git
SPIKE_PATCH=spike.patch

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
	cd $(TOOLCHAIN_REPO) && git submodule update --init --recursive;

replace-newlib:
	cd $(TOOLCHAIN_REPO) && git config --file=.gitmodules submodule.riscv-newlib.url $(BSG_NEWLIB_URL)
	cd $(TOOLCHAIN_REPO) && git config --file=.gitmodules submodule.riscv-newlib.branch $(BSG_NEWLIB_BRANCH)
	cd $(TOOLCHAIN_REPO) && git apply ../$(BSG_NEWLIB_PATCH)
	cd $(TOOLCHAIN_REPO) && git submodule sync
	cd $(TOOLCHAIN_REPO) && git submodule update --init --recursive riscv-newlib

checkout-spike:
	@echo "====================================="
	@echo "Cloning riscv-isa-sim repo..."
	@echo "====================================="
	@rm -rf $(SPIKE_REPO);
	git clone --recursive $(SPIKE_URL);
	cd $(SPIKE_REPO) && git checkout tags/v1.0.0
	cd $(SPIKE_REPO) && git apply ../$(SPIKE_PATCH)

checkout-all: 
	$(MAKE) checkout-repos 
	$(MAKE) replace-newlib 
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
		./configure --prefix=$(RISCV) --disable-linux --with-arch=rv32imaf --with-abi=ilp32

build-riscv-gnu-tools: configure-riscv-gnu-tools
	@echo "====================================="
	@echo "Building toolchain..."
	@echo "====================================="
	cd riscv-gnu-toolchain && $(MAKE) -j 16 newlib && $(MAKE) install

build-spike:
	@echo "====================================="
	@echo "Building $(SPIKE_REPO)..."
	@echo "====================================="
	cd $(SPIKE_REPO) && ./configure --prefix=$(RISCV)
	cd $(SPIKE_REPO) && $(MAKE) && $(MAKE) install

build-all: 
	$(MAKE) build-deps 
	$(MAKE) build-riscv-gnu-tools 
	$(MAKE) build-spike

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
	rm -rf $(DEPENDS_DIR) $(TOOLCHAIN_REPO) $(SPIKE_REPO)

clean-install:
	rm -rf riscv-install

clean-all:
	rm -rf $(DEPENDS_DIR) $(TOOLCHAIN_REPO) $(SPIKE_REPO) riscv-install

installs:
	sudo apt-get install autoconf automake libtool curl gawk bison flex texinfo gperf \
		sed autotools-dev libmpc-dev libmpfr-dev libgmp-dev build-essential

