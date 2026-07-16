// ============================================================================
// File Name   : writeback.sv
// Author      : Kevin Toledo Fernandez / GitHub: systemkev
// Date        : 2026-06-30
// Project     : RISC-V 32-bit Processor
// Description : 
//
// License     : MIT
// ============================================================================

import common_pkg::*;

module writeback (
    // From Writeback Stage 
    input   logic           i_wb_valid, 
    input   logic [31:0]    i_wb_pc,
    input   logic [4:0]     i_wb_rd,
    input   logic [31:0]    i_wb_alu_res,
    input   logic           i_wb_wr_en,
    input   t_wb_src        i_wb_src,
    input   t_mem_types     i_wb_mem_type,
    input   logic           i_wb_illegal,

    // Data from BRAM 
    input   logic [31:0]    i_dmem_data,

    // Outputs to Register File
    output  logic           o_rf_wr_en,
    output  logic [4:0]     o_rf_rd_addr,
    output  logic [31:0]    o_rf_wr_data
);

logic [31:0] formatted_mem_data;
logic [15:0] extracted_half;
logic [7:0]  extracted_byte;

always_comb begin
    formatted_mem_data  = 32'b0;
    extracted_byte      = 8'b0;
    extracted_half      = 16'b0;

    case (i_wb_alu_res[1:0])
        2'b00:  extracted_byte = i_dmem_data[7:0];
        2'b01:  extracted_byte = i_dmem_data[15:8];
        2'b10:  extracted_byte = i_dmem_data[23:16];
        2'b11:  extracted_byte = i_dmem_data[31:24];
    endcase 

    case (i_wb_alu_res[1])
        1'b0:   extracted_half = i_dmem_data[15:0];
        1'b1:   extracted_half = i_dmem_data[31:16];
    endcase 

    case (i_wb_mem_type)
        S_LOAD_BYTE:    formatted_mem_data = {{24{extracted_byte[7]}}, extracted_byte};
        U_LOAD_BYTE:    formatted_mem_data = {24'b0, extracted_byte};
        S_LOAD_HALF:    formatted_mem_data = {{16{extracted_half[15]}}, extracted_half};
        U_LOAD_HALF:    formatted_mem_data = {16'b0, extracted_half};
        S_LOAD_WORD:    formatted_mem_data = i_dmem_data;
        default:        formatted_mem_data = i_dmem_data;
    endcase 
end

// Pass control signals directly to the register file
assign o_rf_wr_en       = i_wb_wr_en;
assign o_rf_rd_addr     = i_wb_rd;

// Multiplex the final data to write to the rf 
always_comb begin 
    case (i_wb_src) 
        WR_ALU_RES:         o_rf_wr_data = i_wb_alu_res;
        WR_READ_RES:        o_rf_wr_data = formatted_mem_data;
        WR_PC_PLUS_4:       o_rf_wr_data = i_wb_pc + 32'd4;
        default:            o_rf_wr_data = 32'b0;
    endcase
end

endmodule 