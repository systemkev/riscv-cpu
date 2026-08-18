// ============================================================================
// File Name   : top.sv
// Author      : Kevin Toledo Fernandez / GitHub: systemkev
// Date        : 2026-07-04
// Project     : RISC-V 32-bit Processor
// Description : 
//
// License     : MIT
// ============================================================================

import common_pkg::*;

module riscv_core (
    input  logic        i_clk,
    input  logic        i_rst,

    // Instruction Memory Interface
    output logic [31:0] o_imem_addr,
    input  logic [31:0] i_imem_data,

    // Data Memory Interface
    output logic [31:0] o_dmem_addr,
    output logic [31:0] o_dmem_wr_data,
    output logic        o_dmem_wr_en,
    output logic [3:0]  o_dmem_byt_en,
    input  logic [31:0] i_dmem_data
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================

    // Fetch -> Decode (IF/ID Pipeline Signals)
    logic           if_valid;
    logic [31:0]    if_pc;
    logic [31:0]    if_instr;

    // Decode -> Execute (ID/EX Pipeline Signals)
    logic           id_valid;
    logic [31:0]    id_pc;
    logic [4:0]     id_rs1;
    logic [4:0]     id_rs2;
    logic [4:0]     id_rd;
    logic [31:0]    id_imm;
    t_alu_ops       id_alu_op;
    logic           id_alu_inp_1;
    logic           id_alu_inp_2;
    logic           id_mem_read;
    logic           id_mem_write;
    t_mem_types     id_mem_type;
    logic           id_reg_write;
    t_wb_src        id_wb_src;
    logic           id_is_branch;
    t_branches      id_branch_type;
    logic           id_is_jump;
    logic           id_jalr;
    logic           id_illegal;
    logic [31:0]    id_pc_plus_4;

    // Register File Read Outputs
    logic [31:0]    rf_rs1_val;
    logic [31:0]    rf_rs2_val;

    // Execute -> Memory (EX/MEM Pipeline Signals)
    logic           ex_valid;
    logic [31:0]    ex_pc;
    logic [4:0]     ex_rd;
    logic [31:0]    ex_alu_result;
    logic [31:0]    ex_rs2_val;
    logic           ex_mem_read;
    logic           ex_mem_write;
    t_mem_types     ex_mem_type;
    logic           ex_reg_write;
    t_wb_src        ex_wb_src;
    logic           ex_illegal;

    // Execute Combinational PC Redirect (EX -> IF)
    logic           ex_redirect;
    logic [31:0]    ex_redirect_target;

    // Memory -> Writeback (MEM/WB Pipeline Signals)
    logic           wb_valid;
    logic [31:0]    wb_pc;
    logic [4:0]     wb_rd;
    logic [31:0]    wb_alu_res;
    logic           wb_wr_en;
    t_wb_src        wb_src;
    t_mem_types     wb_mem_type;
    logic           wb_illegal;

    // Writeback -> Register File Combinational Writes
    logic           rf_wr_en;
    logic [4:0]     rf_wr_addr;
    logic [31:0]    rf_wr_data;

    // Hazard Unit Output Signals
    t_forwarding    hu_fwd_a;
    t_forwarding    hu_fwd_b;
    logic           hu_fetch_stall;
    logic           hu_decode_stall;
    logic           hu_decode_flush;
    logic           hu_execute_flush;

    // =========================================================================
    // Module Instantiations
    // =========================================================================

    // Fetch Stage
    fetch fetch_inst (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_stall        (hu_fetch_stall),
        .i_redirect     (ex_redirect),
        .i_target       (ex_redirect_target),
        .i_imem_data    (i_imem_data),

        .o_imem_addr    (o_imem_addr),
        .o_valid        (if_valid),
        .o_pc           (if_pc),
        .o_instr        (if_instr)
    );

    // Decode Stage
    decoder decode_inst (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_valid        (if_valid),
        .i_pc           (if_pc),
        .i_instr        (if_instr),
        .i_stall        (hu_decode_stall),
        .i_flush        (hu_decode_flush),

        .o_valid        (id_valid),
        .o_pc           (id_pc),
        .o_rs1          (id_rs1),
        .o_rs2          (id_rs2),
        .o_rd           (id_rd),
        .o_imm          (id_imm),
        .o_alu_op       (id_alu_op),
        .o_alu_inp_1    (id_alu_inp_1),
        .o_alu_inp_2    (id_alu_inp_2),
        .o_mem_read     (id_mem_read),
        .o_mem_write    (id_mem_write),
        .o_mem_type     (id_mem_type),
        .o_reg_write    (id_reg_write),
        .o_wr_from      (id_wb_src),
        .o_is_branch    (id_is_branch),
        .o_branch_type  (id_branch_type),
        .o_is_jump      (id_is_jump),
        .o_jalr         (id_jalr),
        .o_illegal      (id_illegal),
        .o_pc_plus_4    (id_pc_plus_4)
    );

    // Register File
    reg_file rf_inst (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_rs1_addr     (id_rs1),
        .i_rs2_addr     (id_rs2),
        .i_rd_addr      (rf_wr_addr),
        .i_rd_val       (rf_wr_data),
        .i_write_enable (rf_wr_en),

        .o_rs1_val      (rf_rs1_val),
        .o_rs2_val      (rf_rs2_val)
    );

    // Execute Stage
    execute execute_inst (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_stall        (1'b0),             // No stalls injected into EXE
        .i_flush        (hu_execute_flush),
        
        .i_valid        (id_valid),
        .i_pc           (id_pc),
        .i_rs1          (id_rs1),
        .i_rs2          (id_rs2),
        .i_rd           (id_rd),
        .i_imm          (id_imm),
        .i_alu_op       (id_alu_op),
        .i_alu_inp_1    (id_alu_inp_1),
        .i_alu_inp_2    (id_alu_inp_2),
        .i_mem_read     (id_mem_read),
        .i_mem_write    (id_mem_write),
        .i_mem_type     (id_mem_type),
        .i_reg_write    (id_reg_write),
        .i_wb_src       (id_wb_src),
        .i_is_branch    (id_is_branch),
        .i_branch_type  (id_branch_type),
        .i_is_jump      (id_is_jump),
        .i_jalr         (id_jalr),
        .i_illegal      (id_illegal),
        .i_pc_plus_4    (id_pc_plus_4),

        .i_rs1_val      (rf_rs1_val),
        .i_rs2_val      (rf_rs2_val),

        .i_forward_op_a (hu_fwd_a),
        .i_forward_op_b (hu_fwd_b),
        .i_mem_fwd_data (ex_alu_result),    // ALU data currently at the start of MEM
        .i_wb_fwd_data  (rf_wr_data),       // Writeback data currently writing to RF
        
        .o_valid        (ex_valid),
        .o_pc           (ex_pc),
        .o_rd           (ex_rd),
        .o_alu_result   (ex_alu_result),
        .o_rs2_val      (ex_rs2_val),
        .o_mem_read     (ex_mem_read),
        .o_mem_write    (ex_mem_write),
        .o_mem_type     (ex_mem_type),
        .o_reg_write    (ex_reg_write),
        .o_wb_src       (ex_wb_src),
        .o_illegal      (ex_illegal),

        .o_redirect     (ex_redirect),
        .o_target       (ex_redirect_target)
    );

    // Memory Stage
    memory memory_inst (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_stall        (1'b0),             // No stalls injected into MEM
        .i_flush        (1'b0),             // No flushes injected into MEM
        
        .i_valid        (ex_valid),
        .i_pc           (ex_pc),
        .i_rd           (ex_rd),
        .i_alu_result   (ex_alu_result),
        .i_rs2_val      (ex_rs2_val),
        .i_mem_read     (ex_mem_read),
        .i_mem_write    (ex_mem_write),
        .i_mem_type     (ex_mem_type),
        .i_reg_write    (ex_reg_write),
        .i_wb_src       (ex_wb_src),
        .i_illegal      (ex_illegal),

        .o_dmem_addr    (o_dmem_addr),
        .o_dmem_wr_data (o_dmem_wr_data),
        .o_dmem_wr_en   (o_dmem_wr_en),
        .o_dmem_byt_en  (o_dmem_byt_en),

        .o_wb_valid     (wb_valid),
        .o_wb_pc        (wb_pc),
        .o_wb_rd        (wb_rd),
        .o_wb_alu_res   (wb_alu_res),
        .o_wb_wr_en     (wb_wr_en),
        .o_wb_src       (wb_src),
        .o_wb_mem_type  (wb_mem_type),
        .o_wb_illegal   (wb_illegal)
    );

    // Writeback Stage
    writeback writeback_inst (
        .i_wb_valid     (wb_valid),
        .i_wb_pc        (wb_pc),
        .i_wb_rd        (wb_rd),
        .i_wb_alu_res   (wb_alu_res),
        .i_wb_wr_en     (wb_wr_en),
        .i_wb_src       (wb_src),
        .i_wb_mem_type  (wb_mem_type),
        .i_wb_illegal   (wb_illegal),

        .i_dmem_data    (i_dmem_data),

        .o_rf_wr_en     (rf_wr_en),
        .o_rf_rd_addr   (rf_wr_addr),
        .o_rf_wr_data   (rf_wr_data)
    );

    // Hazard Unit
    hazard_unit hazard_unit_inst (
        // The instruction currently in the ID stage (combinational rs1/rs2 extracted from Fetch output)
        .i_id_rs1       (if_instr[19:15]),
        .i_id_rs2       (if_instr[24:20]),

        // The instruction currently in the EX stage (passed from the ID pipeline register)
        .i_ex_rs1       (id_rs1),
        .i_ex_rs2       (id_rs2),
        .i_ex_rd        (id_rd),
        .i_ex_mem_read  (id_mem_read),
        .i_ex_redirect  (ex_redirect),

        // The instruction currently in the MEM stage (passed from the EX pipeline register)
        .i_mem_rd       (ex_rd),
        .i_mem_reg_wr   (ex_reg_write),

        // The instruction currently in the WB stage
        .i_wb_rd        (wb_rd),
        .i_wb_reg_wr    (wb_wr_en),

        .o_forward_op_a     (hu_fwd_a),
        .o_forward_op_b     (hu_fwd_b),
        
        .o_fetch_stall      (hu_fetch_stall),
        .o_decode_stall     (hu_decode_stall),
        .o_decode_flush     (hu_decode_flush),
        .o_execute_flush    (hu_execute_flush)
    );

endmodule