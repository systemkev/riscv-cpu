// ============================================================================
// File Name   : fetch.sv
// Author      : Kevin Toledo Fernandez / GitHub: systemkev
// Date        : 2026-06-16
// Project     : RISC-V 32-bit Processor
// Description : Instruction Fetch (IF) stage of the pipelined RISC-V RV32I 
//               processor. Maintains the Program Counter (PC) and interfaces 
//               with Instruction Memory to retrieve 32-bit instructions. 
//               Computes sequential execution (PC + 4) while handling asynchronous 
//               PC redirection from the Execute stage for branches and jumps. 
//               Contains sequential pipeline registers to forward the PC and 
//               fetched instruction to the Decode stage, supporting pipeline 
//               stalls and flushes.
//
// License     : MIT
// ============================================================================

import common_pkg::*;

module fetch (
    input  logic            i_clk,          // Global system clock from FPGA 
    input  logic            i_rst,          // Power-on reset or physical button reset
    input  logic            i_stall,        // 1 -> pipeline must stall, 0 -> normal operation 
    input  logic            i_redirect,     // 1 -> EXE stage determined we redirected, 0 -> normal operation 
    input  logic [31:0]     i_target,       // Jump destination address
    input  logic [31:0]     i_imem_data,    // Instruction fetched from iMem

    output logic [31:0]     o_imem_addr,    // iMem address to fetch from         
    output logic            o_valid,        // 1 -> instruction ready to be decoded, 0 -> normal operation
    output logic [31:0]     o_pc,           // Current instruction address 
    output logic [31:0]     o_instr         // Instruction to pass onto DEC stage 
);

logic [31:0]    pc_cur;     // Current PC
logic [31:0]    pc_dly;     // Delayed PC (aligns with 1 cycle BRAM delay)
logic           valid;       

// Skid buffer to hold instruction during a stall
logic [31:0]    hold_instr;   
logic           is_held;

always_ff @(posedge i_clk) begin
    if (i_rst == 1'b1) begin
        pc_cur          <= RESET_VECTOR;
        pc_dly          <= RESET_VECTOR;
        valid           <= 1'b0;
        hold_instr      <= RESET_VECTOR;
        is_held         <= 1'b0;
    end else if (i_redirect == 1'b1) begin 
        pc_cur          <= i_target;
        valid           <= 1'b0;
        is_held         <= 1'b0; 
    end else if (i_stall == 1'b1) begin 
        if (is_held == 1'b0) begin
            hold_instr  <= i_imem_data;
            is_held     <= 1'b1;
        end
    end else begin
        pc_cur          <= pc_cur + 32'd4;
        pc_dly          <= pc_cur;
        valid           <= 1'b1;
        is_held         <= 1'b0;
    end
end

assign o_imem_addr  = pc_cur;
assign o_pc         = pc_dly;
assign o_valid      = valid && !i_redirect;
assign o_instr      = (is_held == 1'b1)? hold_instr : i_imem_data;

endmodule