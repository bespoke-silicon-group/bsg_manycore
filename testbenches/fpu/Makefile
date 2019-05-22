INCDIR = +incdir+$(BSG_MANYCORE_DIR)/v/vanilla_bean
INCDIR += +incdir+$(BASEJUMP_STL_DIR)/bsg_misc

all: sim

bsg_trace_rom.v: trace.tr
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py trace.tr bsg_trace_rom \
	  > bsg_trace_rom.v

sim: bsg_trace_rom.v
	vcs +v2k -R +lint=all,noSVA-UA,noSVA-NSVU,noVCDE -sverilog -full64 -f sv.include \
		$(INCDIR) -debug_pp -timescale=1ps/1ps +vcs+vcdpluson -l vcs.log

dve:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf DVEfiles csrc simv.daidir simv.vdb
	rm -f bsg_trace_rom.v
	rm -f ucli.key vcdplus.vpd simv *.tar.gz vcs.log
	rm -rf stack.info.*
