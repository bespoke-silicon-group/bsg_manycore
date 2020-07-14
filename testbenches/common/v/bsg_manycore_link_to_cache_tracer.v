/**
 *  bind this to bsg_manycore_link_to_cache
 *    
 *    prints out addresses that are accessed during the program execution.
 *    used for .nbf minimization.
 *
 *  tommy 2019.07.02
 */


module bsg_manycore_link_to_cache_tracer
  import bsg_cache_pkg::*;
  #(parameter link_addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter cache_addr_width_lp="inv"
    , parameter bsg_cache_pkt_width_lp="inv"

  )
  (
    input clk_i
    , input reset_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    , input [bsg_cache_pkt_width_lp-1:0] cache_pkt_o
    , input v_o
    , input ready_i

    , input trace_en_i
  );

  `declare_bsg_cache_pkt_s(cache_addr_width_lp, data_width_p);
  bsg_cache_pkt_s cache_pkt_cast;

  assign cache_pkt_cast = cache_pkt_o;

  integer fd;

   always @(negedge reset_i)
    if (trace_en_i) begin
      fd = $fopen("vcache.log", "w");
      $fwrite(fd, "");
      $fclose(fd);
    end
   
   always @(negedge clk_i) begin
      if (trace_en_i) begin

          if (~reset_i) begin
            if (v_o & ready_i) begin
              fd = $fopen("vcache.log", "a");

              if (cache_pkt_cast.opcode == SM) begin
                $fwrite(fd, "x=%0d,y=%0d,addr=%0d,data=%0d,opcode=SM,t=%0t\n",
                  my_x_i, my_y_i,
                  cache_pkt_cast.addr, cache_pkt_cast.data, $time
                );
              end
        
              if (cache_pkt_cast.opcode == LM) begin
                $fwrite(fd, "x=%0d,y=%0d,addr=%0d,data=%0d,opcode=LM,t=%0t\n",
                  my_x_i, my_y_i,
                  cache_pkt_cast.addr, cache_pkt_cast.data, $time
                );
              end

              $fclose(fd);
            end
          end // if (~reset_i)
      end // if (trace_en_i)
   end // always @ (negedge clk_i)
endmodule
