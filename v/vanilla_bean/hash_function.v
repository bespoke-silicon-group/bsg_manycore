module hash_function 
  #(parameter banks_p="inv"
    , parameter width_p="inv"

    , parameter lg_banks_lp=`BSG_SAFE_CLOG2(banks_p)
    , parameter index_width_lp=$clog2((2**width_p+banks_p-1)/banks_p)
  )
  (
    input [width_p-1:0] i
    , output logic [lg_banks_lp-1:0] bank_o
    , output logic [index_width_lp-1:0] index_o
  );


  if (banks_p == 9) begin: b9

    always_comb begin
      if (i[2:0] == {i[5:4], i[3] ^ i[9]}) begin
        bank_o = 'd8;
      end
      else begin
        bank_o = {1'b0, i[2:0]};
      end

      index_o = i[width_p-1:3];
    end

  end
  else begin: p2

    // assume power of 2
    assign bank_o = i[0+:lg_banks_lp];
    assign index_o = i[index_width_lp-1:lg_banks_lp];

  end



endmodule
