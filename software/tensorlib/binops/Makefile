# Makefile to build binaries for each of the following ops
# from a single source file: binops.c
OPS       := add sub mul div
OP_EXES   := $(foreach op,$(OPS),$(op).riscv)
OP_C_SRCS := $(foreach op,$(OPS),$(op).c)

all: $(OP_EXES)

include ../Makefile.include

# Rule to generate per op source files
$(OP_C_SRCS) : %.c : binops.c
	$(RISCV_GCC) -E $(RISCV_GCC_OPTS) -DOP=$* $^ > $@

$(OP_EXES) : %.riscv: %.o $(COMMON_OBJECTS)
	$(RISCV_LINK) $^ -o $@ $(RISCV_LINK_OPTS)

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules

clean:
	rm *.o *.riscv *.log $(OP_C_SRCS)
