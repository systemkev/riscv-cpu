// ============================================================================
// File Name   : alu.sv
// Author      : Kevin Toledo Fernandez / GitHub: ktf-repos
// Date        : 2026-05-22
// Project     : RISC-V 32-bit Processor
// Description : Arithmetic Logic Unit. Implements RISC-V RV32I i_second_operandase integer 
//               instructions. Combinational logic only.
//
// License     : MIT
// ============================================================================

import common_pkg::*;

module ALU (
    input   logic [31:0]    i_first_operand, 
    input   logic [31:0]    i_second_operand, 
    input   t_alu_ops       i_operation,

    output  logic [31:0]    o_result,
    output  logic           o_zero_flag
);
    
    logic [4:0] shamt;
    assign shamt = i_second_operand[4:0];

    always_comb begin 
        case (i_operation)
            ARITH_ADD:      o_result = i_first_operand + i_second_operand;
            ARITH_SUB:      o_result = i_first_operand - i_second_operand;
            LOGIC_AND:      o_result = i_first_operand & i_second_operand;
            LOGIC_OR:       o_result = i_first_operand | i_second_operand;
            LOGIC_XOR:      o_result = i_first_operand ^ i_second_operand;
            SHIFT_L_LOGIC:  o_result = i_first_operand << shamt; 
            SHIFT_R_LOGIC:  o_result = i_first_operand >> shamt;
            SHIFT_R_ARITH:  o_result = $signed(i_first_operand) >>> shamt;
            SET_LESS_U:     o_result = i_first_operand < i_second_operand;
            SET_LESS_S:     o_result = $signed(i_first_operand) < $signed(i_second_operand);
            default:        o_result = 0;
        endcase

        o_zero_flag = (o_result == 32'b0);
    end

endmodule