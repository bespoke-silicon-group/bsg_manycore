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
TOOLCHAIN_REPO=riscv-gnu-toolchain
TOOLCHAIN_URL=https://github.com/riscv/$(TOOLCHAIN_REPO)
DEPENDS_DIR=$(CURDIR)/depends

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


nothing:

checkout-all:
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
	cd $(TOOLCHAIN_REPO) && git submodule init;
	cd $(TOOLCHAIN_REPO) && git config submodule.riscv-newlib.url \
		https://bitbucket.org/taylor-bsg/bsg_hammerblade_newlib.git;
	cd $(TOOLCHAIN_REPO) && git submodule update --recursive
	cd $(TOOLCHAIN_REPO)/riscv-newlib && git checkout bsg_manycore_newlib

build-deps:
	@echo "====================================="
	@echo "Building depends..."
	@echo "====================================="
	cd $(DEPENDS_DIR) && \
	for dep_tool in $(DEPENDS_LIST); do 	\
		tar xf $$dep_tool.tar.xz &&      \
		cd $$dep_tool	&&	\
		./configure --prefix=$(DEPENDS_DIR) && make && make install; \
		cd ..;	\
	done

configure-riscv-gnu-tools:
	cd riscv-gnu-toolchain && \
		./configure --prefix=$(RISCV) --disable-linux --with-arch=rv32ima --with-abi=ilp32

build-riscv-gnu-tools: configure-riscv-gnu-tools
	@echo "====================================="
	@echo "Building toolchain..."
	@echo "====================================="
	cd riscv-gnu-toolchain && make -j 16 newlib && make install

build-all: build-deps build-riscv-gnu-tools

# Following libs will be placed in the dram
LIB_LIST = \
	$(CURDIR)/riscv-install/lib/gcc/riscv32-unknown-elf/8.3.0/libgcc.a \
	$(CURDIR)/riscv-install/riscv32-unknown-elf/lib/libc.a \
	$(CURDIR)/riscv-install/riscv32-unknown-elf/lib/libgloss.a

rebuild-newlib:
	make -C $(TOOLCHAIN_REPO)/build-newlib
	make -C $(TOOLCHAIN_REPO)/build-newlib install
	for lib in $(LIB_LIST); do \
		$(CURDIR)/riscv-install/bin/riscv32-unknown-elf-objcopy \
			--rename-section .data=.dram \
			--rename-section .rodata=.dram \
			--rename-section .bss=.dram \
			$$lib; \
	done

clean:
	rm -rf riscv-install

really-clean: clean
	rm -rf $(TOOLCHAIN_REPO)
	rm -rf $(DEPENDS_DIR)


installs:
	sudo apt-get install autoconf automake libtool curl gawk bison flex texinfo gperf \
		sed autotools-dev libmpc-dev libmpfr-dev libgmp-dev build-essential

