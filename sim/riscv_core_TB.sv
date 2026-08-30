`timescale 1ns/1ps
`default_nettype none

import common_pkg::*;

module riscv_core_TB;

    // ========================================================================
    // Clock / DUT I/O
    // ========================================================================

    localparam int CLK_PERIOD_NS = 10;
    localparam int IMEM_WORDS    = 1024;
    localparam int DMEM_WORDS    = 2048;
    localparam int IMEM_AW       = $clog2(IMEM_WORDS);
    localparam int DMEM_AW       = $clog2(DMEM_WORDS);

    localparam logic [31:0] NOP       = 32'h0000_0013; // addi x0,x0,0
    localparam logic [31:0] SIG_ADDR  = 32'h0000_0700;
    localparam int          SIG_WORD  = SIG_ADDR >> 2;
    localparam logic [31:0] RAND_BASE = 32'h0000_0300;
    localparam int          RAND_CASES = 40;

    logic        i_clk;
    logic        i_rst;

    logic [31:0] o_imem_addr;
    logic [31:0] i_imem_data;

    logic [31:0] o_dmem_addr;
    logic [31:0] o_dmem_wr_data;
    logic        o_dmem_wr_en;
    logic [3:0]  o_dmem_byt_en;
    logic [31:0] i_dmem_data;

    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [31:0] dmem [0:DMEM_WORDS-1];

    logic [31:0] rand_expected [0:RAND_CASES-1];

    int checks_passed;
    int checks_failed;
    int protocol_errors;

    int stall_count;
    int redirect_count;
    int store_count;

    riscv_core dut (
        .i_clk          (i_clk),
        .i_rst          (i_rst),

        .o_imem_addr    (o_imem_addr),
        .i_imem_data    (i_imem_data),

        .o_dmem_addr    (o_dmem_addr),
        .o_dmem_wr_data (o_dmem_wr_data),
        .o_dmem_wr_en   (o_dmem_wr_en),
        .o_dmem_byt_en  (o_dmem_byt_en),
        .i_dmem_data    (i_dmem_data)
    );

    // ========================================================================
    // Clock
    // ========================================================================

    initial i_clk = 1'b0;
    always #(CLK_PERIOD_NS/2) i_clk = ~i_clk;

    // ========================================================================
    // Synchronous BRAM models
    //
    // These intentionally match the RTL memories:
    //   * instruction read: one clock latency
    //   * data read:        one clock latency
    //   * data write:       byte enables
    // ========================================================================

    initial begin
        i_imem_data = NOP;
        i_dmem_data = 32'b0;
    end

    always @(posedge i_clk) begin
        if ((o_imem_addr >> 2) < IMEM_WORDS)
            i_imem_data <= imem[o_imem_addr[IMEM_AW+1:2]];
        else
            i_imem_data <= NOP;
    end

    always @(posedge i_clk) begin
        if ((o_dmem_addr >> 2) < DMEM_WORDS)
            i_dmem_data <= dmem[o_dmem_addr[DMEM_AW+1:2]];
        else
            i_dmem_data <= 32'hDEAD_BEEF;

        if (o_dmem_wr_en === 1'b1) begin
            if ((o_dmem_addr >> 2) < DMEM_WORDS) begin
                if (o_dmem_byt_en[0]) dmem[o_dmem_addr[DMEM_AW+1:2]][7:0]   <= o_dmem_wr_data[7:0];
                if (o_dmem_byt_en[1]) dmem[o_dmem_addr[DMEM_AW+1:2]][15:8]  <= o_dmem_wr_data[15:8];
                if (o_dmem_byt_en[2]) dmem[o_dmem_addr[DMEM_AW+1:2]][23:16] <= o_dmem_wr_data[23:16];
                if (o_dmem_byt_en[3]) dmem[o_dmem_addr[DMEM_AW+1:2]][31:24] <= o_dmem_wr_data[31:24];
            end else begin
                protocol_errors = protocol_errors + 1;
                $error("DMEM write out of range: addr=%08h", o_dmem_addr);
            end
        end
    end

    // ========================================================================
    // Always-on interface / architectural sanity monitors
    // ========================================================================

    always @(posedge i_clk) begin
        if (!i_rst) begin
            if (dut.fetch_stall)
                stall_count = stall_count + 1;

            if (dut.ex_redirect)
                redirect_count = redirect_count + 1;

            if (o_dmem_wr_en)
                store_count = store_count + 1;

            if (!$isunknown(o_imem_addr) && (o_imem_addr[1:0] !== 2'b00)) begin
                protocol_errors = protocol_errors + 1;
                $error("IMEM address is not word aligned: %08h", o_imem_addr);
            end

            if (o_dmem_wr_en === 1'b1) begin
                if ($isunknown({o_dmem_addr, o_dmem_wr_data, o_dmem_byt_en})) begin
                    protocol_errors = protocol_errors + 1;
                    $error("Unknown/X on active DMEM write interface");
                end

                case (o_dmem_byt_en)
                    4'b0001, 4'b0010, 4'b0100, 4'b1000,
                    4'b0011, 4'b1100, 4'b1111: ;
                    default: begin
                        protocol_errors = protocol_errors + 1;
                        $error("Illegal byte enable on DMEM write: %b", o_dmem_byt_en);
                    end
                endcase
            end
        end else begin
            if (o_dmem_wr_en === 1'b1) begin
                protocol_errors = protocol_errors + 1;
                $error("DMEM write asserted during reset");
            end
        end
    end

    // ========================================================================
    // Generic RV32I instruction encoders
    // ========================================================================

    function automatic logic [31:0] enc_r(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_i(
        input int signed   imm,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input logic [4:0]  rd,
        input logic [6:0]  opcode
    );
        logic [11:0] imm12;
        begin
            imm12 = imm[11:0];
            enc_i = {imm12, rs1, funct3, rd, opcode};
        end
    endfunction

    function automatic logic [31:0] enc_s(
        input int signed   imm,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input logic [6:0]  opcode
    );
        logic [11:0] imm12;
        begin
            imm12 = imm[11:0];
            enc_s = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
        end
    endfunction

    function automatic logic [31:0] enc_b(
        input int signed   offset,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input logic [6:0]  opcode
    );
        logic [12:0] imm13;
        begin
            imm13 = offset[12:0];
            enc_b = {
                imm13[12],
                imm13[10:5],
                rs2,
                rs1,
                funct3,
                imm13[4:1],
                imm13[11],
                opcode
            };
        end
    endfunction

    function automatic logic [31:0] enc_u(
        input logic [19:0] imm20,
        input logic [4:0]  rd,
        input logic [6:0]  opcode
    );
        enc_u = {imm20, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_j(
        input int signed   offset,
        input logic [4:0]  rd,
        input logic [6:0]  opcode
    );
        logic [20:0] imm21;
        begin
            imm21 = offset[20:0];
            enc_j = {
                imm21[20],
                imm21[10:1],
                imm21[11],
                imm21[19:12],
                rd,
                opcode
            };
        end
    endfunction

    // ========================================================================
    // Readable instruction helpers
    // ========================================================================

    function automatic logic [31:0] rv_add  (input logic [4:0] rd, rs1, rs2); rv_add   = enc_r(7'b0000000, rs2, rs1, F3_ADD,  rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_sub  (input logic [4:0] rd, rs1, rs2); rv_sub   = enc_r(7'b0100000, rs2, rs1, F3_ADD,  rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_sll  (input logic [4:0] rd, rs1, rs2); rv_sll   = enc_r(7'b0000000, rs2, rs1, F3_SLL,  rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_slt  (input logic [4:0] rd, rs1, rs2); rv_slt   = enc_r(7'b0000000, rs2, rs1, F3_SLT,  rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_sltu (input logic [4:0] rd, rs1, rs2); rv_sltu  = enc_r(7'b0000000, rs2, rs1, F3_SLTU, rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_xor  (input logic [4:0] rd, rs1, rs2); rv_xor   = enc_r(7'b0000000, rs2, rs1, F3_XOR,  rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_srl  (input logic [4:0] rd, rs1, rs2); rv_srl   = enc_r(7'b0000000, rs2, rs1, F3_SR,   rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_sra  (input logic [4:0] rd, rs1, rs2); rv_sra   = enc_r(7'b0100000, rs2, rs1, F3_SR,   rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_or   (input logic [4:0] rd, rs1, rs2); rv_or    = enc_r(7'b0000000, rs2, rs1, F3_OR,   rd, OP_ALU); endfunction
    function automatic logic [31:0] rv_and  (input logic [4:0] rd, rs1, rs2); rv_and   = enc_r(7'b0000000, rs2, rs1, F3_AND,  rd, OP_ALU); endfunction

    function automatic logic [31:0] rv_addi (input logic [4:0] rd, rs1, input int signed imm); rv_addi = enc_i(imm, rs1, F3_ADD,  rd, OP_IMM); endfunction
    function automatic logic [31:0] rv_slti (input logic [4:0] rd, rs1, input int signed imm); rv_slti = enc_i(imm, rs1, F3_SLT,  rd, OP_IMM); endfunction
    function automatic logic [31:0] rv_sltiu(input logic [4:0] rd, rs1, input int signed imm); rv_sltiu= enc_i(imm, rs1, F3_SLTU, rd, OP_IMM); endfunction
    function automatic logic [31:0] rv_xori (input logic [4:0] rd, rs1, input int signed imm); rv_xori = enc_i(imm, rs1, F3_XOR,  rd, OP_IMM); endfunction
    function automatic logic [31:0] rv_ori  (input logic [4:0] rd, rs1, input int signed imm); rv_ori  = enc_i(imm, rs1, F3_OR,   rd, OP_IMM); endfunction
    function automatic logic [31:0] rv_andi (input logic [4:0] rd, rs1, input int signed imm); rv_andi = enc_i(imm, rs1, F3_AND,  rd, OP_IMM); endfunction
    function automatic logic [31:0] rv_slli (input logic [4:0] rd, rs1, input int unsigned shamt); rv_slli = enc_i(shamt & 31, rs1, F3_SLL, rd, OP_IMM); endfunction
    function automatic logic [31:0] rv_srli (input logic [4:0] rd, rs1, input int unsigned shamt); rv_srli = enc_i(shamt & 31, rs1, F3_SR, rd, OP_IMM); endfunction
    function automatic logic [31:0] rv_srai (input logic [4:0] rd, rs1, input int unsigned shamt); rv_srai = enc_i(12'h400 | (shamt & 31), rs1, F3_SR, rd, OP_IMM); endfunction

    function automatic logic [31:0] rv_lb (input logic [4:0] rd, rs1, input int signed imm); rv_lb  = enc_i(imm, rs1, F3_LB,  rd, OP_LOAD); endfunction
    function automatic logic [31:0] rv_lh (input logic [4:0] rd, rs1, input int signed imm); rv_lh  = enc_i(imm, rs1, F3_LH,  rd, OP_LOAD); endfunction
    function automatic logic [31:0] rv_lw (input logic [4:0] rd, rs1, input int signed imm); rv_lw  = enc_i(imm, rs1, F3_LW,  rd, OP_LOAD); endfunction
    function automatic logic [31:0] rv_lbu(input logic [4:0] rd, rs1, input int signed imm); rv_lbu = enc_i(imm, rs1, F3_LBU, rd, OP_LOAD); endfunction
    function automatic logic [31:0] rv_lhu(input logic [4:0] rd, rs1, input int signed imm); rv_lhu = enc_i(imm, rs1, F3_LHU, rd, OP_LOAD); endfunction

    function automatic logic [31:0] rv_sb(input logic [4:0] rs2, rs1, input int signed imm); rv_sb = enc_s(imm, rs2, rs1, F3_SB, OP_STORE); endfunction
    function automatic logic [31:0] rv_sh(input logic [4:0] rs2, rs1, input int signed imm); rv_sh = enc_s(imm, rs2, rs1, F3_SH, OP_STORE); endfunction
    function automatic logic [31:0] rv_sw(input logic [4:0] rs2, rs1, input int signed imm); rv_sw = enc_s(imm, rs2, rs1, F3_SW, OP_STORE); endfunction

    function automatic logic [31:0] rv_beq (input logic [4:0] rs1, rs2, input int signed off); rv_beq  = enc_b(off, rs2, rs1, F3_BEQ,  OP_BRANCH); endfunction
    function automatic logic [31:0] rv_bne (input logic [4:0] rs1, rs2, input int signed off); rv_bne  = enc_b(off, rs2, rs1, F3_BNE,  OP_BRANCH); endfunction
    function automatic logic [31:0] rv_blt (input logic [4:0] rs1, rs2, input int signed off); rv_blt  = enc_b(off, rs2, rs1, F3_BLT,  OP_BRANCH); endfunction
    function automatic logic [31:0] rv_bge (input logic [4:0] rs1, rs2, input int signed off); rv_bge  = enc_b(off, rs2, rs1, F3_BGE,  OP_BRANCH); endfunction
    function automatic logic [31:0] rv_bltu(input logic [4:0] rs1, rs2, input int signed off); rv_bltu = enc_b(off, rs2, rs1, F3_BLTU, OP_BRANCH); endfunction
    function automatic logic [31:0] rv_bgeu(input logic [4:0] rs1, rs2, input int signed off); rv_bgeu = enc_b(off, rs2, rs1, F3_BGEU, OP_BRANCH); endfunction

    function automatic logic [31:0] rv_lui  (input logic [4:0] rd, input logic [19:0] imm20); rv_lui   = enc_u(imm20, rd, OP_LUI); endfunction
    function automatic logic [31:0] rv_auipc(input logic [4:0] rd, input logic [19:0] imm20); rv_auipc = enc_u(imm20, rd, OP_AUIPC); endfunction
    function automatic logic [31:0] rv_jal  (input logic [4:0] rd, input int signed off); rv_jal = enc_j(off, rd, OP_JAL); endfunction
    function automatic logic [31:0] rv_jalr (input logic [4:0] rd, rs1, input int signed imm); rv_jalr = enc_i(imm, rs1, 3'b000, rd, OP_JALR); endfunction

    // ========================================================================
    // Testbench utility tasks
    // ========================================================================

    task automatic clear_memories;
        int i;
        begin
            for (i = 0; i < IMEM_WORDS; i = i + 1)
                imem[i] = NOP;

            for (i = 0; i < DMEM_WORDS; i = i + 1)
                dmem[i] = 32'b0;
        end
    endtask

    task automatic emit(input logic [31:0] instr, inout int pc);
        begin
            if ((pc >> 2) >= IMEM_WORDS) begin
                $fatal(1, "Program exceeds IMEM size at PC=%0d", pc);
            end
            imem[pc >> 2] = instr;
            pc = pc + 4;
        end
    endtask

    task automatic emit_end(inout int pc, input int signature);
        begin
            emit(rv_addi(5'd29, 5'd0, SIG_ADDR), pc);
            emit(rv_addi(5'd28, 5'd0, signature), pc);
            emit(rv_sw(5'd28, 5'd29, 0), pc);
            emit(rv_jal(5'd0, 0), pc); // stop here forever
        end
    endtask

    task automatic begin_program(input string name);
        begin
            $display("\n============================================================");
            $display("TEST: %s", name);
            $display("============================================================");

            // Assert reset before touching memories so an old in-flight store
            // from the previous test cannot corrupt newly-cleared memory.
            @(negedge i_clk);
            i_rst = 1'b1;
            @(negedge i_clk);

            clear_memories();
            stall_count    = 0;
            redirect_count = 0;
            store_count    = 0;
        end
    endtask

    task automatic release_reset;
        begin
            repeat (3) @(posedge i_clk);
            @(negedge i_clk);
            i_rst = 1'b0;
        end
    endtask

    task automatic wait_for_signature(
        input logic [31:0] signature,
        input int max_cycles,
        input string name
    );
        int cycles;
        begin
            cycles = 0;
            while ((dmem[SIG_WORD] !== signature) && (cycles < max_cycles)) begin
                @(posedge i_clk);
                cycles = cycles + 1;
            end
            @(negedge i_clk);

            if (dmem[SIG_WORD] !== signature) begin
                checks_failed = checks_failed + 1;
                $error("[FAIL] %s timed out after %0d cycles (signature=%08h expected=%08h)",
                       name, cycles, dmem[SIG_WORD], signature);
            end else begin
                checks_passed = checks_passed + 1;
                $display("[PASS] %s completed in %0d cycles", name, cycles);
            end
        end
    endtask

    task automatic expect_reg(
        input int reg_idx,
        input logic [31:0] expected,
        input string what
    );
        logic [31:0] got;
        begin
            if (reg_idx == 0)
                got = 32'b0;
            else
                got = dut.u_reg_file.registers[reg_idx];

            if (got !== expected) begin
                checks_failed = checks_failed + 1;
                $error("[FAIL] %-48s x%0d got=%08h expected=%08h", what, reg_idx, got, expected);
            end else begin
                checks_passed = checks_passed + 1;
                $display("[PASS] %-48s x%0d = %08h", what, reg_idx, got);
            end
        end
    endtask

    task automatic expect_internal_reg0_zero(input string what);
        begin
            if (dut.u_reg_file.registers[0] !== 32'b0) begin
                checks_failed = checks_failed + 1;
                $error("[FAIL] %-48s internal x0=%08h", what, dut.u_reg_file.registers[0]);
            end else begin
                checks_passed = checks_passed + 1;
                $display("[PASS] %-48s internal x0 = 00000000", what);
            end
        end
    endtask

    task automatic expect_mem_word(
        input logic [31:0] byte_addr,
        input logic [31:0] expected,
        input string what
    );
        logic [31:0] got;
        begin
            got = dmem[byte_addr >> 2];
            if (got !== expected) begin
                checks_failed = checks_failed + 1;
                $error("[FAIL] %-48s mem[%08h]=%08h expected=%08h", what, byte_addr, got, expected);
            end else begin
                checks_passed = checks_passed + 1;
                $display("[PASS] %-48s mem[%08h] = %08h", what, byte_addr, got);
            end
        end
    endtask

    task automatic expect_true(input bit condition, input string what);
        begin
            if (!condition) begin
                checks_failed = checks_failed + 1;
                $error("[FAIL] %s", what);
            end else begin
                checks_passed = checks_passed + 1;
                $display("[PASS] %s", what);
            end
        end
    endtask

    // ========================================================================
    // TEST 1: Reset, pipeline reset state, x0 semantics
    // ========================================================================

    task automatic test_reset_and_x0;
        int pc;
        int r;
        begin
            begin_program("Reset behavior and x0 hardwiring");

            pc = 0;
            emit(rv_addi(5'd1, 5'd0, 123), pc);
            emit(rv_addi(5'd0, 5'd1, 7), pc);   // must never modify x0
            emit(rv_addi(5'd2, 5'd0, 5), pc);
            emit_end(pc, 1);

            repeat (3) @(posedge i_clk);
            @(negedge i_clk);

            expect_true(o_imem_addr === 32'h0000_0000, "Fetch PC held at RESET_VECTOR while reset is asserted");
            expect_true(dut.if_valid === 1'b0, "IF valid cleared by reset");
            expect_true(dut.id_valid === 1'b0, "ID/EX valid cleared by reset");
            expect_true(dut.ex_valid === 1'b0, "EX/MEM valid cleared by reset");
            expect_true(dut.wb_valid === 1'b0, "MEM/WB valid cleared by reset");
            expect_true(o_dmem_wr_en === 1'b0, "No data-memory write during reset");

            for (r = 0; r < 32; r = r + 1) begin
                if (dut.u_reg_file.registers[r] !== 32'b0) begin
                    checks_failed = checks_failed + 1;
                    $error("[FAIL] Register x%0d not reset: %08h", r, dut.u_reg_file.registers[r]);
                end
            end

            @(negedge i_clk);
            i_rst = 1'b0;

            wait_for_signature(32'd1, 100, "Reset/x0 program");
            expect_reg(1, 32'd123, "Normal register write after reset");
            expect_reg(2, 32'd5,   "Execution continues after attempted x0 write");
            expect_reg(0, 32'd0,   "Architectural x0 read remains zero");
            expect_internal_reg0_zero("Physical x0 storage was not written");
        end
    endtask

    // ========================================================================
    // TEST 2: RV32I immediate ALU instructions + immediate sign extension
    // ========================================================================

    task automatic test_immediate_alu;
        int pc;
        begin
            begin_program("I-type ALU operations and immediate edge cases");
            pc = 0;

            emit(rv_addi (5'd1,  5'd0, -1),    pc); // FFFFFFFF
            emit(rv_addi (5'd2,  5'd0, 2047),  pc); // max +12-bit
            emit(rv_addi (5'd3,  5'd0, -2048), pc); // min -12-bit
            emit(rv_slti (5'd4,  5'd3, -1),    pc);
            emit(rv_slti (5'd5,  5'd2, -1),    pc);
            emit(rv_sltiu(5'd6,  5'd0, -1),    pc);
            emit(rv_xori (5'd7,  5'd1, 12'h055), pc);
            emit(rv_ori  (5'd8,  5'd0, 12'h123), pc);
            emit(rv_andi (5'd9,  5'd1, 12'h0F0), pc);
            emit(rv_slli (5'd10, 5'd2, 4),      pc);
            emit(rv_srli (5'd11, 5'd1, 28),     pc);
            emit(rv_srai (5'd12, 5'd1, 28),     pc);
            emit(rv_slli (5'd13, 5'd1, 31),     pc);
            emit_end(pc, 2);

            release_reset();
            wait_for_signature(32'd2, 150, "Immediate ALU program");

            expect_reg(1,  32'hFFFF_FFFF, "ADDI sign extends -1");
            expect_reg(2,  32'h0000_07FF, "ADDI maximum positive 12-bit immediate");
            expect_reg(3,  32'hFFFF_F800, "ADDI minimum negative 12-bit immediate");
            expect_reg(4,  32'd1,         "SLTI signed true");
            expect_reg(5,  32'd0,         "SLTI signed false");
            expect_reg(6,  32'd1,         "SLTIU compares sign-extended immediate as unsigned");
            expect_reg(7,  32'hFFFF_FFAA, "XORI result");
            expect_reg(8,  32'h0000_0123, "ORI result");
            expect_reg(9,  32'h0000_00F0, "ANDI result");
            expect_reg(10, 32'h0000_7FF0, "SLLI result");
            expect_reg(11, 32'h0000_000F, "SRLI zero fill");
            expect_reg(12, 32'hFFFF_FFFF, "SRAI sign fill");
            expect_reg(13, 32'h8000_0000, "SLLI shamt=31 boundary");
        end
    endtask

    // ========================================================================
    // TEST 3: Register-register ALU + dense forwarding chains
    // ========================================================================

    task automatic test_rtype_and_forwarding;
        int pc;
        begin
            begin_program("R-type ALU operations and MEM/WB forwarding");
            pc = 0;

            emit(rv_addi(5'd1, 5'd0, 7),  pc);
            emit(rv_addi(5'd2, 5'd0, -3), pc);

            // Dense dependencies intentionally exercise both source operands.
            emit(rv_add (5'd3,  5'd1, 5'd2), pc);
            emit(rv_sub (5'd4,  5'd1, 5'd2), pc);
            emit(rv_and (5'd5,  5'd1, 5'd2), pc);
            emit(rv_or  (5'd6,  5'd1, 5'd2), pc);
            emit(rv_xor (5'd7,  5'd1, 5'd2), pc);
            emit(rv_sll (5'd8,  5'd1, 5'd2), pc);
            emit(rv_srl (5'd9,  5'd2, 5'd1), pc);
            emit(rv_sra (5'd10, 5'd2, 5'd1), pc);
            emit(rv_slt (5'd11, 5'd2, 5'd1), pc);
            emit(rv_sltu(5'd12, 5'd2, 5'd1), pc);

            // Back-to-back RAW chain: result from immediately preceding ops.
            emit(rv_addi(5'd20, 5'd0, 10),    pc);
            emit(rv_addi(5'd21, 5'd20, 5),    pc); // x20 -> x21
            emit(rv_add (5'd22, 5'd21, 5'd20),pc); // MEM + WB sources simultaneously
            emit(rv_sub (5'd23, 5'd22, 5'd21),pc);
            emit(rv_add (5'd24, 5'd23, 5'd22),pc);

            emit_end(pc, 3);

            release_reset();
            wait_for_signature(32'd3, 200, "R-type/forwarding program");

            expect_reg(3,  32'h0000_0004, "ADD");
            expect_reg(4,  32'h0000_000A, "SUB");
            expect_reg(5,  32'h0000_0005, "AND");
            expect_reg(6,  32'hFFFF_FFFF, "OR");
            expect_reg(7,  32'hFFFF_FFFA, "XOR");
            expect_reg(8,  32'hE000_0000, "SLL uses rs2[4:0]");
            expect_reg(9,  32'h01FF_FFFF, "SRL");
            expect_reg(10, 32'hFFFF_FFFF, "SRA");
            expect_reg(11, 32'd1,         "SLT signed");
            expect_reg(12, 32'd0,         "SLTU unsigned");

            expect_reg(20, 32'd10, "Forwarding chain seed");
            expect_reg(21, 32'd15, "Immediate RAW forwarding");
            expect_reg(22, 32'd25, "Two-source mixed-age forwarding");
            expect_reg(23, 32'd10, "Back-to-back SUB forwarding");
            expect_reg(24, 32'd35, "Back-to-back ADD forwarding");
        end
    endtask

    // ========================================================================
    // TEST 4: LUI and AUIPC
    // ========================================================================

    task automatic test_upper_immediates;
        int pc;
        begin
            begin_program("LUI and AUIPC PC-relative behavior");
            pc = 0;

            emit(rv_lui(5'd1, 20'h12345), pc);       // PC 0
            emit(rv_auipc(5'd2, 20'h00001), pc);     // PC 4 -> 0x1004
            emit(NOP, pc);                           // PC 8
            emit(rv_auipc(5'd3, 20'hFFFFF), pc);     // PC 12 -> 0xFFFFF00C
            emit(rv_lui(5'd4, 20'hFFFFF), pc);
            emit_end(pc, 4);

            release_reset();
            wait_for_signature(32'd4, 120, "LUI/AUIPC program");

            expect_reg(1, 32'h1234_5000, "LUI places immediate in bits [31:12]");
            expect_reg(2, 32'h0000_1004, "AUIPC uses instruction PC at nonzero address");
            expect_reg(3, 32'hFFFF_F00C, "AUIPC wraps 32-bit addition correctly");
            expect_reg(4, 32'hFFFF_F000, "LUI high-bit pattern");
        end
    endtask

    // ========================================================================
    // TEST 5: Stores at every legal byte/halfword lane + store forwarding
    // ========================================================================

    task automatic test_stores;
        int pc;
        begin
            begin_program("SB/SH/SW byte lanes and store-data forwarding");
            pc = 0;

            emit(rv_addi(5'd1, 5'd0, 32'h100), pc); // base = 0x100

            // Build A1B2C3D4 and immediately store it.
            emit(rv_lui (5'd2, 20'hA1B2C), pc);
            emit(rv_addi(5'd2, 5'd2, 12'h3D4), pc);
            emit(rv_sw  (5'd2, 5'd1, 0), pc);

            // Four byte offsets. Each ADDI -> SB pair also tests store-data forwarding.
            emit(rv_addi(5'd3, 5'd0, 8'h11), pc);
            emit(rv_sb  (5'd3, 5'd1, 4), pc);
            emit(rv_addi(5'd3, 5'd0, 8'h22), pc);
            emit(rv_sb  (5'd3, 5'd1, 5), pc);
            emit(rv_addi(5'd3, 5'd0, 8'h33), pc);
            emit(rv_sb  (5'd3, 5'd1, 6), pc);
            emit(rv_addi(5'd3, 5'd0, 8'h44), pc);
            emit(rv_sb  (5'd3, 5'd1, 7), pc);

            // Lower and upper halfword lanes.
            emit(rv_lui (5'd4, 20'h00005), pc);
            emit(rv_addi(5'd4, 5'd4, 12'h566), pc); // 0x5566
            emit(rv_sh  (5'd4, 5'd1, 8), pc);

            emit(rv_lui (5'd5, 20'h00007), pc);
            emit(rv_addi(5'd5, 5'd5, 12'h788), pc); // 0x7788
            emit(rv_sh  (5'd5, 5'd1, 10), pc);

            emit_end(pc, 5);

            release_reset();
            wait_for_signature(32'd5, 220, "Store program");

            expect_mem_word(32'h100, 32'hA1B2_C3D4, "SW writes all four bytes");
            expect_mem_word(32'h104, 32'h4433_2211, "SB offsets 0/1/2/3 select correct byte lanes");
            expect_mem_word(32'h108, 32'h7788_5566, "SH selects lower and upper halfword lanes");
            expect_true(store_count >= 8, "All expected stores reached the memory interface");
        end
    endtask

    // ========================================================================
    // TEST 6: Loads, byte offsets, halfword selection, sign/zero extension
    // ========================================================================

    task automatic test_loads;
        int pc;
        begin
            begin_program("LB/LBU/LH/LHU/LW formatting and back-to-back loads");

            // bytes at 0x100: 01 7F FF 80
            dmem[32'h100 >> 2] = 32'h80FF_7F01;
            // halfwords at 0x104: low=7FFF, high=8001
            dmem[32'h104 >> 2] = 32'h8001_7FFF;

            pc = 0;
            emit(rv_addi(5'd1, 5'd0, 32'h100), pc);

            emit(rv_lb (5'd2,  5'd1, 0), pc);
            emit(rv_lb (5'd3,  5'd1, 1), pc);
            emit(rv_lb (5'd4,  5'd1, 2), pc);
            emit(rv_lb (5'd5,  5'd1, 3), pc);
            emit(rv_lbu(5'd6,  5'd1, 2), pc);
            emit(rv_lbu(5'd7,  5'd1, 3), pc);
            emit(rv_lh (5'd8,  5'd1, 4), pc);
            emit(rv_lh (5'd9,  5'd1, 6), pc);
            emit(rv_lhu(5'd10, 5'd1, 6), pc);
            emit(rv_lw (5'd11, 5'd1, 4), pc);

            emit_end(pc, 6);

            release_reset();
            wait_for_signature(32'd6, 220, "Load formatting program");

            expect_reg(2,  32'h0000_0001, "LB byte lane 0 positive");
            expect_reg(3,  32'h0000_007F, "LB byte lane 1 positive");
            expect_reg(4,  32'hFFFF_FFFF, "LB byte lane 2 sign extension");
            expect_reg(5,  32'hFFFF_FF80, "LB byte lane 3 sign extension");
            expect_reg(6,  32'h0000_00FF, "LBU byte lane 2 zero extension");
            expect_reg(7,  32'h0000_0080, "LBU byte lane 3 zero extension");
            expect_reg(8,  32'h0000_7FFF, "LH lower half positive");
            expect_reg(9,  32'hFFFF_8001, "LH upper half sign extension");
            expect_reg(10, 32'h0000_8001, "LHU upper half zero extension");
            expect_reg(11, 32'h8001_7FFF, "LW full 32-bit word");
        end
    endtask

    // ========================================================================
    // TEST 7: Load-use interlocks feeding ALU, store, branch, and JALR
    // ========================================================================

    task automatic test_load_use_hazards;
        int pc;
        begin
            begin_program("Load-use stalls + branch/JALR dependencies");

            dmem[32'h100 >> 2] = 32'd10;
            dmem[32'h108 >> 2] = 32'd65; // odd JALR target -> must become 64

            pc = 0;
            emit(rv_addi(5'd1, 5'd0, 32'h100), pc);       // 0
            emit(rv_lw  (5'd2, 5'd1, 0), pc);             // 4
            emit(rv_add (5'd3, 5'd2, 5'd2), pc);          // 8: immediate load-use
            emit(rv_addi(5'd4, 5'd2, 5), pc);             // 12
            emit(rv_sw  (5'd3, 5'd1, 4), pc);             // 16
            emit(rv_lw  (5'd5, 5'd1, 4), pc);             // 20
            emit(rv_beq (5'd5, 5'd3, 8), pc);             // 24: load -> branch
            emit(rv_addi(5'd31, 5'd31, 1), pc);           // 28: wrong path
            emit(rv_addi(5'd6, 5'd0, 2), pc);             // 32
            emit(rv_lw  (5'd7, 5'd1, 8), pc);             // 36
            emit(rv_jalr(5'd8, 5'd7, 0), pc);             // 40: load -> JALR, target 64
            emit(rv_addi(5'd31, 5'd31, 2), pc);           // 44: wrong path
            emit(NOP, pc);                                // 48
            emit(NOP, pc);                                // 52
            emit(NOP, pc);                                // 56
            emit(NOP, pc);                                // 60
            emit(rv_addi(5'd9, 5'd0, 9), pc);             // 64
            emit_end(pc, 7);

            release_reset();
            wait_for_signature(32'd7, 300, "Load-use hazard program");

            expect_reg(2,  32'd10, "Loaded value reaches register file");
            expect_reg(3,  32'd20, "Load-use ALU consumer receives correct value");
            expect_reg(4,  32'd15, "Subsequent load consumer remains correct");
            expect_mem_word(32'h104, 32'd20, "Forwarded ALU result used as store data");
            expect_reg(5,  32'd20, "Reloaded store result");
            expect_reg(6,  32'd2,  "Load-dependent BEQ redirects correctly");
            expect_reg(7,  32'd65, "JALR target loaded from memory");
            expect_reg(8,  32'd44, "JALR link is PC+4");
            expect_reg(9,  32'd9,  "JALR reaches aligned target");
            expect_reg(31, 32'd0,  "Wrong-path instructions were flushed");
            expect_true(stall_count >= 3, "At least three load-use interlocks were generated");
        end
    endtask

    // ========================================================================
    // TEST 8: Every branch condition, both taken and not-taken
    // ========================================================================

    task automatic test_all_branches;
        int pc;
        begin
            begin_program("BEQ/BNE/BLT/BGE/BLTU/BGEU taken and not-taken");
            pc = 0;

            emit(rv_addi(5'd1, 5'd0, -1), pc); // signed -1 / unsigned FFFFFFFF
            emit(rv_addi(5'd2, 5'd0,  1), pc);

            // Taken branch: skipped instruction increments x31 and must be flushed.
            // Not-taken branch: following assignment must execute.

            emit(rv_beq (5'd1, 5'd1, 8), pc);
            emit(rv_addi(5'd31, 5'd31, 1), pc);
            emit(rv_addi(5'd10, 5'd0, 10), pc);

            emit(rv_beq (5'd1, 5'd2, 8), pc);
            emit(rv_addi(5'd11, 5'd0, 11), pc);
            emit(NOP, pc);

            emit(rv_bne (5'd1, 5'd2, 8), pc);
            emit(rv_addi(5'd31, 5'd31, 1), pc);
            emit(rv_addi(5'd12, 5'd0, 12), pc);

            emit(rv_bne (5'd1, 5'd1, 8), pc);
            emit(rv_addi(5'd13, 5'd0, 13), pc);
            emit(NOP, pc);

            emit(rv_blt (5'd1, 5'd2, 8), pc); // -1 < +1
            emit(rv_addi(5'd31, 5'd31, 1), pc);
            emit(rv_addi(5'd14, 5'd0, 14), pc);

            emit(rv_blt (5'd2, 5'd1, 8), pc);
            emit(rv_addi(5'd15, 5'd0, 15), pc);
            emit(NOP, pc);

            emit(rv_bge (5'd2, 5'd1, 8), pc); // +1 >= -1
            emit(rv_addi(5'd31, 5'd31, 1), pc);
            emit(rv_addi(5'd16, 5'd0, 16), pc);

            emit(rv_bge (5'd1, 5'd2, 8), pc);
            emit(rv_addi(5'd17, 5'd0, 17), pc);
            emit(NOP, pc);

            emit(rv_bltu(5'd2, 5'd1, 8), pc); // 1 < FFFFFFFF
            emit(rv_addi(5'd31, 5'd31, 1), pc);
            emit(rv_addi(5'd18, 5'd0, 18), pc);

            emit(rv_bltu(5'd1, 5'd2, 8), pc);
            emit(rv_addi(5'd19, 5'd0, 19), pc);
            emit(NOP, pc);

            emit(rv_bgeu(5'd1, 5'd2, 8), pc); // FFFFFFFF >= 1
            emit(rv_addi(5'd31, 5'd31, 1), pc);
            emit(rv_addi(5'd20, 5'd0, 20), pc);

            emit(rv_bgeu(5'd2, 5'd1, 8), pc);
            emit(rv_addi(5'd21, 5'd0, 21), pc);
            emit(NOP, pc);

            emit_end(pc, 8);

            release_reset();
            wait_for_signature(32'd8, 450, "All-branch program");

            expect_reg(10, 32'd10, "BEQ taken target executed");
            expect_reg(11, 32'd11, "BEQ not-taken fallthrough executed");
            expect_reg(12, 32'd12, "BNE taken target executed");
            expect_reg(13, 32'd13, "BNE not-taken fallthrough executed");
            expect_reg(14, 32'd14, "BLT signed taken");
            expect_reg(15, 32'd15, "BLT signed not taken");
            expect_reg(16, 32'd16, "BGE signed taken");
            expect_reg(17, 32'd17, "BGE signed not taken");
            expect_reg(18, 32'd18, "BLTU unsigned taken");
            expect_reg(19, 32'd19, "BLTU unsigned not taken");
            expect_reg(20, 32'd20, "BGEU unsigned taken");
            expect_reg(21, 32'd21, "BGEU unsigned not taken");
            expect_reg(31, 32'd0,  "All six taken branches flushed wrong-path instruction");
        end
    endtask

    // ========================================================================
    // TEST 9: Negative branch immediate / backward loop
    // ========================================================================

    task automatic test_backward_branch_loop;
        int pc;
        begin
            begin_program("Backward branch and branch-source forwarding loop");
            pc = 0;

            emit(rv_addi(5'd1, 5'd0, 0), pc); // counter
            emit(rv_addi(5'd2, 5'd0, 5), pc); // limit
            emit(rv_addi(5'd1, 5'd1, 1), pc); // PC=8 loop body
            emit(rv_blt (5'd1, 5'd2, -4), pc);// PC=12 -> back to 8
            emit(rv_addi(5'd3, 5'd1, 0), pc);
            emit_end(pc, 9);

            release_reset();
            wait_for_signature(32'd9, 300, "Backward-loop program");

            expect_reg(1, 32'd5, "Loop iterates exactly five times");
            expect_reg(3, 32'd5, "Fallthrough sees final forwarded counter");
            expect_true(redirect_count >= 4, "Backward branch redirected on loop iterations");
        end
    endtask

    // ========================================================================
    // TEST 10: JAL and JALR link/flush/target alignment
    // ========================================================================

    task automatic test_jumps;
        int pc;
        begin
            begin_program("JAL/JALR targets, PC+4 links, and wrong-path flushing");
            pc = 0;

            // JAL at PC 0 -> PC 12, link x5=4.
            emit(rv_jal(5'd5, 12), pc);                 // 0
            emit(rv_addi(5'd31, 5'd31, 1), pc);        // 4 wrong path
            emit(rv_addi(5'd31, 5'd31, 2), pc);        // 8 wrong path
            emit(rv_addi(5'd1, 5'd0, 3), pc);          // 12

            // JAL at PC 16 -> PC 24, link x6=20.
            emit(rv_jal(5'd6, 8), pc);                  // 16
            emit(rv_addi(5'd31, 5'd31, 4), pc);        // 20 wrong path
            emit(rv_addi(5'd2, 5'd0, 5), pc);          // 24

            // Immediate dependency into JALR. 58 + (-1) = 57, and JALR must clear
            // target bit 0 to land at address 56.
            emit(rv_jal(5'd0, 12), pc);                 // 28 -> 40
            emit(NOP, pc);                              // 32
            emit(NOP, pc);                              // 36
            emit(rv_addi(5'd3, 5'd0, 58), pc);         // 40
            emit(rv_jalr(5'd7, 5'd3, -1), pc);         // 44 -> 57, then bit0 cleared -> 56
            emit(rv_addi(5'd31, 5'd31, 8), pc);        // 48 wrong path
            emit(rv_addi(5'd31, 5'd31, 16), pc);       // 52 wrong path
            emit(rv_addi(5'd4, 5'd0, 9), pc);          // 56 target
            emit_end(pc, 10);

            release_reset();
            wait_for_signature(32'd10, 250, "Jump program");

            expect_reg(5,  32'd4,  "JAL link from PC=0");
            expect_reg(6,  32'd20, "JAL link from PC=16");
            expect_reg(1,  32'd3,  "First JAL target executed");
            expect_reg(2,  32'd5,  "Second JAL target executed");
            expect_reg(7,  32'd48, "JALR link is PC+4");
            expect_reg(4,  32'd9,  "JALR negative immediate + bit-0 target masking");
            expect_reg(31, 32'd0,  "Jumps flushed all wrong-path side effects");
        end
    endtask

    // ========================================================================
    // TEST 11: Illegal encodings must have no architectural side effects
    // ========================================================================

    task automatic test_illegal_instructions;
        int pc;
        logic [31:0] illegal_store;
        logic [31:0] illegal_rtype;
        begin
            begin_program("Illegal instruction side-effect suppression and recovery");

            dmem[32'h100 >> 2] = 32'hCAFE_BABE;

            // STORE opcode with unsupported funct3=011.
            illegal_store = enc_s(0, 5'd2, 5'd1, 3'b011, OP_STORE);
            // R-type opcode with unsupported funct7=0000001 (M-extension style encoding).
            illegal_rtype = enc_r(7'b0000001, 5'd2, 5'd1, F3_ADD, 5'd3, OP_ALU);

            pc = 0;
            emit(rv_addi(5'd1, 5'd0, 32'h100), pc);
            emit(rv_addi(5'd2, 5'd0, 8'h55), pc);
            emit(illegal_store, pc);
            emit(illegal_rtype, pc);
            emit(32'h0000_0073, pc); // ECALL/SYSTEM -> illegal in this core
            emit(32'hFFFF_FFFF, pc); // unknown opcode
            emit(rv_addi(5'd4, 5'd0, 9), pc);
            emit_end(pc, 11);

            release_reset();
            wait_for_signature(32'd11, 180, "Illegal-instruction program");

            expect_mem_word(32'h100, 32'hCAFE_BABE, "Illegal store cannot modify memory");
            expect_reg(3, 32'd0, "Illegal R-type cannot write rd");
            expect_reg(4, 32'd9, "Pipeline recovers after illegal instructions");
        end
    endtask

    // ========================================================================
    // TEST 12: Deterministic randomized R-type stress
    //
    // Operands are kept within ADDI's signed 12-bit range. Every generated ALU
    // result is immediately stored, stressing ALU correctness, forwarding to
    // store data, and sustained pipeline throughput.
    // ========================================================================

    task automatic test_random_rtype_stress;
        int pc;
        int i;
        int op;
        int signed a;
        int signed b;
        int unsigned seed;
        logic [31:0] au;
        logic [31:0] bu;
        begin
            begin_program("Deterministic randomized R-type/forwarding stress");
            pc = 0;
            seed = 32'h5EED_1234;

            emit(rv_addi(5'd27, 5'd0, RAND_BASE), pc);

            for (i = 0; i < RAND_CASES; i = i + 1) begin
                a = int'($urandom(seed) % 2048) - 1024;
                b = int'($urandom(seed) % 2048) - 1024;
                au = a;
                bu = b;
                op = i % 10;

                emit(rv_addi(5'd1, 5'd0, a), pc);
                emit(rv_addi(5'd2, 5'd0, b), pc);

                case (op)
                    0: begin emit(rv_add (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = au + bu; end
                    1: begin emit(rv_sub (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = au - bu; end
                    2: begin emit(rv_and (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = au & bu; end
                    3: begin emit(rv_or  (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = au | bu; end
                    4: begin emit(rv_xor (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = au ^ bu; end
                    5: begin emit(rv_sll (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = au << bu[4:0]; end
                    6: begin emit(rv_srl (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = au >> bu[4:0]; end
                    7: begin emit(rv_sra (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = $signed(au) >>> bu[4:0]; end
                    8: begin emit(rv_slt (5'd3, 5'd1, 5'd2), pc); rand_expected[i] = ($signed(au) < $signed(bu)) ? 32'd1 : 32'd0; end
                    9: begin emit(rv_sltu(5'd3, 5'd1, 5'd2), pc); rand_expected[i] = (au < bu) ? 32'd1 : 32'd0; end
                    default: rand_expected[i] = 32'hDEAD_DEAD;
                endcase

                // Immediate consumer of x3 -> exercises store-data forwarding.
                emit(rv_sw(5'd3, 5'd27, i*4), pc);
            end

            emit_end(pc, 12);

            release_reset();
            wait_for_signature(32'd12, 1200, "Randomized R-type stress program");

            for (i = 0; i < RAND_CASES; i = i + 1) begin
                expect_mem_word(RAND_BASE + i*4, rand_expected[i], $sformatf("Random ALU case %0d", i));
            end
        end
    endtask

    // ========================================================================
    // Main sequence
    // ========================================================================

    initial begin
        checks_passed  = 0;
        checks_failed  = 0;
        protocol_errors = 0;
        stall_count     = 0;
        redirect_count  = 0;
        store_count     = 0;
        i_rst            = 1'b1;

        clear_memories();

        // Give the clock/memory models a clean start.
        repeat (2) @(posedge i_clk);

        test_reset_and_x0();
        test_immediate_alu();
        test_rtype_and_forwarding();
        test_upper_immediates();
        test_stores();
        test_loads();
        test_load_use_hazards();
        test_all_branches();
        test_backward_branch_loop();
        test_jumps();
        test_illegal_instructions();
        test_random_rtype_stress();

        @(negedge i_clk);
        i_rst = 1'b1;

        $display("\n============================================================");
        $display("RISC-V CORE TESTBENCH SUMMARY");
        $display("============================================================");
        $display("Checks passed   : %0d", checks_passed);
        $display("Checks failed   : %0d", checks_failed);
        $display("Protocol errors : %0d", protocol_errors);
        $display("============================================================");

        if ((checks_failed == 0) && (protocol_errors == 0)) begin
            $display("[PASS] ALL CORE TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "[FAIL] CORE TESTBENCH FAILED");
        end
    end

endmodule

`default_nettype wire
