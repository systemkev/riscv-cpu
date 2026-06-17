import common_pkg::*;

module decoder (
    input   logic           i_clk,
    input   logic           i_rst,
    
    // From fetch state
    input   logic           i_valid,        // 0 -> fetch output is invalid, 1 -> fetch output is valid
    input   logic [31:0]    i_pc,           // PC of instruction being decoded
    input   logic [31:0]    i_instr,        // output from fetch (instr to decode)

    // Pipeline control
    input   logic           i_stall,        // when 1 -> freeze, ignore new input
    input   logic           i_flush,        // when 1 -> inject NOP bubble on next cycle

    output  logic           o_valid,        // wired to i_valid (1 -> fetch output is valid)
    output  logic [31:0]    o_pc,           // wired to i_pc (passes pc to execute stage)
    output  logic [4:0]     o_rs1,          // source register 1
    output  logic [4:0]     o_rs2,          // source register 2
    output  logic [4:0]     o_rd,           // destination register
    output  logic [31:0]    o_imm,          // value of immediate
    output  t_alu_ops       o_alu_op,       // operation to be performed by ALU 
    output  logic           o_alu_inp_1,    // 0 -> use rs1, 1 -> use the current PC (used for AUIPC, JAL)
    output  logic           o_alu_inp_2,    // 0 -> use rs2, 1 -> use immediate
    output  logic           o_mem_read,     // 1 -> load instruction, 0 -> o.w.
    output  logic           o_mem_write,    // 1 -> store instruction, 0 -> o.w.
    output  t_mem_types     o_mem_type,     // signed LB, unsigned LB, signed LW, etc. (see common_pkg for def)
    output  logic           o_reg_write,    // 1 -> write back to register file
    output  t_wr_to_reg     o_write_to,     // Enum defined in common_pkg (ALU, Mem Read, or PC+4 get written to rd)
    output  logic           o_is_branch,    // 1 -> branch, 0 -> not a branch
    output  t_branches      o_branch_type,  // Type of comparison (BEQ, BNE, etc. Types defined in common_pkg)
    output  logic           o_is_jump,      // 1 -> jump/redirect, 0 -> not a jump
    output  logic           o_jalr,         // 1 -> when instruction is JALR, 0 -> o.w.
    output  logic           o_illegal       // 1 -> not a RV32I instruction, 0 -> o.w.
);

// Extract all the relevant information from the instruction
logic [6:0] opcode  = i_instr[6:0];
logic [4:0] rd      = i_instr[11:7];
logic [2:0] funct3  = i_instr[14:12];
logic [4:0] rs1     = i_instr[19:15];
logic [4:0] rs2     = i_instr[24:20];
logic [6:0] funct7  = i_instr[31:25];

// Decode the immediate
logic [31:0] imm_i  = {{20{i_instr[31]}}, i_instr[31:20]};
logic [31:0] imm_s  = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};
logic [31:0] imm_b  = {{19{i_instr[31]}}, i_instr[31], i_instr[7], i_instr[30:25], i_instr[11:8], 1'b0};
logic [31:0] imm_u  = {i_instr[31:12], 12'b0};
logic [31:0] imm_j  = {{12{i_instr[31]}}, i_instr[19:12], i_instr[20], i_instr[30:21], 1'b0};

logic           valid;        // wired to i_valid (1 -> fetch output is valid)
logic [31:0]    pc;           // wired to i_pc (passes pc to execute stage)
logic [31:0]    imm;          // value of immediate
t_alu_ops       alu_op;       // operation to be performed by ALU 
logic           alu_inp_1;    // 0 -> use rs1, 1 -> use the current PC (used for AUIPC, JAL)
logic           alu_inp_2;    // 0 -> use rs2, 1 -> use immediate
logic           mem_read;     // 1 -> load instruction, 0 -> o.w.
logic           mem_write;    // 1 -> store instruction, 0 -> o.w.
t_mem_types     mem_type;     // signed LB, unsigned LB, signed LW, etc. (see common_pkg for def)
logic           reg_write;    // 1 -> write back to register file
t_wr_to_reg     write_to;     // Enum defined in common_pkg (ALU, Mem Read, or PC+4 get written to rd)
logic           is_branch;    // 1 -> branch, 0 -> not a branch
t_branches      branch_type;  // Type of comparison (BEQ, BNE, etc. Types defined in common_pkg)
logic           is_jump;      // 1 -> jump/redirect, 0 -> not a jump
logic           is_jalr;         // 1 -> when instruction is JALR, 0 -> o.w.
logic           illegal;       // 1 -> not a RV32I instruction, 0 -> o.w.

always_comb begin
    // Default values (NOP: addi x0, x0, 0)
    valid       = 1'b0;
    pc          = i_pc;
    imm         = 32'b0;
    alu_op      = ARITH_ADD;
    alu_inp_1   = 1'b0;
    alu_inp_2   = 1'b1;
    mem_read    = 1'b0;
    mem_write   = 1'b0;
    mem_type    = t_mem_types'('x);
    reg_write   = 1'b0;
    write_to    = t_wr_to_reg'('x);
    is_branch   = 1'b0;
    branch_type = t_branches'('x);
    is_jump     = 1'b0;
    is_jalr     = 1'b0;
    illegal     = 1'b0;
    if (i_valid) begin
        valid   = 1'b1;
        case(opcode)
            OP_AUIPC: begin
                imm = imm_u;
                alu_inp_1 = 1'b1;
                reg_write = 1'b1;
                write_to = WR_ALU_RES;
            end

            OP_JALR: begin
                if (funct3 == 3'b000) begin
                    imm = imm_i;
                    reg_write = 1'b1;
                    write_to = WR_PC_PLUS_4;
                    is_jump = 1'b1;
                    is_jalr = 1'b1;
                end else
                    illegal = 1'b1;
            end

            OP_JAL: begin
                // set ALU to calculate the target address: PC + imm_j
                imm             = imm_j;
                alu_inp_1       = 1'b1;
                reg_write       = 1'b1;
                write_to        = WR_PC_PLUS_4;
                is_jump         = 1'b1;
            end

            OP_BRANCH: begin
                // set ALU to calculate the target address: PC + imm_b
                imm             = imm_b;
                alu_inp_1       = 1'b1;
                is_branch       = 1'b1;
                
                case(funct3)
                    F3_BEQ:     branch_type     = BEQ;
                    F3_BNE:     branch_type     = BNE;
                    F3_BLT:     branch_type     = BLT;
                    F3_BGE:     branch_type     = BGE;
                    F3_BLTU:    branch_type     = BLTU;
                    F3_BGEU:    branch_type     = BGEU;
                    default:    illegal         = 1'b1;
                endcase
            end

            OP_LUI: begin
                imm = imm_u;
                alu_inp_1 = 1'b0;
                alu_inp_2 = 1'b1;
                reg_write = 1'b1;
                write_to = WR_ALU_RES;
            end

            OP_STORE: begin
                imm             = imm_s;
                mem_write       = 1'b1;

                case (funct3)
                    F3_SB:      mem_type    = STORE_BYTE;
                    F3_SH:      mem_type    = STORE_HALF;
                    F3_SW:      mem_type    = STORE_WORD;
                    default:    illegal     = 1'b1;
                endcase 
            end
        
            OP_LOAD: begin
                imm             = imm_i;
                mem_read        = 1'b1;
                reg_write       = 1'b1;
                write_to        = WR_READ_RES;
                
                case (funct3)
                    F3_LB:      mem_type    = S_LOAD_BYTE;
                    F3_LH:      mem_type    = S_LOAD_HALF;
                    F3_LW:      mem_type    = S_LOAD_WORD;
                    F3_LBU:     mem_type    = U_LOAD_BYTE;
                    F3_LHU:     mem_type    = U_LOAD_HALF;
                    default:    illegal     = 1'b1;
                endcase 
            end

            OP_ALU: begin
                alu_inp_2   = 1'b0;
                reg_write   = 1'b1;
                write_to    = WR_ALU_RES;
                
                case (funct3)
                    F3_ADD: begin
                        case (funct7)
                            7'b0000000: alu_op      = ARITH_ADD;
                            7'b0100000: alu_op      = ARITH_SUB;
                            default:    illegal     = 1'b1;
                        endcase 
                    end

                    F3_SR: begin
                        case (funct7)
                            7'b0000000: alu_op  = SHIFT_R_LOGIC;
                            7'b0100000: alu_op  = SHIFT_R_ARITH;
                            default:    illegal = 1'b1;
                        endcase 
                    end

                    F3_SLL: begin
                        case (funct7)
                            7'b0000000: alu_op  = SHIFT_L_LOGIC;
                            default:    illegal = 1'b1;
                        endcase
                    end

                    F3_SLT: begin
                        case (funct7)
                            7'b0000000: alu_op = SET_LESS_S;
                            default:    illegal = 1'b1;
                        endcase 
                    end

                    F3_SLTU: begin
                        case (funct7)
                            7'b0000000: alu_op = SET_LESS_U;
                            default:    illegal = 1'b1;
                        endcase 
                    end

                    F3_XOR: begin
                        case (funct7)
                            7'b0000000: alu_op = LOGIC_XOR;
                            default:    illegal = 1'b1;
                        endcase 
                    end

                    F3_OR: begin
                        case (funct7)
                            7'b0000000: alu_op = LOGIC_OR;
                            default:    illegal = 1'b1;
                        endcase 
                    end

                    F3_AND: begin
                        case (funct7)
                            7'b0000000: alu_op = LOGIC_AND;
                            default:    illegal = 1'b1;
                        endcase 
                    end

                    default:            illegal = 1'b1;
                endcase 
            end
        
            OP_IMM: begin
                imm         = imm_i;
                reg_write   = 1'b1;
                write_to    = WR_ALU_RES;
                
                case (funct3) 
                    F3_ADD:        alu_op = ARITH_ADD;
                    F3_SLT:        alu_op = SET_LESS_S;
                    F3_SLTU:       alu_op = SET_LESS_U;
                    F3_XOR:        alu_op = LOGIC_XOR;
                    F3_OR:         alu_op = LOGIC_OR;
                    F3_AND:        alu_op = LOGIC_AND;
                    F3_SLL: begin
                        case (funct7)
                            7'b0000000:     alu_op  = SHIFT_L_LOGIC;
                            default:        illegal = 1'b1;
                        endcase
                    end
                    F3_SR: begin
                        case (funct7)
                            7'b0000000:     alu_op  = SHIFT_R_LOGIC;
                            7'b0100000:     alu_op  = SHIFT_R_ARITH;
                            default:        illegal = 1'b1; 
                        endcase
                    end
                    default:        illegal = 1'b1;
                endcase
            end 

            OP_SYS: illegal = 1'b1;
            default: illegal = 1'b1;
        endcase
    end
end

always_ff @(posedge i_clk or posedge i_rst) begin 
    if (i_rst == 1'b1) begin 
        o_valid         <= 1'b0;
        o_pc            <= 'x;
        o_rs1           <= 'x;
        o_rs2           <= 'x;
        o_rd            <= 'x;
        o_imm           <= 'x;
        o_alu_op        <= t_alu_ops'('x);
        o_alu_inp_1     <= 'x;
        o_alu_inp_2     <= 'x;
        o_mem_read      <= 'x;
        o_mem_write     <= 'x;
        o_mem_type      <= t_mem_types'('x);
        o_reg_write     <= 'x;
        o_write_to      <= t_wr_to_reg'('x);
        o_is_branch     <= 'x;
        o_branch_type   <= t_branches'('x);
        o_is_jump       <= 'x;
        o_jalr          <= 'x;
        o_illegal       <= 'x;
    end else if (i_stall == 1'b0) begin
        if (i_flush == 1'b1) begin
            // Inject NOP
            o_valid         <= 1'b0;
            o_reg_write     <= 1'b0;
            o_mem_write     <= 1'b0;
            o_mem_read      <= 1'b0;
            o_is_branch     <= 1'b0;
            o_is_jump       <= 1'b0;
        end else begin
            o_valid         <= valid;
            o_pc            <= pc;
            o_rs1           <= (opcode == OP_LUI)? 5'b0 : rs1;
            o_rs2           <= rs2;
            o_rd            <= rd;
            o_imm           <= imm;
            o_alu_op        <= alu_op;
            o_alu_inp_1     <= alu_inp_1;
            o_alu_inp_2     <= alu_inp_2;
            o_mem_read      <= mem_read;
            o_mem_write     <= mem_write;
            o_mem_type      <= mem_type;
            o_reg_write     <= reg_write;
            o_write_to      <= write_to;
            o_is_branch     <= is_branch;
            o_branch_type   <= branch_type;
            o_is_jump       <= is_jump;
            o_jalr          <= is_jalr;
            o_illegal       <= illegal;
        end
    end
end 
endmodule