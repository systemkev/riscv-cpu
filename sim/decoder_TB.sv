`timescale 1ns / 1ps

import common_pkg::*;

module decoder_TB;

    localparam time CLK_PERIOD = 10ns;

    // ------------------------------------------------------------------------
    // DUT inputs
    // ------------------------------------------------------------------------
    logic        i_clk;
    logic        i_rst;

    logic        i_valid;
    logic [31:0] i_pc;
    logic [31:0] i_instr;
    logic        i_pred_taken;
    logic [31:0] i_pred_target;

    logic        i_stall;
    logic        i_flush;

    // ------------------------------------------------------------------------
    // DUT outputs
    // ------------------------------------------------------------------------
    logic [31:0] o_pc;
    logic        o_valid;

    logic [4:0]  o_rs1;
    logic [4:0]  o_rs2;
    logic [4:0]  o_rd;

    logic [31:0] o_imm;

    t_alu_ops    o_alu_op;
    logic        o_alu_inp_1;
    logic        o_alu_inp_2;

    logic        o_mem_read;
    logic        o_mem_write;
    t_mem_types  o_mem_type;

    logic        o_reg_write;
    t_wb_src     o_wr_from;

    logic        o_is_branch;
    t_branches   o_branch_type;

    logic        o_is_jump;
    logic        o_jalr;
    logic        o_illegal;

    logic [31:0] o_pc_plus_4;
    logic        o_pred_taken;
    logic [31:0] o_pred_target;


    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------
    decoder dut (
        .i_clk          (i_clk),
        .i_rst          (i_rst),

        .i_valid        (i_valid),
        .i_pc           (i_pc),
        .i_instr        (i_instr),
        .i_pred_taken   (i_pred_taken),
        .i_pred_target  (i_pred_target),

        .i_stall        (i_stall),
        .i_flush        (i_flush),

        .o_valid        (o_valid),
        .o_pc           (o_pc),
        .o_rs1          (o_rs1),
        .o_rs2          (o_rs2),
        .o_rd           (o_rd),
        .o_imm          (o_imm),
        .o_alu_op       (o_alu_op),
        .o_alu_inp_1    (o_alu_inp_1),
        .o_alu_inp_2    (o_alu_inp_2),
        .o_mem_read     (o_mem_read),
        .o_mem_write    (o_mem_write),
        .o_mem_type     (o_mem_type),
        .o_reg_write    (o_reg_write),
        .o_wr_from      (o_wr_from),
        .o_is_branch    (o_is_branch),
        .o_branch_type  (o_branch_type),
        .o_is_jump      (o_is_jump),
        .o_jalr         (o_jalr),
        .o_illegal      (o_illegal),
        .o_pc_plus_4    (o_pc_plus_4),
        .o_pred_taken   (o_pred_taken),
        .o_pred_target  (o_pred_target)
    );


    // ========================================================================
    // Clock
    // ========================================================================
    initial begin
        i_clk = 1'b0;
        forever #(CLK_PERIOD / 2) i_clk = ~i_clk;
    end


    // ========================================================================
    // Test accounting
    // ========================================================================
    int tests_run;
    int tests_failed;


    // ========================================================================
    // Expected-result structure
    // ========================================================================
    typedef struct {
        logic        valid;
        logic [31:0] pc;

        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [4:0]  rd;

        logic [31:0] imm;

        t_alu_ops    alu_op;
        logic        alu_inp_1;
        logic        alu_inp_2;

        logic        mem_read;
        logic        mem_write;

        logic        check_mem_type;
        t_mem_types  mem_type;

        logic        reg_write;

        logic        check_wr_from;
        t_wb_src     wr_from;

        logic        is_branch;

        logic        check_branch_type;
        t_branches   branch_type;

        logic        is_jump;
        logic        jalr;
        logic        illegal;
        logic        pred_taken;
        logic [31:0] pred_target;
    } expected_t;


    // ========================================================================
    // Instruction constructors
    // ========================================================================

    // R-type
    function automatic logic [31:0] make_r(
        input logic [6:0] opcode,
        input logic [4:0] rd,
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic [6:0] funct7
    );
        return {
            funct7,
            rs2,
            rs1,
            funct3,
            rd,
            opcode
        };
    endfunction


    // I-type
    function automatic logic [31:0] make_i(
        input logic [6:0]  opcode,
        input logic [4:0]  rd,
        input logic [2:0]  funct3,
        input logic [4:0]  rs1,
        input logic [11:0] imm
    );
        return {
            imm,
            rs1,
            funct3,
            rd,
            opcode
        };
    endfunction


    // S-type
    function automatic logic [31:0] make_s(
        input logic [6:0]  opcode,
        input logic [2:0]  funct3,
        input logic [4:0]  rs1,
        input logic [4:0]  rs2,
        input logic [11:0] imm
    );
        return {
            imm[11:5],
            rs2,
            rs1,
            funct3,
            imm[4:0],
            opcode
        };
    endfunction


    // B-type
    function automatic logic [31:0] make_b(
        input logic [6:0]  opcode,
        input logic [2:0]  funct3,
        input logic [4:0]  rs1,
        input logic [4:0]  rs2,
        input logic [12:0] imm
    );
        return {
            imm[12],
            imm[10:5],
            rs2,
            rs1,
            funct3,
            imm[4:1],
            imm[11],
            opcode
        };
    endfunction


    // U-type
    function automatic logic [31:0] make_u(
        input logic [6:0]  opcode,
        input logic [4:0]  rd,
        input logic [31:0] imm
    );
        return {
            imm[31:12],
            rd,
            opcode
        };
    endfunction


    // J-type
    function automatic logic [31:0] make_j(
        input logic [6:0]  opcode,
        input logic [4:0]  rd,
        input logic [20:0] imm
    );
        return {
            imm[20],
            imm[10:1],
            imm[11],
            imm[19:12],
            rd,
            opcode
        };
    endfunction


    // ========================================================================
    // Default expected result
    // ========================================================================
    function automatic expected_t expected_default(
        input logic [31:0] instr,
        input logic [31:0] pc
    );
        expected_t e;

        e.valid = 1'b1;
        e.pc    = pc;

        e.rs1   = instr[19:15];
        e.rs2   = instr[24:20];
        e.rd    = instr[11:7];

        e.imm   = 32'd0;

        e.alu_op    = ARITH_ADD;
        e.alu_inp_1 = 1'b0;
        e.alu_inp_2 = 1'b1;

        e.mem_read  = 1'b0;
        e.mem_write = 1'b0;

        e.check_mem_type = 1'b0;
        e.mem_type       = S_LOAD_BYTE;

        e.reg_write = 1'b0;

        e.check_wr_from = 1'b0;
        e.wr_from      = WR_ALU_RES;

        e.is_branch = 1'b0;

        e.check_branch_type = 1'b0;
        e.branch_type       = BEQ;

        e.is_jump = 1'b0;
        e.jalr    = 1'b0;
        e.illegal = 1'b0;
        e.pred_taken  = 1'b0;
        e.pred_target = 32'd0;

        return e;
    endfunction


    // ========================================================================
    // Compare DUT output against expected result
    // ========================================================================
    task automatic check_result(
        input string     test_name,
        input expected_t e
    );
        bit failed;

        failed = 1'b0;
        tests_run++;

        if (o_valid !== e.valid) begin
            $error("%s: o_valid expected=%b got=%b",
                   test_name, e.valid, o_valid);
            failed = 1'b1;
        end

        if (o_pc !== e.pc) begin
            $error("%s: o_pc expected=%h got=%h",
                   test_name, e.pc, o_pc);
            failed = 1'b1;
        end

        if (o_rs1 !== e.rs1) begin
            $error("%s: o_rs1 expected=%0d got=%0d",
                   test_name, e.rs1, o_rs1);
            failed = 1'b1;
        end

        if (o_rs2 !== e.rs2) begin
            $error("%s: o_rs2 expected=%0d got=%0d",
                   test_name, e.rs2, o_rs2);
            failed = 1'b1;
        end

        if (o_rd !== e.rd) begin
            $error("%s: o_rd expected=%0d got=%0d",
                   test_name, e.rd, o_rd);
            failed = 1'b1;
        end

        if (o_imm !== e.imm) begin
            $error("%s: o_imm expected=%h got=%h",
                   test_name, e.imm, o_imm);
            failed = 1'b1;
        end

        if (o_alu_op !== e.alu_op) begin
            $error("%s: o_alu_op expected=%0d got=%0d",
                   test_name, e.alu_op, o_alu_op);
            failed = 1'b1;
        end

        if (o_alu_inp_1 !== e.alu_inp_1) begin
            $error("%s: o_alu_inp_1 expected=%b got=%b",
                   test_name, e.alu_inp_1, o_alu_inp_1);
            failed = 1'b1;
        end

        if (o_alu_inp_2 !== e.alu_inp_2) begin
            $error("%s: o_alu_inp_2 expected=%b got=%b",
                   test_name, e.alu_inp_2, o_alu_inp_2);
            failed = 1'b1;
        end

        if (o_mem_read !== e.mem_read) begin
            $error("%s: o_mem_read expected=%b got=%b",
                   test_name, e.mem_read, o_mem_read);
            failed = 1'b1;
        end

        if (o_mem_write !== e.mem_write) begin
            $error("%s: o_mem_write expected=%b got=%b",
                   test_name, e.mem_write, o_mem_write);
            failed = 1'b1;
        end

        if (e.check_mem_type && (o_mem_type !== e.mem_type)) begin
            $error("%s: o_mem_type expected=%0d got=%0d",
                   test_name, e.mem_type, o_mem_type);
            failed = 1'b1;
        end

        if (o_reg_write !== e.reg_write) begin
            $error("%s: o_reg_write expected=%b got=%b",
                   test_name, e.reg_write, o_reg_write);
            failed = 1'b1;
        end

        if (e.check_wr_from && (o_wr_from !== e.wr_from)) begin
            $error("%s: o_wr_from expected=%0d got=%0d",
                   test_name, e.wr_from, o_wr_from);
            failed = 1'b1;
        end

        if (o_is_branch !== e.is_branch) begin
            $error("%s: o_is_branch expected=%b got=%b",
                   test_name, e.is_branch, o_is_branch);
            failed = 1'b1;
        end

        if (e.check_branch_type &&
            (o_branch_type !== e.branch_type)) begin

            $error("%s: o_branch_type expected=%0d got=%0d",
                   test_name, e.branch_type, o_branch_type);
            failed = 1'b1;
        end

        if (o_is_jump !== e.is_jump) begin
            $error("%s: o_is_jump expected=%b got=%b",
                   test_name, e.is_jump, o_is_jump);
            failed = 1'b1;
        end

        if (o_jalr !== e.jalr) begin
            $error("%s: o_jalr expected=%b got=%b",
                   test_name, e.jalr, o_jalr);
            failed = 1'b1;
        end

        if (o_illegal !== e.illegal) begin
            $error("%s: o_illegal expected=%b got=%b",
                   test_name, e.illegal, o_illegal);
            failed = 1'b1;
        end

        if (o_pc_plus_4 !== (e.pc + 32'd4)) begin
            $error("%s: o_pc_plus_4 expected=%h got=%h",
                   test_name, e.pc + 32'd4, o_pc_plus_4);
            failed = 1'b1;
        end

        if (o_pred_taken !== e.pred_taken) begin
            $error("%s: o_pred_taken expected=%b got=%b",
                   test_name, e.pred_taken, o_pred_taken);
            failed = 1'b1;
        end

        if (o_pred_target !== e.pred_target) begin
            $error("%s: o_pred_target expected=%h got=%h",
                   test_name, e.pred_target, o_pred_target);
            failed = 1'b1;
        end

        if (failed) begin
            tests_failed++;
            $display("[FAIL] %s", test_name);
        end
        else begin
            $display("[PASS] %s", test_name);
        end

    endtask


    // ========================================================================
    // Drive an instruction for one decoder cycle
    // ========================================================================
    task automatic run_test(
        input string       test_name,
        input logic [31:0] instr,
        input logic [31:0] pc,
        input expected_t   expected
    );

        @(negedge i_clk);

        i_valid = 1'b1;
        i_instr       = instr;
        i_pc          = pc;
        i_pred_taken  = expected.pred_taken;
        i_pred_target = expected.pred_target;

        i_stall = 1'b0;
        i_flush = 1'b0;

        @(posedge i_clk);
        #1;

        check_result(test_name, expected);

    endtask


    // ========================================================================
    // R-type helper
    // ========================================================================
    task automatic test_r_type(
        input string      name,
        input logic [2:0] funct3,
        input logic [6:0] funct7,
        input t_alu_ops   alu_op
    );

        logic [31:0] instr;
        expected_t e;

        instr = make_r(
            OP_ALU,
            5'd7,
            funct3,
            5'd3,
            5'd12,
            funct7
        );

        e = expected_default(instr, 32'h0000_1000);

        e.alu_op        = alu_op;
        e.alu_inp_2     = 1'b0;
        e.reg_write     = 1'b1;
        e.check_wr_from = 1'b1;
        e.wr_from       = WR_ALU_RES;

        run_test(name, instr, 32'h0000_1000, e);

    endtask


    // ========================================================================
    // I-type ALU helper
    // ========================================================================
    task automatic test_i_alu(
        input string       name,
        input logic [2:0]  funct3,
        input logic [11:0] encoded_imm,
        input logic [31:0] expected_imm,
        input t_alu_ops    alu_op
    );

        logic [31:0] instr;
        expected_t e;

        instr = make_i(
            OP_IMM,
            5'd9,
            funct3,
            5'd4,
            encoded_imm
        );

        e = expected_default(instr, 32'h0000_2000);

        e.rs2           = 5'd0;
        e.imm           = expected_imm;
        e.alu_op        = alu_op;
        e.reg_write     = 1'b1;
        e.check_wr_from = 1'b1;
        e.wr_from       = WR_ALU_RES;

        run_test(name, instr, 32'h0000_2000, e);

    endtask


    // ========================================================================
    // Branch helper
    // ========================================================================
    task automatic test_branch(
        input string       name,
        input logic [2:0]  funct3,
        input t_branches   branch_type
    );

        logic [31:0] instr;
        logic [12:0] imm;
        expected_t e;

        // -16
        imm = 13'h1FF0;

        instr = make_b(
            OP_BRANCH,
            funct3,
            5'd5,
            5'd11,
            imm
        );

        e = expected_default(instr, 32'h0000_3000);

        e.imm               = 32'hFFFF_FFF0;
        e.alu_inp_1         = 1'b1;
        e.is_branch         = 1'b1;
        e.check_branch_type = 1'b1;
        e.branch_type       = branch_type;

        run_test(name, instr, 32'h0000_3000, e);

    endtask


    // ========================================================================
    // Load helper
    // ========================================================================
    task automatic test_load(
        input string       name,
        input logic [2:0]  funct3,
        input t_mem_types  mem_type
    );

        logic [31:0] instr;
        expected_t e;

        // offset = -32
        instr = make_i(
            OP_LOAD,
            5'd14,
            funct3,
            5'd6,
            12'hFE0
        );

        e = expected_default(instr, 32'h0000_4000);

        e.rs2            = 5'd0;
        e.imm            = 32'hFFFF_FFE0;

        e.mem_read       = 1'b1;
        e.check_mem_type = 1'b1;
        e.mem_type       = mem_type;

        e.reg_write      = 1'b1;
        e.check_wr_from  = 1'b1;
        e.wr_from        = WR_READ_RES;

        run_test(name, instr, 32'h0000_4000, e);

    endtask


    // ========================================================================
    // Store helper
    // ========================================================================
    task automatic test_store(
        input string       name,
        input logic [2:0]  funct3,
        input t_mem_types  mem_type
    );

        logic [31:0] instr;
        expected_t e;

        // offset = -20
        instr = make_s(
            OP_STORE,
            funct3,
            5'd8,
            5'd15,
            12'hFEC
        );

        e = expected_default(instr, 32'h0000_5000);

        e.imm            = 32'hFFFF_FFEC;
        e.mem_write      = 1'b1;
        e.check_mem_type = 1'b1;
        e.mem_type       = mem_type;

        run_test(name, instr, 32'h0000_5000, e);

    endtask


    // ========================================================================
    // Illegal instruction checker
    //
    // An illegal instruction can remain "valid" as a pipeline entry, but it
    // should not accidentally cause a register write, memory access, branch,
    // or jump.
    // ========================================================================
    task automatic test_illegal(
        input string       name,
        input logic [31:0] instr
    );

        bit failed;

        @(negedge i_clk);

        i_valid = 1'b1;
        i_instr = instr;
        i_pc          = 32'h0000_8000;
        i_pred_taken  = 1'b0;
        i_pred_target = 32'd0;

        i_stall = 1'b0;
        i_flush = 1'b0;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid !== 1'b1) begin
            $error("%s: expected o_valid=1", name);
            failed = 1'b1;
        end

        if (o_illegal !== 1'b1) begin
            $error("%s: expected o_illegal=1", name);
            failed = 1'b1;
        end

        if (o_reg_write !== 1'b0) begin
            $error("%s: illegal instruction asserted o_reg_write", name);
            failed = 1'b1;
        end

        if (o_mem_read !== 1'b0) begin
            $error("%s: illegal instruction asserted o_mem_read", name);
            failed = 1'b1;
        end

        if (o_mem_write !== 1'b0) begin
            $error("%s: illegal instruction asserted o_mem_write", name);
            failed = 1'b1;
        end

        if (o_is_branch !== 1'b0) begin
            $error("%s: illegal instruction asserted o_is_branch", name);
            failed = 1'b1;
        end

        if (o_is_jump !== 1'b0) begin
            $error("%s: illegal instruction asserted o_is_jump", name);
            failed = 1'b1;
        end

        if (o_jalr !== 1'b0) begin
            $error("%s: illegal instruction asserted o_jalr", name);
            failed = 1'b1;
        end

        if (failed) begin
            tests_failed++;
            $display("[FAIL] %s", name);
        end
        else begin
            $display("[PASS] %s", name);
        end

    endtask


    // ========================================================================
    // i_valid = 0
    // ========================================================================
    task automatic test_invalid_input;

        logic [31:0] instr;
        bit failed;

        instr = make_s(
            OP_STORE,
            F3_SW,
            5'd1,
            5'd2,
            12'h100
        );

        @(negedge i_clk);

        i_valid = 1'b0;
        i_instr = instr;
        i_pc          = 32'h1234_5678;
        i_pred_taken  = 1'b0;
        i_pred_target = 32'd0;

        i_stall = 1'b0;
        i_flush = 1'b0;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid !== 1'b0) begin
            $error("i_valid=0: o_valid must be 0");
            failed = 1'b1;
        end

        if (o_mem_read !== 1'b0 ||
            o_mem_write !== 1'b0 ||
            o_reg_write !== 1'b0 ||
            o_is_branch !== 1'b0 ||
            o_is_jump !== 1'b0 ||
            o_illegal !== 1'b0) begin

            $error("i_valid=0 caused architectural side effects");
            failed = 1'b1;
        end

        if (failed) begin
            tests_failed++;
            $display("[FAIL] i_valid=0 produces bubble");
        end
        else begin
            $display("[PASS] i_valid=0 produces bubble");
        end

    endtask


    // ========================================================================
    // Reset test
    // ========================================================================
    task automatic test_reset;

        bit failed;

        @(negedge i_clk);

        i_rst   = 1'b1;
        i_flush = 1'b1;
        i_stall = 1'b1;
        i_valid = 1'b1;
        i_instr = 32'hFFFF_FFFF;
        i_pc          = 32'hDEAD_BEEF;
        i_pred_taken  = 1'b1;
        i_pred_target = 32'hCAFE_BABE;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid !== 1'b0) failed = 1'b1;
        if (o_pc !== 32'd0) failed = 1'b1;

        if (o_rs1 !== 5'd0) failed = 1'b1;
        if (o_rs2 !== 5'd0) failed = 1'b1;
        if (o_rd  !== 5'd0) failed = 1'b1;

        if (o_imm !== 32'd0) failed = 1'b1;

        if (o_alu_op !== ARITH_ADD) failed = 1'b1;
        if (o_alu_inp_1 !== 1'b0) failed = 1'b1;
        if (o_alu_inp_2 !== 1'b1) failed = 1'b1;

        if (o_mem_read  !== 1'b0) failed = 1'b1;
        if (o_mem_write !== 1'b0) failed = 1'b1;
        if (o_mem_type  !== S_LOAD_BYTE) failed = 1'b1;

        if (o_reg_write !== 1'b0) failed = 1'b1;
        if (o_wr_from   !== WR_ALU_RES) failed = 1'b1;

        if (o_is_branch   !== 1'b0) failed = 1'b1;
        if (o_branch_type !== BEQ) failed = 1'b1;

        if (o_is_jump !== 1'b0) failed = 1'b1;
        if (o_jalr    !== 1'b0) failed = 1'b1;
        if (o_illegal !== 1'b0) failed = 1'b1;
        if (o_pred_taken !== 1'b0) failed = 1'b1;
        if (o_pred_target !== 32'd0) failed = 1'b1;

        if (o_pc_plus_4 !== 32'd0) failed = 1'b1;
        if (o_pred_taken !== 1'b0) failed = 1'b1;
        if (o_pred_target !== 32'd0) failed = 1'b1;

        if (failed) begin
            tests_failed++;
            $display("[FAIL] Reset state / reset priority");
        end
        else begin
            $display("[PASS] Reset state / reset priority");
        end

        @(negedge i_clk);

        i_rst   = 1'b0;
        i_flush = 1'b0;
        i_stall = 1'b0;

    endtask


    // ========================================================================
    // Stall test
    // ========================================================================
    task automatic test_stall;

        logic [31:0] original_pc;
        logic [31:0] original_pc_plus_4;
        logic [4:0]  original_rs1;
        logic [4:0]  original_rs2;
        logic [4:0]  original_rd;
        logic [31:0] original_imm;

        t_alu_ops    original_alu_op;

        logic        original_alu_inp_1;
        logic        original_alu_inp_2;

        logic        original_mem_read;
        logic        original_mem_write;
        t_mem_types  original_mem_type;

        logic        original_reg_write;
        t_wb_src     original_wr_from;

        logic        original_is_branch;
        logic        original_is_jump;
        logic        original_jalr;
        logic        original_illegal;
        logic        original_valid;
        logic        original_pred_taken;
        logic [31:0] original_pred_target;

        bit failed;

        // Put a known load into the decoder register.
        test_load(
            "Stall setup load",
            F3_LW,
            S_LOAD_WORD
        );

        original_valid      = o_valid;
        original_pc         = o_pc;
        original_pc_plus_4  = o_pc_plus_4;
        original_rs1        = o_rs1;
        original_rs2        = o_rs2;
        original_rd         = o_rd;
        original_imm        = o_imm;
        original_alu_op     = o_alu_op;
        original_alu_inp_1  = o_alu_inp_1;
        original_alu_inp_2  = o_alu_inp_2;
        original_mem_read   = o_mem_read;
        original_mem_write  = o_mem_write;
        original_mem_type   = o_mem_type;
        original_reg_write  = o_reg_write;
        original_wr_from    = o_wr_from;
        original_is_branch  = o_is_branch;
        original_is_jump    = o_is_jump;
        original_jalr       = o_jalr;
        original_illegal    = o_illegal;
        original_pred_taken = o_pred_taken;
        original_pred_target = o_pred_target;

        // Present an entirely different instruction while stalled.
        @(negedge i_clk);

        i_stall = 1'b1;
        i_flush = 1'b0;

        i_valid = 1'b1;
        i_pc          = 32'hABCD_0000;
        i_pred_taken  = 1'b1;
        i_pred_target = 32'h1234_0000;

        i_instr = make_r(
            OP_ALU,
            5'd20,
            F3_ADD,
            5'd21,
            5'd22,
            7'b0100000
        );

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid      !== original_valid)      failed = 1'b1;
        if (o_pc         !== original_pc)         failed = 1'b1;
        if (o_pc_plus_4  !== original_pc_plus_4) failed = 1'b1;

        if (o_rs1 !== original_rs1) failed = 1'b1;
        if (o_rs2 !== original_rs2) failed = 1'b1;
        if (o_rd  !== original_rd)  failed = 1'b1;

        if (o_imm !== original_imm) failed = 1'b1;

        if (o_alu_op    !== original_alu_op)    failed = 1'b1;
        if (o_alu_inp_1 !== original_alu_inp_1) failed = 1'b1;
        if (o_alu_inp_2 !== original_alu_inp_2) failed = 1'b1;

        if (o_mem_read  !== original_mem_read)  failed = 1'b1;
        if (o_mem_write !== original_mem_write) failed = 1'b1;
        if (o_mem_type  !== original_mem_type)  failed = 1'b1;

        if (o_reg_write !== original_reg_write) failed = 1'b1;
        if (o_wr_from   !== original_wr_from)   failed = 1'b1;

        if (o_is_branch !== original_is_branch) failed = 1'b1;
        if (o_is_jump   !== original_is_jump)   failed = 1'b1;
        if (o_jalr      !== original_jalr)      failed = 1'b1;
        if (o_illegal   !== original_illegal)   failed = 1'b1;
        if (o_pred_taken !== original_pred_taken) failed = 1'b1;
        if (o_pred_target !== original_pred_target) failed = 1'b1;

        if (failed) begin
            tests_failed++;
            $display("[FAIL] Stall freezes decoder pipeline register");
        end
        else begin
            $display("[PASS] Stall freezes decoder pipeline register");
        end

        @(negedge i_clk);
        i_stall = 1'b0;

    endtask


    // ========================================================================
    // Flush test
    // ========================================================================
    task automatic test_flush;

        logic [31:0] instr;
        expected_t e;
        bit failed;

        // First put JALR in the pipeline. This specifically checks that
        // flush clears a stale o_jalr.
        instr = make_i(
            OP_JALR,
            5'd10,
            3'b000,
            5'd8,
            12'h010
        );

        e = expected_default(instr, 32'h0000_9000);

        e.rs2           = 5'd0;
        e.imm           = 32'h0000_0010;
        e.reg_write     = 1'b1;
        e.check_wr_from = 1'b1;
        e.wr_from       = WR_PC_PLUS_4;
        e.is_jump       = 1'b1;
        e.jalr          = 1'b1;

        run_test(
            "Flush setup JALR",
            instr,
            32'h0000_9000,
            e
        );

        @(negedge i_clk);

        i_flush = 1'b1;
        i_stall = 1'b0;

        i_valid = 1'b1;
        i_instr = 32'hFFFF_FFFF;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid     !== 1'b0) failed = 1'b1;
        if (o_mem_write !== 1'b0) failed = 1'b1;
        if (o_mem_read  !== 1'b0) failed = 1'b1;
        if (o_reg_write !== 1'b0) failed = 1'b1;
        if (o_is_branch !== 1'b0) failed = 1'b1;
        if (o_is_jump   !== 1'b0) failed = 1'b1;
        if (o_illegal   !== 1'b0) failed = 1'b1;
        if (o_pred_taken !== 1'b0) failed = 1'b1;
        if (o_pred_target !== 32'd0) failed = 1'b1;

        // A flushed bubble should not retain JALR control either.
        if (o_jalr !== 1'b0) begin
            $error("Flush left stale o_jalr asserted");
            failed = 1'b1;
        end

        if (failed) begin
            tests_failed++;
            $display("[FAIL] Flush injects bubble");
        end
        else begin
            $display("[PASS] Flush injects bubble");
        end

        @(negedge i_clk);
        i_flush = 1'b0;

    endtask


    // ========================================================================
    // Flush priority over stall
    // ========================================================================
    task automatic test_flush_over_stall;

        bit failed;

        @(negedge i_clk);

        i_valid = 1'b1;
        i_flush = 1'b1;
        i_stall = 1'b1;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid     !== 1'b0) failed = 1'b1;
        if (o_mem_write !== 1'b0) failed = 1'b1;
        if (o_mem_read  !== 1'b0) failed = 1'b1;
        if (o_reg_write !== 1'b0) failed = 1'b1;
        if (o_is_branch !== 1'b0) failed = 1'b1;
        if (o_is_jump   !== 1'b0) failed = 1'b1;
        if (o_illegal   !== 1'b0) failed = 1'b1;
        if (o_pred_taken !== 1'b0) failed = 1'b1;
        if (o_pred_target !== 32'd0) failed = 1'b1;

        if (failed) begin
            tests_failed++;
            $display("[FAIL] Flush priority over stall");
        end
        else begin
            $display("[PASS] Flush priority over stall");
        end

        @(negedge i_clk);

        i_flush = 1'b0;
        i_stall = 1'b0;

    endtask



    task automatic test_prediction_metadata;
        logic [31:0] instr;
        expected_t e;

        instr = make_b(
            OP_BRANCH,
            F3_BEQ,
            5'd1,
            5'd2,
            13'd16
        );

        e = expected_default(instr, 32'h0000_A000);
        e.imm               = 32'd16;
        e.alu_inp_1         = 1'b1;
        e.is_branch         = 1'b1;
        e.check_branch_type = 1'b1;
        e.branch_type       = BEQ;
        e.pred_taken        = 1'b1;
        e.pred_target       = 32'h0000_A010;

        run_test(
            "Prediction metadata passes through ID/EX",
            instr,
            32'h0000_A000,
            e
        );
    endtask

    // ========================================================================
    // Main test sequence
    // ========================================================================
    initial begin

        tests_run    = 0;
        tests_failed = 0;

        i_rst   = 1'b0;
        i_valid = 1'b0;
        i_pc    = 32'd0;
        i_instr = 32'd0;
        i_pred_taken = 1'b0;
        i_pred_target = 32'd0;
        i_stall = 1'b0;
        i_flush = 1'b0;

        // --------------------------------------------------------------------
        // RESET / PIPELINE CONTROL
        // --------------------------------------------------------------------
        test_reset();


        // --------------------------------------------------------------------
        // R-TYPE ALU
        // --------------------------------------------------------------------
        test_r_type(
            "ADD",
            F3_ADD,
            7'b0000000,
            ARITH_ADD
        );

        test_r_type(
            "SUB",
            F3_ADD,
            7'b0100000,
            ARITH_SUB
        );

        test_r_type(
            "SLL",
            F3_SLL,
            7'b0000000,
            SHIFT_L_LOGIC
        );

        test_r_type(
            "SLT",
            F3_SLT,
            7'b0000000,
            SET_LESS_S
        );

        test_r_type(
            "SLTU",
            F3_SLTU,
            7'b0000000,
            SET_LESS_U
        );

        test_r_type(
            "XOR",
            F3_XOR,
            7'b0000000,
            LOGIC_XOR
        );

        test_r_type(
            "SRL",
            F3_SR,
            7'b0000000,
            SHIFT_R_LOGIC
        );

        test_r_type(
            "SRA",
            F3_SR,
            7'b0100000,
            SHIFT_R_ARITH
        );

        test_r_type(
            "OR",
            F3_OR,
            7'b0000000,
            LOGIC_OR
        );

        test_r_type(
            "AND",
            F3_AND,
            7'b0000000,
            LOGIC_AND
        );


        // --------------------------------------------------------------------
        // I-TYPE ALU
        // --------------------------------------------------------------------
        test_i_alu(
            "ADDI positive",
            F3_ADD,
            12'h123,
            32'h0000_0123,
            ARITH_ADD
        );

        test_i_alu(
            "ADDI negative",
            F3_ADD,
            12'hFFF,
            32'hFFFF_FFFF,
            ARITH_ADD
        );

        test_i_alu(
            "ADDI maximum +2047",
            F3_ADD,
            12'h7FF,
            32'h0000_07FF,
            ARITH_ADD
        );

        test_i_alu(
            "ADDI minimum -2048",
            F3_ADD,
            12'h800,
            32'hFFFF_F800,
            ARITH_ADD
        );

        test_i_alu(
            "SLTI",
            F3_SLT,
            12'hFE0,
            32'hFFFF_FFE0,
            SET_LESS_S
        );

        test_i_alu(
            "SLTIU",
            F3_SLTU,
            12'h123,
            32'h0000_0123,
            SET_LESS_U
        );

        test_i_alu(
            "XORI",
            F3_XOR,
            12'h5A5,
            32'h0000_05A5,
            LOGIC_XOR
        );

        test_i_alu(
            "ORI",
            F3_OR,
            12'h321,
            32'h0000_0321,
            LOGIC_OR
        );

        test_i_alu(
            "ANDI",
            F3_AND,
            12'hF0F,
            32'hFFFF_FF0F,
            LOGIC_AND
        );

        // Shift immediate encodings:
        // funct7 occupies imm[11:5], shamt occupies imm[4:0].

        test_i_alu(
            "SLLI",
            F3_SLL,
            {7'b0000000, 5'd17},
            32'd17,
            SHIFT_L_LOGIC
        );

        test_i_alu(
            "SRLI",
            F3_SR,
            {7'b0000000, 5'd13},
            32'd13,
            SHIFT_R_LOGIC
        );

        test_i_alu(
            "SRAI",
            F3_SR,
            {7'b0100000, 5'd29},
            32'd29,
            SHIFT_R_ARITH
        );


        // --------------------------------------------------------------------
        // LUI
        // --------------------------------------------------------------------
        begin
            logic [31:0] instr;
            expected_t e;

            instr = make_u(
                OP_LUI,
                5'd10,
                32'hABCDE000
            );

            e = expected_default(instr, 32'h0000_6000);

            e.rs1           = 5'd0;
            e.rs2           = 5'd0;
            e.imm           = 32'hABCDE000;
            e.reg_write     = 1'b1;
            e.check_wr_from = 1'b1;
            e.wr_from       = WR_ALU_RES;

            run_test(
                "LUI",
                instr,
                32'h0000_6000,
                e
            );
        end


        // --------------------------------------------------------------------
        // AUIPC
        // --------------------------------------------------------------------
        begin
            logic [31:0] instr;
            expected_t e;

            instr = make_u(
                OP_AUIPC,
                5'd11,
                32'h54321000
            );

            e = expected_default(instr, 32'h0000_6400);

            e.rs1           = 5'd0;
            e.rs2           = 5'd0;
            e.imm           = 32'h54321000;
            e.alu_inp_1     = 1'b1;
            e.reg_write     = 1'b1;
            e.check_wr_from = 1'b1;
            e.wr_from       = WR_ALU_RES;

            run_test(
                "AUIPC",
                instr,
                32'h0000_6400,
                e
            );
        end


        // --------------------------------------------------------------------
        // JAL positive
        // --------------------------------------------------------------------
        begin
            logic [31:0] instr;
            expected_t e;

            instr = make_j(
                OP_JAL,
                5'd1,
                21'd2046
            );

            e = expected_default(instr, 32'h0000_7000);

            e.rs1           = 5'd0;
            e.rs2           = 5'd0;
            e.imm           = 32'd2046;
            e.alu_inp_1     = 1'b1;
            e.reg_write     = 1'b1;
            e.check_wr_from = 1'b1;
            e.wr_from       = WR_PC_PLUS_4;
            e.is_jump       = 1'b1;

            run_test(
                "JAL positive offset",
                instr,
                32'h0000_7000,
                e
            );
        end


        // --------------------------------------------------------------------
        // JAL negative
        // --------------------------------------------------------------------
        begin
            logic [31:0] instr;
            expected_t e;

            // -2048 in 21-bit immediate
            instr = make_j(
                OP_JAL,
                5'd1,
                21'h1FF800
            );

            e = expected_default(instr, 32'h0000_7004);

            e.rs1           = 5'd0;
            e.rs2           = 5'd0;
            e.imm           = 32'hFFFF_F800;
            e.alu_inp_1     = 1'b1;
            e.reg_write     = 1'b1;
            e.check_wr_from = 1'b1;
            e.wr_from       = WR_PC_PLUS_4;
            e.is_jump       = 1'b1;

            run_test(
                "JAL negative offset",
                instr,
                32'h0000_7004,
                e
            );
        end


        // --------------------------------------------------------------------
        // JALR
        // --------------------------------------------------------------------
        begin
            logic [31:0] instr;
            expected_t e;

            instr = make_i(
                OP_JALR,
                5'd1,
                3'b000,
                5'd18,
                12'hFF0
            );

            e = expected_default(instr, 32'h0000_7100);

            e.rs2           = 5'd0;
            e.imm           = 32'hFFFF_FFF0;
            e.reg_write     = 1'b1;
            e.check_wr_from = 1'b1;
            e.wr_from       = WR_PC_PLUS_4;
            e.is_jump       = 1'b1;
            e.jalr          = 1'b1;

            run_test(
                "JALR",
                instr,
                32'h0000_7100,
                e
            );
        end


        // --------------------------------------------------------------------
        // BRANCHES
        // --------------------------------------------------------------------
        test_branch("BEQ",  F3_BEQ,  BEQ);
        test_branch("BNE",  F3_BNE,  BNE);
        test_branch("BLT",  F3_BLT,  BLT);
        test_branch("BGE",  F3_BGE,  BGE);
        test_branch("BLTU", F3_BLTU, BLTU);
        test_branch("BGEU", F3_BGEU, BGEU);


        // --------------------------------------------------------------------
        // LOADS
        // --------------------------------------------------------------------
        test_load("LB",  F3_LB,  S_LOAD_BYTE);
        test_load("LH",  F3_LH,  S_LOAD_HALF);
        test_load("LW",  F3_LW,  S_LOAD_WORD);
        test_load("LBU", F3_LBU, U_LOAD_BYTE);
        test_load("LHU", F3_LHU, U_LOAD_HALF);


        // --------------------------------------------------------------------
        // STORES
        // --------------------------------------------------------------------
        test_store("SB", F3_SB, STORE_BYTE);
        test_store("SH", F3_SH, STORE_HALF);
        test_store("SW", F3_SW, STORE_WORD);


        // --------------------------------------------------------------------
        // Register x0 must never be written
        // --------------------------------------------------------------------
        begin
            logic [31:0] instr;
            expected_t e;

            instr = make_i(
                OP_IMM,
                5'd0,
                F3_ADD,
                5'd4,
                12'd100
            );

            e = expected_default(instr, 32'h0000_A000);

            e.rs2           = 5'd0;
            e.imm           = 32'd100;
            e.alu_op        = ARITH_ADD;
            e.reg_write     = 1'b0;
            e.check_wr_from = 1'b1;
            e.wr_from       = WR_ALU_RES;

            run_test(
                "ADDI with rd=x0 suppresses register write",
                instr,
                32'h0000_A000,
                e
            );
        end


        // --------------------------------------------------------------------
        // JAL x0 should jump but not write register
        // --------------------------------------------------------------------
        begin
            logic [31:0] instr;
            expected_t e;

            instr = make_j(
                OP_JAL,
                5'd0,
                21'd100
            );

            e = expected_default(instr, 32'h0000_A100);

            e.rs1           = 5'd0;
            e.rs2           = 5'd0;
            e.imm           = 32'd100;
            e.alu_inp_1     = 1'b1;
            e.reg_write     = 1'b0;
            e.check_wr_from = 1'b1;
            e.wr_from       = WR_PC_PLUS_4;
            e.is_jump       = 1'b1;

            run_test(
                "JAL x0 jumps without register write",
                instr,
                32'h0000_A100,
                e
            );
        end


        // --------------------------------------------------------------------
        // PC+4 overflow
        // --------------------------------------------------------------------
        begin
            logic [31:0] instr;
            expected_t e;

            instr = make_i(
                OP_IMM,
                5'd2,
                F3_ADD,
                5'd1,
                12'd1
            );

            e = expected_default(instr, 32'hFFFF_FFFC);

            e.rs2           = 5'd0;
            e.imm           = 32'd1;
            e.reg_write     = 1'b1;
            e.check_wr_from = 1'b1;
            e.wr_from       = WR_ALU_RES;

            run_test(
                "PC+4 wraps at 32 bits",
                instr,
                32'hFFFF_FFFC,
                e
            );
        end


        // --------------------------------------------------------------------
        // Invalid fetch input
        // --------------------------------------------------------------------
        test_invalid_input();


        // --------------------------------------------------------------------
        // ILLEGAL ENCODINGS
        // --------------------------------------------------------------------

        // Invalid JALR funct3
        test_illegal(
            "Illegal JALR funct3",
            make_i(
                OP_JALR,
                5'd5,
                3'b001,
                5'd2,
                12'd0
            )
        );

        // Invalid branch funct3
        test_illegal(
            "Illegal branch funct3",
            make_b(
                OP_BRANCH,
                3'b010,
                5'd2,
                5'd3,
                13'd8
            )
        );

        // Invalid LOAD funct3 = 011
        test_illegal(
            "Illegal LOAD funct3",
            make_i(
                OP_LOAD,
                5'd4,
                3'b011,
                5'd2,
                12'd0
            )
        );

        // Invalid STORE funct3 = 011
        test_illegal(
            "Illegal STORE funct3",
            make_s(
                OP_STORE,
                3'b011,
                5'd2,
                5'd3,
                12'd0
            )
        );

        // Invalid R-type ADD/SUB funct7
        test_illegal(
            "Illegal R-type funct7",
            make_r(
                OP_ALU,
                5'd8,
                F3_ADD,
                5'd2,
                5'd3,
                7'b1111111
            )
        );

        // Invalid SLL funct7
        test_illegal(
            "Illegal SLL funct7",
            make_r(
                OP_ALU,
                5'd8,
                F3_SLL,
                5'd2,
                5'd3,
                7'b0100000
            )
        );

        // Invalid immediate shift encoding
        test_illegal(
            "Illegal SLLI funct7",
            make_i(
                OP_IMM,
                5'd8,
                F3_SLL,
                5'd2,
                {7'b0100000, 5'd3}
            )
        );

        // SYSTEM unsupported by this decoder
        test_illegal(
            "SYSTEM instruction unsupported",
            make_i(
                OP_SYS,
                5'd0,
                3'b000,
                5'd0,
                12'd0
            )
        );

        // Completely unsupported opcode
        test_illegal(
            "Unknown opcode",
            make_i(
                7'b0001011,
                5'd5,
                3'b000,
                5'd4,
                12'd0
            )
        );


        // --------------------------------------------------------------------
        // STALL
        // --------------------------------------------------------------------
        test_stall();


        // --------------------------------------------------------------------
        // FLUSH
        // --------------------------------------------------------------------
        test_flush();


        // --------------------------------------------------------------------
        // FLUSH > STALL priority
        // --------------------------------------------------------------------
        test_flush_over_stall();

        test_prediction_metadata();


        // --------------------------------------------------------------------
        // Final result
        // --------------------------------------------------------------------
        $display("");
        $display("====================================================");
        $display("DECODER TESTBENCH COMPLETE");
        $display("====================================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_run - tests_failed);
        $display("Tests failed : %0d", tests_failed);
        $display("====================================================");

        if (tests_failed == 0) begin
            $display("[PASS] ALL DECODER TESTS PASSED");
        end
        else begin
            $display("[FAIL] %0d TEST(S) FAILED", tests_failed);
        end

        $finish;

    end

endmodule
