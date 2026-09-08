module riscv_soc #(
    parameter int CLK_HZ = 100_000_000,
    parameter int UART_BAUD = 115_200,
    parameter int IMEM_DEPTH = 4096,
    parameter int DMEM_DEPTH = 4096,
    parameter int L1_LINES = 64,
    parameter int L1_WORDS_PER_LINE = 4,
    parameter string IMEM_INIT_FILE = "program.mem",
    parameter string DMEM_INIT_FILE = ""
)(
    input  logic i_clk,
    input  logic i_rst,

    input  logic i_uart_rx,
    output logic o_uart_tx
);

    localparam logic [31:0] UART_BASE_ADDR =
        32'h8000_0000;

    logic cpu_rst;
    logic loader_hold_reset;
    logic loader_uart_owner;

    logic [7:0] uart_rx_data;
    logic       uart_rx_valid;

    logic        packet_valid;
    logic        packet_error;
    logic [7:0]  packet_cmd;
    logic [31:0] packet_addr;
    logic [31:0] packet_data;

    logic        loader_imem_wr_en;
    logic [31:0] loader_imem_wr_addr;
    logic [31:0] loader_imem_wr_data;

    logic        resp_valid;
    logic        resp_ready;
    logic [7:0]  resp_status;
    logic [7:0]  resp_cmd;
    logic [31:0] resp_addr;
    logic [31:0] resp_data;

    logic       loader_tx_valid;
    logic [7:0] loader_tx_data;

    logic       mmio_tx_valid;
    logic [7:0] mmio_tx_data;

    logic       physical_tx_valid;
    logic [7:0] physical_tx_data;
    logic       physical_tx_ready;
    logic       physical_tx_done;

    logic [31:0] imem_addr;
    logic [31:0] imem_data;

    logic        cpu_dmem_valid;
    logic [31:0] cpu_dmem_addr;
    logic [31:0] cpu_dmem_wr_data;
    logic        cpu_dmem_wr_en;
    logic [3:0]  cpu_dmem_byte_en;
    logic [31:0] cpu_dmem_rd_data;
    logic        cpu_dmem_stall;

    logic        ram_dmem_valid;
    logic        ram_dmem_write;
    logic [31:0] ram_dmem_addr;
    logic [31:0] ram_dmem_wr_data;
    logic [3:0]  ram_dmem_byte_en;
    logic [31:0] ram_dmem_rd_data;
    logic        ram_dmem_stall;

    logic        uart_dmem_valid;
    logic        uart_dmem_write;
    logic [31:0] uart_dmem_addr;
    logic [31:0] uart_dmem_wr_data;
    logic [3:0]  uart_dmem_byte_en;
    logic [31:0] uart_dmem_rd_data;
    logic        uart_dmem_stall;

    logic        cache_cpu_ready;

    logic        cache_mem_valid;
    logic        cache_mem_write;
    logic [31:0] cache_mem_addr;
    logic [31:0] cache_mem_wr_data;
    logic [3:0]  cache_mem_byte_en;
    logic        cache_mem_ready;
    logic [31:0] cache_mem_rd_data;

    logic        bram_read_pending;
    logic        bram_wr_en;
    logic [31:0] bram_rd_data;

    assign cpu_rst =
        i_rst |
        loader_hold_reset;

    assign loader_uart_owner =
        loader_hold_reset |
        resp_valid |
        !resp_ready;

    uart_rx #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (UART_BAUD)
    ) u_uart_rx (
        .i_clk   (i_clk),
        .i_rst   (i_rst),
        .i_rx    (i_uart_rx),
        .o_data  (uart_rx_data),
        .o_valid (uart_rx_valid)
    );

    uart_packet_parser u_uart_packet_parser (
        .i_clk          (i_clk),
        .i_rst          (i_rst),

        .i_byte_valid   (
            uart_rx_valid &&
            loader_hold_reset
        ),

        .i_byte         (uart_rx_data),

        .o_packet_valid (packet_valid),
        .o_packet_error (packet_error),
        .o_cmd          (packet_cmd),
        .o_addr         (packet_addr),
        .o_data         (packet_data)
    );

    uart_program_loader #(
        .IMEM_DEPTH(IMEM_DEPTH)
    ) u_uart_program_loader (
        .i_clk            (i_clk),
        .i_rst            (i_rst),

        .i_packet_valid   (packet_valid),
        .i_packet_error   (packet_error),
        .i_packet_cmd     (packet_cmd),
        .i_packet_addr    (packet_addr),
        .i_packet_data    (packet_data),

        .o_imem_wr_en     (loader_imem_wr_en),
        .o_imem_wr_addr   (loader_imem_wr_addr),
        .o_imem_wr_data   (loader_imem_wr_data),

        .o_cpu_hold_reset (loader_hold_reset),

        .o_resp_valid     (resp_valid),
        .i_resp_ready     (resp_ready),
        .o_resp_status    (resp_status),
        .o_resp_cmd       (resp_cmd),
        .o_resp_addr      (resp_addr),
        .o_resp_data      (resp_data)
    );

    uart_packet_serializer u_uart_packet_serializer (
        .i_clk        (i_clk),
        .i_rst        (i_rst),

        .i_valid      (resp_valid),
        .o_ready      (resp_ready),

        .i_status     (resp_status),
        .i_cmd        (resp_cmd),
        .i_addr       (resp_addr),
        .i_data       (resp_data),

        .i_tx_ready   (
            physical_tx_ready &&
            loader_uart_owner
        ),

        .o_byte_valid (loader_tx_valid),
        .o_byte       (loader_tx_data)
    );

    assign physical_tx_valid =
        loader_uart_owner
        ? loader_tx_valid
        : mmio_tx_valid;

    assign physical_tx_data =
        loader_uart_owner
        ? loader_tx_data
        : mmio_tx_data;

    uart_tx #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (UART_BAUD)
    ) u_uart_tx (
        .i_clk   (i_clk),
        .i_rst   (i_rst),

        .i_valid (physical_tx_valid),
        .i_data  (physical_tx_data),

        .o_ready (physical_tx_ready),
        .o_tx    (o_uart_tx),
        .o_done  (physical_tx_done)
    );

    riscv_core u_core (
        .i_clk          (i_clk),
        .i_rst          (cpu_rst),

        .o_imem_addr    (imem_addr),
        .i_imem_data    (imem_data),

        .o_dmem_valid   (cpu_dmem_valid),
        .o_dmem_addr    (cpu_dmem_addr),
        .o_dmem_wr_data (cpu_dmem_wr_data),
        .o_dmem_wr_en   (cpu_dmem_wr_en),
        .o_dmem_byt_en  (cpu_dmem_byte_en),

        .i_dmem_data    (cpu_dmem_rd_data),
        .i_dmem_stall   (cpu_dmem_stall)
    );

    instruction_memory #(
        .DEPTH_WORDS (IMEM_DEPTH),
        .INIT_FILE   (IMEM_INIT_FILE)
    ) u_imem (
        .i_clk            (i_clk),

        .i_addr           (imem_addr),
        .o_data           (imem_data),

        .i_loader_wr_en   (loader_imem_wr_en),
        .i_loader_wr_addr (loader_imem_wr_addr),
        .i_loader_wr_data (loader_imem_wr_data)
    );

    dmem_addr_decoder #(
        .DMEM_DEPTH     (DMEM_DEPTH),
        .UART_BASE_ADDR (UART_BASE_ADDR)
    ) u_dmem_addr_decoder (
        .i_cpu_valid     (cpu_dmem_valid),
        .i_cpu_write     (cpu_dmem_wr_en),
        .i_cpu_addr      (cpu_dmem_addr),
        .i_cpu_wr_data   (cpu_dmem_wr_data),
        .i_cpu_byte_en   (cpu_dmem_byte_en),

        .o_ram_valid     (ram_dmem_valid),
        .o_ram_write     (ram_dmem_write),
        .o_ram_addr      (ram_dmem_addr),
        .o_ram_wr_data   (ram_dmem_wr_data),
        .o_ram_byte_en   (ram_dmem_byte_en),

        .i_ram_rd_data   (ram_dmem_rd_data),
        .i_ram_stall     (ram_dmem_stall),

        .o_uart_valid    (uart_dmem_valid),
        .o_uart_write    (uart_dmem_write),
        .o_uart_addr     (uart_dmem_addr),
        .o_uart_wr_data  (uart_dmem_wr_data),
        .o_uart_byte_en  (uart_dmem_byte_en),

        .i_uart_rd_data  (uart_dmem_rd_data),
        .i_uart_stall    (uart_dmem_stall),

        .o_cpu_rd_data   (cpu_dmem_rd_data),
        .o_cpu_stall     (cpu_dmem_stall)
    );

    uart_mmio #(
        .BASE_ADDR(UART_BASE_ADDR)
    ) u_uart_mmio (
        .i_clk           (i_clk),
        .i_rst           (cpu_rst),

        .i_req_valid     (uart_dmem_valid),
        .i_req_write     (uart_dmem_write),
        .i_req_addr      (uart_dmem_addr),
        .i_req_wr_data   (uart_dmem_wr_data),
        .i_req_byte_en   (uart_dmem_byte_en),

        .o_req_rd_data   (uart_dmem_rd_data),
        .o_req_stall     (uart_dmem_stall),

        .i_uart_rx_valid (
            uart_rx_valid &&
            !loader_uart_owner
        ),

        .i_uart_rx_data  (uart_rx_data),

        .o_uart_tx_valid (mmio_tx_valid),
        .o_uart_tx_data  (mmio_tx_data),

        .i_uart_tx_ready (
            physical_tx_ready &&
            !loader_uart_owner
        )
    );

    l1_dcache #(
        .LINES          (L1_LINES),
        .WORDS_PER_LINE (L1_WORDS_PER_LINE)
    ) u_l1_dcache (
        .i_clk          (i_clk),
        .i_rst          (cpu_rst),

        .i_cpu_valid    (ram_dmem_valid),
        .i_cpu_write    (ram_dmem_write),
        .i_cpu_uncached (1'b0),
        .i_cpu_addr     (ram_dmem_addr),
        .i_cpu_wr_data  (ram_dmem_wr_data),
        .i_cpu_byte_en  (ram_dmem_byte_en),

        .o_cpu_rd_data  (ram_dmem_rd_data),
        .o_cpu_ready    (cache_cpu_ready),
        .o_cpu_stall    (ram_dmem_stall),

        .o_mem_valid    (cache_mem_valid),
        .o_mem_write    (cache_mem_write),
        .o_mem_addr     (cache_mem_addr),
        .o_mem_wr_data  (cache_mem_wr_data),
        .o_mem_byte_en  (cache_mem_byte_en),

        .i_mem_ready    (cache_mem_ready),
        .i_mem_rd_data  (cache_mem_rd_data)
    );

    assign bram_wr_en =
        cache_mem_valid &&
        cache_mem_write &&
        !bram_read_pending;

    assign cache_mem_ready =
        bram_read_pending ||
        (
            cache_mem_valid &&
            cache_mem_write &&
            !bram_read_pending
        );

    assign cache_mem_rd_data =
        bram_rd_data;

    always_ff @(posedge i_clk) begin
        if (cpu_rst) begin
            bram_read_pending <= 1'b0;
        end else if (bram_read_pending) begin
            bram_read_pending <= 1'b0;
        end else if (
            cache_mem_valid &&
            !cache_mem_write
        ) begin
            bram_read_pending <= 1'b1;
        end
    end

    data_memory #(
        .DEPTH_WORDS (DMEM_DEPTH),
        .INIT_FILE   (DMEM_INIT_FILE)
    ) u_dmem (
        .i_clk      (i_clk),

        .i_addr     (cache_mem_addr),
        .i_wr_data  (cache_mem_wr_data),
        .i_wr_en    (bram_wr_en),
        .i_byte_en  (cache_mem_byte_en),

        .o_rd_data  (bram_rd_data)
    );

endmodule