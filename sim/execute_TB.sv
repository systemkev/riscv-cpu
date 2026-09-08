`timescale 1ns / 1ps

import common_pkg::*;

module execute_TB;

    localparam time CLK_PERIOD = 10ns;

    // ========================================================================
    // DUT Inputs
    // ========================================================================

    logic           i_clk;
    logic           i_rst;

    logic           i_stall;
    logic           i_flush;

    logic           i_valid;
    logic [31:0]    i_pc;
    logic [4:0]     i_rs1;
    logic [4:0]     i_rs2;
    logic [4:0]     i_rd;
    logic [31:0]    i_imm;

    t_alu_ops       i_alu_op;
    logic           i_alu_inp_1;
    logic           i_alu_inp_2;

    logic           i_mem_read;
    logic           i_mem_write;
    t_mem_types     i_mem_type;
    logic           i_reg_write;
    t_wb_src        i_wb_src;

    logic           i_is_branch;
    t_branches      i_branch_type;
    logic           i_is_jump;
    logic           i_jalr;
    logic           i_illegal;

    logic [31:0]    i_rs1_val;
    logic [31:0]    i_rs2_val;

    t_forwarding    i_forward_op_a;
    t_forwarding    i_forward_op_b;
    logic [31:0]    i_mem_fwd_data;
    logic [31:0]    i_wb_fwd_data;


    // ========================================================================
    // DUT Outputs
    // ========================================================================

    logic           o_valid;
    logic [31:0]    o_pc;
    logic [4:0]     o_rd;
    logic [31:0]    o_alu_result;
    logic [31:0]    o_rs2_val;

    logic           o_mem_read;
    logic           o_mem_write;
    t_mem_types     o_mem_type;

    logic           o_reg_write;
    t_wb_src        o_wb_src;
    logic           o_illegal;

    logic           o_redirect;
    logic [31:0]    o_target;


    // ========================================================================
    // DUT
    // ========================================================================

    execute dut (
        .i_clk          (i_clk),
        .i_rst          (i_rst),

        .i_stall        (i_stall),
        .i_flush        (i_flush),

        .i_valid        (i_valid),
        .i_pc           (i_pc),
        .i_rs1          (i_rs1),
        .i_rs2          (i_rs2),
        .i_rd           (i_rd),
        .i_imm          (i_imm),

        .i_alu_op       (i_alu_op),
        .i_alu_inp_1    (i_alu_inp_1),
        .i_alu_inp_2    (i_alu_inp_2),

        .i_mem_read     (i_mem_read),
        .i_mem_write    (i_mem_write),
        .i_mem_type     (i_mem_type),
        .i_reg_write    (i_reg_write),
        .i_wb_src       (i_wb_src),

        .i_is_branch    (i_is_branch),
        .i_branch_type  (i_branch_type),
        .i_is_jump      (i_is_jump),
        .i_jalr         (i_jalr),
        .i_illegal      (i_illegal),

        .i_rs1_val      (i_rs1_val),
        .i_rs2_val      (i_rs2_val),

        .i_forward_op_a (i_forward_op_a),
        .i_forward_op_b (i_forward_op_b),
        .i_mem_fwd_data (i_mem_fwd_data),
        .i_wb_fwd_data  (i_wb_fwd_data),

        .o_valid        (o_valid),
        .o_pc           (o_pc),
        .o_rd           (o_rd),
        .o_alu_result   (o_alu_result),
        .o_rs2_val      (o_rs2_val),

        .o_mem_read     (o_mem_read),
        .o_mem_write    (o_mem_write),
        .o_mem_type     (o_mem_type),
        .o_reg_write    (o_reg_write),
        .o_wb_src       (o_wb_src),
        .o_illegal      (o_illegal),

        .o_redirect     (o_redirect),
        .o_target       (o_target)
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
    // Expected pipeline output
    // ========================================================================

    typedef struct {
        logic           valid;
        logic [31:0]    pc;
        logic [4:0]     rd;
        logic [31:0]    alu_result;
        logic [31:0]    rs2_val;

        logic           mem_read;
        logic           mem_write;
        t_mem_types     mem_type;

        logic           reg_write;
        t_wb_src        wb_src;
        logic           illegal;
    } expected_t;


    // ========================================================================
    // Default DUT inputs
    // ========================================================================

    task automatic default_inputs;

        i_valid         = 1'b0;
        i_pc            = 32'd0;
        i_rs1           = 5'd0;
        i_rs2           = 5'd0;
        i_rd            = 5'd0;
        i_imm           = 32'd0;

        i_alu_op        = ARITH_ADD;
        i_alu_inp_1     = 1'b0;
        i_alu_inp_2     = 1'b0;

        i_mem_read      = 1'b0;
        i_mem_write     = 1'b0;
        i_mem_type      = S_LOAD_BYTE;

        i_reg_write     = 1'b0;
        i_wb_src        = WR_ALU_RES;

        i_is_branch     = 1'b0;
        i_branch_type   = BEQ;

        i_is_jump       = 1'b0;
        i_jalr          = 1'b0;
        i_illegal       = 1'b0;

        i_rs1_val       = 32'd0;
        i_rs2_val       = 32'd0;

        i_forward_op_a  = NO_HAZ;
        i_forward_op_b  = NO_HAZ;

        i_mem_fwd_data  = 32'd0;
        i_wb_fwd_data   = 32'd0;

        i_stall         = 1'b0;
        i_flush         = 1'b0;

    endtask


    // ========================================================================
    // Default expected output
    // ========================================================================

    function automatic expected_t make_expected;

        expected_t e;

        e.valid      = 1'b1;
        e.pc         = 32'h0000_1000;
        e.rd         = 5'd0;

        e.alu_result = 32'd0;
        e.rs2_val    = 32'd0;

        e.mem_read   = 1'b0;
        e.mem_write  = 1'b0;
        e.mem_type   = S_LOAD_BYTE;

        e.reg_write  = 1'b0;
        e.wb_src     = WR_ALU_RES;

        e.illegal    = 1'b0;

        return e;

    endfunction


    // ========================================================================
    // Pipeline-register checker
    // ========================================================================

    task automatic check_pipeline(
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

        if (o_rd !== e.rd) begin
            $error("%s: o_rd expected=%0d got=%0d",
                   test_name, e.rd, o_rd);
            failed = 1'b1;
        end

        if (o_alu_result !== e.alu_result) begin
            $error("%s: o_alu_result expected=%h got=%h",
                   test_name, e.alu_result, o_alu_result);
            failed = 1'b1;
        end

        if (o_rs2_val !== e.rs2_val) begin
            $error("%s: o_rs2_val expected=%h got=%h",
                   test_name, e.rs2_val, o_rs2_val);
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

        if (o_mem_type !== e.mem_type) begin
            $error("%s: o_mem_type expected=%0d got=%0d",
                   test_name, e.mem_type, o_mem_type);
            failed = 1'b1;
        end

        if (o_reg_write !== e.reg_write) begin
            $error("%s: o_reg_write expected=%b got=%b",
                   test_name, e.reg_write, o_reg_write);
            failed = 1'b1;
        end

        if (o_wb_src !== e.wb_src) begin
            $error("%s: o_wb_src expected=%0d got=%0d",
                   test_name, e.wb_src, o_wb_src);
            failed = 1'b1;
        end

        if (o_illegal !== e.illegal) begin
            $error("%s: o_illegal expected=%b got=%b",
                   test_name, e.illegal, o_illegal);
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
    // Combinational redirect checker
    // ========================================================================

    task automatic check_redirect(
        input string       test_name,
        input logic        expected_redirect,
        input logic [31:0] expected_target
    );

        bit failed;

        failed = 1'b0;
        tests_run++;

        if (o_redirect !== expected_redirect) begin
            $error("%s: o_redirect expected=%b got=%b",
                   test_name, expected_redirect, o_redirect);
            failed = 1'b1;
        end

        if (o_target !== expected_target) begin
            $error("%s: o_target expected=%h got=%h",
                   test_name, expected_target, o_target);
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
    // ALU integration test
    // ========================================================================

    task automatic test_alu(
        input string       test_name,
        input t_alu_ops    operation,
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [31:0] expected_result
    );

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h0000_1000;
        i_rd          = 5'd0;

        i_rs1_val     = a;
        i_rs2_val     = b;

        i_alu_inp_1   = 1'b0;
        i_alu_inp_2   = 1'b0;
        i_alu_op      = operation;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_ALU_RES;

        #1;

        check_redirect(
            {test_name, " redirect"},
            1'b0,
            expected_result
        );

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.alu_result = expected_result;
        e.rs2_val    = b;
        e.reg_write  = 1'b1;

        check_pipeline(test_name, e);

    endtask


    // ========================================================================
    // Branch test
    // ========================================================================

    task automatic test_branch(
        input string       test_name,
        input t_branches   branch_type,
        input logic [31:0] rs1_value,
        input logic [31:0] rs2_value,
        input logic        expected_taken
    );

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;

        i_pc          = 32'h0000_4000;
        i_imm         = 32'h0000_0040;

        i_rs1_val     = rs1_value;
        i_rs2_val     = rs2_value;

        i_is_branch   = 1'b1;
        i_branch_type = branch_type;

        // Branch target = PC + immediate
        i_alu_op      = ARITH_ADD;
        i_alu_inp_1   = 1'b1;
        i_alu_inp_2   = 1'b1;

        #1;

        check_redirect(
            {test_name, " redirect"},
            expected_taken,
            32'h0000_4040
        );

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_4000;
        e.alu_result = 32'h0000_4040;
        e.rs2_val    = rs2_value;

        check_pipeline(test_name, e);

    endtask


    // ========================================================================
    // Reset
    // ========================================================================

    task automatic test_reset;

        bit failed;

        @(negedge i_clk);

        default_inputs();

        i_rst       = 1'b1;
        i_stall     = 1'b1;
        i_flush     = 1'b1;

        i_valid     = 1'b1;
        i_pc        = 32'hDEAD_BEEF;
        i_rd        = 5'd31;
        i_mem_read  = 1'b1;
        i_mem_write = 1'b1;
        i_reg_write = 1'b1;
        i_illegal   = 1'b1;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid      !== 1'b0)          failed = 1'b1;
        if (o_pc         !== 32'd0)         failed = 1'b1;
        if (o_rd         !== 5'd0)          failed = 1'b1;
        if (o_alu_result !== 32'd0)         failed = 1'b1;
        if (o_rs2_val    !== 32'd0)         failed = 1'b1;

        if (o_mem_read   !== 1'b0)          failed = 1'b1;
        if (o_mem_write  !== 1'b0)          failed = 1'b1;
        if (o_mem_type   !== S_LOAD_BYTE)   failed = 1'b1;

        if (o_reg_write  !== 1'b0)          failed = 1'b1;
        if (o_wb_src     !== WR_ALU_RES)     failed = 1'b1;
        if (o_illegal    !== 1'b0)          failed = 1'b1;

        if (failed) begin
            tests_failed++;
            $display("[FAIL] Reset state / reset priority");
        end
        else begin
            $display("[PASS] Reset state / reset priority");
        end

        @(negedge i_clk);
        i_rst = 1'b0;

    endtask


    // ========================================================================
    // Operand selection
    // ========================================================================

    task automatic test_operand_selection;

        expected_t e;

        // --------------------------------------------------------------------
        // rs1 + immediate
        // --------------------------------------------------------------------
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h0000_2000;
        i_rd          = 5'd5;

        i_rs1_val     = 32'd100;
        i_rs2_val     = 32'hDEAD_BEEF;
        i_imm         = 32'd25;

        i_alu_op      = ARITH_ADD;
        i_alu_inp_1   = 1'b0;
        i_alu_inp_2   = 1'b1;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_2000;
        e.rd         = 5'd5;
        e.alu_result = 32'd125;
        e.rs2_val    = 32'hDEAD_BEEF;

        check_pipeline("Operand selection: rs1 + immediate", e);


        // --------------------------------------------------------------------
        // PC + immediate
        // --------------------------------------------------------------------
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h1234_0000;
        i_rd          = 5'd6;

        i_rs1_val     = 32'hFFFF_FFFF;
        i_rs2_val     = 32'hAAAA_AAAA;
        i_imm         = 32'h0000_0100;

        i_alu_op      = ARITH_ADD;
        i_alu_inp_1   = 1'b1;
        i_alu_inp_2   = 1'b1;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h1234_0000;
        e.rd         = 5'd6;
        e.alu_result = 32'h1234_0100;
        e.rs2_val    = 32'hAAAA_AAAA;

        check_pipeline("Operand selection: PC + immediate", e);

    endtask


    // ========================================================================
    // Forwarding tests
    // ========================================================================

    task automatic test_forwarding;

        expected_t e;

        // --------------------------------------------------------------------
        // WB -> operand A
        // --------------------------------------------------------------------
        @(negedge i_clk);
        default_inputs();

        i_valid        = 1'b1;
        i_pc           = 32'h0000_5000;
        i_rd           = 5'd0;

        i_rs1_val      = 32'd1;
        i_rs2_val      = 32'd7;
        i_wb_fwd_data  = 32'd100;

        i_forward_op_a = WB_FWD;

        i_alu_op       = ARITH_ADD;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_5000;
        e.alu_result = 32'd107;
        e.rs2_val    = 32'd7;

        check_pipeline("WB forwarding to operand A", e);


        // --------------------------------------------------------------------
        // MEM -> operand A
        // --------------------------------------------------------------------
        @(negedge i_clk);
        default_inputs();

        i_valid         = 1'b1;
        i_pc            = 32'h0000_5004;

        i_rs1_val       = 32'd1;
        i_rs2_val       = 32'd8;
        i_mem_fwd_data  = 32'd200;

        i_forward_op_a  = MEM_FWD;

        i_alu_op        = ARITH_ADD;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_5004;
        e.alu_result = 32'd208;
        e.rs2_val    = 32'd8;

        check_pipeline("MEM forwarding to operand A", e);


        // --------------------------------------------------------------------
        // WB -> operand B
        // --------------------------------------------------------------------
        @(negedge i_clk);
        default_inputs();

        i_valid        = 1'b1;
        i_pc           = 32'h0000_5008;

        i_rs1_val      = 32'd20;
        i_rs2_val      = 32'd1;
        i_wb_fwd_data  = 32'd30;

        i_forward_op_b = WB_FWD;

        i_alu_op       = ARITH_ADD;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_5008;
        e.alu_result = 32'd50;

        // o_rs2_val must contain forwarded value too
        e.rs2_val    = 32'd30;

        check_pipeline("WB forwarding to operand B", e);


        // --------------------------------------------------------------------
        // MEM -> operand B
        // --------------------------------------------------------------------
        @(negedge i_clk);
        default_inputs();

        i_valid         = 1'b1;
        i_pc            = 32'h0000_500C;

        i_rs1_val       = 32'd20;
        i_rs2_val       = 32'd1;
        i_mem_fwd_data  = 32'd40;

        i_forward_op_b  = MEM_FWD;

        i_alu_op        = ARITH_ADD;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_500C;
        e.alu_result = 32'd60;
        e.rs2_val    = 32'd40;

        check_pipeline("MEM forwarding to operand B", e);


        // --------------------------------------------------------------------
        // MEM -> A and WB -> B simultaneously
        // --------------------------------------------------------------------
        @(negedge i_clk);
        default_inputs();

        i_valid         = 1'b1;
        i_pc            = 32'h0000_5010;

        i_rs1_val       = 32'hAAAA_AAAA;
        i_rs2_val       = 32'hBBBB_BBBB;

        i_mem_fwd_data  = 32'd1000;
        i_wb_fwd_data   = 32'd24;

        i_forward_op_a  = MEM_FWD;
        i_forward_op_b  = WB_FWD;

        i_alu_op        = ARITH_ADD;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_5010;
        e.alu_result = 32'd1024;
        e.rs2_val    = 32'd24;

        check_pipeline("Simultaneous MEM-A / WB-B forwarding", e);

    endtask


    // ========================================================================
    // Forwarding must not override PC/immediate selection
    // ========================================================================

    task automatic test_forwarding_with_operand_mux;

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid         = 1'b1;

        i_pc            = 32'h0000_6000;
        i_imm           = 32'h0000_0040;

        i_rs1_val       = 32'h1111_1111;
        i_rs2_val       = 32'h2222_2222;

        i_mem_fwd_data  = 32'hAAAA_AAAA;
        i_wb_fwd_data   = 32'hBBBB_BBBB;

        i_forward_op_a  = MEM_FWD;
        i_forward_op_b  = WB_FWD;

        // ALU should ignore both forwarded values and use PC + immediate.
        i_alu_inp_1     = 1'b1;
        i_alu_inp_2     = 1'b1;
        i_alu_op        = ARITH_ADD;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_6000;
        e.alu_result = 32'h0000_6040;

        // rs2 store path still contains resolved/forwarded rs2.
        e.rs2_val    = 32'hBBBB_BBBB;

        check_pipeline(
            "Forwarding does not override PC/immediate ALU mux",
            e
        );

    endtask


    // ========================================================================
    // Store address + forwarded store data
    // ========================================================================

    task automatic test_store_forwarding;

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid         = 1'b1;
        i_pc            = 32'h0000_7000;

        i_rs1_val       = 32'h1000_0000;
        i_rs2_val       = 32'hDEAD_DEAD;

        i_imm           = 32'd16;

        i_mem_write     = 1'b1;
        i_mem_type      = STORE_WORD;

        // Base + immediate
        i_alu_op        = ARITH_ADD;
        i_alu_inp_1     = 1'b0;
        i_alu_inp_2     = 1'b1;

        // Store data comes from WB forwarding
        i_wb_fwd_data   = 32'hCAFE_BABE;
        i_forward_op_b  = WB_FWD;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc         = 32'h0000_7000;
        e.alu_result = 32'h1000_0010;
        e.rs2_val    = 32'hCAFE_BABE;

        e.mem_write  = 1'b1;
        e.mem_type   = STORE_WORD;

        check_pipeline(
            "Store address + forwarded store data",
            e
        );

    endtask


    // ========================================================================
    // Load/control propagation
    // ========================================================================

    task automatic test_control_propagation;

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h0000_8000;
        i_rd          = 5'd19;

        i_rs1_val     = 32'h2000_0000;
        i_imm         = 32'h0000_0024;

        i_alu_op      = ARITH_ADD;
        i_alu_inp_2   = 1'b1;

        i_mem_read    = 1'b1;
        i_mem_type    = U_LOAD_HALF;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;

        i_illegal     = 1'b0;

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc          = 32'h0000_8000;
        e.rd          = 5'd19;

        e.alu_result  = 32'h2000_0024;

        e.mem_read    = 1'b1;
        e.mem_type    = U_LOAD_HALF;

        e.reg_write   = 1'b1;
        e.wb_src      = WR_READ_RES;

        check_pipeline(
            "EX to MEM control propagation",
            e
        );

    endtask


    // ========================================================================
    // JAL
    // ========================================================================

    task automatic test_jal;

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;

        i_pc          = 32'h0000_9000;
        i_imm         = 32'h0000_0100;
        i_rd          = 5'd1;

        i_is_jump     = 1'b1;
        i_jalr        = 1'b0;

        i_alu_op      = ARITH_ADD;
        i_alu_inp_1   = 1'b1;
        i_alu_inp_2   = 1'b1;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_PC_PLUS_4;

        #1;

        check_redirect(
            "JAL redirect",
            1'b1,
            32'h0000_9100
        );

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc          = 32'h0000_9000;
        e.rd          = 5'd1;
        e.alu_result  = 32'h0000_9100;

        e.reg_write   = 1'b1;
        e.wb_src      = WR_PC_PLUS_4;

        check_pipeline("JAL pipeline output", e);

    endtask


    // ========================================================================
    // JALR + mandatory target bit 0 clearing
    // ========================================================================

    task automatic test_jalr;

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;

        i_pc          = 32'h0000_A000;

        // 0x1003 + 4 = 0x1007
        // JALR target must clear bit 0 -> 0x1006.
        i_rs1_val     = 32'h0000_1003;
        i_imm         = 32'd4;

        i_rd          = 5'd1;

        i_is_jump     = 1'b1;
        i_jalr        = 1'b1;

        i_alu_op      = ARITH_ADD;
        i_alu_inp_1   = 1'b0;
        i_alu_inp_2   = 1'b1;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_PC_PLUS_4;

        #1;

        check_redirect(
            "JALR redirect and bit-0 mask",
            1'b1,
            32'h0000_1006
        );

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc          = 32'h0000_A000;
        e.rd          = 5'd1;

        // MEM gets raw ALU result, not masked redirect address.
        e.alu_result  = 32'h0000_1007;

        e.reg_write   = 1'b1;
        e.wb_src      = WR_PC_PLUS_4;

        check_pipeline(
            "JALR pipeline contains unmasked ALU result",
            e
        );

    endtask


    // ========================================================================
    // Forwarding in branch comparator
    // ========================================================================

    task automatic test_branch_forwarding;

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid         = 1'b1;

        i_pc            = 32'h0000_B000;
        i_imm           = 32'h0000_0080;

        // Raw values are unequal.
        i_rs1_val       = 32'd1;
        i_rs2_val       = 32'd2;

        // Forwarded MEM value makes rs1 == rs2.
        i_mem_fwd_data  = 32'd2;
        i_forward_op_a  = MEM_FWD;

        i_is_branch     = 1'b1;
        i_branch_type   = BEQ;

        i_alu_op        = ARITH_ADD;
        i_alu_inp_1     = 1'b1;
        i_alu_inp_2     = 1'b1;

        #1;

        check_redirect(
            "Branch comparator uses forwarded rs1",
            1'b1,
            32'h0000_B080
        );

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.pc          = 32'h0000_B000;
        e.alu_result  = 32'h0000_B080;
        e.rs2_val     = 32'd2;

        check_pipeline(
            "Branch forwarding pipeline output",
            e
        );

    endtask


    // ========================================================================
    // Invalid instruction cannot redirect
    // ========================================================================

    task automatic test_invalid_redirect;

        expected_t e;

        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b0;

        i_pc          = 32'h1000_0000;
        i_imm         = 32'h0000_0100;

        // Deliberately assert jump while invalid.
        i_is_jump     = 1'b1;

        i_alu_op      = ARITH_ADD;
        i_alu_inp_1   = 1'b1;
        i_alu_inp_2   = 1'b1;

        #1;

        // ALU operands themselves become 0 when i_valid=0.
        check_redirect(
            "Invalid instruction cannot redirect",
            1'b0,
            32'd0
        );

        @(posedge i_clk);
        #1;

        e = make_expected();

        e.valid       = 1'b0;
        e.pc          = 32'h1000_0000;
        e.alu_result  = 32'd0;

        check_pipeline(
            "Invalid instruction pipeline valid",
            e
        );

    endtask


    // ========================================================================
    // Stall freezes pipeline register
    // ========================================================================

    task automatic test_stall;

        logic           old_valid;
        logic [31:0]    old_pc;
        logic [4:0]     old_rd;
        logic [31:0]    old_alu_result;
        logic [31:0]    old_rs2_val;

        logic           old_mem_read;
        logic           old_mem_write;
        t_mem_types     old_mem_type;

        logic           old_reg_write;
        t_wb_src        old_wb_src;
        logic           old_illegal;

        bit failed;

        // First load known state.
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h1111_0000;
        i_rd          = 5'd20;

        i_rs1_val     = 32'd100;
        i_rs2_val     = 32'd50;

        i_alu_op      = ARITH_ADD;

        i_mem_read    = 1'b1;
        i_mem_type    = S_LOAD_WORD;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;

        @(posedge i_clk);
        #1;

        old_valid       = o_valid;
        old_pc          = o_pc;
        old_rd          = o_rd;
        old_alu_result  = o_alu_result;
        old_rs2_val     = o_rs2_val;

        old_mem_read    = o_mem_read;
        old_mem_write   = o_mem_write;
        old_mem_type    = o_mem_type;

        old_reg_write   = o_reg_write;
        old_wb_src      = o_wb_src;
        old_illegal     = o_illegal;


        // Now change everything while stalled.
        @(negedge i_clk);
        default_inputs();

        i_stall       = 1'b1;

        i_valid       = 1'b1;
        i_pc          = 32'hDEAD_BEEF;
        i_rd          = 5'd31;

        i_rs1_val     = 32'hAAAA_AAAA;
        i_rs2_val     = 32'hBBBB_BBBB;

        i_alu_op      = LOGIC_XOR;

        i_mem_write   = 1'b1;
        i_mem_type    = STORE_BYTE;

        i_reg_write   = 1'b0;
        i_illegal     = 1'b1;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid      !== old_valid)      failed = 1'b1;
        if (o_pc         !== old_pc)         failed = 1'b1;
        if (o_rd         !== old_rd)         failed = 1'b1;
        if (o_alu_result !== old_alu_result) failed = 1'b1;
        if (o_rs2_val    !== old_rs2_val)    failed = 1'b1;

        if (o_mem_read   !== old_mem_read)   failed = 1'b1;
        if (o_mem_write  !== old_mem_write)  failed = 1'b1;
        if (o_mem_type   !== old_mem_type)   failed = 1'b1;

        if (o_reg_write  !== old_reg_write)  failed = 1'b1;
        if (o_wb_src     !== old_wb_src)     failed = 1'b1;
        if (o_illegal    !== old_illegal)    failed = 1'b1;

        if (failed) begin
            tests_failed++;
            $display("[FAIL] Stall freezes EX/MEM pipeline register");
        end
        else begin
            $display("[PASS] Stall freezes EX/MEM pipeline register");
        end

    endtask


    // ========================================================================
    // Flush
    // ========================================================================

    task automatic test_flush;

        bit failed;

        // Put side-effecting/illegal values in pipeline first.
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h1234_0000;

        i_mem_read    = 1'b1;
        i_mem_write   = 1'b1;
        i_reg_write   = 1'b1;
        i_illegal     = 1'b1;

        @(posedge i_clk);
        #1;

        // Flush next cycle.
        @(negedge i_clk);

        i_flush       = 1'b1;
        i_stall       = 1'b0;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid !== 1'b0) begin
            $error("Flush did not clear o_valid");
            failed = 1'b1;
        end

        if (o_mem_read !== 1'b0) begin
            $error("Flush did not clear o_mem_read");
            failed = 1'b1;
        end

        if (o_mem_write !== 1'b0) begin
            $error("Flush did not clear o_mem_write");
            failed = 1'b1;
        end

        if (o_reg_write !== 1'b0) begin
            $error("Flush did not clear o_reg_write");
            failed = 1'b1;
        end

        // A true NOP/bubble should not retain an illegal flag.
        if (o_illegal !== 1'b0) begin
            $error("Flush left stale o_illegal asserted");
            failed = 1'b1;
        end

        if (failed) begin
            tests_failed++;
            $display("[FAIL] Flush injects EX/MEM bubble");
        end
        else begin
            $display("[PASS] Flush injects EX/MEM bubble");
        end

    endtask


    // ========================================================================
    // Flush priority over stall
    // ========================================================================

    task automatic test_flush_over_stall;

        bit failed;

        // Put a write into pipeline.
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_reg_write   = 1'b1;
        i_mem_write   = 1'b1;

        @(posedge i_clk);
        #1;

        // Flush and stall simultaneously.
        @(negedge i_clk);

        i_flush = 1'b1;
        i_stall = 1'b1;

        @(posedge i_clk);
        #1;

        tests_run++;
        failed = 1'b0;

        if (o_valid     !== 1'b0) failed = 1'b1;
        if (o_mem_read  !== 1'b0) failed = 1'b1;
        if (o_mem_write !== 1'b0) failed = 1'b1;
        if (o_reg_write !== 1'b0) failed = 1'b1;

        if (failed) begin
            tests_failed++;
            $display("[FAIL] Flush priority over stall");
        end
        else begin
            $display("[PASS] Flush priority over stall");
        end

    endtask


    // ========================================================================
    // Main test sequence
    // ========================================================================

    initial begin

        tests_run    = 0;
        tests_failed = 0;

        i_rst = 1'b0;
        default_inputs();


        // --------------------------------------------------------------------
        // Reset / pipeline control
        // --------------------------------------------------------------------
        test_reset();


        // --------------------------------------------------------------------
        // ALU operations through execute stage
        // --------------------------------------------------------------------

        test_alu(
            "ADD",
            ARITH_ADD,
            32'h7FFF_FFFF,
            32'd1,
            32'h8000_0000
        );

        test_alu(
            "SUB",
            ARITH_SUB,
            32'd100,
            32'd37,
            32'd63
        );

        test_alu(
            "SLL",
            SHIFT_L_LOGIC,
            32'h0000_0003,
            32'd4,
            32'h0000_0030
        );

        test_alu(
            "SRL",
            SHIFT_R_LOGIC,
            32'h8000_0000,
            32'd4,
            32'h0800_0000
        );

        test_alu(
            "SRA",
            SHIFT_R_ARITH,
            32'h8000_0000,
            32'd4,
            32'hF800_0000
        );

        test_alu(
            "SLT signed true",
            SET_LESS_S,
            32'hFFFF_FFFF,     // -1
            32'h0000_0001,
            32'd1
        );

        test_alu(
            "SLT signed false",
            SET_LESS_S,
            32'h0000_0001,
            32'hFFFF_FFFF,     // -1
            32'd0
        );

        test_alu(
            "SLTU true",
            SET_LESS_U,
            32'd1,
            32'hFFFF_FFFF,
            32'd1
        );

        test_alu(
            "SLTU false",
            SET_LESS_U,
            32'hFFFF_FFFF,
            32'd1,
            32'd0
        );

        test_alu(
            "XOR",
            LOGIC_XOR,
            32'hF0F0_55AA,
            32'h0FF0_AA55,
            32'hFF00_FFFF
        );

        test_alu(
            "OR",
            LOGIC_OR,
            32'hF000_00F0,
            32'h0F00_0F00,
            32'hFF00_0FF0
        );

        test_alu(
            "AND",
            LOGIC_AND,
            32'hFFFF_00FF,
            32'h0F0F_F0F0,
            32'h0F0F_00F0
        );


        // --------------------------------------------------------------------
        // Operand selection
        // --------------------------------------------------------------------
        test_operand_selection();


        // --------------------------------------------------------------------
        // Forwarding network
        // --------------------------------------------------------------------
        test_forwarding();

        test_forwarding_with_operand_mux();

        test_store_forwarding();


        // --------------------------------------------------------------------
        // EX -> MEM control propagation
        // --------------------------------------------------------------------
        test_control_propagation();


        // --------------------------------------------------------------------
        // Every branch type - taken and not taken
        // --------------------------------------------------------------------

        test_branch(
            "BEQ taken",
            BEQ,
            32'h1234_5678,
            32'h1234_5678,
            1'b1
        );

        test_branch(
            "BEQ not taken",
            BEQ,
            32'd10,
            32'd11,
            1'b0
        );

        test_branch(
            "BNE taken",
            BNE,
            32'd10,
            32'd11,
            1'b1
        );

        test_branch(
            "BNE not taken",
            BNE,
            32'd55,
            32'd55,
            1'b0
        );


        // Signed: -1 < +1
        test_branch(
            "BLT signed taken",
            BLT,
            32'hFFFF_FFFF,
            32'h0000_0001,
            1'b1
        );

        // Signed: +1 < -1 = false
        test_branch(
            "BLT signed not taken",
            BLT,
            32'h0000_0001,
            32'hFFFF_FFFF,
            1'b0
        );


        // Signed: +1 >= -1
        test_branch(
            "BGE signed taken",
            BGE,
            32'h0000_0001,
            32'hFFFF_FFFF,
            1'b1
        );

        test_branch(
            "BGE signed not taken",
            BGE,
            32'hFFFF_FFFF,
            32'h0000_0001,
            1'b0
        );


        // Unsigned 1 < 0xFFFFFFFF
        test_branch(
            "BLTU taken",
            BLTU,
            32'h0000_0001,
            32'hFFFF_FFFF,
            1'b1
        );

        test_branch(
            "BLTU not taken",
            BLTU,
            32'hFFFF_FFFF,
            32'h0000_0001,
            1'b0
        );


        test_branch(
            "BGEU taken",
            BGEU,
            32'hFFFF_FFFF,
            32'h0000_0001,
            1'b1
        );

        test_branch(
            "BGEU not taken",
            BGEU,
            32'h0000_0001,
            32'hFFFF_FFFF,
            1'b0
        );


        // Equality boundary for >=
        test_branch(
            "BGE equality",
            BGE,
            32'h8000_0000,
            32'h8000_0000,
            1'b1
        );

        test_branch(
            "BGEU equality",
            BGEU,
            32'hFFFF_FFFF,
            32'hFFFF_FFFF,
            1'b1
        );


        // --------------------------------------------------------------------
        // Branch comparator forwarding
        // --------------------------------------------------------------------
        test_branch_forwarding();


        // --------------------------------------------------------------------
        // Jumps
        // --------------------------------------------------------------------
        test_jal();

        test_jalr();


        // --------------------------------------------------------------------
        // i_valid gating
        // --------------------------------------------------------------------
        test_invalid_redirect();


        // --------------------------------------------------------------------
        // Stall
        // --------------------------------------------------------------------
        test_stall();


        // --------------------------------------------------------------------
        // Flush
        // --------------------------------------------------------------------
        test_flush();


        // --------------------------------------------------------------------
        // Flush > stall
        // --------------------------------------------------------------------
        test_flush_over_stall();


        // --------------------------------------------------------------------
        // Final result
        // --------------------------------------------------------------------

        $display("");
        $display("====================================================");
        $display("EXECUTE TESTBENCH COMPLETE");
        $display("====================================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_run - tests_failed);
        $display("Tests failed : %0d", tests_failed);
        $display("====================================================");

        if (tests_failed == 0) begin
            $display("[PASS] ALL EXECUTE TESTS PASSED");
        end
        else begin
            $display("[FAIL] %0d TEST(S) FAILED", tests_failed);
        end

        $finish;

    end

endmodule