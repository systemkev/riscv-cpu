import uart_pkg::*;

module uart_packet_parser (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_byte_valid,
    input  logic [7:0]  i_byte,

    output logic        o_packet_valid,
    output logic        o_packet_error,
    output logic [7:0]  o_cmd,
    output logic [31:0] o_addr,
    output logic [31:0] o_data
);

    typedef enum logic [3:0] {
        S_SYNC,
        S_CMD,
        S_ADDR3,
        S_ADDR2,
        S_ADDR1,
        S_ADDR0,
        S_DATA3,
        S_DATA2,
        S_DATA1,
        S_DATA0,
        S_CRC
    } t_state;

    t_state state;

    logic [7:0]  cmd_reg;
    logic [31:0] addr_reg;
    logic [31:0] data_reg;
    logic [7:0]  crc_reg;

    assign o_cmd  = cmd_reg;
    assign o_addr = addr_reg;
    assign o_data = data_reg;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state          <= S_SYNC;
            cmd_reg        <= 8'b0;
            addr_reg       <= 32'b0;
            data_reg       <= 32'b0;
            crc_reg        <= 8'b0;
            o_packet_valid <= 1'b0;
            o_packet_error <= 1'b0;
        end else begin
            o_packet_valid <= 1'b0;
            o_packet_error <= 1'b0;

            if (i_byte_valid) begin
                case (state)

                    S_SYNC: begin
                        if (i_byte == UART_REQ_SYNC) begin
                            cmd_reg  <= 8'b0;
                            addr_reg <= 32'b0;
                            data_reg <= 32'b0;
                            crc_reg  <= crc8_update(8'h00, i_byte);
                            state    <= S_CMD;
                        end
                    end

                    S_CMD: begin
                        cmd_reg <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state   <= S_ADDR3;
                    end

                    S_ADDR3: begin
                        addr_reg[31:24] <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state <= S_ADDR2;
                    end

                    S_ADDR2: begin
                        addr_reg[23:16] <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state <= S_ADDR1;
                    end

                    S_ADDR1: begin
                        addr_reg[15:8] <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state <= S_ADDR0;
                    end

                    S_ADDR0: begin
                        addr_reg[7:0] <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state <= S_DATA3;
                    end

                    S_DATA3: begin
                        data_reg[31:24] <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state <= S_DATA2;
                    end

                    S_DATA2: begin
                        data_reg[23:16] <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state <= S_DATA1;
                    end

                    S_DATA1: begin
                        data_reg[15:8] <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state <= S_DATA0;
                    end

                    S_DATA0: begin
                        data_reg[7:0] <= i_byte;
                        crc_reg <= crc8_update(crc_reg, i_byte);
                        state <= S_CRC;
                    end

                    S_CRC: begin
                        if (i_byte == crc_reg)
                            o_packet_valid <= 1'b1;
                        else
                            o_packet_error <= 1'b1;

                        state <= S_SYNC;
                    end

                    default: begin
                        state <= S_SYNC;
                    end

                endcase
            end
        end
    end

endmodule