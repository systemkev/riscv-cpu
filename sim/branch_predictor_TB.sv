`timescale 1ns/1ps

module branch_predictor_TB;

    localparam int ENTRIES = 8;
    localparam time CLK_PERIOD = 10ns;

    logic        i_clk;
    logic        i_rst;

    logic [31:0] i_fetch_pc;
    logic        o_pred_taken;
    logic [31:0] o_pred_target;

    logic        i_resolve_valid;
    logic [31:0] i_resolve_pc;
    logic        i_resolve_is_branch;
    logic        i_resolve_is_jump;
    logic        i_resolve_taken;
    logic [31:0] i_resolve_target;
    logic        i_resolve_pred_taken;
    logic [31:0] i_resolve_pred_target;

    logic        o_mispredict;
    logic [31:0] o_recovery_pc;

    int tests_run;
    int tests_failed;

    branch_predictor #(
        .ENTRIES(ENTRIES)
    ) dut (
        .i_clk                 (i_clk),
        .i_rst                 (i_rst),
        .i_fetch_pc            (i_fetch_pc),
        .o_pred_taken          (o_pred_taken),
        .o_pred_target         (o_pred_target),
        .i_resolve_valid       (i_resolve_valid),
        .i_resolve_pc          (i_resolve_pc),
        .i_resolve_is_branch   (i_resolve_is_branch),
        .i_resolve_is_jump     (i_resolve_is_jump),
        .i_resolve_taken       (i_resolve_taken),
        .i_resolve_target      (i_resolve_target),
        .i_resolve_pred_taken  (i_resolve_pred_taken),
        .i_resolve_pred_target (i_resolve_pred_target),
        .o_mispredict          (o_mispredict),
        .o_recovery_pc         (o_recovery_pc)
    );

    initial i_clk = 1'b0;

    always #(CLK_PERIOD / 2) i_clk = ~i_clk;

    task automatic expect1(
        input string name,
        input logic actual,
        input logic expected
    );
        begin
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "%s expected=%b got=%b",
                    name,
                    expected,
                    actual
                );
            end else begin
                $display("[PASS] %s", name);
            end
        end
    endtask

    task automatic expect32(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "%s expected=%08h got=%08h",
                    name,
                    expected,
                    actual
                );
            end else begin
                $display("[PASS] %s", name);
            end
        end
    endtask

    task automatic clear_resolve;
        begin
            i_resolve_valid       = 1'b0;
            i_resolve_pc          = 32'd0;
            i_resolve_is_branch   = 1'b0;
            i_resolve_is_jump     = 1'b0;
            i_resolve_taken       = 1'b0;
            i_resolve_target      = 32'd0;
            i_resolve_pred_taken  = 1'b0;
            i_resolve_pred_target = 32'd0;
        end
    endtask

    task automatic reset_dut;
        begin
            @(negedge i_clk);

            i_rst      = 1'b1;
            i_fetch_pc = 32'd0;

            clear_resolve();

            repeat (2) begin
                @(posedge i_clk);
                #1;
            end

            @(negedge i_clk);

            i_rst = 1'b0;
        end
    endtask

    task automatic check_prediction(
        input string name,
        input logic [31:0] pc,
        input logic expected_taken,
        input logic [31:0] expected_target
    );
        begin
            i_fetch_pc = pc;
            #1;

            expect1(
                {name, " taken"},
                o_pred_taken,
                expected_taken
            );

            expect32(
                {name, " target"},
                o_pred_target,
                expected_target
            );
        end
    endtask

    task automatic resolve_current(
        input string name,
        input logic [31:0] pc,
        input logic is_branch,
        input logic is_jump,
        input logic actual_taken,
        input logic [31:0] actual_target,
        input logic expected_mispredict,
        input logic [31:0] expected_recovery
    );

        logic predicted_taken;
        logic [31:0] predicted_target;

        begin
            i_fetch_pc = pc;
            #1;

            predicted_taken  = o_pred_taken;
            predicted_target = o_pred_target;

            @(negedge i_clk);

            i_resolve_valid       = 1'b1;
            i_resolve_pc          = pc;
            i_resolve_is_branch   = is_branch;
            i_resolve_is_jump     = is_jump;
            i_resolve_taken       = actual_taken;
            i_resolve_target      = actual_target;
            i_resolve_pred_taken  = predicted_taken;
            i_resolve_pred_target = predicted_target;

            #1;

            expect1(
                {name, " mispredict"},
                o_mispredict,
                expected_mispredict
            );

            expect32(
                {name, " recovery"},
                o_recovery_pc,
                expected_recovery
            );

            @(posedge i_clk);
            #1;

            @(negedge i_clk);

            clear_resolve();
        end
    endtask

    initial begin
        tests_run    = 0;
        tests_failed = 0;

        i_rst      = 1'b0;
        i_fetch_pc = 32'd0;

        clear_resolve();

        reset_dut();

        check_prediction(
            "Reset BTB miss",
            32'h0000_0100,
            1'b0,
            32'h0000_0104
        );

        resolve_current(
            "First taken branch",
            32'h0000_0100,
            1'b1,
            1'b0,
            1'b1,
            32'h0000_0180,
            1'b1,
            32'h0000_0180
        );

        check_prediction(
            "Branch learned taken",
            32'h0000_0100,
            1'b1,
            32'h0000_0180
        );

        resolve_current(
            "Correct taken branch",
            32'h0000_0100,
            1'b1,
            1'b0,
            1'b1,
            32'h0000_0180,
            1'b0,
            32'h0000_0180
        );

        check_prediction(
            "Strong taken branch",
            32'h0000_0100,
            1'b1,
            32'h0000_0180
        );

        resolve_current(
            "First not-taken reversal",
            32'h0000_0100,
            1'b1,
            1'b0,
            1'b0,
            32'h0000_0180,
            1'b1,
            32'h0000_0104
        );

        check_prediction(
            "Hysteresis remains taken",
            32'h0000_0100,
            1'b1,
            32'h0000_0180
        );

        resolve_current(
            "Second not-taken reversal",
            32'h0000_0100,
            1'b1,
            1'b0,
            1'b0,
            32'h0000_0180,
            1'b1,
            32'h0000_0104
        );

        check_prediction(
            "Branch switches not taken",
            32'h0000_0100,
            1'b0,
            32'h0000_0180
        );

        resolve_current(
            "Correct not-taken branch",
            32'h0000_0100,
            1'b1,
            1'b0,
            1'b0,
            32'h0000_0180,
            1'b0,
            32'h0000_0104
        );

        reset_dut();

        check_prediction(
            "Unknown jump",
            32'h0000_0200,
            1'b0,
            32'h0000_0204
        );

        resolve_current(
            "First jump",
            32'h0000_0200,
            1'b0,
            1'b1,
            1'b1,
            32'h0000_0300,
            1'b1,
            32'h0000_0300
        );

        check_prediction(
            "Jump BTB hit",
            32'h0000_0200,
            1'b1,
            32'h0000_0300
        );

        resolve_current(
            "Correct predicted jump",
            32'h0000_0200,
            1'b0,
            1'b1,
            1'b1,
            32'h0000_0300,
            1'b0,
            32'h0000_0300
        );

        resolve_current(
            "Jump target changed",
            32'h0000_0200,
            1'b0,
            1'b1,
            1'b1,
            32'h0000_0340,
            1'b1,
            32'h0000_0340
        );

        check_prediction(
            "Updated jump target",
            32'h0000_0200,
            1'b1,
            32'h0000_0340
        );

        reset_dut();

        resolve_current(
            "Alias entry A",
            32'h0000_0300,
            1'b0,
            1'b1,
            1'b1,
            32'h0000_0400,
            1'b1,
            32'h0000_0400
        );

        check_prediction(
            "Alias entry A present",
            32'h0000_0300,
            1'b1,
            32'h0000_0400
        );

        resolve_current(
            "Alias entry B",
            32'h0000_0320,
            1'b0,
            1'b1,
            1'b1,
            32'h0000_0500,
            1'b1,
            32'h0000_0500
        );

        check_prediction(
            "Alias entry B present",
            32'h0000_0320,
            1'b1,
            32'h0000_0500
        );

        check_prediction(
            "Alias entry A evicted",
            32'h0000_0300,
            1'b0,
            32'h0000_0304
        );

        $display("");
        $display("====================================================");
        $display("BRANCH PREDICTOR TESTBENCH COMPLETE");
        $display("====================================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_run - tests_failed);
        $display("Tests failed : %0d", tests_failed);
        $display("====================================================");

        if (tests_failed == 0) begin
            $display("[PASS] ALL BRANCH PREDICTOR TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "[FAIL] BRANCH PREDICTOR TESTBENCH FAILED");
        end
    end

endmodule