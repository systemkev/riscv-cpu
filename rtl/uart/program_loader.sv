import uart_pkg::*;

module uart_program_loader #(
    parameter int IMEM_DEPTH = 4096
)(
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_packet_valid,
    input  logic        i_packet_error,
    input  logic [7:0]  i_packet_cmd,
    input  logic [31:0] i_packet_addr,
    input  logic [31:0] i_packet_data,

    output logic        o_imem_wr_en,
    output logic [31:0] o_imem_wr_addr,
    output logic [31:0] o_imem_wr_data,

    output logic        o_cpu_hold_reset,

    output logic        o_resp_valid,
    input  logic        i_resp_ready,
    output logic [7:0]  o_resp_status,
    output logic [7:0]  o_resp_cmd,
    output logic [31:0] o_resp_addr,
    output logic [31:0] o_resp_data
);

    logic resp_pending;
    logic addr_valid;

    assign addr_valid =
        (i_packet_addr[1:0] == 2'b00) &&
        (i_packet_addr[31:2] < IMEM_DEPTH);

    assign o_resp_valid = resp_pending;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            o_imem_wr_en     <= 1'b0;
            o_imem_wr_addr   <= 32'b0;
            o_imem_wr_data   <= 32'b0;

            o_cpu_hold_reset <= 1'b1;

            resp_pending     <= 1'b0;
            o_resp_status    <= UART_STATUS_OK;
            o_resp_cmd       <= 8'b0;
            o_resp_addr      <= 32'b0;
            o_resp_data      <= 32'b0;
        end else begin

            o_imem_wr_en <= 1'b0;

            if (resp_pending && i_resp_ready)
                resp_pending <= 1'b0;

            if (!resp_pending || i_resp_ready) begin

                if (i_packet_error) begin
                    resp_pending  <= 1'b1;
                    o_resp_status <= UART_STATUS_BAD_CRC;
                    o_resp_cmd    <= i_packet_cmd;
                    o_resp_addr   <= i_packet_addr;
                    o_resp_data   <= i_packet_data;
                end else if (i_packet_valid) begin
                    resp_pending  <= 1'b1;

                    o_resp_status <= UART_STATUS_OK;
                    o_resp_cmd    <= i_packet_cmd;
                    o_resp_addr   <= i_packet_addr;
                    o_resp_data   <= i_packet_data;

                    case (i_packet_cmd)

                        UART_CMD_WRITE_IMEM: begin
                            if (!o_cpu_hold_reset) begin
                                o_resp_status <= UART_STATUS_RUNNING;
                            end else if (!addr_valid) begin
                                o_resp_status <= UART_STATUS_BAD_ADDR;
                            end else begin
                                o_imem_wr_en   <= 1'b1;
                                o_imem_wr_addr <= i_packet_addr;
                                o_imem_wr_data <= i_packet_data;
                            end
                        end

                        UART_CMD_RUN: begin
                            o_cpu_hold_reset <= 1'b0;
                        end

                        UART_CMD_HALT: begin
                            o_cpu_hold_reset <= 1'b1;
                        end

                        UART_CMD_PING: begin
                            o_cpu_hold_reset <= o_cpu_hold_reset;
                        end

                        default: begin
                            o_resp_status <= UART_STATUS_BAD_CMD;
                        end

                    endcase
                end
            end
        end
    end

endmodule