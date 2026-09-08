module dmem_addr_decoder #(
    parameter int DMEM_DEPTH = 4096,
    parameter logic [31:0] UART_BASE_ADDR = 32'h8000_0000
)(
    input  logic        i_cpu_valid,
    input  logic        i_cpu_write,
    input  logic [31:0] i_cpu_addr,
    input  logic [31:0] i_cpu_wr_data,
    input  logic [3:0]  i_cpu_byte_en,

    output logic        o_ram_valid,
    output logic        o_ram_write,
    output logic [31:0] o_ram_addr,
    output logic [31:0] o_ram_wr_data,
    output logic [3:0]  o_ram_byte_en,

    input  logic [31:0] i_ram_rd_data,
    input  logic        i_ram_stall,

    output logic        o_uart_valid,
    output logic        o_uart_write,
    output logic [31:0] o_uart_addr,
    output logic [31:0] o_uart_wr_data,
    output logic [3:0]  o_uart_byte_en,

    input  logic [31:0] i_uart_rd_data,
    input  logic        i_uart_stall,

    output logic [31:0] o_cpu_rd_data,
    output logic        o_cpu_stall
);

    localparam logic [31:0] DMEM_BYTES =
        DMEM_DEPTH * 4;

    logic ram_select;
    logic uart_select;

    assign ram_select =
        i_cpu_addr < DMEM_BYTES;

    assign uart_select =
        (i_cpu_addr >= UART_BASE_ADDR) &&
        (i_cpu_addr < UART_BASE_ADDR + 32'h0000_000C);

    assign o_ram_valid =
        i_cpu_valid &&
        ram_select;

    assign o_ram_write =
        i_cpu_write;

    assign o_ram_addr =
        i_cpu_addr;

    assign o_ram_wr_data =
        i_cpu_wr_data;

    assign o_ram_byte_en =
        i_cpu_byte_en;

    assign o_uart_valid =
        i_cpu_valid &&
        uart_select;

    assign o_uart_write =
        i_cpu_write;

    assign o_uart_addr =
        i_cpu_addr;

    assign o_uart_wr_data =
        i_cpu_wr_data;

    assign o_uart_byte_en =
        i_cpu_byte_en;

    always_comb begin

        o_cpu_rd_data = 32'b0;
        o_cpu_stall   = 1'b0;

        if (i_cpu_valid) begin

            if (ram_select) begin
                o_cpu_rd_data = i_ram_rd_data;
                o_cpu_stall   = i_ram_stall;
            end else if (uart_select) begin
                o_cpu_rd_data = i_uart_rd_data;
                o_cpu_stall   = i_uart_stall;
            end else begin
                o_cpu_rd_data = 32'b0;
                o_cpu_stall   = 1'b0;
            end

        end

    end

endmodule