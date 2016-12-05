//====================================================================
// bsg_manycore_profiler.v
// 11/25/2016, shawnless.xie@gmail.com
//====================================================================
//
//This calculates the stalls and other performance matrics of vanillia
//core


typedef struct packed {

    //the trigger signals
    logic   dmem_stall          ;
    logic   dx_stall            ;
    logic   bt_stall            ;
    logic   in_fifo_full        ;
    logic   out_fifo_full       ;
    logic   credit_full         ;
    logic   res_acq_stall       ;

    //the state control signals
    logic   reset_prof          ;
    logic   finish_prof         ;
} manycore_profiler_s;


module bsg_manycore_profiler(
    input   clk_i
   ,input   integer             x_id_i
   ,input   integer             y_id_i
   ,input   manycore_profiler_s prof_s_i
);

typedef enum {DMEM_STALL,     DX_STALL,       BT_STALL,
              IN_FIFO_FULL,   OUT_FIFO_FULL, CREDIT_FULL,    RES_ACQ_STALL,
              PROF_IND_END
            } prof_matrix_enum;

//the matrix
integer prof_matrix[0:PROF_IND_END] ;
integer non_frozen_cycles           ;

//update the statistics
always_ff@(negedge clk_i)  begin
    if ( prof_s_i.reset_prof)  begin
        prof_matrix[ DMEM_STALL   ] <= 32'b0;
        prof_matrix[ DX_STALL     ] <= 32'b0;
        prof_matrix[ BT_STALL     ] <= 32'b0;
        prof_matrix[ IN_FIFO_FULL ] <= 32'b0;
        prof_matrix[ OUT_FIFO_FULL] <= 32'b0;
        prof_matrix[ CREDIT_FULL  ] <= 32'b0;
        prof_matrix[ RES_ACQ_STALL] <= 32'b0;
        non_frozen_cycles           <= 32'b0;
    end else begin
        if ( prof_s_i.dmem_stall   )  prof_matrix[ DMEM_STALL   ] <= prof_matrix[ DMEM_STALL   ]+ 1;
        if ( prof_s_i.dx_stall     )  prof_matrix[ DX_STALL     ] <= prof_matrix[ DX_STALL     ]+ 1;
        if ( prof_s_i.bt_stall     )  prof_matrix[ BT_STALL     ] <= prof_matrix[ BT_STALL     ]+ 2;
        if ( prof_s_i.in_fifo_full )  prof_matrix[ IN_FIFO_FULL ] <= prof_matrix[ IN_FIFO_FULL ]+ 1;
        if ( prof_s_i.out_fifo_full)  prof_matrix[ OUT_FIFO_FULL] <= prof_matrix[ OUT_FIFO_FULL]+ 1;
        if ( prof_s_i.credit_full  )  prof_matrix[ CREDIT_FULL  ] <= prof_matrix[ CREDIT_FULL  ]+ 1;
        if ( prof_s_i.res_acq_stall)  prof_matrix[ RES_ACQ_STALL] <= prof_matrix[ RES_ACQ_STALL]+ 1;
        non_frozen_cycles <= non_frozen_cycles + 1;
    end
end

//print the statistics
always_ff@(negedge clk_i ) begin
    if( prof_s_i.finish_prof ) begin
        if( x_id_i ==0  &&  y_id_i == 0 ) print_prof_helper;
        print_prof_counts;
        print_prof_percent;
    end
end

///////////////////////////////////////////////////////////////////////
task print_prof_helper;
$display("\n");
$display("## PERFORMANCE DATA ###################################################");
$display("##\n");
$display("## 1. DMEM_stalls includes                          "                   );
$display("##    a. Writing to full network                    "                   );
$display("##    b. fence instructon                           "                   );
$display("##    c. load reserved acquire                      "                   );
$display("## 2. DX_stalls are data dependency stalls"                             );
$display("## 3. BT stalls are branch taken penalties"                             );
$display("## 4. input_fifo_full are cycles when processor input buffer is full"   );
$display("##      these are a result of remote_store/dmem bank conflicts and"     );
$display("##      indicate likely sources of network congestion"                  );
$display("## 5. output_fifo_full are cycles when processor output buffer is full" );
$display("## 6. res_acq_stalls are stalls waiting on lr.w.acquire instructions"   );
$display("##    these are used for high-level flow-control"                       );
$display("##   keep in mind that polling causes instruction count to vary\n"      );
$display("##    X  Y      CYCLES  |      DMEM         DX         BT |   IN_FIFO     OUT_FIFO    Credit    RES_ACQ");
$display("##   -- --  ----------  |---------- ---------- ---------- |  --------   ----------  ---------  --------");
endtask

task print_prof_counts;
$display("##   %2.2d,%2.2d %d  |%d%d%d|%d%d%d%d",
                x_id_i, y_id_i,  non_frozen_cycles,
               prof_matrix[ DMEM_STALL   ],
               prof_matrix[ DX_STALL     ],
               prof_matrix[ BT_STALL     ],
               prof_matrix[ IN_FIFO_FULL ],
               prof_matrix[ OUT_FIFO_FULL],
               prof_matrix[ CREDIT_FULL  ],
               prof_matrix[ RES_ACQ_STALL],
         );
endtask

task print_prof_percent;
$display("##                      | %9.1f%% %9.1f%% %9.1f%%| %9.1f%% %9.1f%% %9.1f%% %9.1f%%"
       ,100 * ( real'( prof_matrix[ DMEM_STALL   ] ) / real'( non_frozen_cycles ) )
       ,100 * ( real'( prof_matrix[ DX_STALL     ] ) / real'( non_frozen_cycles ) )
       ,100 * ( real'( prof_matrix[ BT_STALL     ] ) / real'( non_frozen_cycles ) )
       ,100 * ( real'( prof_matrix[ IN_FIFO_FULL ] ) / real'( non_frozen_cycles ) )
       ,100 * ( real'( prof_matrix[ OUT_FIFO_FULL] ) / real'( non_frozen_cycles ) )
       ,100 * ( real'( prof_matrix[ CREDIT_FULL  ] ) / real'( non_frozen_cycles ) )
       ,100 * ( real'( prof_matrix[ RES_ACQ_STALL] ) / real'( non_frozen_cycles ) )
);
endtask

task print_prof_result;
    print_prof_counts;
    print_prof_percent;
endtask

endmodule
