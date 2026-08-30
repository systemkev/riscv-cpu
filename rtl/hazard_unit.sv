// ============================================================================
// File Name   : hazard_unit.sv
// Author      : Kevin Toledo Fernandez / GitHub: systemkev
// Date        : 2026-07-04
// Project     : RISC-V 32-bit Processor
// Description : 
//
// License     : MIT
// ============================================================================

import common_pkg::*;

module hazard_unit (
    // Inputs from decode stage
    input   logic [4:0]     i_id_rs1,
    input   logic [4:0]     i_id_rs2,

    // Inputs from execute stage
    input   logic [4:0]     i_ex_rs1,
    input   logic [4:0]     i_ex_rs2,
    input   logic [4:0]     i_ex_rd,
    input   logic           i_ex_mem_read,
    input   logic           i_ex_redirect, 

    // Inputs from memory stage
    input   logic [4:0]     i_mem_rd,
    input   logic           i_mem_reg_wr,

    // Inputs from writeback stage
    input   logic [4:0]     i_wb_rd,
    input   logic           i_wb_reg_wr, 

    // Outputs to execute stage
    output  t_forwarding    o_forward_op_a,
    output  t_forwarding    o_forward_op_b,

    // Stall and flush signals
    output  logic           o_fetch_stall,
    output  logic           o_decode_stall,
    output  logic           o_decode_flush,
    output  logic           o_execute_flush
);

    logic load_use_hazard;

    //////////////////////
    // Forwarding Logic //
    //////////////////////
    always_comb begin
        o_forward_op_a = NO_HAZ;
        o_forward_op_b = NO_HAZ;

        // Forward rs1 logic
        if (i_mem_reg_wr == 1'b1 && i_mem_rd != 5'b0 && i_mem_rd == i_ex_rs1)
            o_forward_op_a = MEM_FWD;
        else if (i_wb_reg_wr == 1'b1 && i_wb_rd != 5'b0 && i_wb_rd == i_ex_rs1)
            o_forward_op_a = WB_FWD;

        // Forward rs2 logic
        if (i_mem_reg_wr == 1'b1 && i_mem_rd != 5'b0 && i_mem_rd == i_ex_rs2) 
            o_forward_op_b = MEM_FWD; 
        else if (i_wb_reg_wr == 1'b1 && i_wb_rd != 5'b0 && i_wb_rd == i_ex_rs2) 
            o_forward_op_b = WB_FWD;
    end

    ///////////////////////////
    // Load Use Hazard Logic //
    ///////////////////////////
    always_comb begin 
        load_use_hazard = 1'b0;

        if (i_ex_mem_read == 1'b1 && i_ex_rd != 5'b0 && 
            (i_ex_rd == i_id_rs1 || i_ex_rd == i_id_rs2)) begin
            load_use_hazard = 1'b1;
        end
    end 

    //////////////////////
    // Pipeline Control //
    //////////////////////
    always_comb begin
        o_fetch_stall       = 1'b0;
        o_decode_stall      = 1'b0;
        o_decode_flush      = 1'b0;
        o_execute_flush     = 1'b0;

        if (i_ex_redirect == 1'b1) begin
            // Branch or Jump resolved.
            // Kill the instruction currently in the Decode stage. 
            // (Fetch handles its own kill via vld_delay).
            o_decode_flush  = 1'b1;
        end else if (load_use_hazard) begin
            o_fetch_stall   = 1'b1;
            o_decode_stall  = 1'b1;
            o_execute_flush = 1'b1;
        end 
    end 
endmodule