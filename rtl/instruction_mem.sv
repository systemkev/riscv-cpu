// ============================================================================
// File Name   : instruction_memory.sv
// Description : Synchronous instruction BRAM for RV32I core.
// ============================================================================

module instruction_memory #(
    parameter int DEPTH_WORDS = 4096,
    parameter string INIT_FILE = ""
)(
    input  logic        i_clk,

    input  logic [31:0] i_addr,

    output logic [31:0] o_data
);

    localparam int ADDR_WIDTH = $clog2(DEPTH_WORDS);

    logic [31:0] memory [0:DEPTH_WORDS-1];

    logic [ADDR_WIDTH-1:0] word_addr;

    // RV32I addresses are byte addresses.
    // Each instruction is one 32-bit word = 4 bytes.
    assign word_addr =
        i_addr[ADDR_WIDTH+1:2];

    // Optional initialization from .mem/.hex file
    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    // One-cycle synchronous BRAM read
    always_ff @(posedge i_clk) begin
        o_data <= memory[word_addr];
    end

endmodule