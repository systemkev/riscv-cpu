package uart_pkg;

    localparam logic [7:0] UART_REQ_SYNC  = 8'hA5;
    localparam logic [7:0] UART_RESP_SYNC = 8'h5A;

    localparam logic [7:0] UART_CMD_WRITE_IMEM = 8'h01;
    localparam logic [7:0] UART_CMD_RUN        = 8'h02;
    localparam logic [7:0] UART_CMD_HALT       = 8'h03;
    localparam logic [7:0] UART_CMD_PING       = 8'h04;

    localparam logic [7:0] UART_STATUS_OK       = 8'h00;
    localparam logic [7:0] UART_STATUS_BAD_CRC  = 8'h01;
    localparam logic [7:0] UART_STATUS_BAD_CMD  = 8'h02;
    localparam logic [7:0] UART_STATUS_RUNNING  = 8'h03;
    localparam logic [7:0] UART_STATUS_BAD_ADDR = 8'h04;

    function automatic logic [7:0] crc8_update(
        input logic [7:0] i_crc,
        input logic [7:0] i_data
    );

        logic [7:0] c;
        integer i;

        begin
            c = i_crc ^ i_data;

            for (i = 0; i < 8; i = i + 1) begin
                if (c[7])
                    c = (c << 1) ^ 8'h07;
                else
                    c = c << 1;
            end

            crc8_update = c;
        end

    endfunction

    function automatic logic [7:0] response_crc(
        input logic [7:0]  i_status,
        input logic [7:0]  i_cmd,
        input logic [31:0] i_addr,
        input logic [31:0] i_data
    );

        logic [7:0] c;

        begin
            c = 8'h00;

            c = crc8_update(c, UART_RESP_SYNC);
            c = crc8_update(c, i_status);
            c = crc8_update(c, i_cmd);

            c = crc8_update(c, i_addr[31:24]);
            c = crc8_update(c, i_addr[23:16]);
            c = crc8_update(c, i_addr[15:8]);
            c = crc8_update(c, i_addr[7:0]);

            c = crc8_update(c, i_data[31:24]);
            c = crc8_update(c, i_data[23:16]);
            c = crc8_update(c, i_data[15:8]);
            c = crc8_update(c, i_data[7:0]);

            response_crc = c;
        end

    endfunction

endpackage