module uart_rx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 115_200
)(
    input  logic       i_clk,
    input  logic       i_rst,
    input  logic       i_rx,

    output logic [7:0] o_data,
    output logic       o_valid
);

    localparam int CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam int HALF_CLKS    = CLKS_PER_BIT / 2;
    localparam int COUNT_W      = $clog2(CLKS_PER_BIT + 1);

    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP
    } t_state;

    t_state state;

    logic rx_meta;
    logic rx_sync;

    logic [COUNT_W-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            rx_meta   <= 1'b1;
            rx_sync   <= 1'b1;
            state     <= S_IDLE;
            clk_count <= '0;
            bit_index <= '0;
            shift_reg <= 8'b0;
            o_data    <= 8'b0;
            o_valid   <= 1'b0;
        end else begin
            rx_meta <= i_rx;
            rx_sync <= rx_meta;

            o_valid <= 1'b0;

            case (state)

                S_IDLE: begin
                    clk_count <= '0;
                    bit_index <= '0;

                    if (!rx_sync)
                        state <= S_START;
                end

                S_START: begin
                    if (clk_count == HALF_CLKS - 1) begin
                        clk_count <= '0;

                        if (!rx_sync)
                            state <= S_DATA;
                        else
                            state <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;

                        shift_reg[bit_index] <= rx_sync;

                        if (bit_index == 3'd7) begin
                            bit_index <= '0;
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        state <= S_IDLE;

                        if (rx_sync) begin
                            o_data  <= shift_reg;
                            o_valid <= 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule