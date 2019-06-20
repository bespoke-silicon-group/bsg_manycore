
# Workspace directory
dir = ../../..

export BSG_CADENV_DIR = $(dir)/bsg_cadenv
export BASEJUMP_STL_DIR = $(dir)/basejump_stl
export BSG_MANYCORE_DIR = ../..

# Environment
include $(BSG_CADENV_DIR)/cadenv.mk

repos = $(BASEJUMP_STL_DIR)

$(BASEJUMP_STL_DIR):
	cd $(dir); git clone https://github.com/bespoke-silicon-group/basejump_stl.git; cd ./basejump_stl; git checkout dev-wormhole-network

run: $(repos)
	$(VCS_BIN)/vcs -full64 -sverilog -timescale=1ps/1ps -f ./filelist -debug_pp -R -top bsg_manycore_loopback_ddr_link_tester +vcs+vcdpluson
    
view: $(repos)
	$(VCS_BIN)/dve -full64 -vpd vcdplus.vpd &

junk = csrc DVEfiles simv.daidir *.old *.vpd simv *.key

clean:
	rm -rf $(junk)
    
clean_all:
	rm -rf $(junk) $(repos)

