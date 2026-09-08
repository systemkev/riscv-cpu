module uart_mmio #(
    parameter logic [31:0] BASE_ADDR = 32'h8000_0000
)(
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_req_valid,
    input  logic        i_req_write,
    input  logic [31:0] i_req_addr,
    input  logic [31:0] i_req_wr_data,
    input  logic [3:0]  i_req_byte_en,

    output logic [31:0] o_req_rd_data,
    output logic        o_req_stall,

    input  logic        i_uart_rx_valid,
    input  logic [7:0]  i_uart_rx_data,

    output logic        o_uart_tx_valid,
    output logic [7:0]  o_uart_tx_data,
    input  logic        i_uart_tx_ready
);

    localparam logic [31:0] UART_TX_ADDR =
        BASE_ADDR + 32'h0000_0000;

    localparam logic [31:0] UART_RX_ADDR =
        BASE_ADDR + 32'h0000_0004;

    localparam logic [31:0] UART_STATUS_ADDR =
        BASE_ADDR + 32'h0000_0008;

    logic [7:0] rx_data_q;
    logic       rx_pending;

    logic [7:0] tx_data_q;
    logic       tx_pending;

    logic tx_write_req;
    logic rx_read_req;
    logic tx_can_accept;

    assign tx_write_req =
        i_req_valid &&
        i_req_write &&
        (i_req_addr == UART_TX_ADDR);

    assign rx_read_req =
        i_req_valid &&
        !i_req_write &&
        (i_req_addr == UART_RX_ADDR);

    assign tx_can_accept =
        !tx_pending ||
        i_uart_tx_ready;

    assign o_req_stall =
        tx_write_req &&
        !tx_can_accept;

    assign o_uart_tx_valid =
        tx_pending;

    assign o_uart_tx_data =
        tx_data_q;

    always_comb begin
        o_req_rd_data = 32'b0;

        case (i_req_addr)

            UART_RX_ADDR: begin
                o_req_rd_data = {
                    24'b0,
                    rx_data_q
                };
            end

            UART_STATUS_ADDR: begin
                o_req_rd_data = {
                    30'b0,
                    rx_pending,
                    tx_can_accept
                };
            end

            default: begin
                o_req_rd_data = 32'b0;
            end

        endcase
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            rx_data_q  <= 8'b0;
            rx_pending <= 1'b0;
        end else begin

            if (rx_read_req && !o_req_stall)
                rx_pending <= 1'b0;

            if (i_uart_rx_valid) begin
                rx_data_q  <= i_uart_rx_data;
                rx_pending <= 1'b1;
            end

        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            tx_data_q  <= 8'b0;
            tx_pending <= 1'b0;
        end else begin

            if (
                tx_pending &&
                i_uart_tx_ready
            ) begin
                tx_pending <= 1'b0;
            end

            if (
                tx_write_req &&
                tx_can_accept
            ) begin
                tx_data_q  <= i_req_wr_data[7:0];
                tx_pending <= 1'b1;
            end

        end
    end

endmodule