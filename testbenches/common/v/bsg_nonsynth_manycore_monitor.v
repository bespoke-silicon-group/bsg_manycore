`include "bsg_manycore_packet.vh"

module bsg_nonsynth_manycore_monitor #( x_cord_width_p="inv"
                                       , y_cord_width_p="inv"
                                       , addr_width_p="inv"
                                       , data_width_p="inv"
                                       , load_id_width_p = "inv"
                                       , channel_num_p="inv"
                                        // enable pass_thru
                                       , pass_thru_p=0
                                       , pass_thru_max_out_credits_p=4
                                       , pass_thru_freeze_init_p=1'b0
                                       , max_cycles_p=1_000_000
                                       , packet_width_lp                = `bsg_manycore_packet_width  (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
                                       , bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
                                       , num_nets_lp=2
                                       )
   (input clk_i
    ,input  reset_i

    ,input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    ,output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // this allows you to attach nodes to the monitor
    // that send data, such as the bsg_manycore_spmd_loader
    // these are only used if pass_thru_p=1

    ,input  [packet_width_lp-1:0] pass_thru_data_i
    ,input                        pass_thru_v_i
    ,output                       pass_thru_ready_o
    ,output [$clog2(pass_thru_max_out_credits_p+1)-1:0] pass_thru_out_credits_o
    ,input [x_cord_width_p-1:0]   pass_thru_x_i
    ,input [y_cord_width_p-1:0]   pass_thru_y_i

    ,input [39:0] cycle_count_i
    ,output finish_o
	,output success_o
	,output timeout_o
    );

   logic                              cgni_v, cgni_yumi;

   logic [data_width_p-1:0     ]      pkt_data;
   logic [addr_width_p-1:0     ]      pkt_addr;
   logic [(data_width_p>>3)-1:0]      pkt_mask;
   logic [x_cord_width_p-1:0]         pkt_x_cord;
   logic [y_cord_width_p-1:0]         pkt_y_cord;

   logic cgni_yumi_r;
   bsg_manycore_endpoint_standard #(.x_cord_width_p    (x_cord_width_p)
                                    ,.y_cord_width_p   (y_cord_width_p)
                                    ,.fifo_els_p       (2)
                                    //,.freeze_init_p (pass_thru_freeze_init_p)
                                    ,.max_out_credits_p(pass_thru_max_out_credits_p)
                                    ,.data_width_p     (data_width_p)
                                    ,.addr_width_p     (addr_width_p)
                                    ,.load_id_width_p  (load_id_width_p)
                                    ) endp
     (.clk_i
      ,.reset_i

      ,.link_sif_i
      ,.link_sif_o

      ,.in_v_o         (cgni_v)
      ,.in_yumi_i      (cgni_yumi)
      ,.in_data_o      (pkt_data)
      ,.in_mask_o      (pkt_mask)
      ,.in_addr_o      (pkt_addr)
      ,.in_we_o        ()
      ,.in_src_x_cord_o(pkt_x_cord)
      ,.in_src_y_cord_o(pkt_y_cord)

      ,.returned_data_r_o   ()
      ,.returned_load_id_r_o()
      ,.returned_v_r_o      ()

      ,.returning_data_i ( 0 )
      //we have to delay the returning data at least 1 cycle.
      ,.returning_v_i    (cgni_yumi_r )

      // outgoing data for this module
      ,.out_v_i     (pass_thru_p ? pass_thru_v_i    : 1'b0)
      ,.out_packet_i(pass_thru_p ? pass_thru_data_i : 0)
      ,.out_ready_o (pass_thru_ready_o)
      ,.out_credits_o(pass_thru_out_credits_o)

      ,.my_x_i(pass_thru_x_i)
      ,.my_y_i(pass_thru_y_i)
      );

   // incoming packets on main network: always deque
   assign cgni_yumi = cgni_v;

   logic finish_r, finish_r_r;
   logic success_r, timeout_r;

   assign finish_o = finish_r;
   assign success_o = success_r;
   assign timeout_o = timeout_r;

   always @(posedge clk_i)
     finish_r_r <= finish_r;

   always_ff @(posedge clk_i)
     if (finish_r_r)
       $finish();

   always_ff@(posedge clk_i)
     cgni_yumi_r <= cgni_yumi;

   always @(negedge clk_i)
   begin
     if (reset_i == 0)
       begin
		   if (cycle_count_i > max_cycles_p)
		   begin
			 $display("## TIMEOUT reached max_cycles_p = %x",max_cycles_p);
			 finish_r <= 1'b1;
			 timeout_r <= 1'b1;
		   end

          if (cgni_v)
            begin

               unique case ({pkt_addr[addr_width_p-2:0],2'b00})
                 16'hEAD_0:
                   begin
                      $display("## RECEIVED FINISH PACKET from tile y,x=%2d,%2d at I/O %x, data %x on cycle 0x%x (%d)"
                               ,pkt_y_cord
                               ,pkt_x_cord
                               ,channel_num_p
                               ,pkt_data
                               ,cycle_count_i
                               ,cycle_count_i
                               );
                      finish_r <= 1'b1;
					            success_r <= 1'b1;
                   end
                 16'hEAD_4:
                   begin
                      $display("## RECEIVED TIME PACKET from tile y,x=%2d,%2d at I/O %x, data %x on cycle 0x%x (%d)"
                               ,pkt_y_cord
                               ,pkt_x_cord
                               ,channel_num_p
                               ,pkt_data
                               ,cycle_count_i
                               ,cycle_count_i);
                   end
                 16'hEAD_8:
                   begin
                      $display("## RECEIVED FAIL PACKET from tile y,x=%2d,%2d at I/O %x, data %x on cycle 0x%x (%d)"
                               ,pkt_y_cord
                               ,pkt_x_cord
                               ,channel_num_p
                               ,pkt_data
                               ,cycle_count_i
                               ,cycle_count_i
                               );
                      finish_r <= 1'b1;
                   end

                 default:
                   $display("## RECEIVED I/O PACKET from tile y,x=%2d,%2d at I/O %x, addr %x, data %x on cycle (%d)"
                            ,pkt_y_cord
                            ,pkt_x_cord
                            ,channel_num_p
                            ,pkt_addr<<2
                            ,pkt_data
                            ,cycle_count_i
                            );
               endcase
            end
       end else begin
			finish_r <= 1'b0;
			success_r <= 1'b0;
			timeout_r <= 1'b0;
	   end
	end

endmodule

