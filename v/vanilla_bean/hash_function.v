/**
 *  hash_function.v
 *
 */

module hash_function 
  #(parameter banks_p="inv"
    , parameter width_p="inv"
    , parameter vcache_sets_p="inv"

    , parameter lg_banks_lp=`BSG_SAFE_CLOG2(banks_p)
    , parameter index_width_lp=$clog2((2**width_p+banks_p-1)/banks_p)
    , parameter lg_vcache_sets_lp=`BSG_SAFE_CLOG2(vcache_sets_p)
  )
  (
    input [width_p-1:0] i
    , output logic [lg_banks_lp-1:0] bank_o
    , output logic [index_width_lp-1:0] index_o
  );


  if (banks_p == 9) begin: b9

    always_comb begin
      // we want to pick i[lg_vcache_sets_lp+3] to XOR with i[3],
      // since this is the first non-index bit used by vcache.
      if (i[2:0] == {i[5:4], i[3] ^ i[lg_vcache_sets_lp+3]}) begin
        bank_o = 'd8;
      end
      else begin
        bank_o = {1'b0, i[2:0]};
      end

      index_o = i[width_p-1:3];
    end

  end
  else if (`BSG_IS_POW2(banks_p)) begin: p2

    assign bank_o  = i[0+:lg_banks_lp];
    assign index_o = i[lg_banks_lp+:index_width_lp];
  end
  else begin: unhandled
    initial assert("banks_p" == "unhandled") else $error("unhandled case for %m");
  end



endmodule
