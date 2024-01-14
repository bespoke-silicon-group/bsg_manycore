include ../../../cad/common/mk/cadenv.mk
include ../../../cad/flow/dc/rm_setup/dc.mk

BSG_IP_CORES_DIR=../../../bsg_ip_cores
BSG_MANYCORE_DIR=../../../bsg_manycore

# be careful about changing these
# as the packet format will change in input.trace

export bsg_tiles_X=4
export bsg_tiles_Y=1

VLOG  = xvlog -sv
VELAB = xelab -debug typical -s top_sim
VSIM  = xsim --runall top_sim


ifeq ($(BSG_IP_CORES_DIR),)
$(error BSG_IP_CORES_DIR must be defined)
endif

ifeq ($(BSG_MANYCORE_DIR),)
$(error BSG_MANYCORE_DIR must be defined)
endif

DESIGN_HDRS = $(addprefix $(BSG_IP_CORES_DIR)/, bsg_misc/bsg_defines.sv bsg_noc/bsg_noc_pkg.v bsg_noc/bsg_noc_links.vh)     \
              -i $(BSG_MANYCORE_DIR)/v/ -i $(BSG_IP_CORES_DIR)/bsg_noc

DESIGN_SRCS = \
  $(addprefix $(BSG_IP_CORES_DIR)/, bsg_misc/bsg_transpose.sv bsg_misc/bsg_crossbar_o_by_i.v bsg_misc/bsg_cycle_counter.v\
    bsg_misc/bsg_round_robin_arb.sv bsg_misc/bsg_arb_fixed.v bsg_misc/bsg_priority_encode.v bsg_misc/bsg_priority_encode_one_hot_out.v \
    bsg_misc/bsg_mux_one_hot.sv bsg_misc/bsg_encode_one_hot.v bsg_misc/bsg_scan.v bsg_misc/bsg_counter_up_down.v \
    bsg_misc/bsg_circular_ptr.sv bsg_mem/bsg_mem_1r1w.v  bsg_dataflow/bsg_fifo_tracker.v  bsg_misc/bsg_dff_reset.v        \
    bsg_mem/bsg_mem_1rw_sync_mask_write_byte.sv bsg_mem/bsg_mem_1rw_sync.sv bsg_dataflow/bsg_fifo_1r1w_small.v bsg_dataflow/bsg_two_fifo.v \
    bsg_test/bsg_nonsynth_clock_gen.sv bsg_test/bsg_nonsynth_reset_gen.v bsg_noc/bsg_mesh_router.v bsg_noc/bsg_mesh_stitch.v \
    bsg_noc/bsg_mesh_router_buffered.sv bsg_misc/bsg_decode_with_v.v bsg_misc/bsg_decode.v bsg_misc/bsg_dff_reset_en.v bsg_misc/bsg_counter_clear_up.v) \
  $(addprefix $(BSG_MANYCORE_DIR)/v/, bsg_manycore_mesh.v bsg_manycore_mesh_node.v bsg_manycore_pkt_encode.v bsg_manycore_pkt_decode.v bsg_manycore_packet_streamer.v \
                                      bsg_manycore_endpoint.sv bsg_manycore_endpoint_standard.v bsg_manycore_link_sif_tieoff.v bsg_manycore_accel_default.v ) \
  $(addprefix $(BSG_MANYCORE_DIR)/testbenches/network_only/, adn_example.sv ) \
  $(addprefix $(BSG_MANYCORE_DIR)/testbenches/common/v/, bsg_nonsynth_manycore_packet_printer.sv)

TOP_LEVEL = $(BSG_MANYCORE_DIR)/testbenches/network_only/test_bsg_manycore.sv

all: gen_adn.run

bsg_rom_gen_adn.v: input.trace
	$(BSG_IP_CORES_DIR)/bsg_mem/bsg_ascii_to_rom.py input.trace bsg_rom_gen_adn > bsg_rom_gen_adn.v

clean:
	-rm bsg_rom_gen_adn.v  *.log *.pb *.jou *.wdb
	-rm -rf xsim.dir


%.run: bsg_rom_%.v
	$(VLOG) $(DESIGN_HDRS) $(DESIGN_SRCS) bsg_rom_$*.v $(TOP_LEVEL) -d SPMD=$* -d bsg_tiles_X=$(bsg_tiles_X) -d bsg_tiles_Y=$(bsg_tiles_Y) $(VLOG_EXTRA)
	$(VELAB) test_bsg_manycore | grep -v Compiling
	$(VSIM) $(TEE-CMD)

vcs.run: bsg_rom_gen_adn.v
	$(VCS) -full64 -sverilog  -top test_bsg_manycore  $(TOP_LEVEL) $(DESIGN_HDRS) $(DESIGN_SRCS) $< +define+bsg_tiles_X=$(bsg_tiles_X) +define+bsg_tiles_Y=$(bsg_tiles_Y) +incdir+$(BSG_IP_CORES_DIR)/bsg_misc  +incdir+$(BSG_IP_CORES_DIR)/bsg_noc +incdir+$(BSG_MANYCORE_DIR)/v
	./simv
