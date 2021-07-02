.DEFAULT_GOAL = nothing
.PHONY: machines

nothing:

all: checkout_submodules machines tools

checkout_submodules:
	git submodule update --init --recursive

machines:
	make -j 3 -C machines/

tools:
	make -C software/riscv-tools checkout-all
	make -C software/riscv-tools build-all

# helpful grep rule that allows you to skip large compiled riscv-tools and imports directories
%.grep:
	grep -r "$*" --exclude-dir=imports --exclude-dir=riscv-tools
