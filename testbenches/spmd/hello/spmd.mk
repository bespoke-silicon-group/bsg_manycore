# ======================================================================
# This is a templete make framgment every spmd should have.
#
# This fragment should:
#
# - list all the required sources; makefile in the top dir. has rules to 
#   generate object files from these sources
#
# - contain a rule to generate the elf-binary <spmd>.riscv linking object 
#   files generated with listed sources
#
# - contain a rule for verilog simulation of tile array with your spmd. 
#   The target name should be in the form <simulator>_spmd.<spmd>. Makefile 
#   in the top dir. has rules for generating hex file and ROM required by 
#   this target.
# ======================================================================

spmd = hello

# Simulation parameters
MAX_CYCLES = 1000000
MEM_SIZE   = 8192 
XTILES     = 4
YTILES     = 4

$(spmd)_c_src = \
	hello.c \
	syscalls.c \

$(spmd)_asm_src = \
	crt.S \

$(spmd)_c_objs   = $(patsubst %.c, %.o, $($(spmd)_c_src))
$(spmd)_asm_objs = $(patsubst %.S, %.o, $($(spmd)_asm_src))

$(spmd).riscv: $($(spmd)_c_objs) $($(spmd)_asm_objs)
	$(RISCV_LINK) $($(spmd)_c_objs) $($(spmd)_asm_objs) -o $(spmd).riscv $(RISCV_LINK_OPTS)

vivado_spmd.$(spmd): $(MEM_DIR)/hex/$(spmd).hex $(ROM_DIR)/bsg_rom_$(spmd).v
	@echo testing $(spmd)...
	$(VLOG) $(DESIGN_HDRS) $(DESIGN_SRCS) $(ROM_DIR)/bsg_rom_$(spmd).v $(SIM_TOP_DIR)/test_bsg_vscale_tile_array.v \
		-d SPMD=$(spmd) -d XTILES=$(XTILES) -d YTILES=$(YTILES) -d MEM_SIZE=$(MEM_SIZE) -d MAX_CYCLES=$(MAX_CYCLES)
	$(VELAB) test_bsg_vscale_tile_array | grep -v Compiling
	$(VSIM)

