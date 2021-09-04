
`include "bsg_defines.v"

module hash_function_reverse
  #(parameter width_p="inv"
    ,parameter banks_p="inv"

    , parameter lg_banks_lp=`BSG_SAFE_CLOG2(banks_p)
    , parameter index_width_lp=$clog2((2**width_p+banks_p-1)/banks_p)
  )
  (
    input [index_width_lp-1:0] index_i
    , input [lg_banks_lp-1:0] bank_i

    , output logic [width_p-1:0] o
  );





  if (banks_p == 9) begin: b9
    
    always_comb begin
      if (bank_i == 'd8) begin
        o = {index_i, index_i[2:1], index_i[0] ^ index_i[9]}; 
      end
      else begin
        o = {index_i, bank_i[2:0]};
      end
    end


  end
  else begin: p2

    // assume power of 2
    assign o = {index_i, bank_i};

  end






endmodule
