bsg_tiles_X=1
bsg_tiles_Y=1

all: main.run

include  ../Makefile.include

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles

LOOP_SIZE ?= 2

main.S:
	python main.py $(LOOP_SIZE) > main.S

main.o: main.S

main.riscv: $(LINK_SCRIPT) main.o
	$(RISCV_LINK) main.o -o $@ $(RISCV_LINK_OPTS)




include ../../mk/Makefile.tail_rules

clean:
	rm -rf *.o *.a *.jou *.log *.pelog *.pb bsg_manycore_io_complex_rom.v *.riscv *.wdb *.bin *.hex *.ld
	rm -rf xsim.dir *.mem stack.info.*
	rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd *.vdb coverage* constfile.txt
	rm -rf build/ *.bc* *.ll*
	rm -rf lfs.c *.nbf *.csv *.png *.saif
	rm -rf dramsim3epoch.json pc_stats dramsim3.json dramsim3.txt dramsim3.tag.json
	rm -rf dis main.S

