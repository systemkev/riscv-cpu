module uart_tx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 115_200
)(
    input  logic       i_clk,
    input  logic       i_rst,

    input  logic       i_valid,
    input  logic [7:0] i_data,

    output logic       o_ready,
    output logic       o_tx,
    output logic       o_done
);

    localparam int CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam int COUNT_W      = $clog2(CLKS_PER_BIT + 1);

    logic [9:0] frame;
    logic [3:0] bit_index;
    logic [COUNT_W-1:0] clk_count;
    logic busy;

    assign o_ready = !busy;
    assign o_tx    = busy ? frame[bit_index] : 1'b1;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            frame     <= 10'h3FF;
            bit_index <= 4'd0;
            clk_count <= '0;
            busy      <= 1'b0;
            o_done    <= 1'b0;
        end else begin
            o_done <= 1'b0;

            if (!busy) begin
                clk_count <= '0;
                bit_index <= 4'd0;

                if (i_valid) begin
                    frame <= {1'b1, i_data, 1'b0};
                    busy  <= 1'b1;
                end
            end else begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= '0;

                    if (bit_index == 4'd9) begin
                        bit_index <= 4'd0;
                        busy      <= 1'b0;
                        o_done    <= 1'b1;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    clk_count <= clk_count + 1'b1;
                end
            end
        end
    end

endmodule