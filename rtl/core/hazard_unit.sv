import common_pkg::*;

module hazard_unit (
    input   logic [4:0]     i_id_rs1,
    input   logic [4:0]     i_id_rs2,
    input   logic [4:0]     i_ex_rs1,
    input   logic [4:0]     i_ex_rs2,
    input   logic [4:0]     i_ex_rd,
    input   logic           i_ex_mem_read,
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

    logic load_use_hazard;

    always_comb begin
        o_forward_op_a = NO_HAZ;
        o_forward_op_b = NO_HAZ;

        if (i_mem_reg_wr && i_mem_rd != 5'd0 && i_mem_rd == i_ex_rs1)
            o_forward_op_a = MEM_FWD;
        else if (i_wb_reg_wr && i_wb_rd != 5'd0 && i_wb_rd == i_ex_rs1)
            o_forward_op_a = WB_FWD;

        if (i_mem_reg_wr && i_mem_rd != 5'd0 && i_mem_rd == i_ex_rs2)
            o_forward_op_b = MEM_FWD;
        else if (i_wb_reg_wr && i_wb_rd != 5'd0 && i_wb_rd == i_ex_rs2)
            o_forward_op_b = WB_FWD;
    end

    assign load_use_hazard =
        i_ex_mem_read &&
        i_ex_rd != 5'd0 &&
        (i_ex_rd == i_id_rs1 || i_ex_rd == i_id_rs2);

    assign o_fetch_stall =
        i_cache_stall ||
        (load_use_hazard && !i_ex_mispredict);

    assign o_decode_stall =
        i_cache_stall ||
        (load_use_hazard && !i_ex_mispredict);

    assign o_execute_stall = i_cache_stall;
    assign o_memory_stall  = i_cache_stall;

    assign o_decode_flush =
        !i_cache_stall &&
        i_ex_mispredict;

    assign o_execute_flush =
        !i_cache_stall &&
        !i_ex_mispredict &&
        load_use_hazard;

endmodule