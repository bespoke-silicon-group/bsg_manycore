// MBT 9/18/2016
//
// this is a hardware version of bsg_tq_receiver_confirm and bsg_tq_receiver_release
//
//

module bsg_tq_receiver #(width_p       = 32
                       // the greatest amount that is processed at a time
                         , max_depth_p = 1
                         , lg_max_depth_p = `BSG_CLOG2_SAFE(max_depth_p+1)
                         )
   (input clk_i
    , input reset_i

    , output confirm_o
    , input release_i

    , input [lg_max_depth_p-1:0] depth_i

    , input                send_v_i
    , input [width_p-1:0]  send_data_i

    , output               receive_v_o
    , output [width_p-1:0] receive_data_o
    , input                receive_yumi_o
    );

   logic [width_p-1:0] send_r, receive_r, send_n, receive_n, diff_n;

   // this is the send register, which gets
   // updated by the remote party

   bsg_dff_reset_en #(.width_p(width_p)) send_reg
     (
      .clock_i (clk_i)
      ,.reset_i
      ,.en_i   (send_v_i   )
      ,.data_i (send_data_i)
      ,.data_o (send_r)
      );

   // this is the receive register, which gets
   // updated by the local party

   bsg_dff_reset_en #(.width_p(width_p)) receive_reg
     (
      .clock_i (clk_i)
      ,.reset_i
      ,.en_i   (receive_yumi_o)
      ,.data_i (receive_n)
      ,.data_o (receive_r)
      );

   assign receive_n = (receive_r + depth_i);
   assign diff_n    = (receive_n - send_r);

   // if the sign bit is not set, then
   // we can confirm because there is enough data

   assign confirm_o = ~diff_n[width_p-1];

   // we update the receive register when
   //
   //   - we receive a release_i signal (implying confirm_i is also set)
   //        -- AND --
   //   - we are able to transmit an update packet
   //

   assign receive_v_o     = release_i;
   assign receive_data_o  = receive_n;

   always @(negedge clk_i)
     assert (~release_i | confirm_o)
       else $error("## release_i without confirm high! (%m)");

endmodule
