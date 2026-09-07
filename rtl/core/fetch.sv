import common_pkg::*;

module fetch (
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic        i_stall,
    input  logic        i_redirect,
    input  logic [31:0] i_target,
    input  logic        i_pred_taken,
    input  logic [31:0] i_pred_target,
    input  logic [31:0] i_imem_data,

    output logic [31:0] o_imem_addr,
    output logic        o_valid,
    output logic [31:0] o_pc,
    output logic [31:0] o_instr,
    output logic        o_pred_taken,
    output logic [31:0] o_pred_target
);

    logic [31:0] pc_cur;
    logic [31:0] pc_dly;
    logic        valid;
    logic [31:0] hold_instr;
    logic        is_held;
    logic        pred_taken_dly;
    logic [31:0] pred_target_dly;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            pc_cur          <= RESET_VECTOR;
            pc_dly          <= RESET_VECTOR;
            valid           <= 1'b0;
            hold_instr      <= 32'b0;
            is_held         <= 1'b0;
            pred_taken_dly  <= 1'b0;
            pred_target_dly <= 32'b0;
        end else if (i_redirect) begin
            pc_cur          <= i_target;
            valid           <= 1'b0;
            is_held         <= 1'b0;
            pred_taken_dly  <= 1'b0;
            pred_target_dly <= 32'b0;
        end else if (i_stall) begin
            if (!is_held) begin
                hold_instr <= i_imem_data;
                is_held    <= 1'b1;
            end
        end else begin
            pc_cur          <= i_pred_taken ? i_pred_target : pc_cur + 32'd4;
            pc_dly          <= pc_cur;
            valid           <= 1'b1;
            is_held         <= 1'b0;
            pred_taken_dly  <= i_pred_taken;
            pred_target_dly <= i_pred_target;
        end
    end

    assign o_imem_addr   = pc_cur;
    assign o_pc          = pc_dly;
    assign o_valid       = valid && !i_redirect;
    assign o_instr       = is_held ? hold_instr : i_imem_data;
    assign o_pred_taken  = pred_taken_dly;
    assign o_pred_target = pred_target_dly;

endmodule