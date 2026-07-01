// ============================================================================
// File Name   : memory.sv
// Author      : Kevin Toledo Fernandez / GitHub: ktf-repos
// Date        : 2026-06-16
// Project     : RISC-V 32-bit Processor
// Description : Memory (MEM) stage of the pipelined RISC-V RV32I processor. 
//               Interfaces with the Data Memory block to execute Load and Store 
//               instructions. Handles memory read formatting (sign-extension for 
//               bytes/halfwords) and forwards final ALU results, memory data, 
//               and control signals to the Writeback (WB) stage.
//
// License     : MIT
// ============================================================================

import common_pkg::*;

module memory (
    // Global signals
    input   logic           i_clk,
    input   logic           i_rst,

    // Pipeline control
    input   logic           i_stall,        // when 1 -> freeze, ignore new input
    input   logic           i_flush,        // when 1 -> inject NOP bubble on next cycle

    // From Execute Stage
    input   logic           i_valid,
    input   logic [31:0]    i_pc,
    input   logic [4:0]     i_rd,
    input   logic [31:0]    i_alu_result,   // memory address for load/store, ALU result for writeback
    input   logic [31:0]    i_rs2_val,      // store data forwarded to MEM
    input   logic           i_mem_read,
    input   logic           i_mem_write,
    input   t_mem_types     i_mem_type, 
    input   logic           i_reg_write,
    input   t_wb_src        i_wb_src,
    input   logic           i_illegal,

    // To BRAM
    output  logic [31:0]    o_dmem_addr,
    output  logic [31:0]    o_dmem_wr_data,
    output  logic           o_dmem_wr_en,
    output  logic [3:0]     o_dmem_byt_en,

    // To Writeback Stage (delayed to match 1 cycle BRAM read)
    output  logic           o_wb_valid, 
    output  logic [31:0]    o_wb_pc,
    output  logic [4:0]     o_wb_rd,
    output  logic [31:0]    o_wb_alu_res,
    output  logic           o_wb_wr_en,
    output  t_wb_src        o_wb_src,
    output  t_mem_types     o_wb_mem_type,
    output  logic           o_wb_illegal
);

// Drive BRAM combinationally 
assign o_dmem_addr      = i_alu_result;
assign o_dmem_wr_data   = i_rs2_val;
assign o_dmem_wr_en     = i_valid & ~i_illegal & i_mem_write;

always_comb begin 
    o_dmem_byt_en       = 4'b0000;
    if (i_valid && ~i_illegal && i_mem_write) begin 
        case (i_mem_type)
            STORE_BYTE:     o_dmem_byt_en = 4'b0001 << i_alu_result[1:0];
            STORE_HALF:     o_dmem_byt_en = 4'b0011 << (i_alu_result[1]*2);
            STORE_WORD:     o_dmem_byt_en = 4'b1111;
            default:        o_dmem_byt_en = 4'b0000;
        endcase 
    end
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        o_wb_valid      <= 1'b0;
        o_wb_illegal    <= 1'b0;
        o_wb_pc         <= 'x;
        o_wb_rd         <= 'x;
        o_wb_alu_res    <= 'x;
        o_wb_wr_en      <= 1'b0;
        o_wb_src        <= t_wb_src'('x);
        o_wb_mem_type   <= t_mem_types'('x);
    end else if (~i_stall) begin
        if (i_flush) begin
            o_wb_valid      <= 1'b0;
            o_wb_illegal    <= 1'b0;
            o_wb_wr_en      <= 1'b0;
        end else begin
            o_wb_valid      <= i_valid;
            o_wb_illegal    <= i_illegal;
            o_wb_pc         <= i_pc;
            o_wb_rd         <= i_rd;
            o_wb_alu_res    <= i_alu_result;
            o_wb_wr_en      <= i_reg_write & ~i_illegal & i_valid;
            o_wb_src        <= i_wb_src;
            o_wb_mem_type   <= i_mem_type; // Passed down to format the read data (Sign extend LB, LH, etc.)
        end
    end
end

endmodule 