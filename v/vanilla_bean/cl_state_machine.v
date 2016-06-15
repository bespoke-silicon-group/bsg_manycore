`include "parameters.v"
`include "definitions.v"

/**
 *  This module descibes the state machine that runs the core. It
 *  determines if the core is running, idle, or in an error state.
 */
module cl_state_machine
(
    input instruction_s instruction_i,
    input state_e       state_i,
    input               net_pc_write_cmd_idle_i,
    input               stall_i,
    output state_e      state_o
);

always_comb
begin
    unique case (state_i)
        // Initial state, core is idle and will only start if the
        // network writes to the PC
        IDLE:
            if (net_pc_write_cmd_idle_i)
                state_o = RUN;
            else
                state_o = IDLE;

        // RISC-V edit:
        // Run state, core is executing and will only go to idle
        // when reset is asserted
        RUN:
            state_o = RUN;

        // Error state, something has gone wrong and should stay in
        // the error state until a reset
        ERR:
            state_o = ERR;

        // Should never get here, so if it does, force the core into
        // an error state
        default:
            state_o = ERR;
    endcase
end

endmodule

