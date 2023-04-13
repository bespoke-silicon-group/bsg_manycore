`include "HardFloat_consts.vi"
`include "HardFloat_specialize.vi"

module
    test_fpu_fdiv_fsqrt
	import bsg_vanilla_pkg::*;
	#(parameter expWidth = 8, parameter sigWidth = 24, parameter bits_per_iter_p = 1, parameter reg_addr_width_p = RV32_reg_addr_width_gp);
	
    parameter maxNumErrors = 20;

    localparam formatWidth = expWidth + sigWidth;
    localparam maxNumCyclesToDelay = sigWidth + 10;
    integer errorCount, count, partialCount, moreIn, queueCount;

    reg reset, clock;
    initial begin
        clock = 1;
        forever #5 clock = !clock;
    end

    reg inValid;
    wire inReady;

    integer delay;
    always @(posedge clock) begin
        if (reset) begin
            delay <= 0;
        end else begin
            delay <=
                inValid && inReady ? {$random} % maxNumCyclesToDelay
                    : delay ? delay - 1 : 0;
        end
    end
	
	reg [reg_addr_width_p-1:0] inRd;
	reg inYumi;
    reg [(`floatControlWidth - 1):0] control;
	frm_e roundingMode;
	reg sqrtOp;
    reg [(formatWidth - 1):0] a, b, expectOut;
    reg [4:0] expectExceptionFlags;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    wire [formatWidth:0] recA, recB;
    fNToRecFN#(expWidth, sigWidth) fNToRecFN_a(a, recA);
    fNToRecFN#(expWidth, sigWidth) fNToRecFN_b(b, recB);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/	
	
    reg [formatWidth:0] queue_a[1:5], queue_b[1:5];
    reg [(formatWidth - 1):0] queue_expectOut[1:5];
    reg [4:0] queue_expectExceptionFlags[1:5];
	integer tc_file,out_file;

	initial begin
		tc_file = $fopen("test_input_32.txt", "r");
		out_file = $fopen("output_32.txt", "a");
		$fwrite(out_file, "\n");	
		$fwrite(out_file, "---------------------New Simulation---------------------\n");
		if(bits_per_iter_p == 2) begin
        $fwrite(out_file, "Testing 'divSqrt%0dBit_medium'\n", formatWidth);
		end else begin
		$fwrite(out_file, "Testing 'divSqrt%0dBit_small'\n", formatWidth);
		end

        errorCount = 0;
        count = 0;
        partialCount = 0;
        moreIn = 1;
        queueCount = 0;
		inRd = 0;
		
        inValid = 0;
        reset = 1;
        #21;
        reset = 0;
        while (
            $fscanf(
                tc_file,
                "%b %b %b %h %h %h %b",
				control,
				roundingMode,
				sqrtOp,
                a,
                b,
                expectOut,
                expectExceptionFlags
            ) == 7
        ) begin
            while (delay != 0) #10;
            inValid = 1;
            while (!inReady) #10;
            #10;
			inValid = 0;
            queueCount = queueCount + 1;
            queue_a[5] = queue_a[4];
            queue_a[4] = queue_a[3];
            queue_a[3] = queue_a[2];
            queue_a[2] = queue_a[1];
            queue_a[1] = a;
            queue_b[5] = queue_b[4];
            queue_b[4] = queue_b[3];
            queue_b[3] = queue_b[2];
            queue_b[2] = queue_b[1];
            queue_b[1] = b;
            queue_expectOut[5] = queue_expectOut[4];
            queue_expectOut[4] = queue_expectOut[3];
            queue_expectOut[3] = queue_expectOut[2];
            queue_expectOut[2] = queue_expectOut[1];
            queue_expectOut[1] = expectOut;
            queue_expectExceptionFlags[5] = queue_expectExceptionFlags[4];
            queue_expectExceptionFlags[4] = queue_expectExceptionFlags[3];
            queue_expectExceptionFlags[3] = queue_expectExceptionFlags[2];
            queue_expectExceptionFlags[2] = queue_expectExceptionFlags[1];
            queue_expectExceptionFlags[1] = expectExceptionFlags;
        end
        moreIn = 0;
    end

    wire outValid,sqrtOpOut;
    wire [formatWidth:0] recOut;
    wire [4:0] exceptionFlags;
	//wire outRd;

	fpu_fdiv_fsqrt#(.exp_width_p(expWidth), .sig_width_p(sigWidth), .bits_per_iter_p(bits_per_iter_p))
		DUT(
			.clk_i(clock),
			.reset_i(reset),
			.v_i(inValid),
			.rd_i(inRd),
			.rm_i(roundingMode),
			.fp_rs1_i(recA),
			.fp_rs2_i(recB),
			.fsqrt_i(sqrtOp),
			.ready_and_o(inReady),
			.v_o(outValid),
			.result_o(recOut),
			.sqrtOpOut(sqrtOpOut),
			.fflags_o(exceptionFlags),
			.rd_o(),
			.yumi_i(inYumi)
		);
		
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/	
	wire [formatWidth-1:0] out;
	recFNToFN#(expWidth, sigWidth) recToFN_out (recOut, out);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/	
	always @(negedge clock) begin
		inYumi <= outValid;
	end	
	
    wire sameOut = (out == queue_expectOut[queueCount])&&(exceptionFlags==queue_expectExceptionFlags[queueCount]);
    integer doExit;
    always @(posedge clock) begin

        doExit = 0;
        if (outValid) begin
            if (!queueCount) begin
                $display("--> Spurious 'outValid'.");
                $stop;
            end
            partialCount = partialCount + 1;
            if (partialCount == 10000) begin
                count = count + 10000;
                $fwrite(out_file, "%0d...\n", count);
                partialCount = 0;
            end
            if (!sameOut
            ) begin
                if (errorCount == 0) begin
                    $display(
  "Errors found in 'divSqrt%0d', control %H :\n",
                        formatWidth,
                        control
                    );
					$fwrite(
						out_file,
  "Errors found in 'divSqrt%0d', control %H :\n",
                        formatWidth,
                        control
                    );
                end
                $write(
                    "%H %H", queue_a[queueCount], queue_b[queueCount]);
			    $fwrite(
                    out_file, "%H %H sqrtOp-%b Mode-%d", queue_a[queueCount], queue_b[queueCount], sqrtOpOut,roundingMode);
                if (formatWidth > 64) begin
                    $write("\n\t");
					$fwrite(out_file,"\n\t");
                end else begin
                    $write("  ");
					$fwrite(out_file,"  ");
                end
                $write("=> %H %H", out, exceptionFlags);
				$fwrite(out_file,"=> %H %H", out, exceptionFlags);
                if (formatWidth > 32) begin
                    $write("\n\t");
					$fwrite(out_file,"\n\t");
                end else begin
                    $write("  ");
					$fwrite(out_file,"  ");
                end
                $display(
                    "expected %H %H",
                    queue_expectOut[queueCount],
                    queue_expectExceptionFlags[queueCount]
                );
				$fwrite(out_file,"expected %H %H\n",
                    queue_expectOut[queueCount],
                    queue_expectExceptionFlags[queueCount]);
                errorCount = errorCount + 1;
                doExit = (errorCount == maxNumErrors);
            end
            queueCount = queueCount - 1;
        end else begin
            doExit = !moreIn && !queueCount;
        end

        if (doExit) begin
            count = count + partialCount;
            if (errorCount) begin
                $fwrite(
                    out_file,
                    "--> In %0d tests, %0d errors found.\n",
                    count,
                    errorCount
                );
				$fwrite(out_file, "---------------------Finished With Errors---------------------\n");
				$fclose(out_file);
				$fclose(tc_file);
                $stop;
            end else if (count == 0) begin
				$fwrite(out_file, "--> Invalid test-cases input.");
				$fwrite(out_file, "---------------------Finished With Invalid Inputs---------------------\n");
				$fclose(out_file);
				$fclose(tc_file);
                $stop;
            end else begin
                $display(
"In %0d tests, no errors found in 'divSqrt%0d', control %H, rounding mode 0-6.\n",
                    count,
                    formatWidth,
                    control
                );
				$fwrite(
				    out_file,
"In %0d tests, no errors found in 'divSqrt%0d', control %H, rounding mode 0-6.\n",
                    count,
                    formatWidth,
                    control
                );
				$fwrite(out_file, "---------------------Finished Immaculately---------------------\n");
				$fclose(out_file);
				$fclose(tc_file);
            end
            $finish;
        end
    end

endmodule

