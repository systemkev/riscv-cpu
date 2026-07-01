// ============================================================================
// File Name   : common_pkg.sv
// Author      : Kevin Toledo Fernandez / GitHub: ktf-repos
// Date        : 2026-06-10
// Project     : RISC-V 32-bit Processor
// Description : Centralized package definition for the RV32I processor. 
//               Contains globally accessible typed enumerations (ALU operations, 
//               branch conditions, memory access sizes, register names) and 
//               constant parameters for instruction opcodes and function fields. 
//
// License     : MIT
// ============================================================================

package common_pkg;
    typedef enum logic [3:0] {
        ARITH_ADD,          // adds two 32 bit numbers
        ARITH_SUB,          // subtracts two 32 bit numbers 
        LOGIC_AND,          // logical AND
        LOGIC_OR,           // logical OR
        LOGIC_XOR,          // logical XOR
        SHIFT_L_LOGIC,      // shift left logical
        SHIFT_R_LOGIC,      // shift right logical
        SHIFT_R_ARITH,      // shift right arithmetic
        SET_LESS_U,         // performs less than comparison assuming unsigned integer
        SET_LESS_S          // performs less than comparison assuming signed integer 
    } t_alu_ops;

    typedef enum logic [2:0] {
        S_LOAD_BYTE,
        U_LOAD_BYTE,
        S_LOAD_WORD,
        S_LOAD_HALF,
        U_LOAD_HALF,
        STORE_BYTE,
        STORE_HALF,
        STORE_WORD
    } t_mem_types;

    typedef enum logic [1:0] {
        WR_ALU_RES,
        WR_READ_RES,
        WR_PC_PLUS_4
    } t_wr_to_reg;

    typedef enum logic [2:0] {
        BEQ,
        BNE,
        BLT,
        BGE,
        BLTU,
        BGEU
    } t_branches;

    typedef enum logic [4:0] {
        reg_x0_zero,
        reg_x1_ra,
        reg_x2_sp,
        reg_x3_gp,
        reg_x4_tp,
        reg_x5_t0,
        reg_x6_t1,
        reg_x7_t2,
        reg_x8_s0,
        reg_x9_s1,
        reg_x10_a0,
        reg_x11_a1,
        reg_x12_a2,
        reg_x13_a3,
        reg_x14_a4,
        reg_x15_a5,
        reg_x16_a6,
        reg_x17_a7,
        reg_x18_s2,
        reg_x19_s3,
        reg_x20_s4,
        reg_x21_s5,
        reg_x22_s6,
        reg_x23_s7,
        reg_x24_s8,
        reg_x25_s9,
        reg_x26_s10,
        reg_x27_s11,
        reg_x28_t3,
        reg_x29_t4,
        reg_x30_t5,
        reg_x31_t6
    } t_registers;

    localparam logic [6:0]
        OP_LOAD     = 7'b0000011,
        OP_IMM      = 7'b0010011,
        OP_AUIPC    = 7'b0010111,
        OP_STORE    = 7'b0100011,
        OP_ALU      = 7'b0110011,
        OP_LUI      = 7'b0110111,
        OP_BRANCH   = 7'b1100011,
        OP_JALR     = 7'b1100111,
        OP_JAL      = 7'b1101111,
        OP_SYS      = 7'b1110011;
    
    localparam logic [2:0]
        F3_ADD      = 3'b000,
        F3_SLT      = 3'b010,
        F3_SLTU     = 3'b011,
        F3_XOR      = 3'b100,
        F3_OR       = 3'b110,
        F3_AND      = 3'b111,
        F3_SLL      = 3'b001,
        F3_SR       = 3'b101;
    
    localparam logic [2:0]
        F3_LB       = 3'b000,
        F3_LH       = 3'b001,
        F3_LW       = 3'b010,
        F3_LBU      = 3'b100,
        F3_LHU      = 3'b101;
    
    localparam logic [2:0]
        F3_SB       = 3'b000,
        F3_SH       = 3'b001,
        F3_SW       = 3'b010;
    
    localparam logic [2:0]
        F3_BEQ      = 3'b000,
        F3_BNE      = 3'b001,
        F3_BLT      = 3'b100,
        F3_BGE      = 3'b101,
        F3_BLTU     = 3'b110,
        F3_BGEU     = 3'b111;

endpackage