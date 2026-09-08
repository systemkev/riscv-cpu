`timescale 1ns/1ps

import common_pkg::*;

module writeback_TB;

    // =========================================================================
    // DUT Inputs
    // =========================================================================

    logic           i_stall;
    logic           i_wb_valid;
    logic [31:0]    i_wb_pc;
    logic [4:0]     i_wb_rd;
    logic [31:0]    i_wb_alu_res;
    logic           i_wb_wr_en;
    t_wb_src        i_wb_src;
    t_mem_types     i_wb_mem_type;
    logic           i_wb_illegal;

    logic [31:0]    i_wb_mem_data;

    // =========================================================================
    // DUT Outputs
    // =========================================================================

    logic           o_rf_wr_en;
    logic [4:0]     o_rf_rd_addr;
    logic [31:0]    o_rf_wr_data;

    // =========================================================================
    // Testbench bookkeeping
    // =========================================================================

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // =========================================================================
    // DUT
    // =========================================================================

    writeback dut (
        .i_stall        (i_stall),
        .i_wb_valid     (i_wb_valid),
        .i_wb_pc        (i_wb_pc),
        .i_wb_rd        (i_wb_rd),
        .i_wb_alu_res   (i_wb_alu_res),
        .i_wb_wr_en     (i_wb_wr_en),
        .i_wb_src       (i_wb_src),
        .i_wb_mem_type  (i_wb_mem_type),
        .i_wb_illegal   (i_wb_illegal),

        .i_wb_mem_data    (i_wb_mem_data),

        .o_rf_wr_en     (o_rf_wr_en),
        .o_rf_rd_addr   (o_rf_rd_addr),
        .o_rf_wr_data   (o_rf_wr_data)
    );

    // =========================================================================
    // Utility functions
    // =========================================================================

    function automatic logic [7:0] expected_byte (
        input logic [31:0] data,
        input logic [1:0]  offset
    );
        case (offset)
            2'b00: expected_byte = data[7:0];
            2'b01: expected_byte = data[15:8];
            2'b10: expected_byte = data[23:16];
            2'b11: expected_byte = data[31:24];
        endcase
    endfunction


    function automatic logic [15:0] expected_half (
        input logic [31:0] data,
        input logic        offset_bit1
    );
        case (offset_bit1)
            1'b0: expected_half = data[15:0];
            1'b1: expected_half = data[31:16];
        endcase
    endfunction


    function automatic logic [31:0] expected_mem_data (
        input logic [31:0] data,
        input logic [1:0]  offset,
        input t_mem_types  mem_type
    );

        logic [7:0]  byte_val;
        logic [15:0] half_val;

        begin
            byte_val = expected_byte(data, offset);
            half_val = expected_half(data, offset[1]);

            case (mem_type)

                S_LOAD_BYTE:
                    expected_mem_data =
                        {{24{byte_val[7]}}, byte_val};

                U_LOAD_BYTE:
                    expected_mem_data =
                        {24'b0, byte_val};

                S_LOAD_HALF:
                    expected_mem_data =
                        {{16{half_val[15]}}, half_val};

                U_LOAD_HALF:
                    expected_mem_data =
                        {16'b0, half_val};

                S_LOAD_WORD:
                    expected_mem_data = data;

                default:
                    expected_mem_data = data;

            endcase
        end
    endfunction


    // =========================================================================
    // Checker
    // =========================================================================

    task automatic check_outputs (
        input string       test_name,
        input logic        expected_wr_en,
        input logic [4:0]  expected_rd,
        input logic [31:0] expected_data
    );

        test_count++;

        #1;

        if ((o_rf_wr_en   === expected_wr_en) &&
            (o_rf_rd_addr === expected_rd)    &&
            (o_rf_wr_data === expected_data)) begin

            pass_count++;

            $display(
                "[PASS] %s",
                test_name
            );

        end
        else begin

            fail_count++;

            $display(
                "[FAIL] %s", test_name
            );

            $display(
                "       o_rf_wr_en:   expected=%b actual=%b",
                expected_wr_en,
                o_rf_wr_en
            );

            $display(
                "       o_rf_rd_addr: expected=%0d actual=%0d",
                expected_rd,
                o_rf_rd_addr
            );

            $display(
                "       o_rf_wr_data: expected=%08h actual=%08h",
                expected_data,
                o_rf_wr_data
            );

        end
    endtask


    // =========================================================================
    // General stimulus helper
    // =========================================================================

    task automatic drive_and_check (
        input string       test_name,

        input logic        wb_valid,
        input logic [31:0] wb_pc,
        input logic [4:0]  wb_rd,
        input logic [31:0] wb_alu_res,
        input logic        wb_wr_en,
        input t_wb_src     wb_src,
        input t_mem_types  wb_mem_type,
        input logic        wb_illegal,
        input logic [31:0] dmem_data,

        input logic [31:0] expected_data
    );

        begin

            i_wb_valid    = wb_valid;
            i_wb_pc       = wb_pc;
            i_wb_rd       = wb_rd;
            i_wb_alu_res  = wb_alu_res;
            i_wb_wr_en    = wb_wr_en;
            i_wb_src      = wb_src;
            i_wb_mem_type = wb_mem_type;
            i_wb_illegal  = wb_illegal;
            i_wb_mem_data   = dmem_data;

            check_outputs(
                test_name,
                wb_valid && wb_wr_en && !wb_illegal && !i_stall,
                wb_rd,
                expected_data
            );

        end
    endtask


    // =========================================================================
    // Test: ALU writeback
    // =========================================================================

    task automatic test_alu_writeback;

        $display("\n--- ALU writeback tests ---");

        drive_and_check(
            "ALU result = zero",
            1'b1,
            32'h1000_0000,
            5'd1,
            32'h0000_0000,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'hDEAD_BEEF,
            32'h0000_0000
        );

        drive_and_check(
            "ALU result = all ones",
            1'b1,
            32'h1000_0000,
            5'd31,
            32'hFFFF_FFFF,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'h1234_5678,
            32'hFFFF_FFFF
        );

        drive_and_check(
            "ALU arbitrary result",
            1'b1,
            32'h1234_5678,
            5'd17,
            32'hA5A5_5A5A,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'hCAFE_BABE,
            32'hA5A5_5A5A
        );

    endtask


    // =========================================================================
    // Test: PC + 4 writeback
    // =========================================================================

    task automatic test_pc_plus_4;

        $display("\n--- PC+4 writeback tests ---");

        drive_and_check(
            "PC+4 normal",
            1'b1,
            32'h0000_1000,
            5'd1,
            32'hDEAD_BEEF,
            1'b1,
            WR_PC_PLUS_4,
            S_LOAD_WORD,
            1'b0,
            32'h1111_2222,
            32'h0000_1004
        );

        drive_and_check(
            "PC+4 near upper address range",
            1'b1,
            32'hFFFF_FFF8,
            5'd2,
            32'h0000_0000,
            1'b1,
            WR_PC_PLUS_4,
            S_LOAD_WORD,
            1'b0,
            32'h0000_0000,
            32'hFFFF_FFFC
        );

        drive_and_check(
            "PC+4 wraps around",
            1'b1,
            32'hFFFF_FFFC,
            5'd3,
            32'h0000_0000,
            1'b1,
            WR_PC_PLUS_4,
            S_LOAD_WORD,
            1'b0,
            32'h0000_0000,
            32'h0000_0000
        );

    endtask


    // =========================================================================
    // Test: signed byte loads
    // =========================================================================

    task automatic test_signed_byte_loads;

        logic [31:0] data;

        $display("\n--- Signed byte load tests ---");

        /*
         * Byte lanes:
         *
         * [31:24] = 8'h80  -> negative
         * [23:16] = 8'h7F  -> positive
         * [15:8]  = 8'hFF  -> negative
         * [7:0]   = 8'h01  -> positive
         */

        data = 32'h807F_FF01;

        drive_and_check(
            "LB offset 0 positive",
            1'b1,
            32'h0,
            5'd10,
            32'h0000_0000,
            1'b1,
            WR_READ_RES,
            S_LOAD_BYTE,
            1'b0,
            data,
            32'h0000_0001
        );

        // ALU low bits select byte lane 1.
        drive_and_check(
            "LB offset 1 negative",
            1'b1,
            32'h0,
            5'd10,
            32'h0000_0001,
            1'b1,
            WR_READ_RES,
            S_LOAD_BYTE,
            1'b0,
            data,
            32'hFFFF_FFFF
        );

        drive_and_check(
            "LB offset 2 positive",
            1'b1,
            32'h0,
            5'd10,
            32'h0000_0002,
            1'b1,
            WR_READ_RES,
            S_LOAD_BYTE,
            1'b0,
            data,
            32'h0000_007F
        );

        drive_and_check(
            "LB offset 3 negative",
            1'b1,
            32'h0,
            5'd10,
            32'h0000_0003,
            1'b1,
            WR_READ_RES,
            S_LOAD_BYTE,
            1'b0,
            data,
            32'hFFFF_FF80
        );

    endtask


    // =========================================================================
    // Test: unsigned byte loads
    // =========================================================================

    task automatic test_unsigned_byte_loads;

        logic [31:0] data;

        $display("\n--- Unsigned byte load tests ---");

        data = 32'h80FF_7F01;

        for (int offset = 0; offset < 4; offset++) begin

            drive_and_check(
                $sformatf("LBU byte offset %0d", offset),
                1'b1,
                32'h1000,
                5'd12,
                offset,
                1'b1,
                WR_READ_RES,
                U_LOAD_BYTE,
                1'b0,
                data,
                expected_mem_data(
                    data,
                    offset[1:0],
                    U_LOAD_BYTE
                )
            );

        end

    endtask


    // =========================================================================
    // Test: signed halfword loads
    // =========================================================================

    task automatic test_signed_half_loads;

        logic [31:0] data;

        $display("\n--- Signed halfword load tests ---");

        /*
         * Upper half = 16'h8001 -> negative
         * Lower half = 16'h7FFF -> positive
         */

        data = 32'h8001_7FFF;

        drive_and_check(
            "LH lower half positive offset 0",
            1'b1,
            32'h0,
            5'd13,
            32'h0000_0000,
            1'b1,
            WR_READ_RES,
            S_LOAD_HALF,
            1'b0,
            data,
            32'h0000_7FFF
        );

        drive_and_check(
            "LH upper half negative offset 2",
            1'b1,
            32'h0,
            5'd13,
            32'h0000_0002,
            1'b1,
            WR_READ_RES,
            S_LOAD_HALF,
            1'b0,
            data,
            32'hFFFF_8001
        );

    endtask


    // =========================================================================
    // Test: unsigned halfword loads
    // =========================================================================

    task automatic test_unsigned_half_loads;

        logic [31:0] data;

        $display("\n--- Unsigned halfword load tests ---");

        data = 32'hFFFF_8000;

        drive_and_check(
            "LHU lower half",
            1'b1,
            32'h0,
            5'd14,
            32'h0000_0000,
            1'b1,
            WR_READ_RES,
            U_LOAD_HALF,
            1'b0,
            data,
            32'h0000_8000
        );

        drive_and_check(
            "LHU upper half",
            1'b1,
            32'h0,
            5'd14,
            32'h0000_0002,
            1'b1,
            WR_READ_RES,
            U_LOAD_HALF,
            1'b0,
            data,
            32'h0000_FFFF
        );

    endtask


    // =========================================================================
    // Test: word loads
    // =========================================================================

    task automatic test_word_loads;

        $display("\n--- Word load tests ---");

        drive_and_check(
            "LW arbitrary value",
            1'b1,
            32'h0,
            5'd15,
            32'h0000_0000,
            1'b1,
            WR_READ_RES,
            S_LOAD_WORD,
            1'b0,
            32'h1234_ABCD,
            32'h1234_ABCD
        );

        drive_and_check(
            "LW all zeros",
            1'b1,
            32'h0,
            5'd15,
            32'h0000_0000,
            1'b1,
            WR_READ_RES,
            S_LOAD_WORD,
            1'b0,
            32'h0000_0000,
            32'h0000_0000
        );

        drive_and_check(
            "LW all ones",
            1'b1,
            32'h0,
            5'd15,
            32'h0000_0000,
            1'b1,
            WR_READ_RES,
            S_LOAD_WORD,
            1'b0,
            32'hFFFF_FFFF,
            32'hFFFF_FFFF
        );

    endtask


    // =========================================================================
    // Test: halfword offset behavior
    //
    // The current RTL uses only i_wb_alu_res[1] for halfword selection.
    // Therefore offsets 0/1 select the lower half and 2/3 select upper half.
    //
    // This tests the RTL exactly as written.
    // =========================================================================

    task automatic test_halfword_all_offsets;

        logic [31:0] data;

        $display("\n--- Halfword offset selection tests ---");

        data = 32'hABCD_1234;

        for (int offset = 0; offset < 4; offset++) begin

            drive_and_check(
                $sformatf(
                    "Halfword selection offset %0d",
                    offset
                ),
                1'b1,
                32'h0,
                5'd8,
                offset,
                1'b1,
                WR_READ_RES,
                U_LOAD_HALF,
                1'b0,
                data,
                expected_mem_data(
                    data,
                    offset[1:0],
                    U_LOAD_HALF
                )
            );

        end

    endtask


    // =========================================================================
    // Test: register-file control passthrough
    // =========================================================================

    task automatic test_control_passthrough;

        $display("\n--- Register file control tests ---");

        drive_and_check(
            "Write enable asserted",
            1'b1,
            32'h0,
            5'd20,
            32'h1234_5678,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'h0,
            32'h1234_5678
        );

        drive_and_check(
            "Write enable deasserted",
            1'b1,
            32'h0,
            5'd21,
            32'hAAAA_BBBB,
            1'b0,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'h0,
            32'hAAAA_BBBB
        );

        // rd = x0 is forwarded by this module.
        // Suppression of writes to x0 is assumed to occur elsewhere.
        drive_and_check(
            "Destination register x0",
            1'b1,
            32'h0,
            5'd0,
            32'hCAFE_BABE,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'h0,
            32'hCAFE_BABE
        );

        drive_and_check(
            "Destination register x31",
            1'b1,
            32'h0,
            5'd31,
            32'h1234_5678,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'h0,
            32'h1234_5678
        );

    endtask


    // =========================================================================
    // Test: valid / illegal gating
    //
    // IMPORTANT:
    // i_wb_valid and i_wb_illegal are not referenced anywhere by the current DUT.
    // Therefore o_rf_wr_en must still exactly equal i_wb_wr_en.
    //
    // If you later change the RTL so invalid/illegal instructions suppress
    // writes, these tests should be changed accordingly.
    // =========================================================================

    task automatic test_valid_illegal_gating;

        $display("\n--- valid / illegal input behavior tests ---");

        drive_and_check(
            "Valid=0 suppresses write",
            1'b0,
            32'h1000,
            5'd5,
            32'h1111_2222,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'h0,
            32'h1111_2222
        );

        drive_and_check(
            "Illegal=1 suppresses write",
            1'b1,
            32'h1000,
            5'd6,
            32'h3333_4444,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b1,
            32'h0,
            32'h3333_4444
        );

        drive_and_check(
            "Valid=0 illegal=1 suppresses write",
            1'b0,
            32'h1000,
            5'd7,
            32'h5555_6666,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b1,
            32'h0,
            32'h5555_6666
        );

    endtask


    // =========================================================================
    // Test: source mux isolation
    //
    // Verify changing unrelated inputs does not affect selected writeback data.
    // =========================================================================

    task automatic test_mux_isolation;

        $display("\n--- Writeback mux isolation tests ---");

        // ALU selected: PC and DMEM should be irrelevant.
        drive_and_check(
            "ALU source ignores PC and memory",
            1'b1,
            32'hDEAD_BEEF,
            5'd1,
            32'h1122_3344,
            1'b1,
            WR_ALU_RES,
            S_LOAD_BYTE,
            1'b0,
            32'hFFFF_FFFF,
            32'h1122_3344
        );

        // Memory selected: PC should be irrelevant.
        drive_and_check(
            "Memory source ignores PC",
            1'b1,
            32'hCAFE_BABE,
            5'd2,
            32'h0000_0002,
            1'b1,
            WR_READ_RES,
            U_LOAD_BYTE,
            1'b0,
            32'hAABB_CCDD,
            32'h0000_00BB
        );

        // PC+4 selected: ALU result other than PC should not contribute,
        // except that i_wb_alu_res is completely ignored by this mux branch.
        drive_and_check(
            "PC+4 source ignores ALU/memory data",
            1'b1,
            32'h0000_0200,
            5'd3,
            32'hFFFF_FFFF,
            1'b1,
            WR_PC_PLUS_4,
            S_LOAD_BYTE,
            1'b0,
            32'hDEAD_BEEF,
            32'h0000_0204
        );

    endtask


    // =========================================================================
    // Randomized ALU tests
    // =========================================================================

    task automatic test_random_alu;

        logic [31:0] rand_alu;
        logic [31:0] rand_pc;
        logic [31:0] rand_mem;
        logic [4:0]  rand_rd;
        logic        rand_en;

        $display("\n--- Randomized ALU tests ---");

        for (int i = 0; i < 100; i++) begin

            rand_alu = $urandom;
            rand_pc  = $urandom;
            rand_mem = $urandom;
            rand_rd  = $urandom_range(0, 31);
            rand_en  = $urandom_range(0, 1);

            drive_and_check(
                $sformatf("Random ALU test %0d", i),
                $urandom_range(0, 1),
                rand_pc,
                rand_rd,
                rand_alu,
                rand_en,
                WR_ALU_RES,
                S_LOAD_WORD,
                $urandom_range(0, 1),
                rand_mem,
                rand_alu
            );

        end

    endtask


    // =========================================================================
    // Randomized PC+4 tests
    // =========================================================================

    task automatic test_random_pc;

        logic [31:0] rand_pc;
        logic [4:0]  rand_rd;

        $display("\n--- Randomized PC+4 tests ---");

        for (int i = 0; i < 100; i++) begin

            rand_pc = $urandom;
            rand_rd = $urandom_range(0, 31);

            drive_and_check(
                $sformatf("Random PC+4 test %0d", i),
                1'b1,
                rand_pc,
                rand_rd,
                $urandom,
                $urandom_range(0, 1),
                WR_PC_PLUS_4,
                S_LOAD_WORD,
                1'b0,
                $urandom,
                rand_pc + 32'd4
            );

        end

    endtask


    // =========================================================================
    // Randomized load tests
    // =========================================================================

    task automatic test_random_loads;

        logic [31:0] rand_mem;
        logic [31:0] rand_addr;
        logic [4:0]  rand_rd;

        $display("\n--- Randomized load tests ---");

        // ---------------------------------------------------------------------
        // Random signed byte
        // ---------------------------------------------------------------------

        for (int i = 0; i < 50; i++) begin

            rand_mem  = $urandom;
            rand_addr = $urandom;
            rand_rd   = $urandom_range(0, 31);

            drive_and_check(
                $sformatf("Random LB test %0d", i),
                1'b1,
                $urandom,
                rand_rd,
                rand_addr,
                1'b1,
                WR_READ_RES,
                S_LOAD_BYTE,
                1'b0,
                rand_mem,
                expected_mem_data(
                    rand_mem,
                    rand_addr[1:0],
                    S_LOAD_BYTE
                )
            );

        end

        // ---------------------------------------------------------------------
        // Random unsigned byte
        // ---------------------------------------------------------------------

        for (int i = 0; i < 50; i++) begin

            rand_mem  = $urandom;
            rand_addr = $urandom;
            rand_rd   = $urandom_range(0, 31);

            drive_and_check(
                $sformatf("Random LBU test %0d", i),
                1'b1,
                $urandom,
                rand_rd,
                rand_addr,
                1'b1,
                WR_READ_RES,
                U_LOAD_BYTE,
                1'b0,
                rand_mem,
                expected_mem_data(
                    rand_mem,
                    rand_addr[1:0],
                    U_LOAD_BYTE
                )
            );

        end

        // ---------------------------------------------------------------------
        // Random signed halfword
        // ---------------------------------------------------------------------

        for (int i = 0; i < 50; i++) begin

            rand_mem  = $urandom;
            rand_addr = $urandom;
            rand_rd   = $urandom_range(0, 31);

            drive_and_check(
                $sformatf("Random LH test %0d", i),
                1'b1,
                $urandom,
                rand_rd,
                rand_addr,
                1'b1,
                WR_READ_RES,
                S_LOAD_HALF,
                1'b0,
                rand_mem,
                expected_mem_data(
                    rand_mem,
                    rand_addr[1:0],
                    S_LOAD_HALF
                )
            );

        end

        // ---------------------------------------------------------------------
        // Random unsigned halfword
        // ---------------------------------------------------------------------

        for (int i = 0; i < 50; i++) begin

            rand_mem  = $urandom;
            rand_addr = $urandom;
            rand_rd   = $urandom_range(0, 31);

            drive_and_check(
                $sformatf("Random LHU test %0d", i),
                1'b1,
                $urandom,
                rand_rd,
                rand_addr,
                1'b1,
                WR_READ_RES,
                U_LOAD_HALF,
                1'b0,
                rand_mem,
                expected_mem_data(
                    rand_mem,
                    rand_addr[1:0],
                    U_LOAD_HALF
                )
            );

        end

        // ---------------------------------------------------------------------
        // Random word
        // ---------------------------------------------------------------------

        for (int i = 0; i < 50; i++) begin

            rand_mem  = $urandom;
            rand_addr = $urandom;
            rand_rd   = $urandom_range(0, 31);

            drive_and_check(
                $sformatf("Random LW test %0d", i),
                1'b1,
                $urandom,
                rand_rd,
                rand_addr,
                1'b1,
                WR_READ_RES,
                S_LOAD_WORD,
                1'b0,
                rand_mem,
                rand_mem
            );

        end

    endtask


    // =========================================================================
    // Main test sequence
    // =========================================================================


    task automatic test_stall_gating;

        $display("\n--- Stall gating tests ---");

        i_stall = 1'b1;

        drive_and_check(
            "Stall suppresses register write",
            1'b1,
            32'h0000_1000,
            5'd9,
            32'hABCD_1234,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'hDEAD_BEEF,
            32'hABCD_1234
        );

        i_stall = 1'b0;

        drive_and_check(
            "Write resumes after stall",
            1'b1,
            32'h0000_1000,
            5'd9,
            32'hABCD_1234,
            1'b1,
            WR_ALU_RES,
            S_LOAD_WORD,
            1'b0,
            32'hDEAD_BEEF,
            32'hABCD_1234
        );

    endtask

    initial begin

        $display("============================================================");
        $display("                WRITEBACK TESTBENCH");
        $display("============================================================");

        // ---------------------------------------------------------------------
        // Default initialization
        // ---------------------------------------------------------------------

        i_stall       = 1'b0;
        i_wb_valid    = 1'b0;
        i_wb_pc       = 32'b0;
        i_wb_rd       = 5'b0;
        i_wb_alu_res  = 32'b0;
        i_wb_wr_en    = 1'b0;
        i_wb_src      = WR_ALU_RES;
        i_wb_mem_type = S_LOAD_WORD;
        i_wb_illegal  = 1'b0;
        i_wb_mem_data   = 32'b0;

        #5;

        // ---------------------------------------------------------------------
        // Directed tests
        // ---------------------------------------------------------------------

        test_alu_writeback();
        test_pc_plus_4();

        test_signed_byte_loads();
        test_unsigned_byte_loads();

        test_signed_half_loads();
        test_unsigned_half_loads();

        test_word_loads();

        test_halfword_all_offsets();

        test_control_passthrough();
        test_valid_illegal_gating();
        test_stall_gating();

        test_mux_isolation();

        // ---------------------------------------------------------------------
        // Random tests
        // ---------------------------------------------------------------------

        test_random_alu();
        test_random_pc();
        test_random_loads();

        // ---------------------------------------------------------------------
        // Results
        // ---------------------------------------------------------------------

        $display("\n============================================================");
        $display("                 TESTBENCH SUMMARY");
        $display("============================================================");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("============================================================");

        if (fail_count == 0) begin
            $display("[PASS] ALL WRITEBACK TESTS PASSED");
        end
        else begin
            $display("[FAIL] %0d WRITEBACK TEST(S) FAILED", fail_count);
        end

        $display("============================================================");

        $finish;
    end

endmodule
