
module bsg_manycore_proc_trace #(parameter mem_width_lp=-1
                                 , data_width_p=-1
                                 , addr_width_p="inv"
                                 , load_id_width_p = "inv"
                                 , x_cord_width_p="inv"
                                 , y_cord_width_p="inv"
                                 , packet_width_lp="inv"
                                 , return_packet_width_lp="inv"
                                 , bsg_manycore_link_sif_width_lp="inv"
                                 , num_nets_lp=2
                                 )
  (input clk_i
   , input [2:0] xbar_port_v_in
   , input [2:0][mem_width_lp-1:0] xbar_port_addr_in
   , input [2:0][data_width_p-1:0] xbar_port_data_in
   , input [2:0][(data_width_p>>3)-1:0] xbar_port_mask_in
   , input [2:0] xbar_port_we_in
   , input [2:0] xbar_port_yumi_out
   , input [x_cord_width_p-1:0] my_x_i
   , input [y_cord_width_p-1:0] my_y_i

   , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
   , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

   , input freeze_r
   , input cgni_v_in
   , input [packet_width_lp-1:0] cgni_data_in
   );

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);

   `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);
   bsg_manycore_link_sif_s link_sif_i_cast, link_sif_o_cast;

   assign link_sif_i_cast = link_sif_i;
   assign link_sif_o_cast = link_sif_o;

   bsg_manycore_packet_s [1:0] packets;
   bsg_manycore_return_packet_s [1:0] return_packets;


   genvar i;

   logic [1:0] logwrite;
   logic [2:0] conflicts;

//   if (0)
   always @(negedge clk_i)
     begin
        logwrite = { (xbar_port_we_in[2] & xbar_port_yumi_out[2])
                     ,xbar_port_we_in[1] & xbar_port_yumi_out[1]
          };

        conflicts = xbar_port_yumi_out ^ xbar_port_v_in;

/*        if (~freeze_r & ((|logwrite)
             | link_sif_i_cast.fwd.v
             | link_sif_o_cast.fwd.v
             | link_sif_i_cast.rev.v
             | link_sif_o_cast.rev.v
             | (|conflicts))) */
          begin
             $fwrite(1,"%x ", test_bsg_manycore.cycle_count);
             $fwrite(1,"YX=%x,%x %b%b %b%b %b %x ", my_y_i,my_x_i
                     , link_sif_i_cast.fwd.ready_and_rev
                     , link_sif_o_cast.fwd.ready_and_rev
                     , link_sif_i_cast.rev.ready_and_rev
                     , link_sif_o_cast.rev.ready_and_rev
                     , cgni_v_in
                     , cgni_data_in);

             if (logwrite[0])
               $fwrite(1,"D%1.1x[%x,%b]=%x, ", 1,{ xbar_port_addr_in[1],2'b00},xbar_port_mask_in[1],xbar_port_data_in[1]);

             if (logwrite[1])
               $fwrite(1,"D%1.1x[%x,%b]=%x, ", 2,{ xbar_port_addr_in[2],2'b00},xbar_port_mask_in[2],xbar_port_data_in[2]);

             if (~|logwrite)
               $fwrite(1,"                   ");

             packets        = { link_sif_i_cast.fwd.data, link_sif_o_cast.fwd.data };
             return_packets = { link_sif_i_cast.rev.data, link_sif_o_cast.rev.data };

             if (link_sif_i_cast.fwd.v)
               $fwrite(1,"<-{%2.2b,%4.4b %8.8x,%8.8x,YX={%x,%x->%x,%x}} "
                       ,packets[1].op,packets[1].op_ex,packets[1].addr,packets[1].data, packets[1].return_pkt.y_cord, packets[1].return_pkt.x_cord, packets[1].y_cord,packets[1].x_cord);

             if (link_sif_o_cast.fwd.v)
               $fwrite(1,"->{%2.2b,%4.4b %8.8x,%8.8x,YX={%x,%x->%x,%x}} "
                       ,packets[0].op,packets[0].op_ex,packets[0].addr,packets[0].data,  packets[0].return_pkt.y_cord, packets[0].return_pkt.x_cord, packets[0].y_cord,packets[0].x_cord);

//             if (link_sif_i_cast.rev.v)
               $fwrite(1,"<-c(YX=%x,%x) ",return_packets[1].y_cord, return_packets[1].x_cord);

//             if (link_sif_o_cast.rev.v)
               $fwrite(1,"->c(YX=%x,%x) ",return_packets[0].y_cord, return_packets[0].x_cord);

             // detect bank conflicts

             if (|conflicts)
               $fwrite(1,"C%b",conflicts);

             $fwrite(1,"\n");
          end // if (xbar_port_yumi_out[1]...
     end
endmodule
