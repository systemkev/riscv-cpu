`timescale 1ns/1ps

import common_pkg::*;

module hazard_unit_TB;

    // =========================================================================
    // DUT Inputs
    // =========================================================================

    // Decode stage
    logic [4:0]     i_id_rs1;
    logic [4:0]     i_id_rs2;

    // Execute stage
    logic [4:0]     i_ex_rs1;
    logic [4:0]     i_ex_rs2;
    logic [4:0]     i_ex_rd;
    logic           i_ex_mem_read;
    logic           i_ex_mispredict;
    logic           i_cache_stall;

    // Memory stage
    logic [4:0]     i_mem_rd;
    logic           i_mem_reg_wr;

    // Writeback stage
    logic [4:0]     i_wb_rd;
    logic           i_wb_reg_wr;

    // =========================================================================
    // DUT Outputs
    // =========================================================================

    t_forwarding    o_forward_op_a;
    t_forwarding    o_forward_op_b;

    logic           o_fetch_stall;
    logic           o_decode_stall;
    logic           o_execute_stall;
    logic           o_memory_stall;
    logic           o_decode_flush;
    logic           o_execute_flush;

    // =========================================================================
    // Testbench bookkeeping
    // =========================================================================

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // =========================================================================
    // DUT
    // =========================================================================

    hazard_unit dut (
        .i_id_rs1          (i_id_rs1),
        .i_id_rs2          (i_id_rs2),

        .i_ex_rs1          (i_ex_rs1),
        .i_ex_rs2          (i_ex_rs2),
        .i_ex_rd           (i_ex_rd),
        .i_ex_mem_read     (i_ex_mem_read),
        .i_ex_mispredict     (i_ex_mispredict),

        .i_mem_rd          (i_mem_rd),
        .i_mem_reg_wr      (i_mem_reg_wr),

        .i_wb_rd           (i_wb_rd),
        .i_wb_reg_wr       (i_wb_reg_wr),
        .i_cache_stall     (i_cache_stall),

        .o_forward_op_a    (o_forward_op_a),
        .o_forward_op_b    (o_forward_op_b),

        .o_fetch_stall     (o_fetch_stall),
        .o_decode_stall    (o_decode_stall),
        .o_execute_stall   (o_execute_stall),
        .o_memory_stall    (o_memory_stall),
        .o_decode_flush    (o_decode_flush),
        .o_execute_flush   (o_execute_flush)
    );

    // =========================================================================
    // Reset all inputs
    // =========================================================================

    task automatic clear_inputs;
        begin
            i_id_rs1       = 5'd0;
            i_id_rs2       = 5'd0;

            i_ex_rs1       = 5'd0;
            i_ex_rs2       = 5'd0;
            i_ex_rd        = 5'd0;
            i_ex_mem_read  = 1'b0;
            i_ex_mispredict  = 1'b0;
            i_cache_stall    = 1'b0;

            i_mem_rd       = 5'd0;
            i_mem_reg_wr   = 1'b0;

            i_wb_rd        = 5'd0;
            i_wb_reg_wr    = 1'b0;
        end
    endtask

    // =========================================================================
    // Reference model
    //
    // Calculates what the DUT SHOULD produce from the current inputs.
    // =========================================================================

    task automatic calculate_expected (
        output t_forwarding exp_forward_a,
        output t_forwarding exp_forward_b,

        output logic        exp_fetch_stall,
        output logic        exp_decode_stall,
        output logic        exp_execute_stall,
        output logic        exp_memory_stall,
        output logic        exp_decode_flush,
        output logic        exp_execute_flush
    );

        logic load_use_hazard;

        begin

            // -------------------------------------------------------------
            // Forwarding A
            // -------------------------------------------------------------

            exp_forward_a = NO_HAZ;

            if (i_mem_reg_wr &&
                (i_mem_rd != 5'd0) &&
                (i_mem_rd == i_ex_rs1)) begin

                exp_forward_a = MEM_FWD;

            end
            else if (i_wb_reg_wr &&
                     (i_wb_rd != 5'd0) &&
                     (i_wb_rd == i_ex_rs1)) begin

                exp_forward_a = WB_FWD;

            end

            // -------------------------------------------------------------
            // Forwarding B
            // -------------------------------------------------------------

            exp_forward_b = NO_HAZ;

            if (i_mem_reg_wr &&
                (i_mem_rd != 5'd0) &&
                (i_mem_rd == i_ex_rs2)) begin

                exp_forward_b = MEM_FWD;

            end
            else if (i_wb_reg_wr &&
                     (i_wb_rd != 5'd0) &&
                     (i_wb_rd == i_ex_rs2)) begin

                exp_forward_b = WB_FWD;

            end

            // -------------------------------------------------------------
            // Load-use hazard
            // -------------------------------------------------------------

            load_use_hazard =
                i_ex_mem_read &&
                (i_ex_rd != 5'd0) &&
                (
                    (i_ex_rd == i_id_rs1) ||
                    (i_ex_rd == i_id_rs2)
                );

            // -------------------------------------------------------------
            // Pipeline control
            //
            // Mispredict has priority over load-use hazard.
            // -------------------------------------------------------------

            exp_fetch_stall   = 1'b0;
            exp_decode_stall  = 1'b0;
            exp_execute_stall = 1'b0;
            exp_memory_stall  = 1'b0;
            exp_decode_flush  = 1'b0;
            exp_execute_flush = 1'b0;

            if (i_cache_stall) begin

                exp_fetch_stall   = 1'b1;
                exp_decode_stall  = 1'b1;
                exp_execute_stall = 1'b1;
                exp_memory_stall  = 1'b1;

            end
            else if (i_ex_mispredict) begin

                exp_decode_flush = 1'b1;

            end
            else if (load_use_hazard) begin

                exp_fetch_stall   = 1'b1;
                exp_decode_stall  = 1'b1;
                exp_execute_flush = 1'b1;

            end

        end

    endtask

    // =========================================================================
    // Master checker
    // =========================================================================

    task automatic check_outputs (
        input string test_name
    );

        t_forwarding exp_forward_a;
        t_forwarding exp_forward_b;

        logic exp_fetch_stall;
        logic exp_decode_stall;
        logic exp_execute_stall;
        logic exp_memory_stall;
        logic exp_decode_flush;
        logic exp_execute_flush;

        begin

            calculate_expected(
                exp_forward_a,
                exp_forward_b,

                exp_fetch_stall,
                exp_decode_stall,
                exp_execute_stall,
                exp_memory_stall,
                exp_decode_flush,
                exp_execute_flush
            );

            // Allow combinational logic to settle
            #1;

            test_count++;

            if (
                (o_forward_op_a  === exp_forward_a)     &&
                (o_forward_op_b  === exp_forward_b)     &&
                (o_fetch_stall   === exp_fetch_stall)   &&
                (o_decode_stall  === exp_decode_stall)  &&
                (o_execute_stall === exp_execute_stall) &&
                (o_memory_stall  === exp_memory_stall)  &&
                (o_decode_flush  === exp_decode_flush)  &&
                (o_execute_flush === exp_execute_flush)
            ) begin

                pass_count++;

                $display(
                    "[PASS] %s",
                    test_name
                );

            end
            else begin

                fail_count++;

                $display(
                    "\n[FAIL] %s",
                    test_name
                );

                $display(
                    "------------------------------------------------------------"
                );

                $display(
                    "Inputs:"
                );

                $display(
                    "  ID:  rs1=%0d rs2=%0d",
                    i_id_rs1,
                    i_id_rs2
                );

                $display(
                    "  EX:  rs1=%0d rs2=%0d rd=%0d mem_read=%b mispredict=%b",
                    i_ex_rs1,
                    i_ex_rs2,
                    i_ex_rd,
                    i_ex_mem_read,
                    i_ex_mispredict
                );

                $display(
                    "  MEM: rd=%0d reg_wr=%b",
                    i_mem_rd,
                    i_mem_reg_wr
                );

                $display(
                    "  WB:  rd=%0d reg_wr=%b",
                    i_wb_rd,
                    i_wb_reg_wr
                );

                $display(
                    "------------------------------------------------------------"
                );

                $display(
                    "Forward A: expected=%s actual=%s",
                    exp_forward_a.name(),
                    o_forward_op_a.name()
                );

                $display(
                    "Forward B: expected=%s actual=%s",
                    exp_forward_b.name(),
                    o_forward_op_b.name()
                );

                $display(
                    "Fetch stall:   expected=%b actual=%b",
                    exp_fetch_stall,
                    o_fetch_stall
                );

                $display(
                    "Decode stall:  expected=%b actual=%b",
                    exp_decode_stall,
                    o_decode_stall
                );

                $display(
                    "Decode flush:  expected=%b actual=%b",
                    exp_decode_flush,
                    o_decode_flush
                );

                $display(
                    "Execute flush: expected=%b actual=%b",
                    exp_execute_flush,
                    o_execute_flush
                );

                $display(
                    "------------------------------------------------------------\n"
                );

            end

        end

    endtask

    // =========================================================================
    // Test 1: Idle/default behavior
    // =========================================================================

    task automatic test_idle;

        begin

            $display("\n============================================================");
            $display("1. IDLE / DEFAULT TESTS");
            $display("============================================================");

            clear_inputs();

            check_outputs(
                "No hazards: all outputs inactive"
            );

            // Arbitrary unrelated registers
            clear_inputs();

            i_id_rs1 = 5'd1;
            i_id_rs2 = 5'd2;

            i_ex_rs1 = 5'd3;
            i_ex_rs2 = 5'd4;
            i_ex_rd  = 5'd5;

            i_mem_rd = 5'd6;
            i_wb_rd  = 5'd7;

            check_outputs(
                "Unrelated register addresses cause no hazards"
            );

        end

    endtask

    // =========================================================================
    // Test 2: MEM -> EX forwarding on operand A
    // =========================================================================

    task automatic test_mem_forward_a;

        begin

            $display("\n============================================================");
            $display("2. MEM -> EX FORWARDING: OPERAND A");
            $display("============================================================");

            clear_inputs();

            i_ex_rs1     = 5'd5;
            i_mem_rd     = 5'd5;
            i_mem_reg_wr = 1'b1;

            check_outputs(
                "MEM forwards matching register to operand A"
            );

            // Write enable must be required
            clear_inputs();

            i_ex_rs1     = 5'd5;
            i_mem_rd     = 5'd5;
            i_mem_reg_wr = 1'b0;

            check_outputs(
                "MEM does not forward A when reg_write=0"
            );

            // x0 must never be forwarded
            clear_inputs();

            i_ex_rs1     = 5'd0;
            i_mem_rd     = 5'd0;
            i_mem_reg_wr = 1'b1;

            check_outputs(
                "MEM x0 does not forward to operand A"
            );

            // No register match
            clear_inputs();

            i_ex_rs1     = 5'd5;
            i_mem_rd     = 5'd6;
            i_mem_reg_wr = 1'b1;

            check_outputs(
                "MEM nonmatching register does not forward A"
            );

        end

    endtask

    // =========================================================================
    // Test 3: MEM -> EX forwarding on operand B
    // =========================================================================

    task automatic test_mem_forward_b;

        begin

            $display("\n============================================================");
            $display("3. MEM -> EX FORWARDING: OPERAND B");
            $display("============================================================");

            clear_inputs();

            i_ex_rs2     = 5'd9;
            i_mem_rd     = 5'd9;
            i_mem_reg_wr = 1'b1;

            check_outputs(
                "MEM forwards matching register to operand B"
            );

            clear_inputs();

            i_ex_rs2     = 5'd9;
            i_mem_rd     = 5'd9;
            i_mem_reg_wr = 1'b0;

            check_outputs(
                "MEM does not forward B when reg_write=0"
            );

            clear_inputs();

            i_ex_rs2     = 5'd0;
            i_mem_rd     = 5'd0;
            i_mem_reg_wr = 1'b1;

            check_outputs(
                "MEM x0 does not forward to operand B"
            );

            clear_inputs();

            i_ex_rs2     = 5'd9;
            i_mem_rd     = 5'd10;
            i_mem_reg_wr = 1'b1;

            check_outputs(
                "MEM nonmatching register does not forward B"
            );

        end

    endtask

    // =========================================================================
    // Test 4: WB -> EX forwarding on operand A
    // =========================================================================

    task automatic test_wb_forward_a;

        begin

            $display("\n============================================================");
            $display("4. WB -> EX FORWARDING: OPERAND A");
            $display("============================================================");

            clear_inputs();

            i_ex_rs1    = 5'd12;
            i_wb_rd     = 5'd12;
            i_wb_reg_wr = 1'b1;

            check_outputs(
                "WB forwards matching register to operand A"
            );

            clear_inputs();

            i_ex_rs1    = 5'd12;
            i_wb_rd     = 5'd12;
            i_wb_reg_wr = 1'b0;

            check_outputs(
                "WB does not forward A when reg_write=0"
            );

            clear_inputs();

            i_ex_rs1    = 5'd0;
            i_wb_rd     = 5'd0;
            i_wb_reg_wr = 1'b1;

            check_outputs(
                "WB x0 does not forward to operand A"
            );

            clear_inputs();

            i_ex_rs1    = 5'd12;
            i_wb_rd     = 5'd13;
            i_wb_reg_wr = 1'b1;

            check_outputs(
                "WB nonmatching register does not forward A"
            );

        end

    endtask

    // =========================================================================
    // Test 5: WB -> EX forwarding on operand B
    // =========================================================================

    task automatic test_wb_forward_b;

        begin

            $display("\n============================================================");
            $display("5. WB -> EX FORWARDING: OPERAND B");
            $display("============================================================");

            clear_inputs();

            i_ex_rs2    = 5'd20;
            i_wb_rd     = 5'd20;
            i_wb_reg_wr = 1'b1;

            check_outputs(
                "WB forwards matching register to operand B"
            );

            clear_inputs();

            i_ex_rs2    = 5'd20;
            i_wb_rd     = 5'd20;
            i_wb_reg_wr = 1'b0;

            check_outputs(
                "WB does not forward B when reg_write=0"
            );

            clear_inputs();

            i_ex_rs2    = 5'd0;
            i_wb_rd     = 5'd0;
            i_wb_reg_wr = 1'b1;

            check_outputs(
                "WB x0 does not forward to operand B"
            );

        end

    endtask

    // =========================================================================
    // Test 6: MEM forwarding must have priority over WB forwarding
    // =========================================================================

    task automatic test_forwarding_priority;

        begin

            $display("\n============================================================");
            $display("6. FORWARDING PRIORITY");
            $display("============================================================");

            // Both MEM and WB target rs1
            clear_inputs();

            i_ex_rs1 = 5'd15;

            i_mem_rd     = 5'd15;
            i_mem_reg_wr = 1'b1;

            i_wb_rd      = 5'd15;
            i_wb_reg_wr  = 1'b1;

            check_outputs(
                "MEM has priority over WB for operand A"
            );

            // Both MEM and WB target rs2
            clear_inputs();

            i_ex_rs2 = 5'd18;

            i_mem_rd     = 5'd18;
            i_mem_reg_wr = 1'b1;

            i_wb_rd      = 5'd18;
            i_wb_reg_wr  = 1'b1;

            check_outputs(
                "MEM has priority over WB for operand B"
            );

            // Same source register used for A and B
            clear_inputs();

            i_ex_rs1 = 5'd11;
            i_ex_rs2 = 5'd11;

            i_mem_rd     = 5'd11;
            i_mem_reg_wr = 1'b1;

            i_wb_rd      = 5'd11;
            i_wb_reg_wr  = 1'b1;

            check_outputs(
                "MEM has priority for both operands simultaneously"
            );

        end

    endtask

    // =========================================================================
    // Test 7: Simultaneous independent forwarding
    // =========================================================================

    task automatic test_simultaneous_forwarding;

        begin

            $display("\n============================================================");
            $display("7. SIMULTANEOUS FORWARDING");
            $display("============================================================");

            // A from MEM, B from WB
            clear_inputs();

            i_ex_rs1 = 5'd7;
            i_ex_rs2 = 5'd8;

            i_mem_rd     = 5'd7;
            i_mem_reg_wr = 1'b1;

            i_wb_rd      = 5'd8;
            i_wb_reg_wr  = 1'b1;

            check_outputs(
                "Operand A from MEM while operand B from WB"
            );

            // A from WB, B from MEM
            clear_inputs();

            i_ex_rs1 = 5'd7;
            i_ex_rs2 = 5'd8;

            i_mem_rd     = 5'd8;
            i_mem_reg_wr = 1'b1;

            i_wb_rd      = 5'd7;
            i_wb_reg_wr  = 1'b1;

            check_outputs(
                "Operand A from WB while operand B from MEM"
            );

            // Both operands from MEM
            clear_inputs();

            i_ex_rs1 = 5'd4;
            i_ex_rs2 = 5'd4;

            i_mem_rd     = 5'd4;
            i_mem_reg_wr = 1'b1;

            check_outputs(
                "Both operands can forward from MEM"
            );

            // Both operands from WB
            clear_inputs();

            i_ex_rs1 = 5'd4;
            i_ex_rs2 = 5'd4;

            i_wb_rd     = 5'd4;
            i_wb_reg_wr = 1'b1;

            check_outputs(
                "Both operands can forward from WB"
            );

        end

    endtask

    // =========================================================================
    // Test 8: Basic load-use hazards
    // =========================================================================

    task automatic test_load_use;

        begin

            $display("\n============================================================");
            $display("8. LOAD-USE HAZARDS");
            $display("============================================================");

            // rs1 hazard
            clear_inputs();

            i_ex_rd       = 5'd10;
            i_ex_mem_read = 1'b1;

            i_id_rs1      = 5'd10;
            i_id_rs2      = 5'd20;

            check_outputs(
                "Load-use hazard through ID rs1"
            );

            // rs2 hazard
            clear_inputs();

            i_ex_rd       = 5'd10;
            i_ex_mem_read = 1'b1;

            i_id_rs1      = 5'd20;
            i_id_rs2      = 5'd10;

            check_outputs(
                "Load-use hazard through ID rs2"
            );

            // Both operands
            clear_inputs();

            i_ex_rd       = 5'd10;
            i_ex_mem_read = 1'b1;

            i_id_rs1      = 5'd10;
            i_id_rs2      = 5'd10;

            check_outputs(
                "Load-use hazard through both source operands"
            );

            // No match
            clear_inputs();

            i_ex_rd       = 5'd10;
            i_ex_mem_read = 1'b1;

            i_id_rs1      = 5'd11;
            i_id_rs2      = 5'd12;

            check_outputs(
                "Load followed by independent instruction does not stall"
            );

        end

    endtask

    // =========================================================================
    // Test 9: Load-use exclusions
    // =========================================================================

    task automatic test_load_use_exclusions;

        begin

            $display("\n============================================================");
            $display("9. LOAD-USE EXCLUSION TESTS");
            $display("============================================================");

            // Same register but EX isn't a load
            clear_inputs();

            i_ex_rd       = 5'd6;
            i_ex_mem_read = 1'b0;

            i_id_rs1      = 5'd6;

            check_outputs(
                "Matching register does not stall when EX is not a load"
            );

            // x0 destination
            clear_inputs();

            i_ex_rd       = 5'd0;
            i_ex_mem_read = 1'b1;

            i_id_rs1      = 5'd0;
            i_id_rs2      = 5'd0;

            check_outputs(
                "Load destination x0 never creates load-use hazard"
            );

            // Completely independent
            clear_inputs();

            i_ex_rd       = 5'd31;
            i_ex_mem_read = 1'b1;

            i_id_rs1      = 5'd1;
            i_id_rs2      = 5'd2;

            check_outputs(
                "Unrelated load causes no stall"
            );

        end

    endtask

    // =========================================================================
    // Test 10: Mispredict handling
    // =========================================================================

    task automatic test_mispredict;

        begin

            $display("\n============================================================");
            $display("10. REDIRECT / CONTROL HAZARDS");
            $display("============================================================");

            clear_inputs();

            i_ex_mispredict = 1'b1;

            check_outputs(
                "Mispredict flushes decode stage"
            );

            // Mispredict with arbitrary registers
            clear_inputs();

            i_ex_mispredict = 1'b1;

            i_id_rs1 = 5'd2;
            i_id_rs2 = 5'd3;

            i_ex_rs1 = 5'd4;
            i_ex_rs2 = 5'd5;
            i_ex_rd  = 5'd6;

            check_outputs(
                "Mispredict unaffected by unrelated register state"
            );

        end

    endtask

    // =========================================================================
    // Test 11: Mispredict priority over load-use stall
    // =========================================================================

    task automatic test_mispredict_priority;

        begin

            $display("\n============================================================");
            $display("11. REDIRECT VS LOAD-USE PRIORITY");
            $display("============================================================");

            clear_inputs();

            // Create a load-use hazard
            i_ex_mem_read = 1'b1;
            i_ex_rd       = 5'd5;

            i_id_rs1      = 5'd5;

            // Simultaneously mispredict
            i_ex_mispredict = 1'b1;

            check_outputs(
                "Mispredict has priority over load-use hazard"
            );

            // Match rs2 as well
            clear_inputs();

            i_ex_mem_read = 1'b1;
            i_ex_rd       = 5'd17;

            i_id_rs1      = 5'd17;
            i_id_rs2      = 5'd17;

            i_ex_mispredict = 1'b1;

            check_outputs(
                "Mispredict priority when both source registers have load-use hazard"
            );

        end

    endtask

    // =========================================================================
    // Test 12: Forwarding and pipeline-control independence
    // =========================================================================

    task automatic test_forwarding_with_stalls;

        begin

            $display("\n============================================================");
            $display("12. FORWARDING + PIPELINE CONTROL INTERACTION");
            $display("============================================================");

            // Simultaneous MEM forwarding + load-use hazard
            clear_inputs();

            i_ex_rs1 = 5'd8;

            i_mem_rd     = 5'd8;
            i_mem_reg_wr = 1'b1;

            i_ex_mem_read = 1'b1;
            i_ex_rd       = 5'd12;
            i_id_rs1      = 5'd12;

            check_outputs(
                "Forwarding logic remains valid during load-use stall"
            );

            // Simultaneous WB forwarding + mispredict
            clear_inputs();

            i_ex_rs2 = 5'd22;

            i_wb_rd     = 5'd22;
            i_wb_reg_wr = 1'b1;

            i_ex_mispredict = 1'b1;

            check_outputs(
                "Forwarding logic remains valid during mispredict"
            );

            // MEM + WB forwarding, load-use, and mispredict all active
            clear_inputs();

            i_ex_rs1 = 5'd5;
            i_ex_rs2 = 5'd6;

            i_mem_rd     = 5'd5;
            i_mem_reg_wr = 1'b1;

            i_wb_rd     = 5'd6;
            i_wb_reg_wr = 1'b1;

            i_ex_mem_read = 1'b1;
            i_ex_rd       = 5'd10;

            i_id_rs1 = 5'd10;

            i_ex_mispredict = 1'b1;

            check_outputs(
                "Forwarding + load-use + mispredict simultaneous"
            );

        end

    endtask

    // =========================================================================
    // Test 13: Exhaustive MEM forwarding register matching
    //
    // Tries every 32 x 32 source/destination register combination.
    // =========================================================================

    task automatic test_exhaustive_mem_forwarding;

        begin

            $display("\n============================================================");
            $display("13. EXHAUSTIVE MEM FORWARDING");
            $display("============================================================");

            for (int src = 0; src < 32; src++) begin

                for (int dst = 0; dst < 32; dst++) begin

                    clear_inputs();

                    i_ex_rs1     = src[4:0];
                    i_ex_rs2     = src[4:0];

                    i_mem_rd     = dst[4:0];
                    i_mem_reg_wr = 1'b1;

                    check_outputs(
                        $sformatf(
                            "MEM exhaustive src=x%0d dst=x%0d",
                            src,
                            dst
                        )
                    );

                end

            end

        end

    endtask

    // =========================================================================
    // Test 14: Exhaustive WB forwarding register matching
    // =========================================================================

    task automatic test_exhaustive_wb_forwarding;

        begin

            $display("\n============================================================");
            $display("14. EXHAUSTIVE WB FORWARDING");
            $display("============================================================");

            for (int src = 0; src < 32; src++) begin

                for (int dst = 0; dst < 32; dst++) begin

                    clear_inputs();

                    i_ex_rs1 = src[4:0];
                    i_ex_rs2 = src[4:0];

                    i_wb_rd     = dst[4:0];
                    i_wb_reg_wr = 1'b1;

                    check_outputs(
                        $sformatf(
                            "WB exhaustive src=x%0d dst=x%0d",
                            src,
                            dst
                        )
                    );

                end

            end

        end

    endtask

    // =========================================================================
    // Test 15: Exhaustive load-use hazard register matching
    //
    // Tests every EX destination against every ID source register.
    // =========================================================================

    task automatic test_exhaustive_load_use;

        begin

            $display("\n============================================================");
            $display("15. EXHAUSTIVE LOAD-USE HAZARDS");
            $display("============================================================");

            // -------------------------------------------------------------
            // rs1
            // -------------------------------------------------------------

            for (int ex_rd = 0; ex_rd < 32; ex_rd++) begin

                for (int id_rs = 0; id_rs < 32; id_rs++) begin

                    clear_inputs();

                    i_ex_mem_read = 1'b1;
                    i_ex_rd       = ex_rd[4:0];

                    i_id_rs1      = id_rs[4:0];
                    i_id_rs2      = 5'd0;

                    check_outputs(
                        $sformatf(
                            "Load-use rs1 exhaustive EX.rd=x%0d ID.rs1=x%0d",
                            ex_rd,
                            id_rs
                        )
                    );

                end

            end

            // -------------------------------------------------------------
            // rs2
            // -------------------------------------------------------------

            for (int ex_rd = 0; ex_rd < 32; ex_rd++) begin

                for (int id_rs = 0; id_rs < 32; id_rs++) begin

                    clear_inputs();

                    i_ex_mem_read = 1'b1;
                    i_ex_rd       = ex_rd[4:0];

                    i_id_rs1      = 5'd0;
                    i_id_rs2      = id_rs[4:0];

                    check_outputs(
                        $sformatf(
                            "Load-use rs2 exhaustive EX.rd=x%0d ID.rs2=x%0d",
                            ex_rd,
                            id_rs
                        )
                    );

                end

            end

        end

    endtask

    // =========================================================================
    // Test 16: Random stress testing
    // =========================================================================

    task automatic test_random;

        begin

            $display("\n============================================================");
            $display("16. RANDOMIZED STRESS TESTING");
            $display("============================================================");

            for (int i = 0; i < 2000; i++) begin

                i_id_rs1       = $urandom_range(0, 31);
                i_id_rs2       = $urandom_range(0, 31);

                i_ex_rs1       = $urandom_range(0, 31);
                i_ex_rs2       = $urandom_range(0, 31);
                i_ex_rd        = $urandom_range(0, 31);

                i_ex_mem_read  = $urandom_range(0, 1);
                i_ex_mispredict  = $urandom_range(0, 1);

                i_mem_rd       = $urandom_range(0, 31);
                i_mem_reg_wr   = $urandom_range(0, 1);

                i_wb_rd        = $urandom_range(0, 31);
                i_wb_reg_wr    = $urandom_range(0, 1);

                check_outputs(
                    $sformatf(
                        "Random hazard test %0d",
                        i
                    )
                );

            end

        end

    endtask

    // =========================================================================
    // Test 17: Rapid combinational changes
    //
    // Since the hazard unit is combinational, make sure outputs immediately
    // track changing hazards without requiring a clock.
    // =========================================================================

    task automatic test_combinational_response;

        begin

            $display("\n============================================================");
            $display("17. COMBINATIONAL RESPONSE");
            $display("============================================================");

            clear_inputs();
            check_outputs(
                "Combination sequence step 1: idle"
            );

            i_ex_rs1     = 5'd5;
            i_mem_rd     = 5'd5;
            i_mem_reg_wr = 1'b1;

            check_outputs(
                "Combination sequence step 2: MEM forward"
            );

            i_mem_reg_wr = 1'b0;
            i_wb_rd      = 5'd5;
            i_wb_reg_wr  = 1'b1;

            check_outputs(
                "Combination sequence step 3: transition MEM to WB forward"
            );

            i_ex_mem_read = 1'b1;
            i_ex_rd       = 5'd7;
            i_id_rs2      = 5'd7;

            check_outputs(
                "Combination sequence step 4: add load-use hazard"
            );

            i_ex_mispredict = 1'b1;

            check_outputs(
                "Combination sequence step 5: mispredict overrides stall"
            );

            i_ex_mispredict = 1'b0;
            i_ex_mem_read = 1'b0;
            i_wb_reg_wr   = 1'b0;

            check_outputs(
                "Combination sequence step 6: return to idle"
            );

        end

    endtask


    task automatic test_cache_stall;

        $display("\n--- Cache stall tests ---");

        clear_inputs();
        i_cache_stall = 1'b1;
        check_outputs("Cache miss stalls entire pipeline");

        clear_inputs();
        i_cache_stall   = 1'b1;
        i_ex_mispredict = 1'b1;
        check_outputs("Cache stall has priority over mispredict");

        clear_inputs();
        i_cache_stall  = 1'b1;
        i_ex_mem_read  = 1'b1;
        i_ex_rd        = 5'd9;
        i_id_rs1       = 5'd9;
        check_outputs("Cache stall has priority over load-use");

        clear_inputs();
        i_cache_stall = 1'b1;
        i_mem_reg_wr  = 1'b1;
        i_mem_rd      = 5'd7;
        i_ex_rs1      = 5'd7;
        check_outputs("Forwarding selection remains valid during cache stall");

    endtask

    // =========================================================================
    // Main
    // =========================================================================

    initial begin

        $display("");
        $display("============================================================");
        $display("            HAZARD UNIT TESTBENCH STARTING");
        $display("============================================================");

        clear_inputs();

        #5;

        // ---------------------------------------------------------------------
        // Directed functional tests
        // ---------------------------------------------------------------------

        test_idle();

        test_mem_forward_a();
        test_mem_forward_b();

        test_wb_forward_a();
        test_wb_forward_b();

        test_forwarding_priority();
        test_simultaneous_forwarding();

        test_load_use();
        test_load_use_exclusions();

        test_mispredict();
        test_mispredict_priority();
        test_cache_stall();

        test_forwarding_with_stalls();

        // ---------------------------------------------------------------------
        // Exhaustive tests
        // ---------------------------------------------------------------------

        test_exhaustive_mem_forwarding();
        test_exhaustive_wb_forwarding();
        test_exhaustive_load_use();

        // ---------------------------------------------------------------------
        // Random / dynamic tests
        // ---------------------------------------------------------------------

        test_random();
        test_combinational_response();

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------

        $display("");
        $display("============================================================");
        $display("                 TESTBENCH SUMMARY");
        $display("============================================================");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("============================================================");

        if (fail_count == 0) begin

            $display("");
            $display("****************************************************");
            $display("*                                                  *");
            $display("*          ALL HAZARD UNIT TESTS PASSED            *");
            $display("*                                                  *");
            $display("****************************************************");

        end
        else begin

            $display("");
            $display("****************************************************");
            $display("*                                                  *");
            $display("*            HAZARD UNIT TEST FAILED               *");
            $display("*                                                  *");
            $display("*              FAILURES: %0d                       ", fail_count);
            $display("*                                                  *");
            $display("****************************************************");

            $fatal(
                1,
                "%0d hazard-unit tests failed",
                fail_count
            );

        end

        $finish;

    end

endmodule
