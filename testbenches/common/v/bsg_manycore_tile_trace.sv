

module bsg_manycore_tile_trace #(
  bsg_manycore_link_sif_width_lp="inv"
  ,packet_width_lp="inv"
  ,return_packet_width_lp="inv"
  ,x_cord_width_p="inv"
  ,y_cord_width_p="inv"
  ,addr_width_p="inv"
  ,data_width_p="inv"
  ,load_id_width_p="inv"
  ,dirs_lp=4
  ,num_nets_lp=2
  )
   (input clk_i
    , input  [dirs_lp-1:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_i
    , input [dirs_lp-1:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_o
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
    , input freeze
    );

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);

   bsg_manycore_link_sif_s [dirs_lp-1:0] links_sif_i_cast, links_sif_o_cast;

   bsg_manycore_packet_s [dirs_lp-1:0] pkt;
   bsg_manycore_return_packet_s [dirs_lp-1:0] return_pkt;

   assign links_sif_i_cast = links_sif_i;
   assign links_sif_o_cast = links_sif_o;

   genvar i;

   logic [dirs_lp-1:0] activity;

   for (i = 0; i < dirs_lp; i=i+1)
     begin : rof2
        assign pkt[i]        = links_sif_o_cast[i].fwd.data;
        assign return_pkt[i] = links_sif_o_cast[i].rev.data;
        assign activity  [i] = (links_sif_o_cast[i].fwd.v & links_sif_i_cast[i].fwd.v)
                              |(links_sif_o_cast[i].rev.v & links_sif_i_cast[i].rev.v);
     end


//   if (0)
   always @(negedge clk_i)
     begin
//        if ( ~freeze &  (|activity))
        if (1)
          begin
             $fwrite(1,"%x ", test_bsg_manycore.cycle_count);
             $fwrite(1,"YX=%x,%x r ", my_y_i,my_x_i);
             $fwrite(1,"WENS vo=%b%b%b%b ri=%b%b%b%b vi=%b%b%b%b ro=%b%b%b%b "
                     ,links_sif_o_cast[0].fwd.v
                     ,links_sif_o_cast[1].fwd.v
                     ,links_sif_o_cast[2].fwd.v
                     ,links_sif_o_cast[3].fwd.v

                     ,links_sif_i_cast[0].fwd.ready_and_rev
                     ,links_sif_i_cast[1].fwd.ready_and_rev
                     ,links_sif_i_cast[2].fwd.ready_and_rev
                     ,links_sif_i_cast[3].fwd.ready_and_rev

                     ,links_sif_i_cast[0].fwd.v
                     ,links_sif_i_cast[1].fwd.v
                     ,links_sif_i_cast[2].fwd.v
                     ,links_sif_i_cast[3].fwd.v

                     ,links_sif_o_cast[0].fwd.ready_and_rev
                     ,links_sif_o_cast[1].fwd.ready_and_rev
                     ,links_sif_o_cast[2].fwd.ready_and_rev
                     ,links_sif_o_cast[3].fwd.ready_and_rev

                     );
//             if (links_sif_o_cast[0].fwd.v & links_sif_i_cast[0].fwd.ready_and_rev)
               $fwrite(1,"W<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}"
                       ,pkt[0].op,pkt[0].addr,pkt[0].data, pkt[0].return_pkt.y_cord, pkt[0].return_pkt.x_cord, pkt[0].y_cord,pkt[0].x_cord);
//             if (links_sif_o_cast[1].fwd.v & links_sif_i_cast[1].fwd.ready_and_rev)
               $fwrite(1,"E<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[1].op,pkt[1].addr,pkt[1].data, pkt[1].return_pkt.y_cord, pkt[1].return_pkt.x_cord,pkt[1].y_cord,pkt[1].x_cord);
//             if (links_sif_o_cast[2].fwd.v & links_sif_i_cast[2].fwd.ready_and_rev)
               $fwrite(1,"N<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[2].op,pkt[2].addr,pkt[2].data, pkt[2].return_pkt.y_cord, pkt[2].return_pkt.x_cord, pkt[2].y_cord,pkt[2].x_cord);
//             if (links_sif_o_cast[3].fwd.v & links_sif_i_cast[3].fwd.ready_and_rev)
               $fwrite(1,"S<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[3].op,pkt[3].addr,pkt[3].data, pkt[3].return_pkt.y_cord, pkt[3].return_pkt.x_cord, pkt[3].y_cord,pkt[3].x_cord);

//             if (links_sif_o_cast[0].rev.v & links_sif_i_cast[0].rev.ready_and_rev)
               $fwrite(1,"W<-c YX={%x,%x}", return_pkt[0].y_cord, return_pkt[0].x_cord);
//             if (links_sif_o_cast[1].rev.v & links_sif_i_cast[1].rev.ready_and_rev)
               $fwrite(1,"E<-c YX={%x,%x}", return_pkt[1].y_cord, return_pkt[1].x_cord);
//             if (links_sif_o_cast[2].rev.v & links_sif_i_cast[2].rev.ready_and_rev)
               $fwrite(1,"N<-c YX={%x,%x}", return_pkt[2].y_cord, return_pkt[2].x_cord);
//             if (links_sif_o_cast[3].rev.v & links_sif_i_cast[3].rev.ready_and_rev)
               $fwrite(1,"S<-c YX={%x,%x}", return_pkt[3].y_cord, return_pkt[3].x_cord);

             $fwrite(1,"\n");

          end
     end
endmodule
