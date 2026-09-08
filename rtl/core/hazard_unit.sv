import common_pkg::*;

module hazard_unit (
    input   logic [4:0]     i_id_rs1,
    input   logic [4:0]     i_id_rs2,
    input   logic [4:0]     i_ex_rs1,
    input   logic [4:0]     i_ex_rs2,
    input   logic [4:0]     i_ex_rd,
    input   logic           i_ex_mem_read,
    input   logic           i_ex_reg_write,
    input   logic           i_ex_mispredict,
    input   logic [4:0]     i_mem_rd,
    input   logic           i_mem_reg_wr,
    input   logic [4:0]     i_wb_rd,
    input   logic           i_wb_reg_wr,
    input   logic           i_cache_stall,
    output  t_forwarding    o_forward_op_a,
    output  t_forwarding    o_forward_op_b,
    output  logic           o_fetch_stall,
    output  logic           o_decode_stall,
    output  logic           o_execute_stall,
    output  logic           o_memory_stall,
    output  logic           o_decode_flush,
    output  logic           o_execute_flush
);

    logic raw_hazard;

    always_comb begin
        o_forward_op_a = NO_HAZ;
        o_forward_op_b = NO_HAZ;
    end

    assign raw_hazard =
        i_ex_reg_write &&
        i_ex_rd != 5'd0 &&
        (i_ex_rd == i_id_rs1 || i_ex_rd == i_id_rs2);

    assign o_fetch_stall =
        i_cache_stall ||
        (raw_hazard && !i_ex_mispredict);

    assign o_decode_stall =
        i_cache_stall ||
        (raw_hazard && !i_ex_mispredict);

    assign o_execute_stall = i_cache_stall;
    assign o_memory_stall  = i_cache_stall;

    assign o_decode_flush =
        !i_cache_stall &&
        i_ex_mispredict;

    assign o_execute_flush =
        !i_cache_stall &&
        !i_ex_mispredict &&
        raw_hazard;

endmodule
