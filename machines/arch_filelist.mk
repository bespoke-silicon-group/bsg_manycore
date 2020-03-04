# This file contains a list of the *core* manycore architecture files that are
# used in simulation. This has NOT been used in tapeout or any tapeout related
# activities beyond simulation

VINCLUDES += $(BASEJUMP_STL_DIR)/bsg_misc
VINCLUDES += $(BASEJUMP_STL_DIR)/bsg_cache
VINCLUDES += $(BASEJUMP_STL_DIR)/bsg_noc
VINCLUDES += $(BASEJUMP_STL_DIR)/bsg_fpu
VINCLUDES += $(BSG_MANYCORE_DIR)/v
VINCLUDES += $(BSG_MANYCORE_DIR)/v/vanilla_bean

VHEADERS += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_defines.v
VHEADERS += $(BASEJUMP_STL_DIR)/bsg_noc/bsg_noc_pkg.v
VHEADERS += $(BASEJUMP_STL_DIR)/bsg_noc/bsg_noc_links.vh
VHEADERS += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_pkg.v
VHEADERS += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_pkg.v
VHEADERS += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_defines.vh
VHEADERS += $(BSG_MANYCORE_DIR)/v/bsg_manycore_pkg.v
VHEADERS += $(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_vanilla_pkg.v
VHEADERS += $(BSG_MANYCORE_DIR)/v/bsg_manycore_addr_pkg.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_less_than.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_reduce.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_abs.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_mul_synth.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_priority_encode.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_priority_encode_one_hot_out.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_encode_one_hot.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_scan.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux_one_hot.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux_segmented.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_mux_bitwise.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_en_bypass.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_en.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_reset.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_dff_reset_en.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_transpose.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_crossbar_o_by_i.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_decode_with_v.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_decode.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_counter_clear_up.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_counter_up_down.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_round_robin_arb.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_circular_ptr.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_imul_iterative.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_idiv_iterative.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_idiv_iterative_controller.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_buf.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_buf_ctrl.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_xnor.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_nor2.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_adder_cin.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_expand_bitmask.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_lru_pseudo_tree_decode.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_lru_pseudo_tree_encode.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_lru_pseudo_tree_backup.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_thermometer_count.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_1r1w_large.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_1rw_large.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_1r1w_small.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_1r1w_small_unhardened.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_two_fifo.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_round_robin_n_to_1.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_round_robin_2_to_2.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_parallel_in_serial_out.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_serial_in_parallel_out.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_fifo_tracker.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_make_2D_array.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_flatten_2D_array.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1r1w.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1r1w_synth.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1r1w_sync.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1r1w_sync_synth.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_synth.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_2r1w_sync.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_2r1w_sync_synth.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_byte_synth.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_stitch.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_router.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_noc/bsg_mesh_router_buffered.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_classify.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_preprocess.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_add_sub.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_mul.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_cmp.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_i2f.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_f2i.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_clz.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fpu/bsg_fpu_sticky.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_async/bsg_launch_sync_sync.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_async/bsg_sync_sync.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_async/bsg_async_fifo.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_async/bsg_async_ptr_gray.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_decode.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_dma.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_miss.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_sbuf.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_sbuf_queue.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_link_to_cache.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_vcache_blocking.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_decode.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_miss_fifo.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_data_mem.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_stat_mem.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_tag_mem.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_dma.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_mhu.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_tl_stage.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_link_to_cache_non_blocking.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_vcache_non_blocking.v

VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_manycore_proc_vanilla.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/network_rx.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/network_tx.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/vanilla_core.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/alu.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/cl_decode.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_float.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_float_aux.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/fpu_int.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/icache.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/imul_idiv_iterative.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/load_packer.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/lsu.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/regfile.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/scoreboard.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/hash_function.v

VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_tile.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_hetero_socket.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_mesh_node.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_endpoint.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_endpoint_standard.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_lock_ctrl.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_1hold.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_link_sif_tieoff.v
