// ============================================================================
// File Name   : memory.sv
// Author      : Kevin Toledo Fernandez / GitHub: systemkev
// Date        : 2026-06-16
// Project     : RISC-V 32-bit Processor
// Description : Memory (MEM) stage of the pipelined RISC-V RV32I processor.
// ============================================================================

import common_pkg::*;

module memory (
    // Global signals
    input   logic           i_clk,
    input   logic           i_rst,

    // Pipeline control
    input   logic           i_stall,
    input   logic           i_flush,

    // From Execute Stage
    input   logic           i_valid,
    input   logic [31:0]    i_pc,
    input   logic [4:0]     i_rd,
    input   logic [31:0]    i_alu_result,
    input   logic [31:0]    i_rs2_val,
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

    // To Writeback Stage
    output  logic           o_wb_valid,
    output  logic [31:0]    o_wb_pc,
    output  logic [4:0]     o_wb_rd,
    output  logic [31:0]    o_wb_alu_res,
    output  logic           o_wb_wr_en,
    output  t_wb_src        o_wb_src,
    output  t_mem_types     o_wb_mem_type,
    output  logic           o_wb_illegal
);


    // ========================================================================
    // Data-memory interface
    // ========================================================================

    // Address is always the effective address calculated by EX.
    assign o_dmem_addr = i_alu_result;


    // A store may modify memory only when the instruction is active and valid.
    assign o_dmem_wr_en =
        i_valid      &&
        ~i_illegal   &&
        i_mem_write  &&
        ~i_stall     &&
        ~i_flush     &&
        ~i_rst;


    // ========================================================================
    // Store data alignment / byte enables
    // ========================================================================

    always_comb begin

        o_dmem_wr_data = 32'b0;
        o_dmem_byt_en  = 4'b0000;

        if (
            i_valid      &&
            ~i_illegal   &&
            i_mem_write  &&
            ~i_stall     &&
            ~i_flush     &&
            ~i_rst
        ) begin

            case (i_mem_type)

                // ------------------------------------------------------------
                // SB
                //
                // The low byte of rs2 must be written regardless of address
                // offset. Replication places that byte on every BRAM lane;
                // byte-enable selects the actual destination lane.
                // ------------------------------------------------------------

                STORE_BYTE: begin

                    o_dmem_wr_data =
                        {4{i_rs2_val[7:0]}};

                    o_dmem_byt_en =
                        4'b0001 << i_alu_result[1:0];

                end


                // ------------------------------------------------------------
                // SH
                //
                // For aligned halfword accesses:
                //
                // address[1] = 0 -> lanes 0/1
                // address[1] = 1 -> lanes 2/3
                //
                // Replication ensures rs2[15:0] exists on either half.
                // ------------------------------------------------------------

                STORE_HALF: begin

                    o_dmem_wr_data =
                        {2{i_rs2_val[15:0]}};

                    if (i_alu_result[1] == 1'b0)
                        o_dmem_byt_en = 4'b0011;
                    else
                        o_dmem_byt_en = 4'b1100;

                end


                // ------------------------------------------------------------
                // SW
                // ------------------------------------------------------------

                STORE_WORD: begin

                    o_dmem_wr_data = i_rs2_val;
                    o_dmem_byt_en  = 4'b1111;

                end


                default: begin

                    o_dmem_wr_data = 32'b0;
                    o_dmem_byt_en  = 4'b0000;

                end

            endcase

        end

    end


    // ========================================================================
    // MEM -> WB pipeline register
    //
    // Priority: reset > flush > stall > normal
    // ========================================================================

    always_ff @(posedge i_clk) begin

        if (i_rst) begin

            o_wb_valid      <= 1'b0;
            o_wb_pc         <= 32'b0;
            o_wb_rd         <= 5'b0;
            o_wb_alu_res    <= 32'b0;

            o_wb_wr_en      <= 1'b0;
            o_wb_src        <= WR_ALU_RES;
            o_wb_mem_type   <= S_LOAD_BYTE;
            o_wb_illegal    <= 1'b0;

        end

        else if (i_flush) begin

            // Inject a deterministic bubble.
            o_wb_valid      <= 1'b0;
            o_wb_pc         <= 32'b0;
            o_wb_rd         <= 5'b0;
            o_wb_alu_res    <= 32'b0;

            o_wb_wr_en      <= 1'b0;
            o_wb_src        <= WR_ALU_RES;
            o_wb_mem_type   <= S_LOAD_BYTE;
            o_wb_illegal    <= 1'b0;

        end

        else if (!i_stall) begin

            o_wb_valid      <= i_valid;
            o_wb_pc         <= i_pc;
            o_wb_rd         <= i_rd;
            o_wb_alu_res    <= i_alu_result;

            o_wb_wr_en      <=
                i_reg_write &&
                ~i_illegal  &&
                i_valid;

            o_wb_src        <= i_wb_src;
            o_wb_mem_type   <= i_mem_type;
            o_wb_illegal    <= i_illegal;

        end

        // else:
        // stall -> retain all MEM/WB pipeline registers

    end


endmodule