// ============================================================================
// File Name   : data_memory.sv
// Description : 32-bit synchronous BRAM with byte-write enables.
// ============================================================================

module data_memory #(
    parameter int DEPTH_WORDS = 4096,
    parameter string INIT_FILE = ""
)(
    input  logic        i_clk,

    input  logic [31:0] i_addr,

    input  logic [31:0] i_wr_data,
    input  logic        i_wr_en,
    input  logic [3:0]  i_byte_en,

    output logic [31:0] o_rd_data
);

    localparam int ADDR_WIDTH = $clog2(DEPTH_WORDS);

    logic [31:0] memory [0:DEPTH_WORDS-1];

    logic [ADDR_WIDTH-1:0] word_addr;

    assign word_addr =
        i_addr[ADDR_WIDTH+1:2];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    always_ff @(posedge i_clk) begin

        // ------------------------------------------------------------
        // Synchronous read
        // ------------------------------------------------------------

        o_rd_data <= memory[word_addr];

        // ------------------------------------------------------------
        // Byte writes
        // ------------------------------------------------------------

        if (i_wr_en) begin

            if (i_byte_en[0])
                memory[word_addr][7:0]
                    <= i_wr_data[7:0];

            if (i_byte_en[1])
                memory[word_addr][15:8]
                    <= i_wr_data[15:8];

            if (i_byte_en[2])
                memory[word_addr][23:16]
                    <= i_wr_data[23:16];

            if (i_byte_en[3])
                memory[word_addr][31:24]
                    <= i_wr_data[31:24];

        end

    end

endmodule