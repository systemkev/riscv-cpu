// ============================================================================
// File Name   : execute.sv
// Author      : Kevin Toledo Fernandez / GitHub: systemkev
// Date        : 2026-06-16
// Project     : RISC-V 32-bit Processor
// Description : Execute (EX) stage of the pipelined RISC-V RV32I processor. 
//               Handles operand selection and instantiates the Arithmetic Logic
//               Unit (ALU). Evaluates branch/jump conditions to generate 
//               combinational PC redirection signals for the Fetch stage. 
//               Contains sequential pipeline registers to forward control and 
//               data signals to the Memory stage, supporting stalls and flushes.
//
// License     : MIT
// ============================================================================

import common_pkg::*;

module execute (
    input   logic           i_clk,
    input   logic           i_rst,

    // Pipeline control
    input   logic           i_stall,        // when 1 -> freeze, ignore new input
    input   logic           i_flush,        // when 1 -> inject NOP bubble on next cycle
    
    // From decode stage        
    input   logic           i_valid,        // wired to i_valid (1 -> fetch output is valid)
    input   logic [31:0]    i_pc,           // wired to i_pc (passes pc to execute stage)
    input   logic [4:0]     i_rs1,          // source register 1
    input   logic [4:0]     i_rs2,          // source register 2
    input   logic [4:0]     i_rd,           // destination register
    input   logic [31:0]    i_imm,          // value of immediate
    input   t_alu_ops       i_alu_op,       // operation to be performed by ALU 
    input   logic           i_alu_inp_1,    // 0 -> use rs1, 1 -> use the current PC (used for AUIPC, JAL)
    input   logic           i_alu_inp_2,    // 0 -> use rs2, 1 -> use immediate
    input   logic           i_mem_read,     // 1 -> load instruction, 0 -> o.w.
    input   logic           i_mem_write,    // 1 -> store instruction, 0 -> o.w.
    input   t_mem_types     i_mem_type,     // signed LB, unsigned LB, signed LW, etc. (see common_pkg for def)
    input   logic           i_reg_write,    // 1 -> write back to register file
    input   t_wb_src        i_wb_src,       // Enum defined in common_pkg (ALU, Mem Read, or PC+4 get written to rd)
    input   logic           i_is_branch,    // 1 -> branch, 0 -> not a branch
    input   t_branches      i_branch_type,  // Type of comparison (BEQ, BNE, etc. Types defined in common_pkg)
    input   logic           i_is_jump,      // 1 -> jump/redirect, 0 -> not a jump
    input   logic           i_jalr,         // 1 -> when instruction is JALR, 0 -> o.w.
    input   logic           i_illegal,      // 1 -> not a RV32I instruction, 0 -> o.w.

    // Register file signals
    input   logic [31:0]    i_rs1_val,
    input   logic [31:0]    i_rs2_val,

    // Forwarding logic
    input   t_forwarding    i_forward_op_a, // 00 -> NO_HAZ, 01 -> WB forward, 10 -> MEM forward
    input   t_forwarding    i_forward_op_b, // 00 -> NO_HAZ, 01 -> WB forward, 10 -> MEM forward
    input   logic [31:0]    i_mem_fwd_data, 
    input   logic [31:0]    i_wb_fwd_data,

    // To memory stage
    output  logic           o_valid,
    output  logic [31:0]    o_pc,
    output  logic [4:0]     o_rd,
    output  logic [31:0]    o_alu_result,   // memory address for load/store, ALU result for writeback
    output  logic [31:0]    o_rs2_val,      // store data forwarded to MEM
    output  logic           o_mem_read,
    output  logic           o_mem_write,
    output  t_mem_types     o_mem_type, 
    output  logic           o_reg_write,
    output  t_wb_src        o_wb_src,
    output  logic           o_illegal,

    // PC redirect (combination, goes to fetch stage)
    // Asserted same cycle branch/jump resolves
    // Decode's flush is driven by this
    output  logic           o_redirect, 
    output  logic [31:0]    o_target
);

logic [31:0]        alu_op_1;
logic [31:0]        alu_op_2;
logic [31:0]        alu_result;
logic               alu_zero;
logic               branch_taken;

// Resolve data hazards and determine what rs1 and rs2 should be
logic [31:0]        resolved_rs1;
logic [31:0]        resolved_rs2;

always_comb begin 
    // Forwarding mux for rs1 
    case (i_forward_op_a)
        NO_HAZ:     resolved_rs1 = i_rs1_val;
        WB_FWD:     resolved_rs1 = i_wb_fwd_data;
        MEM_FWD:    resolved_rs1 = i_mem_fwd_data;
        default:    resolved_rs1 = i_rs1_val;
    endcase 

    // Forwarding mux for rs2
    case (i_forward_op_b)
        NO_HAZ:     resolved_rs2 = i_rs2_val;
        WB_FWD:     resolved_rs2 = i_wb_fwd_data;
        MEM_FWD:    resolved_rs2 = i_mem_fwd_data;
        default:    resolved_rs2 = i_rs2_val;
    endcase 
end

// Operand selection
always_comb begin
    if (i_valid) begin
        alu_op_1 = (i_alu_inp_1 == 1'b0) ? resolved_rs1 : i_pc;
        alu_op_2 = (i_alu_inp_2 == 1'b0) ? resolved_rs2 : i_imm;
    end else begin
        alu_op_1 = 32'b0;
        alu_op_2 = 32'b0;
    end
end

// Instantiate the ALU and pass in its arguments
ALU alu_core (
    .i_first_operand            (alu_op_1),
    .i_second_operand           (alu_op_2),
    .i_operation                (i_alu_op),
    .o_result                   (alu_result),
    .o_zero_flag                (alu_zero)
);

// Branch comparator 
always_comb begin
    branch_taken = 1'b0;
    case (i_branch_type)
        BEQ:        branch_taken = (resolved_rs1 == resolved_rs2);
        BNE:        branch_taken = (resolved_rs1 != resolved_rs2);

        // Signed comparisons
        BLT:        branch_taken = ($signed(resolved_rs1) < $signed(resolved_rs2));
        BGE:        branch_taken = ($signed(resolved_rs1) >= $signed(resolved_rs2));

        // Unsigned comparisons
        BLTU:       branch_taken = (resolved_rs1 < resolved_rs2);
        BGEU:       branch_taken = (resolved_rs1 >= resolved_rs2);

        default:    branch_taken = 1'b0;
    endcase 
end

// Drive the redirect signal
assign o_redirect   = i_valid & (i_is_jump | (i_is_branch & branch_taken));
assign o_target     = i_jalr ? (alu_result & 32'hFFFFFFFE) : alu_result;

// Clocked pipeline register
always_ff @(posedge i_clk) begin 
    if (i_rst == 1'b1) begin 
        o_valid             <= 1'b0;
        o_pc                <= '0;
        o_rd                <= '0;
        o_alu_result        <= '0;
        o_rs2_val           <= '0;
        o_mem_read          <= '0;
        o_mem_write         <= '0;
        o_mem_type          <= S_LOAD_BYTE;
        o_reg_write         <= '0;
        o_wb_src            <= WR_ALU_RES;
        o_illegal           <= '0;
    end else if (i_flush == 1'b1) begin
        // Inject NOP (Zero out write enables and valid flag)
        o_valid         <= 1'b0;
        o_pc            <= '0;
        o_rd            <= '0;
        o_alu_result    <= '0;
        o_rs2_val       <= '0;
        o_mem_read      <= 1'b0;
        o_mem_write     <= 1'b0;
        o_mem_type      <= S_LOAD_BYTE;
        o_reg_write     <= 1'b0;
        o_wb_src        <= WR_ALU_RES;
        o_illegal       <= 1'b0;
    end else if (i_stall == 1'b0) begin
        // Normal operation
        o_valid         <= i_valid;      
        o_pc            <= i_pc;
        o_rd            <= i_rd;
        o_alu_result    <= alu_result;      // Pass the calculated math/address forward
        o_rs2_val       <= resolved_rs2;    // Forwarded for STORE instructions
        o_mem_read      <= i_mem_read;
        o_mem_write     <= i_mem_write;
        o_mem_type      <= i_mem_type;
        o_reg_write     <= i_reg_write;
        o_wb_src        <= i_wb_src;
        o_illegal       <= i_illegal;
    end
end
endmodule