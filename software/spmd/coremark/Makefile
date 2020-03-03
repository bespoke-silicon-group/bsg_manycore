
include ../Makefile.include



COREMARK_TOP=../coremark-top
COREMARK_SRC=../../imports/coremark/
MANYCORE_PORT_SRC=$(BSG_MANYCORE_DIR)/software/spmd/coremark/
MANYCORE_PORT_DST=$(COREMARK_TOP)/manycore

all:
	ln -sf $(COREMARK_SRC) $(COREMARK_TOP)
	ln -sf $(MANYCORE_PORT_SRC) $(MANYCORE_PORT_DST)
	make coremark.run PORT_DIR=manycore ITERATIONS=1 -C $(COREMARK_TOP) bsg_tiles_X=1 bsg_tiles_Y=1
clean:
	make clean PORT_DIR=manycore -C $(COREMARK_TOP)
	rm -rf $(MANYCORE_PORT_DST)
	rm -rf $(COREMARK_TOP)
	rm -rf *.o *.log
	rm -rf coremark.dis


dve:
	dve -full64 -vpd ../../../imports/coremark/vcdplus.vpd &

dis:
	$(RISCV_BIN_DIR)/riscv32-unknown-elf-objdump -M numeric --disassemble-all \
		../../../imports/coremark/coremark.riscv > coremark.dis

	
