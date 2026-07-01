// ============================================================================
// File Name   : fetch.sv
// Author      : Kevin Toledo Fernandez / GitHub: ktf-repos
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
    input  logic            i_clk,
    input  logic            i_rst,
    input  logic            i_stall,
    input  logic            i_redirect,        
    input  logic [31:0]     i_redirect_target, 

    output logic [31:0]     o_imem_addr,       
    input  logic [31:0]     i_imem_data,       

    output logic            o_valid,           
    output logic [31:0]     o_pc,              
    output logic [31:0]     o_instr            
);

logic [31:0]    pc_current      = 32'b0;
logic [31:0]    pc_delayed      = 32'b0;
logic           vld_delay       = 1'b0;     

always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        pc_current          <= 32'b0;
        pc_delayed          <= 32'b0;
        vld_delay           <= 1'b0;
    end else if (~i_stall) begin 
        if (i_redirect) begin
            pc_current      <= i_redirect_target;
            vld_delay       <= 1'b0;
        end else begin
            pc_delayed      <= pc_current;
            pc_current      <= pc_current + 32'd4; 
            vld_delay       <= 1'b1;
        end
    end
end

assign o_imem_addr  = pc_current;
assign o_instr      = i_imem_data;
assign o_pc         = pc_delayed;
assign o_valid      = vld_delay;

endmodule