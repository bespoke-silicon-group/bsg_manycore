# This file contains a list of the *core* manycore architecture files that are
# used in simulation. This has NOT been used in tapeout or any tapeout related
# activities beyond simulation

ARCH_VINCDIRS =$(BASEJUMP_STL_DIR)/bsg_misc
ARCH_VINCDIRS+=$(BASEJUMP_STL_DIR)/bsg_cache
ARCH_VINCDIRS+=$(BASEJUMP_STL_DIR)/bsg_noc
ARCH_VINCDIRS+=$(BSG_MANYCORE_DIR)/v
ARCH_VINCDIRS+=$(BSG_MANYCORE_DIR)/v/vanilla_bean

ARCH_VDEFINES =$(BASEJUMP_STL_DIR)/bsg_misc/bsg_defines.v
ARCH_VDEFINES+=$(BASEJUMP_STL_DIR)/bsg_noc/bsg_noc_pkg.v
ARCH_VDEFINES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_pkg.v
ARCH_VDEFINES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_pkg.v

ARCH_VSOURCES =$(BASEJUMP_STL_DIR)/bsg_misc/bsg_less_than.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_reduce.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_abs.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_mul_synth.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_priority_encode.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_priority_encode_one_hot_out.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_encode_one_hot.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_scan.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux_one_hot.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux_segmented.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_en_bypass.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_en.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_reset.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_transpose.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_crossbar_o_by_i.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_decode_with_v.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_decode.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_counter_clear_up.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_counter_up_down.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_round_robin_arb.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_circular_ptr.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_imul_iterative.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_idiv_iterative.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_idiv_iterative_controller.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_buf.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_buf_ctrl.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_xnor.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_nor2.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_adder_cin.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_misc/bsg_cycle_counter.v

ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_1r1w_small.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_two_fifo.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_round_robin_n_to_1.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_parallel_in_serial_out.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_serial_in_parallel_out.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_tracker.v

ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1r1w.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1r1w_synth.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_synth.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_2r1w_sync.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_2r1w_sync_synth.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_byte_synth.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v

ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_stitch.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_router.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_router_buffered.v

ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_classify.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_preprocess.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_add_sub.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_mul.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_cmp.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_i2f.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_f2i.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_clz.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_sticky.v

ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_pkt_decode.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_dma.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_miss.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_sbuf.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_sbuf_queue.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_axi_rx.v
ARCH_VSOURCES+=$(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_axi_tx.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_link_to_cache.v

ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_manycore_proc_vanilla.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/network_rx.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/network_tx.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/vanilla_core.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/alu.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/cl_decode.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_float.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_float_aux.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_int.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/icache.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/imul_idiv_iterative.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/load_packer.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/lsu.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/regfile.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/scoreboard.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/hash_function.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/hash_function_reverse.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_cache_to_axi_hashed.v

ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_tile.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_hetero_socket.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_mesh_node.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_endpoint.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_endpoint_standard.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_lock_ctrl.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_1hold.v
ARCH_VSOURCES+=$(BSG_MANYCORE_DIR)/v/bsg_manycore_link_sif_tieoff.v
