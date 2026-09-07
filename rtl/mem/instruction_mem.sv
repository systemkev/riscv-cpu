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
    output logic [31:0] o_data,

    input  logic        i_loader_wr_en,
    input  logic [31:0] i_loader_wr_addr,
    input  logic [31:0] i_loader_wr_data
);

    localparam int ADDR_WIDTH = $clog2(DEPTH_WORDS);

    (* ram_style = "block" *)
    logic [31:0] memory [0:DEPTH_WORDS-1];

    logic [ADDR_WIDTH-1:0] cpu_word_addr;
    logic [ADDR_WIDTH-1:0] loader_word_addr;

    assign cpu_word_addr =
        i_addr[ADDR_WIDTH+1:2];

    assign loader_word_addr =
        i_loader_wr_addr[ADDR_WIDTH+1:2];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    always_ff @(posedge i_clk) begin
        o_data <= memory[cpu_word_addr];
    end

    always_ff @(posedge i_clk) begin
        if (i_loader_wr_en)
            memory[loader_word_addr] <= i_loader_wr_data;
    end

endmodule