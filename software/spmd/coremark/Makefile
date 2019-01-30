
include ../Makefile.include

COREMARK_TOP=../coremark-top
COREMARK_SRC=../../imports/coremark/
MANYCORE_PORT_SRC=$(BSG_MANYCORE_DIR)/software/spmd/coremark/
MANYCORE_PORT_DST=$(COREMARK_TOP)/manycore

all:
	ln -s $(COREMARK_SRC) $(COREMARK_TOP)
	ln -s $(MANYCORE_PORT_SRC) $(MANYCORE_PORT_DST)
clean:
	rm -rf $(MANYCORE_PORT_DST)
	rm -rf $(COREMARK_TOP)

