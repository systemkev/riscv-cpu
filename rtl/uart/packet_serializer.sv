import uart_pkg::*;

module uart_packet_serializer (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_valid,
    output logic        o_ready,

    input  logic [7:0]  i_status,
    input  logic [7:0]  i_cmd,
    input  logic [31:0] i_addr,
    input  logic [31:0] i_data,

    input  logic        i_tx_ready,
    output logic        o_byte_valid,
    output logic [7:0]  o_byte
);

    logic busy;
    logic [3:0] byte_index;

    logic [7:0]  status_reg;
    logic [7:0]  cmd_reg;
    logic [31:0] addr_reg;
    logic [31:0] data_reg;
    logic [7:0]  crc_reg;

    assign o_ready      = !busy;
    assign o_byte_valid = busy && i_tx_ready;

    always_comb begin
        case (byte_index)
            4'd0:  o_byte = UART_RESP_SYNC;
            4'd1:  o_byte = status_reg;
            4'd2:  o_byte = cmd_reg;
            4'd3:  o_byte = addr_reg[31:24];
            4'd4:  o_byte = addr_reg[23:16];
            4'd5:  o_byte = addr_reg[15:8];
            4'd6:  o_byte = addr_reg[7:0];
            4'd7:  o_byte = data_reg[31:24];
            4'd8:  o_byte = data_reg[23:16];
            4'd9:  o_byte = data_reg[15:8];
            4'd10: o_byte = data_reg[7:0];
            4'd11: o_byte = crc_reg;
            default: o_byte = 8'b0;
        endcase
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            busy       <= 1'b0;
            byte_index <= 4'd0;
            status_reg <= 8'b0;
            cmd_reg    <= 8'b0;
            addr_reg   <= 32'b0;
            data_reg   <= 32'b0;
            crc_reg    <= 8'b0;
        end else begin

            if (!busy) begin
                byte_index <= 4'd0;

                if (i_valid) begin
                    busy       <= 1'b1;
                    status_reg <= i_status;
                    cmd_reg    <= i_cmd;
                    addr_reg   <= i_addr;
                    data_reg   <= i_data;

                    crc_reg <= response_crc(
                        i_status,
                        i_cmd,
                        i_addr,
                        i_data
                    );
                end
            end else if (i_tx_ready) begin
                if (byte_index == 4'd11) begin
                    busy       <= 1'b0;
                    byte_index <= 4'd0;
                end else begin
                    byte_index <= byte_index + 1'b1;
                end
            end

        end
    end

endmodule