// MBT 9/18/2016
//
// this is a hardware version of bsg_tq_sender_confirm and bsg_tq_sender_xfer
//
//

module bsg_tq_sender #(width_p       = 32
                       // the largest buffer ever allowed
                       , max_els_p   = -1
                       // the greatest amount that is every sent at a time
                       , max_depth_p = 1
                       , lg_max_depth_p = `BSG_CLOG2_SAFE(max_depth_p+1)
                       , lg_max_els_p   = `BSG_CLOG2_SAFE(max_els_p+1)
                       )
   (input clk_i
    , input reset_i

    , output confirm_o
    , input release_i  // aka xfer


    // how much we want to transfer
    , input [lg_max_depth_p-1:0] depth_i

    // incoming configuration data
    // how many elements are in the remote buffer
    , input                      max_els_v_i
    , input [lg_max_els_p-1:0]   max_els_data_i

    // incoming data from receiver
    , input                receive_v_i
    , input [width_p-1:0]  receive_data_i

    // whether outstanding stores are committed
    , input                stores_committed_i

    , output               send_v_o       // this also indicates successful release
    , output [width_p-1:0] send_data_o
    , input                send_yumi_o
    );

   logic [width_p-1:0] send_r, receive_r, send_n, receive_n, remaining_words;

   logic [lg_max_els_p-1:0] max_els_data_r;

   // this is the max_els register, which gets updated
   // when the accelerator is configured

   bsg_dff_reset_en #(.width_p(lg_max_els_p)) max_els_reg
     (
      .clock_i(clk_i)
      ,.reset_i
      ,.en_i(max_els_v_i)
      ,.data_i(max_els_data_i)
      ,.data_o(max_els_data_r)
      );

   // this is the receive register, which gets
   // updated by the remote party

   bsg_dff_reset_en #(.width_p(width_p)) receive_reg
     (
      .clock_i (clk_i)
      ,.reset_i
      ,.en_i   (receive_v_i   )
      ,.data_i (receive_data_i)
      ,.data_o (receive_r     )
      );

   // this is the send register, which gets
   // updated by the local party

   bsg_dff_reset_en #(.width_p(width_p)) send_reg
     (
      .clock_i (clk_i)
      ,.reset_i
      ,.en_i   (send_yumi_o)
      ,.data_i (send_n)
      ,.data_o (send_r)
      );

   assign send_n           = (send_r + depth_i);
   assign remaining_words  = (send_n - max_els_data_r - receiver_r);

   // the remaining_words is not negative
   assign confirm_o        = ~remaining_words[width_p-1];

   // we update the send register when
   //
   //   - we receive a release_i signal (implying confirm_i is also set)
   //        -- AND --
   //   - we are able to transmit an update packet
   //

   assign send_v_o     = release_i & stores_committed_i;

   // updating the actual pointer
   assign send_data_o  = send_n;

   always @(negedge clk_i)
     assert (~release_i | confirm_o)
       else $error("## release_i without confirm high! (%m)");

endmodule
