#########################################################
COREMARK_DIR=/home/shx/coremark-shaolin

bsg_tiles_X = 16 
bsg_tiles_Y = 31 

##########################################################
COREMARK_INCS=-I$(COREMARK_DIR)/ -I$(COREMARK_DIR)/manycore

COREMARK_SRCS=$(COREMARK_DIR)/core_matrix.c
COREMARK_SRCS+=$(COREMARK_DIR)/core_state.c
COREMARK_SRCS+=$(COREMARK_DIR)/core_list_join.c
COREMARK_SRCS+=$(COREMARK_DIR)/manycore/core_util.c

COREMARK_OBJS=$(COREMARK_SRCS:.c=.o)
##########################################################
RISCV_GCC_EXTRA_OPTS ?= -Os -fno-exceptions -s -finline-functions $(COREMARK_INCS)

all: main.run

include ../Makefile.include

#########################################################
#            FPU OPTION
#     The number of horizon node must be two and must 
#     be vanilla core 
BSG_FPU_OP=0

main.riscv:  main.o $(COREMARK_OBJS) 
	$(RISCV_LINK) $^ -o $@ $(RISCV_LINK_OPTS) -Wl,-Map,link.map

clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v main.riscv *.wdb main.bin main.hex main.vec
	-rm -rf xsim.dir
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd

main.o: Makefile

include ../../mk/Makefile.tail_rules
