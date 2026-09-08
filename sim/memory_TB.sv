`timescale 1ns / 1ps

import common_pkg::*;

module memory_TB;

    localparam time CLK_PERIOD = 10ns;


    // ========================================================================
    // DUT inputs
    // ========================================================================

    logic           i_clk;
    logic           i_rst;

    logic           i_stall;
    logic           i_flush;

    logic           i_valid;
    logic [31:0]    i_pc;
    logic [4:0]     i_rd;
    logic [31:0]    i_alu_result;
    logic [31:0]    i_rs2_val;

    logic           i_mem_read;
    logic           i_mem_write;
    t_mem_types     i_mem_type;

    logic           i_reg_write;
    t_wb_src        i_wb_src;
    logic           i_illegal;
    logic [31:0]    i_dmem_rd_data;


    // ========================================================================
    // DUT outputs
    // ========================================================================

    logic           o_dmem_valid;
    logic [31:0]    o_dmem_addr;
    logic [31:0]    o_dmem_wr_data;
    logic           o_dmem_wr_en;
    logic [3:0]     o_dmem_byt_en;

    logic           o_wb_valid;
    logic [31:0]    o_wb_pc;
    logic [4:0]     o_wb_rd;
    logic [31:0]    o_wb_alu_res;
    logic [31:0]    o_wb_mem_data;
    logic           o_wb_wr_en;
    t_wb_src        o_wb_src;
    t_mem_types     o_wb_mem_type;
    logic           o_wb_illegal;


    // ========================================================================
    // DUT
    // ========================================================================

    memory dut (
        .i_clk          (i_clk),
        .i_rst          (i_rst),

        .i_stall        (i_stall),
        .i_flush        (i_flush),

        .i_valid        (i_valid),
        .i_pc           (i_pc),
        .i_rd           (i_rd),
        .i_alu_result   (i_alu_result),
        .i_rs2_val      (i_rs2_val),

        .i_mem_read     (i_mem_read),
        .i_mem_write    (i_mem_write),
        .i_mem_type     (i_mem_type),

        .i_reg_write    (i_reg_write),
        .i_wb_src       (i_wb_src),
        .i_illegal      (i_illegal),

        .o_dmem_valid   (o_dmem_valid),
        .o_dmem_addr    (o_dmem_addr),
        .o_dmem_wr_data (o_dmem_wr_data),
        .o_dmem_wr_en   (o_dmem_wr_en),
        .o_dmem_byt_en  (o_dmem_byt_en),
        .i_dmem_rd_data (i_dmem_rd_data),

        .o_wb_valid     (o_wb_valid),
        .o_wb_pc        (o_wb_pc),
        .o_wb_rd        (o_wb_rd),
        .o_wb_alu_res   (o_wb_alu_res),
        .o_wb_mem_data  (o_wb_mem_data),
        .o_wb_wr_en     (o_wb_wr_en),
        .o_wb_src       (o_wb_src),
        .o_wb_mem_type  (o_wb_mem_type),
        .o_wb_illegal   (o_wb_illegal)
    );


    // ========================================================================
    // Clock
    // ========================================================================

    initial begin
        i_clk = 1'b0;

        forever
            #(CLK_PERIOD / 2) i_clk = ~i_clk;
    end


    // ========================================================================
    // Test statistics
    // ========================================================================

    int tests_run;
    int tests_failed;


    // ========================================================================
    // Expected WB structure
    // ========================================================================

    typedef struct {
        logic           valid;
        logic [31:0]    pc;
        logic [4:0]     rd;
        logic [31:0]    alu_res;
        logic [31:0]    mem_data;

        logic           wr_en;
        t_wb_src        wb_src;
        t_mem_types     mem_type;
        logic           illegal;
    } expected_wb_t;


    // ========================================================================
    // Default inputs
    // ========================================================================

    task automatic default_inputs;

        i_rst           = 1'b0;

        i_stall         = 1'b0;
        i_flush         = 1'b0;

        i_valid         = 1'b0;
        i_pc            = 32'd0;
        i_rd            = 5'd0;

        i_alu_result    = 32'd0;
        i_rs2_val       = 32'd0;

        i_mem_read      = 1'b0;
        i_mem_write     = 1'b0;
        i_mem_type      = S_LOAD_BYTE;

        i_reg_write     = 1'b0;
        i_wb_src        = WR_ALU_RES;
        i_illegal       = 1'b0;
        i_dmem_rd_data  = 32'd0;

    endtask


    // ========================================================================
    // Default expected WB state
    // ========================================================================

    function automatic expected_wb_t make_expected_wb;

        expected_wb_t e;

        e.valid        = 1'b0;
        e.pc           = 32'd0;
        e.rd           = 5'd0;
        e.alu_res      = 32'd0;
        e.mem_data     = 32'd0;

        e.wr_en        = 1'b0;
        e.wb_src       = WR_ALU_RES;
        e.mem_type     = S_LOAD_BYTE;
        e.illegal      = 1'b0;

        return e;

    endfunction


    // ========================================================================
    // PASS / FAIL helper
    // ========================================================================

    task automatic report_result(
        input string test_name,
        input bit failed
    );

        tests_run++;

        if (failed) begin
            tests_failed++;
            $display("[FAIL] %s", test_name);
        end
        else begin
            $display("[PASS] %s", test_name);
        end

    endtask


    // ========================================================================
    // DMEM checker
    // ========================================================================

    task automatic check_dmem(
        input string       test_name,
        input logic [31:0] expected_addr,
        input logic [31:0] expected_data,
        input logic        expected_wr_en,
        input logic [3:0]  expected_byt_en
    );

        bit failed;

        failed = 1'b0;

        if (o_dmem_valid !== (
            i_valid &&
            !i_illegal &&
            (i_mem_read || i_mem_write) &&
            !i_flush &&
            !i_rst
        )) begin
            $error(
                "%s: o_dmem_valid unexpected value %b",
                test_name,
                o_dmem_valid
            );
            failed = 1'b1;
        end

        if (o_dmem_addr !== expected_addr) begin
            $error(
                "%s: o_dmem_addr expected=%h got=%h",
                test_name,
                expected_addr,
                o_dmem_addr
            );

            failed = 1'b1;
        end


        if (o_dmem_wr_data !== expected_data) begin
            $error(
                "%s: o_dmem_wr_data expected=%h got=%h",
                test_name,
                expected_data,
                o_dmem_wr_data
            );

            failed = 1'b1;
        end


        if (o_dmem_wr_en !== expected_wr_en) begin
            $error(
                "%s: o_dmem_wr_en expected=%b got=%b",
                test_name,
                expected_wr_en,
                o_dmem_wr_en
            );

            failed = 1'b1;
        end


        if (o_dmem_byt_en !== expected_byt_en) begin
            $error(
                "%s: o_dmem_byt_en expected=%b got=%b",
                test_name,
                expected_byt_en,
                o_dmem_byt_en
            );

            failed = 1'b1;
        end


        report_result(test_name, failed);

    endtask


    // ========================================================================
    // WB checker
    // ========================================================================

    task automatic check_wb(
        input string        test_name,
        input expected_wb_t e
    );

        bit failed;

        failed = 1'b0;


        if (o_wb_valid !== e.valid) begin
            $error(
                "%s: o_wb_valid expected=%b got=%b",
                test_name,
                e.valid,
                o_wb_valid
            );

            failed = 1'b1;
        end


        if (o_wb_pc !== e.pc) begin
            $error(
                "%s: o_wb_pc expected=%h got=%h",
                test_name,
                e.pc,
                o_wb_pc
            );

            failed = 1'b1;
        end


        if (o_wb_rd !== e.rd) begin
            $error(
                "%s: o_wb_rd expected=%0d got=%0d",
                test_name,
                e.rd,
                o_wb_rd
            );

            failed = 1'b1;
        end


        if (o_wb_alu_res !== e.alu_res) begin
            $error(
                "%s: o_wb_alu_res expected=%h got=%h",
                test_name,
                e.alu_res,
                o_wb_alu_res
            );

            failed = 1'b1;
        end

        if (o_wb_mem_data !== e.mem_data) begin
            $error(
                "%s: o_wb_mem_data expected=%h got=%h",
                test_name,
                e.mem_data,
                o_wb_mem_data
            );

            failed = 1'b1;
        end


        if (o_wb_wr_en !== e.wr_en) begin
            $error(
                "%s: o_wb_wr_en expected=%b got=%b",
                test_name,
                e.wr_en,
                o_wb_wr_en
            );

            failed = 1'b1;
        end


        if (o_wb_src !== e.wb_src) begin
            $error(
                "%s: o_wb_src expected=%0d got=%0d",
                test_name,
                e.wb_src,
                o_wb_src
            );

            failed = 1'b1;
        end


        if (o_wb_mem_type !== e.mem_type) begin
            $error(
                "%s: o_wb_mem_type expected=%0d got=%0d",
                test_name,
                e.mem_type,
                o_wb_mem_type
            );

            failed = 1'b1;
        end


        if (o_wb_illegal !== e.illegal) begin
            $error(
                "%s: o_wb_illegal expected=%b got=%b",
                test_name,
                e.illegal,
                o_wb_illegal
            );

            failed = 1'b1;
        end


        report_result(test_name, failed);

    endtask


    // ========================================================================
    // Reset
    // ========================================================================

    task automatic test_reset;

        bit failed;

        @(negedge i_clk);

        default_inputs();

        i_rst           = 1'b1;
        i_stall         = 1'b1;
        i_flush         = 1'b1;

        i_valid         = 1'b1;
        i_pc            = 32'hDEAD_BEEF;
        i_rd            = 5'd31;

        i_alu_result    = 32'h1234_5678;
        i_rs2_val       = 32'hCAFE_BABE;

        i_mem_write     = 1'b1;
        i_mem_type      = STORE_WORD;

        i_reg_write     = 1'b1;
        i_illegal       = 1'b0;
        i_dmem_rd_data  = 32'd0;


        #1;

        // Reset must prevent combinational memory write.
        check_dmem(
            "Reset suppresses DMEM write",
            32'h1234_5678,
            32'h0000_0000,
            1'b0,
            4'b0000
        );


        @(posedge i_clk);
        #1;


        failed = 1'b0;

        if (o_wb_valid !== 1'b0)
            failed = 1'b1;

        if (o_wb_pc !== 32'd0)
            failed = 1'b1;

        if (o_wb_rd !== 5'd0)
            failed = 1'b1;

        if (o_wb_alu_res !== 32'd0)
            failed = 1'b1;

        if (o_wb_wr_en !== 1'b0)
            failed = 1'b1;

        if (o_wb_illegal !== 1'b0)
            failed = 1'b1;

        if (o_wb_src !== WR_ALU_RES)
            failed = 1'b1;

        if (o_wb_mem_type !== S_LOAD_BYTE)
            failed = 1'b1;


        report_result(
            "Reset state / reset priority",
            failed
        );


        @(negedge i_clk);

        i_rst = 1'b0;

    endtask


    // ========================================================================
    // No-store combinational behavior
    // ========================================================================

    task automatic test_no_store;

        @(negedge i_clk);

        default_inputs();

        i_alu_result = 32'h1234_5678;
        i_rs2_val    = 32'hCAFE_BABE;

        #1;

        check_dmem(
            "No store -> DMEM write disabled",
            32'h1234_5678,
            32'h0000_0000,
            1'b0,
            4'b0000
        );

    endtask


    // ========================================================================
    // SB byte lanes
    // ========================================================================

    task automatic test_store_byte;

        logic [31:0] address;
        logic [31:0] data;

        data = 32'hA1B2_C3D4;


        for (int offset = 0; offset < 4; offset++) begin

            @(negedge i_clk);

            default_inputs();

            address = 32'h1000_0000 + offset;

            i_valid       = 1'b1;
            i_mem_write   = 1'b1;
            i_mem_type    = STORE_BYTE;

            i_alu_result  = address;
            i_rs2_val     = data;

            #1;


            // rs2[7:0] = D4 replicated into all BRAM lanes.
            check_dmem(
                $sformatf("STORE_BYTE offset %0d", offset),
                address,
                32'hD4D4_D4D4,
                1'b1,
                4'b0001 << offset
            );

        end

    endtask


    // ========================================================================
    // SH halfword lanes
    // ========================================================================

    task automatic test_store_half;

        // --------------------------------------------------------------------
        // Offset 0
        // --------------------------------------------------------------------

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_mem_write   = 1'b1;
        i_mem_type    = STORE_HALF;

        i_alu_result  = 32'h2000_0000;
        i_rs2_val     = 32'h1122_3344;

        #1;

        check_dmem(
            "STORE_HALF lower lanes",
            32'h2000_0000,
            32'h3344_3344,
            1'b1,
            4'b0011
        );


        // --------------------------------------------------------------------
        // Offset 2
        // --------------------------------------------------------------------

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_mem_write   = 1'b1;
        i_mem_type    = STORE_HALF;

        i_alu_result  = 32'h2000_0002;
        i_rs2_val     = 32'h5566_7788;

        #1;

        check_dmem(
            "STORE_HALF upper lanes",
            32'h2000_0002,
            32'h7788_7788,
            1'b1,
            4'b1100
        );

    endtask


    // ========================================================================
    // SW
    // ========================================================================

    task automatic test_store_word;

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_mem_write   = 1'b1;
        i_mem_type    = STORE_WORD;

        i_alu_result  = 32'h3000_0000;
        i_rs2_val     = 32'hDEAD_BEEF;

        #1;

        check_dmem(
            "STORE_WORD",
            32'h3000_0000,
            32'hDEAD_BEEF,
            1'b1,
            4'b1111
        );

    endtask


    // ========================================================================
    // Store gating
    // ========================================================================

    task automatic test_store_gating;

        // --------------------------------------------------------------------
        // Invalid
        // --------------------------------------------------------------------

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b0;
        i_mem_write   = 1'b1;
        i_mem_type    = STORE_WORD;

        i_alu_result  = 32'h4000_0000;
        i_rs2_val     = 32'h1111_1111;

        #1;

        check_dmem(
            "Invalid instruction cannot write memory",
            32'h4000_0000,
            32'h0000_0000,
            1'b0,
            4'b0000
        );


        // --------------------------------------------------------------------
        // Illegal
        // --------------------------------------------------------------------

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_illegal     = 1'b1;

        i_mem_write   = 1'b1;
        i_mem_type    = STORE_WORD;

        i_alu_result  = 32'h4000_0004;
        i_rs2_val     = 32'h2222_2222;

        #1;

        check_dmem(
            "Illegal instruction cannot write memory",
            32'h4000_0004,
            32'h0000_0000,
            1'b0,
            4'b0000
        );


        // --------------------------------------------------------------------
        // mem_write = 0
        // --------------------------------------------------------------------

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;

        i_mem_write   = 1'b0;
        i_mem_type    = STORE_WORD;

        i_alu_result  = 32'h4000_0008;
        i_rs2_val     = 32'h3333_3333;

        #1;

        check_dmem(
            "mem_write=0 cannot write memory",
            32'h4000_0008,
            32'h0000_0000,
            1'b0,
            4'b0000
        );


        // --------------------------------------------------------------------
        // Stall
        // --------------------------------------------------------------------

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_stall       = 1'b1;

        i_mem_write   = 1'b1;
        i_mem_type    = STORE_WORD;

        i_alu_result  = 32'h4000_000C;
        i_rs2_val     = 32'h4444_4444;

        #1;

        check_dmem(
            "Stall preserves active DMEM store request",
            32'h4000_000C,
            32'h4444_4444,
            1'b1,
            4'b1111
        );


        // --------------------------------------------------------------------
        // Flush
        // --------------------------------------------------------------------

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_flush       = 1'b1;

        i_mem_write   = 1'b1;
        i_mem_type    = STORE_WORD;

        i_alu_result  = 32'h4000_0010;
        i_rs2_val     = 32'h5555_5555;

        #1;

        check_dmem(
            "Flush suppresses DMEM write",
            32'h4000_0010,
            32'h0000_0000,
            1'b0,
            4'b0000
        );

    endtask


    // ========================================================================
    // Basic WB propagation
    // ========================================================================

    task automatic test_wb_propagation;

        expected_wb_t e;

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;

        i_pc          = 32'h0000_1000;
        i_rd          = 5'd17;

        i_alu_result  = 32'h1234_ABCD;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_ALU_RES;
        i_mem_type    = S_LOAD_BYTE;

        @(posedge i_clk);
        #1;


        e = make_expected_wb();

        e.valid       = 1'b1;
        e.pc          = 32'h0000_1000;
        e.rd          = 5'd17;
        e.alu_res     = 32'h1234_ABCD;

        e.wr_en       = 1'b1;
        e.wb_src      = WR_ALU_RES;
        e.mem_type    = S_LOAD_BYTE;


        check_wb(
            "Basic MEM -> WB propagation",
            e
        );

    endtask


    // ========================================================================
    // WB sources
    // ========================================================================

    task automatic test_wb_sources;

        expected_wb_t e;


        // ALU
        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h2000;
        i_rd          = 5'd1;
        i_alu_result  = 32'hAAAA_AAAA;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_ALU_RES;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b1;
        e.pc          = 32'h2000;
        e.rd          = 5'd1;
        e.alu_res     = 32'hAAAA_AAAA;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_ALU_RES;

        check_wb("WB source ALU", e);


        // Memory
        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h2004;
        i_rd          = 5'd2;
        i_alu_result  = 32'hBBBB_BBBB;

        i_mem_read    = 1'b1;
        i_mem_type    = S_LOAD_WORD;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b1;
        e.pc          = 32'h2004;
        e.rd          = 5'd2;
        e.alu_res     = 32'hBBBB_BBBB;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_READ_RES;
        e.mem_type    = S_LOAD_WORD;

        check_wb("WB source memory", e);


        // PC + 4
        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h2008;
        i_rd          = 5'd3;
        i_alu_result  = 32'hCCCC_CCCC;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_PC_PLUS_4;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b1;
        e.pc          = 32'h2008;
        e.rd          = 5'd3;
        e.alu_res     = 32'hCCCC_CCCC;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_PC_PLUS_4;

        check_wb("WB source PC+4", e);

    endtask


    // ========================================================================
    // Load type propagation
    // ========================================================================

    task automatic test_load_types;

        expected_wb_t e;


        // LB
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_mem_read    = 1'b1;
        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;
        i_mem_type    = S_LOAD_BYTE;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();
        e.valid       = 1'b1;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_READ_RES;
        e.mem_type    = S_LOAD_BYTE;

        check_wb("Load type LB", e);


        // LBU
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_mem_read    = 1'b1;
        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;
        i_mem_type    = U_LOAD_BYTE;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();
        e.valid       = 1'b1;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_READ_RES;
        e.mem_type    = U_LOAD_BYTE;

        check_wb("Load type LBU", e);


        // LH
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_mem_read    = 1'b1;
        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;
        i_mem_type    = S_LOAD_HALF;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();
        e.valid       = 1'b1;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_READ_RES;
        e.mem_type    = S_LOAD_HALF;

        check_wb("Load type LH", e);


        // LHU
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_mem_read    = 1'b1;
        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;
        i_mem_type    = U_LOAD_HALF;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();
        e.valid       = 1'b1;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_READ_RES;
        e.mem_type    = U_LOAD_HALF;

        check_wb("Load type LHU", e);


        // LW
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_mem_read    = 1'b1;
        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;
        i_mem_type    = S_LOAD_WORD;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();
        e.valid       = 1'b1;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_READ_RES;
        e.mem_type    = S_LOAD_WORD;

        check_wb("Load type LW", e);

    endtask


    // ========================================================================
    // WB write-enable gating
    // ========================================================================

    task automatic test_wb_gating;

        expected_wb_t e;


        // reg_write = 0
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_reg_write   = 1'b0;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b1;
        e.wr_en       = 1'b0;

        check_wb("WB reg_write=0", e);


        // Invalid
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b0;
        i_reg_write   = 1'b1;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b0;
        e.wr_en       = 1'b0;

        check_wb("Invalid instruction cannot write register", e);


        // Illegal
        @(negedge i_clk);
        default_inputs();

        i_valid       = 1'b1;
        i_reg_write   = 1'b1;
        i_illegal     = 1'b1;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b1;
        e.wr_en       = 1'b0;
        e.illegal     = 1'b1;

        check_wb("Illegal instruction cannot write register", e);

    endtask


    // ========================================================================
    // Store still propagates as a valid instruction, but does not write RF
    // ========================================================================

    task automatic test_store_wb_behavior;

        expected_wb_t e;

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h5000;

        i_mem_write   = 1'b1;
        i_mem_type    = STORE_WORD;

        i_alu_result  = 32'h1000_0000;
        i_rs2_val     = 32'hDEAD_BEEF;

        i_reg_write   = 1'b0;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b1;
        e.pc          = 32'h5000;
        e.alu_res     = 32'h1000_0000;

        e.wr_en       = 1'b0;
        e.mem_type    = STORE_WORD;

        check_wb(
            "Store propagates without register write",
            e
        );

    endtask


    // ========================================================================
    // Back-to-back traffic
    // ========================================================================

    task automatic test_back_to_back;

        expected_wb_t e;


        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h6000;
        i_rd          = 5'd20;
        i_alu_result  = 32'hAAAA_0001;
        i_reg_write   = 1'b1;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b1;
        e.pc          = 32'h6000;
        e.rd          = 5'd20;
        e.alu_res     = 32'hAAAA_0001;
        e.wr_en       = 1'b1;

        check_wb("Back-to-back instruction 1", e);


        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h6004;
        i_rd          = 5'd21;
        i_alu_result  = 32'hBBBB_0002;
        i_reg_write   = 1'b1;
        i_wb_src      = WR_PC_PLUS_4;

        @(posedge i_clk);
        #1;

        e = make_expected_wb();

        e.valid       = 1'b1;
        e.pc          = 32'h6004;
        e.rd          = 5'd21;
        e.alu_res     = 32'hBBBB_0002;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_PC_PLUS_4;

        check_wb("Back-to-back instruction 2", e);

    endtask


    // ========================================================================
    // Stall
    // ========================================================================

    task automatic test_stall;

        expected_wb_t e;

        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h7000;
        i_rd          = 5'd22;
        i_alu_result  = 32'h1234_5678;

        i_reg_write   = 1'b1;
        i_wb_src      = WR_READ_RES;
        i_mem_type    = S_LOAD_WORD;

        @(posedge i_clk);
        #1;


        e = make_expected_wb();

        e.valid       = 1'b1;
        e.pc          = 32'h7000;
        e.rd          = 5'd22;
        e.alu_res     = 32'h1234_5678;
        e.wr_en       = 1'b1;
        e.wb_src      = WR_READ_RES;
        e.mem_type    = S_LOAD_WORD;


        @(negedge i_clk);

        default_inputs();

        i_stall       = 1'b1;

        i_valid       = 1'b1;
        i_pc          = 32'hDEAD_BEEF;
        i_rd          = 5'd31;
        i_alu_result  = 32'hFFFF_FFFF;

        i_reg_write   = 1'b0;
        i_wb_src      = WR_PC_PLUS_4;
        i_illegal     = 1'b1;


        @(posedge i_clk);
        #1;


        check_wb(
            "Stall freezes MEM/WB pipeline register",
            e
        );

    endtask


    // ========================================================================
    // Flush
    // ========================================================================

    task automatic test_flush;

        expected_wb_t e;


        // First put something active into WB.
        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h8000;
        i_rd          = 5'd25;

        i_reg_write   = 1'b1;

        @(posedge i_clk);
        #1;


        // Flush next cycle.
        @(negedge i_clk);

        default_inputs();

        i_flush       = 1'b1;


        @(posedge i_clk);
        #1;


        e = make_expected_wb();

        check_wb(
            "Flush injects MEM/WB bubble",
            e
        );

    endtask


    // ========================================================================
    // Flush priority over stall
    // ========================================================================

    task automatic test_flush_over_stall;

        expected_wb_t e;


        // Put an active instruction in WB.
        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_pc          = 32'h9000;
        i_rd          = 5'd26;
        i_reg_write   = 1'b1;

        @(posedge i_clk);
        #1;


        // Both asserted.
        @(negedge i_clk);

        default_inputs();

        i_flush       = 1'b1;
        i_stall       = 1'b1;


        @(posedge i_clk);
        #1;


        e = make_expected_wb();

        check_wb(
            "Flush priority over stall",
            e
        );

    endtask


    // ========================================================================
    // Reset priority
    // ========================================================================

    task automatic test_reset_priority;

        expected_wb_t e;


        // Load active state.
        @(negedge i_clk);

        default_inputs();

        i_valid       = 1'b1;
        i_reg_write   = 1'b1;

        @(posedge i_clk);
        #1;


        // Reset + flush + stall.
        @(negedge i_clk);

        default_inputs();

        i_rst         = 1'b1;
        i_flush       = 1'b1;
        i_stall       = 1'b1;


        @(posedge i_clk);
        #1;


        e = make_expected_wb();

        check_wb(
            "Reset priority over flush/stall",
            e
        );


        @(negedge i_clk);

        i_rst = 1'b0;

    endtask


    // ========================================================================
    // Main
    // ========================================================================


    task automatic test_load_data_capture;

        expected_wb_t e;

        @(negedge i_clk);

        default_inputs();

        i_valid        = 1'b1;
        i_pc           = 32'h0000_A000;
        i_rd           = 5'd19;
        i_alu_result   = 32'h0000_0102;
        i_mem_read     = 1'b1;
        i_mem_type     = U_LOAD_BYTE;
        i_reg_write    = 1'b1;
        i_wb_src       = WR_READ_RES;
        i_dmem_rd_data = 32'hA1B2_C3D4;

        #1;

        check_dmem(
            "Load asserts cache request",
            32'h0000_0102,
            32'd0,
            1'b0,
            4'b0000
        );

        @(posedge i_clk);
        #1;

        e = make_expected_wb();
        e.valid    = 1'b1;
        e.pc       = 32'h0000_A000;
        e.rd       = 5'd19;
        e.alu_res  = 32'h0000_0102;
        e.mem_data = 32'hA1B2_C3D4;
        e.wr_en    = 1'b1;
        e.wb_src   = WR_READ_RES;
        e.mem_type = U_LOAD_BYTE;

        check_wb(
            "Load data captured into MEM/WB",
            e
        );

    endtask

    initial begin

        tests_run    = 0;
        tests_failed = 0;

        default_inputs();


        // --------------------------------------------------------------------
        // Reset
        // --------------------------------------------------------------------

        test_reset();


        // --------------------------------------------------------------------
        // BRAM write interface
        // --------------------------------------------------------------------

        test_no_store();

        test_store_byte();

        test_store_half();

        test_store_word();

        test_store_gating();


        // --------------------------------------------------------------------
        // MEM -> WB path
        // --------------------------------------------------------------------

        test_wb_propagation();

        test_wb_sources();

        test_load_types();
        test_load_data_capture();

        test_wb_gating();

        test_store_wb_behavior();

        test_back_to_back();


        // --------------------------------------------------------------------
        // Pipeline control
        // --------------------------------------------------------------------

        test_stall();

        test_flush();

        test_flush_over_stall();

        test_reset_priority();


        // --------------------------------------------------------------------
        // Results
        // --------------------------------------------------------------------

        $display("");
        $display("====================================================");
        $display("MEMORY TESTBENCH COMPLETE");
        $display("====================================================");

        $display(
            "Tests run    : %0d",
            tests_run
        );

        $display(
            "Tests passed : %0d",
            tests_run - tests_failed
        );

        $display(
            "Tests failed : %0d",
            tests_failed
        );

        $display("====================================================");


        if (tests_failed == 0)
            $display("[PASS] ALL MEMORY TESTS PASSED");
        else
            $display(
                "[FAIL] %0d TEST(S) FAILED",
                tests_failed
            );


        $finish;

    end


endmodule
