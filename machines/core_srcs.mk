# This file contains a list of the *core* manycore architecture files that are
# used in simulation. This has NOT been used in tapeout or any tapeout related
# activities beyond simulation

CORE_SRCS =$(BASEJUMP_STL_DIR)/bsg_misc/bsg_defines.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_noc/bsg_noc_pkg.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_pkg.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_pkg.v

CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_less_than.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_reduce.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_abs.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_mul_synth.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_priority_encode.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_priority_encode_one_hot_out.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_encode_one_hot.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_scan.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux_one_hot.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux_segmented.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_en_bypass.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_en.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_reset.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_transpose.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_crossbar_o_by_i.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_decode_with_v.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_decode.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_counter_clear_up.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_counter_up_down.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_round_robin_arb.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_circular_ptr.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_imul_iterative.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_idiv_iterative.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_idiv_iterative_controller.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_buf.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_buf_ctrl.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_xnor.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_nor2.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_adder_cin.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_cycle_counter.v

CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_1r1w_small.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_two_fifo.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_round_robin_n_to_1.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_parallel_in_serial_out.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_serial_in_parallel_out.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_tracker.v

CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1r1w.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1r1w_synth.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_synth.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_2r1w_sync.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_2r1w_sync_synth.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_byte_synth.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v

CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_stitch.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_router.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_router_buffered.v

CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_classify.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_preprocess.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_add_sub.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_mul.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_cmp.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_i2f.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_f2i.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_clz.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_sticky.v

CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_pkt_decode.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_dma.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_miss.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_sbuf.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_sbuf_queue.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_axi_rx.v
CORE_SRCS+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_axi_tx.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_link_to_cache.v

CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_manycore_proc_vanilla.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/network_rx.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/network_tx.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/vanilla_core.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/alu.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/cl_decode.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_float.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_float_aux.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_int.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/icache.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/imul_idiv_iterative.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/load_packer.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/lsu.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/regfile.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/scoreboard.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/hash_function.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/hash_function_reverse.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_cache_to_axi_hashed.v

CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_tile.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_hetero_socket.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_mesh_node.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_endpoint.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_endpoint_standard.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_lock_ctrl.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_1hold.v
CORE_SRCS+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_link_sif_tieoff.v
