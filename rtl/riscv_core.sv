// ============================================================================
// File Name   : riscv_core.sv
// Description : Top-level RV32I CPU core. Connects IF/ID/EX/MEM/WB,
//               register file, forwarding, and hazard control.
// ============================================================================

import common_pkg::*;

module riscv_core (
    input  logic        i_clk,
    input  logic        i_rst,

    // Instruction memory interface
    output logic [31:0] o_imem_addr,
    input  logic [31:0] i_imem_data,

    // Data memory interface
    output logic [31:0] o_dmem_addr,
    output logic [31:0] o_dmem_wr_data,
    output logic        o_dmem_wr_en,
    output logic [3:0]  o_dmem_byt_en,
    input  logic [31:0] i_dmem_data
);

    // ========================================================================
    // IF -> ID
    // ========================================================================

    logic        if_valid;
    logic [31:0] if_pc;
    logic [31:0] if_instr;

    // ========================================================================
    // ID -> EX
    // ========================================================================

    logic        id_valid;
    logic [31:0] id_pc;

    logic [4:0]  id_rs1;
    logic [4:0]  id_rs2;
    logic [4:0]  id_rd;

    logic [31:0] id_imm;

    t_alu_ops    id_alu_op;

    logic        id_alu_inp_1;
    logic        id_alu_inp_2;

    logic        id_mem_read;
    logic        id_mem_write;
    t_mem_types  id_mem_type;

    logic        id_reg_write;
    t_wb_src     id_wb_src;

    logic        id_is_branch;
    t_branches   id_branch_type;

    logic        id_is_jump;
    logic        id_jalr;
    logic        id_illegal;

    logic [31:0] id_pc_plus_4;

    // ========================================================================
    // Register file read values
    // ========================================================================

    logic [31:0] rs1_val;
    logic [31:0] rs2_val;

    // ========================================================================
    // EX -> MEM
    // ========================================================================

    logic        ex_valid;
    logic [31:0] ex_pc;

    logic [4:0]  ex_rd;

    logic [31:0] ex_alu_result;
    logic [31:0] ex_rs2_val;

    logic        ex_mem_read;
    logic        ex_mem_write;
    t_mem_types  ex_mem_type;

    logic        ex_reg_write;
    t_wb_src     ex_wb_src;

    logic        ex_illegal;

    logic        ex_redirect;
    logic [31:0] ex_target;

    // ========================================================================
    // MEM -> WB
    // ========================================================================

    logic        wb_valid;
    logic [31:0] wb_pc;

    logic [4:0]  wb_rd;

    logic [31:0] wb_alu_res;

    logic        wb_wr_en;
    t_wb_src     wb_src;
    t_mem_types  wb_mem_type;

    logic        wb_illegal;

    // ========================================================================
    // WB -> Register file
    // ========================================================================

    logic        rf_wr_en;
    logic [4:0]  rf_wr_addr;
    logic [31:0] rf_wr_data;

    // ========================================================================
    // Hazard unit
    // ========================================================================

    t_forwarding forward_a;
    t_forwarding forward_b;

    logic fetch_stall;
    logic decode_stall;

    logic decode_flush;
    logic execute_flush;

    // ========================================================================
    // Decode-stage register addresses used by load-use detector
    //
    // We cannot blindly use instruction[19:15] and [24:20], because those
    // fields aren't source registers for every instruction.
    // ========================================================================

    logic [4:0] hazard_id_rs1;
    logic [4:0] hazard_id_rs2;

    always_comb begin

        hazard_id_rs1 = 5'd0;
        hazard_id_rs2 = 5'd0;

        if (if_valid) begin

            case (if_instr[6:0])

                // rs1 + rs2
                OP_ALU,
                OP_BRANCH,
                OP_STORE: begin
                    hazard_id_rs1 = if_instr[19:15];
                    hazard_id_rs2 = if_instr[24:20];
                end

                // rs1 only
                OP_IMM,
                OP_LOAD,
                OP_JALR: begin
                    hazard_id_rs1 = if_instr[19:15];
                    hazard_id_rs2 = 5'd0;
                end

                // LUI, AUIPC, JAL do not consume registers
                default: begin
                    hazard_id_rs1 = 5'd0;
                    hazard_id_rs2 = 5'd0;
                end

            endcase
        end
    end

    // ========================================================================
    // MEM forwarding value
    //
    // ALU instructions forward their ALU result.
    // JAL/JALR forward PC+4.
    //
    // Loads cannot forward from MEM because the synchronous BRAM data does
    // not arrive until WB. Load-use interlock handles this case.
    // ========================================================================

    logic [31:0] mem_forward_data;
    logic        mem_can_forward;

    always_comb begin

        mem_forward_data = ex_alu_result;
        mem_can_forward  = ex_reg_write;

        case (ex_wb_src)

            WR_ALU_RES: begin
                mem_forward_data = ex_alu_result;
            end

            WR_PC_PLUS_4: begin
                mem_forward_data = ex_pc + 32'd4;
            end

            WR_READ_RES: begin
                // Load data is not available from this stage yet.
                mem_forward_data = 32'd0;
                mem_can_forward  = 1'b0;
            end

            default: begin
                mem_forward_data = ex_alu_result;
                mem_can_forward  = 1'b0;
            end

        endcase

    end

    // ========================================================================
    // Fetch
    // ========================================================================

    fetch u_fetch (
        .i_clk          (i_clk),
        .i_rst          (i_rst),

        .i_stall        (fetch_stall),

        .i_redirect     (ex_redirect),
        .i_target       (ex_target),

        .i_imem_data    (i_imem_data),

        .o_imem_addr    (o_imem_addr),

        .o_valid        (if_valid),
        .o_pc           (if_pc),
        .o_instr        (if_instr)
    );

    // ========================================================================
    // Decode
    //
    // Both redirect flushes and load-use bubbles kill the ID/EX contents.
    //
    // Your hazard signal named "execute_flush" really means:
    //     inject a bubble INTO the Execute stage,
    // which means flushing the decoder's ID/EX pipeline registers.
    // ========================================================================

    decoder u_decoder (
        .i_clk          (i_clk),
        .i_rst          (i_rst),

        .i_valid        (if_valid),
        .i_pc           (if_pc),
        .i_instr        (if_instr),

        .i_stall        (decode_stall),
        .i_flush        (decode_flush | execute_flush),

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

    // ========================================================================
    // Register File
    // ========================================================================

    reg_file u_reg_file (
        .i_clk          (i_clk),

        .i_rd_val       (rf_wr_data),
        .i_rd_addr      (rf_wr_addr),

        .i_rs1_addr     (id_rs1),
        .i_rs2_addr     (id_rs2),

        .i_write_enable (rf_wr_en),

        .i_rst          (i_rst),

        .o_rs1_val      (rs1_val),
        .o_rs2_val      (rs2_val)
    );

    // ========================================================================
    // Execute
    // ========================================================================

    execute u_execute (
        .i_clk              (i_clk),
        .i_rst              (i_rst),

        // With fixed-latency BRAM, MEM never backpressures EX.
        .i_stall            (1'b0),

        // Load-use bubbling occurs in ID/EX, not EX/MEM.
        .i_flush            (1'b0),

        .i_valid            (id_valid),

        .i_pc               (id_pc),

        .i_rs1              (id_rs1),
        .i_rs2              (id_rs2),
        .i_rd               (id_rd),

        .i_imm              (id_imm),

        .i_alu_op           (id_alu_op),
        .i_alu_inp_1        (id_alu_inp_1),
        .i_alu_inp_2        (id_alu_inp_2),

        .i_mem_read         (id_mem_read),
        .i_mem_write        (id_mem_write),
        .i_mem_type         (id_mem_type),

        .i_reg_write        (id_reg_write),
        .i_wb_src           (id_wb_src),

        .i_is_branch        (id_is_branch),
        .i_branch_type      (id_branch_type),

        .i_is_jump          (id_is_jump),
        .i_jalr             (id_jalr),

        .i_illegal          (id_illegal),

        .i_rs1_val          (rs1_val),
        .i_rs2_val          (rs2_val),

        .i_forward_op_a     (forward_a),
        .i_forward_op_b     (forward_b),

        .i_mem_fwd_data     (mem_forward_data),
        .i_wb_fwd_data      (rf_wr_data),

        .o_valid            (ex_valid),
        .o_pc               (ex_pc),

        .o_rd               (ex_rd),

        .o_alu_result       (ex_alu_result),
        .o_rs2_val          (ex_rs2_val),

        .o_mem_read         (ex_mem_read),
        .o_mem_write        (ex_mem_write),
        .o_mem_type         (ex_mem_type),

        .o_reg_write        (ex_reg_write),
        .o_wb_src           (ex_wb_src),

        .o_illegal          (ex_illegal),

        .o_redirect         (ex_redirect),
        .o_target           (ex_target)
    );

    // ========================================================================
    // Memory
    // ========================================================================

    memory u_memory (
        .i_clk              (i_clk),
        .i_rst              (i_rst),

        .i_stall            (1'b0),
        .i_flush            (1'b0),

        .i_valid            (ex_valid),

        .i_pc               (ex_pc),
        .i_rd               (ex_rd),

        .i_alu_result       (ex_alu_result),
        .i_rs2_val          (ex_rs2_val),

        .i_mem_read         (ex_mem_read),
        .i_mem_write        (ex_mem_write),
        .i_mem_type         (ex_mem_type),

        .i_reg_write        (ex_reg_write),
        .i_wb_src           (ex_wb_src),

        .i_illegal          (ex_illegal),

        .o_dmem_addr        (o_dmem_addr),
        .o_dmem_wr_data     (o_dmem_wr_data),
        .o_dmem_wr_en       (o_dmem_wr_en),
        .o_dmem_byt_en      (o_dmem_byt_en),

        .o_wb_valid         (wb_valid),
        .o_wb_pc            (wb_pc),
        .o_wb_rd            (wb_rd),
        .o_wb_alu_res       (wb_alu_res),
        .o_wb_wr_en         (wb_wr_en),
        .o_wb_src           (wb_src),
        .o_wb_mem_type      (wb_mem_type),
        .o_wb_illegal       (wb_illegal)
    );

    // ========================================================================
    // Writeback
    // ========================================================================

    writeback u_writeback (
        .i_wb_valid         (wb_valid),

        .i_wb_pc            (wb_pc),
        .i_wb_rd            (wb_rd),

        .i_wb_alu_res       (wb_alu_res),

        .i_wb_wr_en         (wb_wr_en),
        .i_wb_src           (wb_src),
        .i_wb_mem_type      (wb_mem_type),
        .i_wb_illegal       (wb_illegal),

        .i_dmem_data        (i_dmem_data),

        .o_rf_wr_en         (rf_wr_en),
        .o_rf_rd_addr       (rf_wr_addr),
        .o_rf_wr_data       (rf_wr_data)
    );

    // ========================================================================
    // Hazard / forwarding unit
    // ========================================================================

    hazard_unit u_hazard (
        // Current instruction waiting in ID
        .i_id_rs1           (hazard_id_rs1),
        .i_id_rs2           (hazard_id_rs2),

        // Current instruction in EX
        .i_ex_rs1           (id_rs1),
        .i_ex_rs2           (id_rs2),
        .i_ex_rd            (id_rd),

        .i_ex_mem_read      (id_mem_read),

        .i_ex_redirect      (ex_redirect),

        // Current instruction in MEM
        .i_mem_rd           (ex_rd),
        .i_mem_reg_wr       (mem_can_forward),

        // Current instruction in WB
        .i_wb_rd            (wb_rd),
        .i_wb_reg_wr        (wb_wr_en),

        .o_forward_op_a     (forward_a),
        .o_forward_op_b     (forward_b),

        .o_fetch_stall      (fetch_stall),
        .o_decode_stall     (decode_stall),

        .o_decode_flush     (decode_flush),
        .o_execute_flush    (execute_flush)
    );

endmodule