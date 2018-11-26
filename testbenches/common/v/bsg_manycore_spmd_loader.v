`include "bsg_manycore_packet.vh"

//should we shut down the dynamic feature of the arbiter ?
//`define  SHUT_DY_ARB

`ifndef NUM_CODE_SECTIONS
	`define DEFAULT_CODE_SECTIONS
`endif
`ifndef CODE_SECTIONS
	`define DEFAULT_CODE_SECTIONS
`endif

`ifdef DEFAULT_CODE_SECTIONS
	`define NUM_CODE_SECTIONS 1
	`define CODE_SECTIONS `_bsg_dram_start_addr,`_bsg_dram_end_addr
`endif

module bsg_manycore_spmd_loader

import bsg_noc_pkg   ::*; // {P=0, W, E, N, S}

 #( parameter icache_entries_num_p   = -1 // size of icache entry
   ,parameter data_width_p    = 32
   ,parameter addr_width_p    = 30
   ,parameter epa_addr_width_p= 16
   ,parameter dram_ch_addr_width_p=-1
   ,parameter tile_id_ptr_p   = -1
   ,parameter num_rows_p      = -1
   ,parameter num_cols_p      = -1
   ,parameter load_rows_p     = num_rows_p
   ,parameter load_cols_p     = num_cols_p

   ,parameter y_cord_width_lp  = `BSG_SAFE_CLOG2(num_rows_p + 1)
   ,parameter x_cord_width_lp  = `BSG_SAFE_CLOG2(num_cols_p)
   ,parameter packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)
   //the data memory realted paraemters
   ,parameter unsigned  dmem_start_addr_lp = `_bsg_data_start_addr
   ,parameter dmem_end_addr_lp   = `_bsg_data_end_addr
   ,parameter dmem_init_file_name = `_dmem_init_file_name

   //the dram  realted paraemters
   //VCS do not support index larger then 32'h7fff_ffff
   ,parameter unsigned dram_start_addr_lp = `_bsg_dram_start_addr
   ,parameter unsigned dram_end_addr_lp   = `_bsg_dram_end_addr  
   ,parameter dram_init_file_name = `_dram_init_file_name

   // Only the address space derived from the follwoing prameters is
   // loaded into the memory
   ,parameter unsigned num_code_sections_p = `NUM_CODE_SECTIONS
   ,parameter integer code_sections_p[0:(2*num_code_sections_p)-1] = '{`CODE_SECTIONS}
  )
  ( input                        clk_i
   ,input                        reset_i
   ,output [packet_width_lp-1:0] data_o
   ,output                       v_o
   ,input                        ready_i

   ,input [y_cord_width_lp-1:0]  my_y_i
   ,input [x_cord_width_lp-1:0]  my_x_i
  );

  //initilization files
  localparam dmem_size_lp = dmem_end_addr_lp - dmem_start_addr_lp;
  localparam dram_size_lp = dram_end_addr_lp - dram_start_addr_lp; 

  logic [7:0]  DMEM[dmem_end_addr_lp:dmem_start_addr_lp];
  logic [7:0]  DRAM[dram_end_addr_lp:dram_start_addr_lp];

  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp);
  `declare_bsg_manycore_dram_addr_s(dram_ch_addr_width_p);

  localparam    config_addr_bits = 1 << ( epa_addr_width_p-1);
  localparam    unfreeze_addr = addr_width_p'(0) | config_addr_bits;

  logic                         var_v_o;
  bsg_manycore_packet_s         var_data_o;

  assign v_o    = var_v_o;
  assign data_o = var_data_o;

//----------------------------------------------------------------------------
// Main Procedure 
//----------------------------------------------------------------------------
  initial begin
        $readmemh(dmem_init_file_name, DMEM);
        $readmemh(dram_init_file_name, DRAM);
        
        var_v_o = 1'b0;
        wait( reset_i === 1'b0); //wait until the reset is done

        init_icache_tag ();
        init_dmem       ();
        init_dram       ();
        unfreeze_tiles  ();

        @(posedge clk_i);  
        var_v_o = 1'b0;
  end
//----------------------------------------------------------------------------
// Task to init the icache
//----------------------------------------------------------------------------
  task init_icache_tag();
        int x_cord, y_cord, icache_addr;
        for (y_cord =0; y_cord < num_rows_p; y_cord++ ) begin
                for (x_cord =0; x_cord < num_cols_p; x_cord ++) begin
                     $display("Initilizing ICACHE, y_cord=%02d, x_cord=%02d, range=0000 - %h", y_cord, x_cord, icache_entries_num_p-1);
                     for(icache_addr =0; icache_addr <icache_entries_num_p; icache_addr ++) begin
                                @(posedge clk_i);          //pull up the valid
                                var_v_o = 1'b1; 

                                var_data_o.data   = 'b0;
                                var_data_o.addr   =  icache_addr;
                                var_data_o.op     = `ePacketOp_remote_store;
                                var_data_o.op_ex  =  4'b1111;
                                var_data_o.x_cord = x_cord;
                                var_data_o.y_cord = y_cord;
                                var_data_o.src_x_cord = my_x_i;
                                var_data_o.src_y_cord = my_y_i;

                                @(negedge clk_i);
                                wait( ready_i === 1'b1);   //check if the ready is pulled up.
                       end 
                end
        end
  endtask 
  ///////////////////////////////////////////////////////////////////////////////
  // Task to load the data memory
  task init_dmem();
        int x_cord, y_cord, dmem_addr, init_data;
        for (y_cord =0; y_cord < num_rows_p; y_cord++ ) begin
                for (x_cord =0; x_cord < num_cols_p; x_cord ++) begin
                     $display("Initilizing DMEM, y_cord=%02d, x_cord=%02d, range=%h - %h (byte)", y_cord, x_cord, dmem_start_addr_lp, dmem_end_addr_lp);
                     for(dmem_addr =dmem_start_addr_lp; dmem_addr < dmem_end_addr_lp; dmem_addr= dmem_addr +4) begin
                                @(posedge clk_i);          //pull up the valid
                                var_v_o = 1'b1; 
                                
                                init_data   = {DMEM[dmem_addr+3], DMEM[dmem_addr+2], DMEM[dmem_addr+1], DMEM[dmem_addr]};
                                //TODO: SHX: This is used to fixe the
                                //gcc-toolchain bugs, in some case, it put the initilized data into .bss and .sbss section.
                                //which should be in .data or .sdata seciton. 
                                //
                                //Does the RISC-V toolchain assumes that all uninitilized data are zeros, so they put the zero
                                //initilized data into .bss and .sbss section?
                                //--------------------------------------------------------------------------------------------
                                if( init_data === 32'bx) init_data = 32'b0;
                                //--------------------------------------------------------------------------------------------
                                
                                var_data_o.data   = init_data    ;
                                var_data_o.addr   =  dmem_addr>>2;
                                var_data_o.op     = `ePacketOp_remote_store;
                                var_data_o.op_ex  =  4'b1111; //TODO not handle the byte write.
                                var_data_o.x_cord = x_cord;
                                var_data_o.y_cord = y_cord;
                                var_data_o.src_x_cord = my_x_i;
                                var_data_o.src_y_cord = my_y_i;

                                @(negedge clk_i);
                                wait( ready_i === 1'b1);   //check if the ready is pulled up.
                       end 
                end
        end
  endtask 
  ///////////////////////////////////////////////////////////////////////////////
  // Task to load the dram
  task init_dram( );
        int dram_addr;
        bsg_manycore_dram_addr_s  dram_addr_cast; 

        int instr_count = 0;
        for(integer section = 0; section < num_code_sections_p; section = section + 1) begin
            $display("Initilizing DRAM section:%2d, range=%h - %h", section+1, code_sections_p[2*section], code_sections_p[2*section+1]);
            for(dram_addr = code_sections_p[2*section]; dram_addr < code_sections_p[2*section+1]; dram_addr= dram_addr +4) begin
                       @(posedge clk_i);          //pull up the valid
                       instr_count++;
                       var_v_o = 1'b1; 

                       dram_addr_cast = dram_addr; 

                       var_data_o.data   = {DRAM[dram_addr+3], DRAM[dram_addr+2], DRAM[dram_addr+1], DRAM[dram_addr]};
                       var_data_o.addr   = dram_addr >>2;
                       var_data_o.op     = `ePacketOp_remote_store;
                       var_data_o.op_ex  =  4'b1111; //TODO not handle the byte write.
                       var_data_o.x_cord = x_cord_width_lp'( dram_addr_cast.x_cord );
                       var_data_o.y_cord = {y_cord_width_lp{1'b1}};
                       var_data_o.src_x_cord = my_x_i;
                       var_data_o.src_y_cord = my_y_i;

                       @(negedge clk_i);
                       wait( ready_i === 1'b1);   //check if the ready is pulled up.
            end
        end
        $display("instr_count %d", instr_count);
  endtask 
  ///////////////////////////////////////////////////////////////////////////////
  // Task to unfreeze the tiles
  task unfreeze_tiles();
        int x_cord, y_cord ;

        $display("Unfreezing tiles ...");
        for (y_cord =0; y_cord < num_rows_p; y_cord++ ) begin
                for (x_cord =0; x_cord < num_cols_p; x_cord ++) begin
                    @(posedge clk_i);          //pull up the valid
                    var_v_o = 1'b1; 

                    var_data_o.data   =  'b0;
                    var_data_o.addr   = unfreeze_addr >> 2; 
                    var_data_o.op     = `ePacketOp_remote_store;
                    var_data_o.op_ex  =  4'b1111; //TODO not handle the byte write.
                    var_data_o.x_cord = x_cord;
                    var_data_o.y_cord = y_cord;
                    var_data_o.src_x_cord = my_x_i;
                    var_data_o.src_y_cord = my_y_i;

                    @(negedge clk_i);
                    wait( ready_i === 1'b1);   //check if the ready is pulled up.
                end
        end
  endtask 
endmodule
