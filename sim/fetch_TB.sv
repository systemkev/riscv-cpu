`timescale 1ns / 1ps

import common_pkg::*;

module fetch_TB;

    localparam time CLK_PERIOD = 10ns;

    // ========================================================================
    // DUT inputs
    // ========================================================================

    logic        i_clk;
    logic        i_rst;
    logic        i_stall;
    logic        i_redirect;
    logic [31:0] i_target;
    logic        i_pred_taken;
    logic [31:0] i_pred_target;
    logic [31:0] i_imem_data;


    // ========================================================================
    // DUT outputs
    // ========================================================================

    logic [31:0] o_imem_addr;
    logic        o_valid;
    logic [31:0] o_pc;
    logic [31:0] o_instr;
    logic        o_pred_taken;
    logic [31:0] o_pred_target;


    // ========================================================================
    // DUT
    // ========================================================================

    fetch dut (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_stall        (i_stall),
        .i_redirect     (i_redirect),
        .i_target       (i_target),
        .i_pred_taken   (i_pred_taken),
        .i_pred_target  (i_pred_target),
        .i_imem_data    (i_imem_data),

        .o_imem_addr    (o_imem_addr),
        .o_valid        (o_valid),
        .o_pc           (o_pc),
        .o_instr        (o_instr),
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
    // Test counters
    // ========================================================================

    int tests_run;
    int tests_failed;


    // ========================================================================
    // Instruction-memory model
    //
    // Deterministic word returned for every address.
    //
    // This is NOT intended to represent real RISC-V instructions. Fetch does
    // not care what the instruction bits mean. The unique values simply allow
    // us to verify that the instruction corresponds to the correct PC.
    // ========================================================================

    function automatic logic [31:0] imem_word(
        input logic [31:0] addr
    );
        return addr ^ 32'hC001_C0DE;
    endfunction


    // ========================================================================
    // 1-cycle synchronous BRAM model
    //
    // At each rising edge:
    //
    //      address presented during cycle N
    //
    // becomes:
    //
    //      i_imem_data during cycle N+1
    //
    // This matches the memory latency assumed by fetch.sv.
    // ========================================================================

    logic [31:0] imem_q;

    assign i_imem_data = imem_q;

    initial begin
        imem_q = 32'd0;
    end

    always @(posedge i_clk) begin
        imem_q <= imem_word(o_imem_addr);
    end


    // ========================================================================
    // Default control inputs
    // ========================================================================

    task automatic default_inputs;

        i_rst      = 1'b0;
        i_stall    = 1'b0;
        i_redirect   = 1'b0;
        i_target     = 32'd0;
        i_pred_taken = 1'b0;
        i_pred_target = 32'd0;

    endtask


    // ========================================================================
    // Quiet reset
    //
    // Two cycles are used so that both:
    //
    //      fetch state
    //      synchronous BRAM output
    //
    // settle to RESET_VECTOR.
    // ========================================================================

    task automatic quiet_reset;

        @(negedge i_clk);

        i_rst      = 1'b1;
        i_stall    = 1'b0;
        i_redirect   = 1'b0;
        i_target     = 32'd0;
        i_pred_taken = 1'b0;
        i_pred_target = 32'd0;

        @(posedge i_clk);
        #1;

        @(posedge i_clk);
        #1;

        @(negedge i_clk);

        i_rst = 1'b0;

    endtask


    // ========================================================================
    // General output checker
    // ========================================================================

    task automatic check_state(
        input string       test_name,
        input logic        expected_valid,
        input logic [31:0] expected_imem_addr,
        input logic [31:0] expected_pc,
        input logic [31:0] expected_instr,
        input logic        check_instr
    );

        bit failed;

        failed = 1'b0;
        tests_run++;

        if (o_valid !== expected_valid) begin
            $error(
                "%s: o_valid expected=%b got=%b",
                test_name,
                expected_valid,
                o_valid
            );

            failed = 1'b1;
        end


        if (o_imem_addr !== expected_imem_addr) begin
            $error(
                "%s: o_imem_addr expected=%h got=%h",
                test_name,
                expected_imem_addr,
                o_imem_addr
            );

            failed = 1'b1;
        end


        if (o_pc !== expected_pc) begin
            $error(
                "%s: o_pc expected=%h got=%h",
                test_name,
                expected_pc,
                o_pc
            );

            failed = 1'b1;
        end


        if (check_instr &&
            (o_instr !== expected_instr)) begin

            $error(
                "%s: o_instr expected=%h got=%h",
                test_name,
                expected_instr,
                o_instr
            );

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
    // Check only o_valid
    //
    // Useful for testing the combinational redirect gating without advancing
    // the clock.
    // ========================================================================

    task automatic check_valid(
        input string test_name,
        input logic  expected_valid
    );

        bit failed;

        failed = 1'b0;
        tests_run++;

        if (o_valid !== expected_valid) begin

            $error(
                "%s: o_valid expected=%b got=%b",
                test_name,
                expected_valid,
                o_valid
            );

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
    // Reset + reset priority
    // ========================================================================

    task automatic test_reset;

        @(negedge i_clk);

        // Assert every competing condition.
        i_rst      = 1'b1;
        i_stall    = 1'b1;
        i_redirect = 1'b1;
        i_target      = 32'hDEAD_BEEF;
        i_pred_taken  = 1'b1;
        i_pred_target = 32'h1234_5678;

        @(posedge i_clk);
        #1;

        // Don't check instruction yet; BRAM was previously looking at an
        // unknown/uninitialized address.
        check_state(
            "Reset state / reset priority",
            1'b0,
            RESET_VECTOR,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // Hold reset one more cycle. BRAM should now contain the instruction
        // corresponding to RESET_VECTOR.
        @(posedge i_clk);
        #1;

        check_state(
            "Reset held for second cycle",
            1'b0,
            RESET_VECTOR,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        @(negedge i_clk);

        i_rst      = 1'b0;
        i_stall    = 1'b0;
        i_redirect   = 1'b0;
        i_pred_taken = 1'b0;
        i_pred_target = 32'd0;

    endtask


    // ========================================================================
    // Sequential fetch
    // ========================================================================

    task automatic test_sequential_fetch;

        quiet_reset();


        // --------------------------------------------------------------------
        // First instruction after reset
        // --------------------------------------------------------------------

        @(posedge i_clk);
        #1;

        check_state(
            "Sequential fetch 0",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // --------------------------------------------------------------------
        // Second instruction
        // --------------------------------------------------------------------

        @(posedge i_clk);
        #1;

        check_state(
            "Sequential fetch 1",
            1'b1,
            RESET_VECTOR + 32'd8,
            RESET_VECTOR + 32'd4,
            imem_word(RESET_VECTOR + 32'd4),
            1'b1
        );


        // --------------------------------------------------------------------
        // Third instruction
        // --------------------------------------------------------------------

        @(posedge i_clk);
        #1;

        check_state(
            "Sequential fetch 2",
            1'b1,
            RESET_VECTOR + 32'd12,
            RESET_VECTOR + 32'd8,
            imem_word(RESET_VECTOR + 32'd8),
            1'b1
        );


        // --------------------------------------------------------------------
        // Fourth instruction
        // --------------------------------------------------------------------

        @(posedge i_clk);
        #1;

        check_state(
            "Sequential fetch 3",
            1'b1,
            RESET_VECTOR + 32'd16,
            RESET_VECTOR + 32'd12,
            imem_word(RESET_VECTOR + 32'd12),
            1'b1
        );

    endtask


    // ========================================================================
    // Single-cycle stall
    // ========================================================================

    task automatic test_single_cycle_stall;

        quiet_reset();


        // Fetch RESET_VECTOR normally.
        @(posedge i_clk);
        #1;

        check_state(
            "Single stall setup",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // --------------------------------------------------------------------
        // Stall.
        //
        // BRAM itself will advance and return data from RESET_VECTOR+4,
        // but fetch must keep presenting the original instruction using
        // hold_instr.
        // --------------------------------------------------------------------

        @(negedge i_clk);
        i_stall = 1'b1;

        @(posedge i_clk);
        #1;

        check_state(
            "Single-cycle stall holds instruction",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // --------------------------------------------------------------------
        // Resume
        // --------------------------------------------------------------------

        @(negedge i_clk);
        i_stall = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "Resume after single-cycle stall",
            1'b1,
            RESET_VECTOR + 32'd8,
            RESET_VECTOR + 32'd4,
            imem_word(RESET_VECTOR + 32'd4),
            1'b1
        );

    endtask


    // ========================================================================
    // Multi-cycle stall
    // ========================================================================

    task automatic test_multi_cycle_stall;

        quiet_reset();


        // Initial valid instruction.
        @(posedge i_clk);
        #1;

        check_state(
            "Multi-stall setup",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        @(negedge i_clk);
        i_stall = 1'b1;


        // --------------------------------------------------------------------
        // Stall cycle 1
        // --------------------------------------------------------------------

        @(posedge i_clk);
        #1;

        check_state(
            "Multi-cycle stall 1",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // --------------------------------------------------------------------
        // Stall cycle 2
        // --------------------------------------------------------------------

        @(posedge i_clk);
        #1;

        check_state(
            "Multi-cycle stall 2",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // --------------------------------------------------------------------
        // Stall cycle 3
        // --------------------------------------------------------------------

        @(posedge i_clk);
        #1;

        check_state(
            "Multi-cycle stall 3",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // --------------------------------------------------------------------
        // Resume
        // --------------------------------------------------------------------

        @(negedge i_clk);
        i_stall = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "Resume after multi-cycle stall",
            1'b1,
            RESET_VECTOR + 32'd8,
            RESET_VECTOR + 32'd4,
            imem_word(RESET_VECTOR + 32'd4),
            1'b1
        );


        // Ensure normal sequence continues.
        @(posedge i_clk);
        #1;

        check_state(
            "Sequence continues after multi-stall",
            1'b1,
            RESET_VECTOR + 32'd12,
            RESET_VECTOR + 32'd8,
            imem_word(RESET_VECTOR + 32'd8),
            1'b1
        );

    endtask


    // ========================================================================
    // Stall immediately after reset
    //
    // No valid instruction exists yet. Stall should keep valid low.
    // ========================================================================

    task automatic test_stall_after_reset;

        quiet_reset();

        // quiet_reset returns on negedge, so apply stall immediately.
        i_stall = 1'b1;

        @(posedge i_clk);
        #1;

        check_state(
            "Stall immediately after reset",
            1'b0,
            RESET_VECTOR,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );

        @(posedge i_clk);
        #1;

        check_state(
            "Second stall immediately after reset",
            1'b0,
            RESET_VECTOR,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );

        @(negedge i_clk);
        i_stall = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "First fetch after reset stall",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );

    endtask


    // ========================================================================
    // Basic redirect
    // ========================================================================

    task automatic test_redirect;

        logic [31:0] target;

        target = 32'h0000_4000;

        quiet_reset();


        // Get two valid sequential instructions into the pipeline.
        @(posedge i_clk);
        #1;

        @(posedge i_clk);
        #1;

        check_state(
            "Redirect setup",
            1'b1,
            RESET_VECTOR + 32'd8,
            RESET_VECTOR + 32'd4,
            imem_word(RESET_VECTOR + 32'd4),
            1'b1
        );


        // --------------------------------------------------------------------
        // Assert redirect during the cycle.
        //
        // o_valid must drop COMBINATIONALLY before the rising edge.
        // --------------------------------------------------------------------

        @(negedge i_clk);

        i_target   = target;
        i_redirect = 1'b1;

        #1;

        check_valid(
            "Redirect combinationally kills current valid",
            1'b0
        );


        // --------------------------------------------------------------------
        // Redirect clock edge
        //
        // PC changes immediately to target, but output instruction is invalid
        // because target BRAM data has not returned yet.
        // --------------------------------------------------------------------

        @(posedge i_clk);
        #1;

        check_state(
            "Redirect changes instruction-memory address",
            1'b0,
            target,

            // pc_dly does not change on redirect.
            RESET_VECTOR + 32'd4,

            32'd0,
            1'b0
        );


        // --------------------------------------------------------------------
        // Release redirect.
        //
        // Target instruction should become valid after one BRAM cycle.
        // --------------------------------------------------------------------

        @(negedge i_clk);
        i_redirect = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "First instruction after redirect",
            1'b1,
            target + 32'd4,
            target,
            imem_word(target),
            1'b1
        );


        // Next target instruction.
        @(posedge i_clk);
        #1;

        check_state(
            "Sequential execution after redirect",
            1'b1,
            target + 32'd8,
            target + 32'd4,
            imem_word(target + 32'd4),
            1'b1
        );

    endtask


    // ========================================================================
    // Redirect must beat stall
    // ========================================================================

    task automatic test_redirect_over_stall;

        logic [31:0] target;

        target = 32'h0000_8000;

        quiet_reset();


        // Fetch first instruction.
        @(posedge i_clk);
        #1;


        // Stall it so skid buffer becomes active.
        @(negedge i_clk);
        i_stall = 1'b1;

        @(posedge i_clk);
        #1;

        check_state(
            "Redirect-over-stall setup",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // --------------------------------------------------------------------
        // Assert redirect while still stalled.
        //
        // RTL priority:
        //
        // reset > redirect > stall > normal
        // --------------------------------------------------------------------

        @(negedge i_clk);

        i_redirect = 1'b1;
        i_stall    = 1'b1;
        i_target   = target;

        #1;

        check_valid(
            "Redirect kills valid while stalled",
            1'b0
        );


        @(posedge i_clk);
        #1;

        check_state(
            "Redirect has priority over stall",
            1'b0,
            target,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // Release both.
        @(negedge i_clk);

        i_redirect = 1'b0;
        i_stall    = 1'b0;


        @(posedge i_clk);
        #1;

        check_state(
            "Redirect target after stalled redirect",
            1'b1,
            target + 32'd4,
            target,
            imem_word(target),
            1'b1
        );

    endtask


    // ========================================================================
    // Back-to-back redirects
    // ========================================================================

    task automatic test_back_to_back_redirects;

        logic [31:0] target_1;
        logic [31:0] target_2;

        target_1 = 32'h0000_A000;
        target_2 = 32'h0000_B000;

        quiet_reset();


        // Create a valid instruction first.
        @(posedge i_clk);
        #1;


        // --------------------------------------------------------------------
        // Redirect #1
        // --------------------------------------------------------------------

        @(negedge i_clk);

        i_redirect = 1'b1;
        i_target   = target_1;

        @(posedge i_clk);
        #1;

        check_state(
            "Back-to-back redirect 1",
            1'b0,
            target_1,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // --------------------------------------------------------------------
        // Redirect #2 immediately afterward
        // --------------------------------------------------------------------

        @(negedge i_clk);

        i_redirect = 1'b1;
        i_target   = target_2;

        @(posedge i_clk);
        #1;

        check_state(
            "Back-to-back redirect 2",
            1'b0,
            target_2,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // --------------------------------------------------------------------
        // Release redirect. Latest target must win.
        // --------------------------------------------------------------------

        @(negedge i_clk);
        i_redirect = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "Latest redirect target wins",
            1'b1,
            target_2 + 32'd4,
            target_2,
            imem_word(target_2),
            1'b1
        );

    endtask


    // ========================================================================
    // Stall immediately after redirect
    //
    // This ensures a stall during the redirect bubble does not accidentally
    // make wrong-path BRAM data valid.
    // ========================================================================

    task automatic test_stall_after_redirect;

        logic [31:0] target;

        target = 32'h0000_C000;

        quiet_reset();


        // Initial normal instruction.
        @(posedge i_clk);
        #1;


        // Redirect.
        @(negedge i_clk);

        i_redirect = 1'b1;
        i_target   = target;

        @(posedge i_clk);
        #1;

        check_state(
            "Stall-after-redirect setup",
            1'b0,
            target,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // --------------------------------------------------------------------
        // Release redirect but immediately stall.
        // Valid must remain zero.
        // --------------------------------------------------------------------

        @(negedge i_clk);

        i_redirect = 1'b0;
        i_stall    = 1'b1;

        @(posedge i_clk);
        #1;

        check_state(
            "Stall extends redirect bubble safely",
            1'b0,
            target,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // Hold another cycle.
        @(posedge i_clk);
        #1;

        check_state(
            "Redirect bubble remains invalid while stalled",
            1'b0,
            target,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // Resume.
        @(negedge i_clk);
        i_stall = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "Target instruction after redirect stall",
            1'b1,
            target + 32'd4,
            target,
            imem_word(target),
            1'b1
        );

    endtask


    // ========================================================================
    // Redirect target ignored when redirect=0
    // ========================================================================

    task automatic test_target_ignored;

        quiet_reset();

        // quiet_reset() already returns at negedge.
        // Apply stimulus immediately.
        i_target   = 32'hDEAD_BEEF;
        i_redirect = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "i_target ignored when redirect=0",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );

        @(posedge i_clk);
        #1;

        check_state(
            "Sequential PC unaffected by unused target",
            1'b1,
            RESET_VECTOR + 32'd8,
            RESET_VECTOR + 32'd4,
            imem_word(RESET_VECTOR + 32'd4),
            1'b1
        );

    endtask


    // ========================================================================
    // PC 32-bit wraparound
    // ========================================================================

    task automatic test_pc_wraparound;

        quiet_reset();


        // Redirect to final aligned 32-bit word.
        @(negedge i_clk);

        i_redirect = 1'b1;
        i_target   = 32'hFFFF_FFFC;


        @(posedge i_clk);
        #1;

        check_state(
            "Wraparound redirect setup",
            1'b0,
            32'hFFFF_FFFC,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // Release redirect.
        @(negedge i_clk);

        i_redirect = 1'b0;


        // Fetch at FFFFFFFC.
        // Next PC address wraps to 00000000.
        @(posedge i_clk);
        #1;

        check_state(
            "PC wraps from FFFFFFFC to 00000000",
            1'b1,
            32'h0000_0000,
            32'hFFFF_FFFC,
            imem_word(32'hFFFF_FFFC),
            1'b1
        );


        // Fetch address 0.
        @(posedge i_clk);
        #1;

        check_state(
            "Fetch continues after PC wraparound",
            1'b1,
            32'h0000_0004,
            32'h0000_0000,
            imem_word(32'h0000_0000),
            1'b1
        );

    endtask


    // ========================================================================
    // Reset during active operation
    // ========================================================================

    task automatic test_reset_during_operation;

        quiet_reset();


        // Fetch several instructions.
        @(posedge i_clk);
        #1;

        @(posedge i_clk);
        #1;

        @(posedge i_clk);
        #1;


        // Assert reset while also asserting redirect/stall.
        @(negedge i_clk);

        i_rst      = 1'b1;
        i_stall    = 1'b1;
        i_redirect = 1'b1;
        i_target   = 32'h1234_5678;


        @(posedge i_clk);
        #1;

        check_state(
            "Reset during active operation",
            1'b0,
            RESET_VECTOR,
            RESET_VECTOR,
            32'd0,
            1'b0
        );


        // Hold reset so BRAM realigns too.
        @(posedge i_clk);
        #1;

        check_state(
            "Reset fully restores fetch state",
            1'b0,
            RESET_VECTOR,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // Resume.
        @(negedge i_clk);

        i_rst      = 1'b0;
        i_stall    = 1'b0;
        i_redirect = 1'b0;


        @(posedge i_clk);
        #1;

        check_state(
            "Fetch restarts at RESET_VECTOR",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );

    endtask


    // ========================================================================
    // Repeated stall / resume cycles
    //
    // Ensures the skid buffer can be reused rather than only functioning once.
    // ========================================================================

    task automatic test_repeated_stalls;

        quiet_reset();


        // Fetch PC0.
        @(posedge i_clk);
        #1;

        check_state(
            "Repeated stalls: initial instruction",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // Stall PC0.
        @(negedge i_clk);
        i_stall = 1'b1;

        @(posedge i_clk);
        #1;

        check_state(
            "Repeated stalls: first hold",
            1'b1,
            RESET_VECTOR + 32'd4,
            RESET_VECTOR,
            imem_word(RESET_VECTOR),
            1'b1
        );


        // Resume to PC1.
        @(negedge i_clk);
        i_stall = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "Repeated stalls: first resume",
            1'b1,
            RESET_VECTOR + 32'd8,
            RESET_VECTOR + 32'd4,
            imem_word(RESET_VECTOR + 32'd4),
            1'b1
        );


        // Stall PC1.
        @(negedge i_clk);
        i_stall = 1'b1;

        @(posedge i_clk);
        #1;

        check_state(
            "Repeated stalls: second hold",
            1'b1,
            RESET_VECTOR + 32'd8,
            RESET_VECTOR + 32'd4,
            imem_word(RESET_VECTOR + 32'd4),
            1'b1
        );


        // Resume to PC2.
        @(negedge i_clk);
        i_stall = 1'b0;

        @(posedge i_clk);
        #1;

        check_state(
            "Repeated stalls: second resume",
            1'b1,
            RESET_VECTOR + 32'd12,
            RESET_VECTOR + 32'd8,
            imem_word(RESET_VECTOR + 32'd8),
            1'b1
        );

    endtask



    task automatic check_prediction(
        input string       test_name,
        input logic        expected_taken,
        input logic [31:0] expected_target
    );
        bit failed;
        failed = 1'b0;
        tests_run++;

        if (o_pred_taken !== expected_taken) begin
            $error(
                "%s: o_pred_taken expected=%b got=%b",
                test_name,
                expected_taken,
                o_pred_taken
            );
            failed = 1'b1;
        end

        if (o_pred_target !== expected_target) begin
            $error(
                "%s: o_pred_target expected=%h got=%h",
                test_name,
                expected_target,
                o_pred_target
            );
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

    task automatic test_prediction;
        logic [31:0] source_pc;
        logic [31:0] target_pc;

        quiet_reset();

        source_pc = RESET_VECTOR;
        target_pc = 32'h0000_0100;

        i_pred_taken  = 1'b1;
        i_pred_target = target_pc;

        @(posedge i_clk);
        #1;

        check_state(
            "Prediction redirects next fetch",
            1'b1,
            target_pc,
            source_pc,
            imem_word(source_pc),
            1'b1
        );

        check_prediction(
            "Prediction metadata follows fetched instruction",
            1'b1,
            target_pc
        );

        @(negedge i_clk);
        i_pred_taken  = 1'b0;
        i_pred_target = 32'd0;

        @(posedge i_clk);
        #1;

        check_state(
            "Fetch proceeds sequentially from predicted target",
            1'b1,
            target_pc + 32'd4,
            target_pc,
            imem_word(target_pc),
            1'b1
        );

        check_prediction(
            "Non-taken prediction metadata",
            1'b0,
            32'd0
        );
    endtask

    task automatic test_redirect_over_prediction;
        quiet_reset();

        i_pred_taken  = 1'b1;
        i_pred_target = 32'h0000_0200;
        i_redirect    = 1'b1;
        i_target      = 32'h0000_0080;

        @(posedge i_clk);
        #1;

        check_state(
            "Redirect overrides prediction",
            1'b0,
            32'h0000_0080,
            RESET_VECTOR,
            32'd0,
            1'b0
        );

        check_prediction(
            "Redirect clears prediction metadata",
            1'b0,
            32'd0
        );

        @(negedge i_clk);
        i_redirect    = 1'b0;
        i_pred_taken  = 1'b0;
        i_pred_target = 32'd0;

        @(posedge i_clk);
        #1;

        check_state(
            "Fetch resumes at recovery target",
            1'b1,
            32'h0000_0084,
            32'h0000_0080,
            imem_word(32'h0000_0080),
            1'b1
        );
    endtask

    // ========================================================================
    // Main test sequence
    // ========================================================================

    initial begin

        tests_run    = 0;
        tests_failed = 0;

        default_inputs();


        // --------------------------------------------------------------------
        // Reset
        // --------------------------------------------------------------------

        test_reset();


        // --------------------------------------------------------------------
        // Normal sequential fetch / BRAM alignment
        // --------------------------------------------------------------------

        test_sequential_fetch();


        // --------------------------------------------------------------------
        // Stall behavior / skid buffer
        // --------------------------------------------------------------------

        test_single_cycle_stall();

        test_multi_cycle_stall();

        test_stall_after_reset();

        test_repeated_stalls();


        // --------------------------------------------------------------------
        // Redirect behavior
        // --------------------------------------------------------------------

        test_redirect();

        test_redirect_over_stall();

        test_back_to_back_redirects();

        test_stall_after_redirect();

        test_target_ignored();

        test_prediction();

        test_redirect_over_prediction();


        // --------------------------------------------------------------------
        // Boundary / recovery behavior
        // --------------------------------------------------------------------

        test_pc_wraparound();

        test_reset_during_operation();


        // --------------------------------------------------------------------
        // Results
        // --------------------------------------------------------------------

        $display("");
        $display("====================================================");
        $display("FETCH TESTBENCH COMPLETE");
        $display("====================================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_run - tests_failed);
        $display("Tests failed : %0d", tests_failed);
        $display("====================================================");

        if (tests_failed == 0) begin
            $display("[PASS] ALL FETCH TESTS PASSED");
        end
        else begin
            $display("[FAIL] %0d TEST(S) FAILED", tests_failed);
        end

        $finish;

    end

endmodule
