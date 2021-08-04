bsg_tiles_X = 4
bsg_tiles_Y = 4
NUM_FINISH = 16

all: main.run

include ../Makefile.include

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles bsg_set_tile_x_y.o bsg_tile_config_vars.o

main.riscv: $(LINK_SCRIPT)  main.o bsg_set_tile_x_y.o bsg_tile_config_vars.o
	$(RISCV_LINK)  main.o -o $@ $(RISCV_LINK_OPTS)


include ../../mk/Makefile.tail_rules

