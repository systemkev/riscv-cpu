import common_pkg::*;

module memory (
    input   logic           i_clk,
    input   logic           i_rst,
    input   logic           i_stall,
    input   logic           i_flush,

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

    output  logic           o_dmem_valid,
    output  logic [31:0]    o_dmem_addr,
    output  logic [31:0]    o_dmem_wr_data,
    output  logic           o_dmem_wr_en,
    output  logic [3:0]     o_dmem_byt_en,
    input   logic [31:0]    i_dmem_rd_data,

    output  logic           o_wb_valid,
    output  logic [31:0]    o_wb_pc,
    output  logic [4:0]     o_wb_rd,
    output  logic [31:0]    o_wb_alu_res,
    output  logic [31:0]    o_wb_mem_data,
    output  logic           o_wb_wr_en,
    output  t_wb_src        o_wb_src,
    output  t_mem_types     o_wb_mem_type,
    output  logic           o_wb_illegal
);

    assign o_dmem_valid =
        i_valid &&
        !i_illegal &&
        (i_mem_read || i_mem_write) &&
        !i_flush &&
        !i_rst;

    assign o_dmem_addr = i_alu_result;

    assign o_dmem_wr_en =
        i_valid &&
        !i_illegal &&
        i_mem_write &&
        !i_flush &&
        !i_rst;

    always_comb begin
        o_dmem_wr_data = 32'b0;
        o_dmem_byt_en  = 4'b0000;

        if (
            i_valid &&
            !i_illegal &&
            i_mem_write &&
            !i_flush &&
            !i_rst
        ) begin
            case (i_mem_type)
                STORE_BYTE: begin
                    o_dmem_wr_data = {4{i_rs2_val[7:0]}};
                    o_dmem_byt_en  = 4'b0001 << i_alu_result[1:0];
                end

                STORE_HALF: begin
                    o_dmem_wr_data = {2{i_rs2_val[15:0]}};
                    o_dmem_byt_en  = i_alu_result[1] ? 4'b1100 : 4'b0011;
                end

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

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            o_wb_valid    <= 1'b0;
            o_wb_pc       <= 32'b0;
            o_wb_rd       <= 5'b0;
            o_wb_alu_res  <= 32'b0;
            o_wb_mem_data <= 32'b0;
            o_wb_wr_en    <= 1'b0;
            o_wb_src      <= WR_ALU_RES;
            o_wb_mem_type <= S_LOAD_BYTE;
            o_wb_illegal  <= 1'b0;
        end else if (i_flush) begin
            o_wb_valid    <= 1'b0;
            o_wb_pc       <= 32'b0;
            o_wb_rd       <= 5'b0;
            o_wb_alu_res  <= 32'b0;
            o_wb_mem_data <= 32'b0;
            o_wb_wr_en    <= 1'b0;
            o_wb_src      <= WR_ALU_RES;
            o_wb_mem_type <= S_LOAD_BYTE;
            o_wb_illegal  <= 1'b0;
        end else if (!i_stall) begin
            o_wb_valid    <= i_valid;
            o_wb_pc       <= i_pc;
            o_wb_rd       <= i_rd;
            o_wb_alu_res  <= i_alu_result;
            o_wb_mem_data <= i_mem_read ? i_dmem_rd_data : 32'b0;
            o_wb_wr_en    <= i_reg_write && !i_illegal && i_valid;
            o_wb_src      <= i_wb_src;
            o_wb_mem_type <= i_mem_type;
            o_wb_illegal  <= i_illegal;
        end
    end

endmodule