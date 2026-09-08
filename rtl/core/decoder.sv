import common_pkg::*;

module decoder (
    input   logic           i_clk,
    input   logic           i_rst,
    input   logic           i_valid,
    input   logic [31:0]    i_pc,
    input   logic [31:0]    i_instr,
    input   logic           i_pred_taken,
    input   logic [31:0]    i_pred_target,
    input   logic           i_stall,
    input   logic           i_flush,

    output  logic           o_valid,
    output  logic [31:0]    o_pc,
    output  logic [4:0]     o_rs1,
    output  logic [4:0]     o_rs2,
    output  logic [4:0]     o_rd,
    output  logic [31:0]    o_imm,
    output  t_alu_ops       o_alu_op,
    output  logic           o_alu_inp_1,
    output  logic           o_alu_inp_2,
    output  logic           o_mem_read,
    output  logic           o_mem_write,
    output  t_mem_types     o_mem_type,
    output  logic           o_reg_write,
    output  t_wb_src        o_wr_from,
    output  logic           o_is_branch,
    output  t_branches      o_branch_type,
    output  logic           o_is_jump,
    output  logic           o_jalr,
    output  logic           o_illegal,
    output  logic [31:0]    o_pc_plus_4,
    output  logic           o_pred_taken,
    output  logic [31:0]    o_pred_target
);

    logic           valid;
    logic [31:0]    pc;
    logic [31:0]    imm;
    t_alu_ops       alu_op;
    logic           alu_inp_1;
    logic           alu_inp_2;
    logic           mem_read;
    logic           mem_write;
    t_mem_types     mem_type;
    logic           reg_write;
    t_wb_src        wb_data_src;
    logic           is_branch;
    t_branches      branch_type;
    logic           is_jump;
    logic           is_jalr;
    logic           illegal;
    logic           use_rs1;
    logic           use_rs2;

    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;

    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;

    assign opcode = i_instr[6:0];
    assign rd     = i_instr[11:7];
    assign funct3 = i_instr[14:12];
    assign rs1    = i_instr[19:15];
    assign rs2    = i_instr[24:20];
    assign funct7 = i_instr[31:25];

    assign imm_i = {{20{i_instr[31]}}, i_instr[31:20]};
    assign imm_s = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};
    assign imm_b = {{19{i_instr[31]}}, i_instr[31], i_instr[7], i_instr[30:25], i_instr[11:8], 1'b0};
    assign imm_u = {i_instr[31:12], 12'b0};
    assign imm_j = {{12{i_instr[31]}}, i_instr[19:12], i_instr[20], i_instr[30:21], 1'b0};

    always_comb begin
        valid       = 1'b0;
        pc          = i_pc;
        imm         = 32'b0;
        alu_op      = ARITH_ADD;
        alu_inp_1   = 1'b0;
        alu_inp_2   = 1'b1;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_type    = S_LOAD_BYTE;
        reg_write   = 1'b0;
        wb_data_src = WR_ALU_RES;
        is_branch   = 1'b0;
        branch_type = BEQ;
        is_jump     = 1'b0;
        is_jalr     = 1'b0;
        illegal     = 1'b0;
        use_rs1     = 1'b1;
        use_rs2     = 1'b1;

        if (i_valid) begin
            valid = 1'b1;

            case (opcode)
                OP_AUIPC: begin
                    imm         = imm_u;
                    alu_inp_1   = 1'b1;
                    reg_write   = 1'b1;
                    use_rs1     = 1'b0;
                    use_rs2     = 1'b0;
                    wb_data_src = WR_ALU_RES;
                end

                OP_JALR: begin
                    if (funct3 == 3'b000) begin
                        imm         = imm_i;
                        reg_write   = 1'b1;
                        wb_data_src = WR_PC_PLUS_4;
                        is_jump     = 1'b1;
                        is_jalr     = 1'b1;
                        use_rs1     = 1'b1;
                        use_rs2     = 1'b0;
                    end else begin
                        illegal = 1'b1;
                    end
                end

                OP_JAL: begin
                    imm         = imm_j;
                    alu_inp_1   = 1'b1;
                    reg_write   = 1'b1;
                    wb_data_src = WR_PC_PLUS_4;
                    is_jump     = 1'b1;
                    use_rs1     = 1'b0;
                    use_rs2     = 1'b0;
                end

                OP_BRANCH: begin
                    imm       = imm_b;
                    alu_inp_1 = 1'b1;
                    is_branch = 1'b1;

                    case (funct3)
                        F3_BEQ:  branch_type = BEQ;
                        F3_BNE:  branch_type = BNE;
                        F3_BLT:  branch_type = BLT;
                        F3_BGE:  branch_type = BGE;
                        F3_BLTU: branch_type = BLTU;
                        F3_BGEU: branch_type = BGEU;
                        default: illegal = 1'b1;
                    endcase
                end

                OP_LUI: begin
                    imm         = imm_u;
                    alu_inp_1   = 1'b0;
                    alu_inp_2   = 1'b1;
                    reg_write   = 1'b1;
                    wb_data_src = WR_ALU_RES;
                    use_rs1     = 1'b0;
                    use_rs2     = 1'b0;
                end

                OP_STORE: begin
                    imm       = imm_s;
                    mem_write = 1'b1;

                    case (funct3)
                        F3_SB:  mem_type = STORE_BYTE;
                        F3_SH:  mem_type = STORE_HALF;
                        F3_SW:  mem_type = STORE_WORD;
                        default: illegal = 1'b1;
                    endcase
                end

                OP_LOAD: begin
                    imm         = imm_i;
                    mem_read    = 1'b1;
                    reg_write   = 1'b1;
                    wb_data_src = WR_READ_RES;
                    use_rs1     = 1'b1;
                    use_rs2     = 1'b0;

                    case (funct3)
                        F3_LB:  mem_type = S_LOAD_BYTE;
                        F3_LH:  mem_type = S_LOAD_HALF;
                        F3_LW:  mem_type = S_LOAD_WORD;
                        F3_LBU: mem_type = U_LOAD_BYTE;
                        F3_LHU: mem_type = U_LOAD_HALF;
                        default: illegal = 1'b1;
                    endcase
                end

                OP_ALU: begin
                    alu_inp_2   = 1'b0;
                    reg_write   = 1'b1;
                    wb_data_src = WR_ALU_RES;

                    case (funct3)
                        F3_ADD: begin
                            case (funct7)
                                7'b0000000: alu_op = ARITH_ADD;
                                7'b0100000: alu_op = ARITH_SUB;
                                default: illegal = 1'b1;
                            endcase
                        end

                        F3_SR: begin
                            case (funct7)
                                7'b0000000: alu_op = SHIFT_R_LOGIC;
                                7'b0100000: alu_op = SHIFT_R_ARITH;
                                default: illegal = 1'b1;
                            endcase
                        end

                        F3_SLL: begin
                            case (funct7)
                                7'b0000000: alu_op = SHIFT_L_LOGIC;
                                default: illegal = 1'b1;
                            endcase
                        end

                        F3_SLT: begin
                            case (funct7)
                                7'b0000000: alu_op = SET_LESS_S;
                                default: illegal = 1'b1;
                            endcase
                        end

                        F3_SLTU: begin
                            case (funct7)
                                7'b0000000: alu_op = SET_LESS_U;
                                default: illegal = 1'b1;
                            endcase
                        end

                        F3_XOR: begin
                            case (funct7)
                                7'b0000000: alu_op = LOGIC_XOR;
                                default: illegal = 1'b1;
                            endcase
                        end

                        F3_OR: begin
                            case (funct7)
                                7'b0000000: alu_op = LOGIC_OR;
                                default: illegal = 1'b1;
                            endcase
                        end

                        F3_AND: begin
                            case (funct7)
                                7'b0000000: alu_op = LOGIC_AND;
                                default: illegal = 1'b1;
                            endcase
                        end

                        default: illegal = 1'b1;
                    endcase
                end

                OP_IMM: begin
                    imm         = imm_i;
                    reg_write   = 1'b1;
                    wb_data_src = WR_ALU_RES;
                    use_rs1     = 1'b1;
                    use_rs2     = 1'b0;

                    case (funct3)
                        F3_ADD:  alu_op = ARITH_ADD;
                        F3_SLT:  alu_op = SET_LESS_S;
                        F3_SLTU: alu_op = SET_LESS_U;
                        F3_XOR:  alu_op = LOGIC_XOR;
                        F3_OR:   alu_op = LOGIC_OR;
                        F3_AND:  alu_op = LOGIC_AND;

                        F3_SLL: begin
                            imm = {27'b0, i_instr[24:20]};
                            case (funct7)
                                7'b0000000: alu_op = SHIFT_L_LOGIC;
                                default: illegal = 1'b1;
                            endcase
                        end

                        F3_SR: begin
                            imm = {27'b0, i_instr[24:20]};
                            case (funct7)
                                7'b0000000: alu_op = SHIFT_R_LOGIC;
                                7'b0100000: alu_op = SHIFT_R_ARITH;
                                default: illegal = 1'b1;
                            endcase
                        end

                        default: illegal = 1'b1;
                    endcase
                end

                OP_SYS: begin
                    illegal = 1'b1;
                end

                default: begin
                    illegal = 1'b1;
                end
            endcase

            if (illegal) begin
                reg_write = 1'b0;
                mem_read  = 1'b0;
                mem_write = 1'b0;
                is_branch = 1'b0;
                is_jump   = 1'b0;
                is_jalr   = 1'b0;
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            o_valid       <= 1'b0;
            o_pc          <= 32'b0;
            o_rs1         <= 5'b0;
            o_rs2         <= 5'b0;
            o_rd          <= 5'b0;
            o_imm         <= 32'b0;
            o_alu_op      <= ARITH_ADD;
            o_alu_inp_1   <= 1'b0;
            o_alu_inp_2   <= 1'b1;
            o_mem_read    <= 1'b0;
            o_mem_write   <= 1'b0;
            o_mem_type    <= S_LOAD_BYTE;
            o_reg_write   <= 1'b0;
            o_wr_from     <= WR_ALU_RES;
            o_is_branch   <= 1'b0;
            o_branch_type <= BEQ;
            o_is_jump     <= 1'b0;
            o_jalr        <= 1'b0;
            o_illegal     <= 1'b0;
            o_pc_plus_4   <= 32'b0;
            o_pred_taken  <= 1'b0;
            o_pred_target <= 32'b0;
        end else if (i_flush) begin
            o_valid       <= 1'b0;
            o_pc          <= 32'b0;
            o_rs1         <= 5'b0;
            o_rs2         <= 5'b0;
            o_rd          <= 5'b0;
            o_imm         <= 32'b0;
            o_alu_op      <= ARITH_ADD;
            o_alu_inp_1   <= 1'b0;
            o_alu_inp_2   <= 1'b1;
            o_mem_read    <= 1'b0;
            o_mem_write   <= 1'b0;
            o_mem_type    <= S_LOAD_BYTE;
            o_reg_write   <= 1'b0;
            o_wr_from     <= WR_ALU_RES;
            o_is_branch   <= 1'b0;
            o_branch_type <= BEQ;
            o_is_jump     <= 1'b0;
            o_jalr        <= 1'b0;
            o_illegal     <= 1'b0;
            o_pc_plus_4   <= 32'b0;
            o_pred_taken  <= 1'b0;
            o_pred_target <= 32'b0;
        end else if (!i_stall) begin
            o_valid       <= valid;
            o_pc          <= pc;
            o_rs1         <= use_rs1 ? rs1 : 5'd0;
            o_rs2         <= use_rs2 ? rs2 : 5'd0;
            o_rd          <= rd;
            o_imm         <= imm;
            o_alu_op      <= alu_op;
            o_alu_inp_1   <= alu_inp_1;
            o_alu_inp_2   <= alu_inp_2;
            o_mem_read    <= mem_read;
            o_mem_write   <= mem_write;
            o_mem_type    <= mem_type;
            o_reg_write   <= reg_write && (rd != 5'd0);
            o_wr_from     <= wb_data_src;
            o_is_branch   <= is_branch;
            o_branch_type <= branch_type;
            o_is_jump     <= is_jump;
            o_jalr        <= is_jalr;
            o_illegal     <= illegal;
            o_pc_plus_4   <= pc + 32'd4;
            o_pred_taken  <= i_pred_taken;
            o_pred_target <= i_pred_target;
        end
    end

endmodule