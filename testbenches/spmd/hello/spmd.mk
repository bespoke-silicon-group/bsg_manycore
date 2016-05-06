# =============================================================
# This is a templete make framgment every spmd should have.
#
# This fragment should:
#
# - list all the required sources; makefile in the top dir.
#   has rules to generate object files from these sources
#
# - contain a rule to generate the elf-binary <spmd>.riscv
#   linking object files generated with listed sources
# =============================================================

hello_c_src = \
	hello.c \
	syscalls.c \

hello_asm_src = \
	crt.S \

hello_c_objs   = $(patsubst %.c, %.o, $(hello_c_src))
hello_asm_objs = $(patsubst %.S, %.o, $(hello_asm_src))

hello.riscv: $(hello_c_objs) $(hello_asm_objs)
	$(RISCV_LINK) $(hello_c_objs) $(hello_asm_objs) -o hello.riscv $(RISCV_LINK_OPTS)
