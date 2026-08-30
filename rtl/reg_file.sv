// ============================================================================
// File Name   : reg_file.sv
// Author      : Kevin Toledo Fernandez / GitHub: systemkev
// Date        : 2026-05-23
// Project     : RISC-V 32-bit Processor
// Description : 32x32 synchronous register file with two async read ports and
//               one sync write port. x0 hardwired to zero.
//
// License     : MIT
// ============================================================================
 
module reg_file(
    input logic         i_clk,
 
    // To write to a register, we need its address and the value to write to it
    input logic [31:0]  i_rd_val,
    input logic [4:0]   i_rd_addr,
 
    // To read two registers, we need two address, one for each read.
    input logic [4:0]   i_rs1_addr,
    input logic [4:0]   i_rs2_addr,
 
    input logic         i_write_enable,     // Enable write to rd
    input logic         i_rst,              // Reset for when system boots up
 
    // Output for the reads
    output logic [31:0] o_rs1_val,
    output logic [31:0] o_rs2_val
 
);
    // RISC-V has 32 general purpose registers
    // Recall: x0 is hardwired to 0.
    logic [31:0] registers [32];
 
    always_comb begin
        // Reads are combinational. Reading x0 is hardwired to output 0
        if(i_rs1_addr == 5'b0) 
            o_rs1_val = 32'b0;
        else if(i_write_enable && i_rs1_addr == i_rd_addr)
            o_rs1_val = i_rd_val;
        else
            o_rs1_val = registers[i_rs1_addr];
        
        if(i_rs2_addr == 5'b0) 
            o_rs2_val = 32'b0;
        else if(i_write_enable && i_rs2_addr == i_rd_addr)
            o_rs2_val = i_rd_val;
        else
            o_rs2_val = registers[i_rs2_addr];
    end
 
    always_ff @(posedge i_clk) begin
        // Reset will write 0 to all registers
 
        // Otherwise, on the rising edge, write i_rd_val into i_rd_addr
        // if i_write_enable is enabled (i.e., 1)
        if(i_rst) begin
            for(int i = 0; i < 32; i++) begin
                registers[i] <= 32'b0;
            end
        end else if(i_write_enable && i_rd_addr != 5'b0) begin
            registers[i_rd_addr] <= i_rd_val;
        end
    end
endmodule