module l1_dcache #(
    parameter int LINES          = 64,
    parameter int WORDS_PER_LINE = 4
)(
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_cpu_valid,
    input  logic        i_cpu_write,
    input  logic        i_cpu_uncached,
    input  logic [31:0] i_cpu_addr,
    input  logic [31:0] i_cpu_wr_data,
    input  logic [3:0]  i_cpu_byte_en,

    output logic [31:0] o_cpu_rd_data,
    output logic        o_cpu_ready,
    output logic        o_cpu_stall,

    output logic        o_mem_valid,
    output logic        o_mem_write,
    output logic [31:0] o_mem_addr,
    output logic [31:0] o_mem_wr_data,
    output logic [3:0]  o_mem_byte_en,

    input  logic        i_mem_ready,
    input  logic [31:0] i_mem_rd_data
);

    localparam int INDEX_BITS     = $clog2(LINES);
    localparam int WORD_BITS      = $clog2(WORDS_PER_LINE);
    localparam int TAG_BITS       = 32 - INDEX_BITS - WORD_BITS - 2;
    localparam int DATA_ADDR_BITS = INDEX_BITS + WORD_BITS;
    localparam int DATA_WORDS     = LINES * WORDS_PER_LINE;

    typedef enum logic [3:0] {
        S_IDLE,
        S_LOOKUP,
        S_WRITEBACK_READ,
        S_WRITEBACK_SEND,
        S_REFILL,
        S_MISS_READ,
        S_MISS_WRITE,
        S_RESPONSE,
        S_UNCACHED
    } t_cache_state;

    t_cache_state state;

    (* ram_style = "block" *)
    logic [31:0] data_array [0:DATA_WORDS-1];

    (* ram_style = "distributed" *)
    logic [TAG_BITS-1:0] tag_array [0:LINES-1];

    logic [LINES-1:0] valid_array;
    logic [LINES-1:0] dirty_array;

    logic [31:0] req_addr;
    logic        req_write;
    logic        req_uncached;
    logic [31:0] req_wr_data;
    logic [3:0]  req_byte_en;

    logic [INDEX_BITS-1:0] req_index;
    logic [WORD_BITS-1:0]  req_word;
    logic [TAG_BITS-1:0]   req_tag;

    logic [TAG_BITS-1:0] victim_tag;
    logic [WORD_BITS-1:0] word_count;

    logic req_hit;

    logic [DATA_ADDR_BITS-1:0] data_addr;
    logic [31:0]               data_wr_data;
    logic [3:0]                data_wr_en;
    logic                      data_rd_en;
    logic [31:0]               data_rd_data;

    logic [31:0] uncached_rd_data;

    assign req_hit =
        valid_array[req_index] &&
        (tag_array[req_index] == req_tag);

    always_comb begin
        data_addr    = {req_index, req_word};
        data_wr_data = 32'b0;
        data_wr_en   = 4'b0000;
        data_rd_en   = 1'b0;

        case (state)

            S_LOOKUP: begin
                if (req_hit) begin
                    if (req_write) begin
                        data_addr    = {req_index, req_word};
                        data_wr_data = req_wr_data;
                        data_wr_en   = req_byte_en;
                    end else begin
                        data_addr  = {req_index, req_word};
                        data_rd_en = 1'b1;
                    end
                end
            end

            S_WRITEBACK_READ: begin
                data_addr  = {req_index, word_count};
                data_rd_en = 1'b1;
            end

            S_REFILL: begin
                if (i_mem_ready) begin
                    data_addr    = {req_index, word_count};
                    data_wr_data = i_mem_rd_data;
                    data_wr_en   = 4'b1111;
                end
            end

            S_MISS_READ: begin
                data_addr  = {req_index, req_word};
                data_rd_en = 1'b1;
            end

            S_MISS_WRITE: begin
                data_addr    = {req_index, req_word};
                data_wr_data = req_wr_data;
                data_wr_en   = req_byte_en;
            end

            default: begin
                data_addr    = {req_index, req_word};
                data_wr_data = 32'b0;
                data_wr_en   = 4'b0000;
                data_rd_en   = 1'b0;
            end

        endcase
    end

    always_ff @(posedge i_clk) begin
        if (data_wr_en[0])
            data_array[data_addr][7:0]
                <= data_wr_data[7:0];

        if (data_wr_en[1])
            data_array[data_addr][15:8]
                <= data_wr_data[15:8];

        if (data_wr_en[2])
            data_array[data_addr][23:16]
                <= data_wr_data[23:16];

        if (data_wr_en[3])
            data_array[data_addr][31:24]
                <= data_wr_data[31:24];

        if (data_rd_en)
            data_rd_data <= data_array[data_addr];
    end

    always_comb begin
        o_cpu_rd_data = 32'b0;
        o_cpu_ready   = 1'b0;
        o_cpu_stall   = 1'b0;

        o_mem_valid   = 1'b0;
        o_mem_write   = 1'b0;
        o_mem_addr    = 32'b0;
        o_mem_wr_data = 32'b0;
        o_mem_byte_en = 4'b0000;

        case (state)

            S_IDLE: begin
                if (i_cpu_valid)
                    o_cpu_stall = 1'b1;
            end

            S_LOOKUP: begin
                o_cpu_stall = 1'b1;
            end

            S_WRITEBACK_READ: begin
                o_cpu_stall = 1'b1;
            end

            S_WRITEBACK_SEND: begin
                o_cpu_stall   = 1'b1;
                o_mem_valid   = 1'b1;
                o_mem_write   = 1'b1;
                o_mem_addr    = {
                    victim_tag,
                    req_index,
                    word_count,
                    2'b00
                };
                o_mem_wr_data = data_rd_data;
                o_mem_byte_en = 4'b1111;
            end

            S_REFILL: begin
                o_cpu_stall = 1'b1;
                o_mem_valid = 1'b1;
                o_mem_write = 1'b0;
                o_mem_addr  = {
                    req_tag,
                    req_index,
                    word_count,
                    2'b00
                };
            end

            S_MISS_READ: begin
                o_cpu_stall = 1'b1;
            end

            S_MISS_WRITE: begin
                o_cpu_stall = 1'b1;
            end

            S_RESPONSE: begin
                o_cpu_ready = 1'b1;
                o_cpu_stall = 1'b0;

                if (req_uncached)
                    o_cpu_rd_data = uncached_rd_data;
                else
                    o_cpu_rd_data = data_rd_data;
            end

            S_UNCACHED: begin
                o_cpu_stall   = 1'b1;
                o_mem_valid   = 1'b1;
                o_mem_write   = req_write;
                o_mem_addr    = req_addr;
                o_mem_wr_data = req_wr_data;
                o_mem_byte_en = req_byte_en;
            end

            default: begin
                o_cpu_stall = 1'b0;
            end

        endcase
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state             <= S_IDLE;

            req_addr          <= 32'b0;
            req_write         <= 1'b0;
            req_uncached      <= 1'b0;
            req_wr_data       <= 32'b0;
            req_byte_en       <= 4'b0000;

            req_index         <= '0;
            req_word          <= '0;
            req_tag           <= '0;

            victim_tag        <= '0;
            word_count        <= '0;

            uncached_rd_data  <= 32'b0;

            valid_array       <= '0;
            dirty_array       <= '0;
        end else begin

            case (state)

                S_IDLE: begin
                    if (i_cpu_valid) begin
                        req_addr     <= i_cpu_addr;
                        req_write    <= i_cpu_write;
                        req_uncached <= i_cpu_uncached;
                        req_wr_data  <= i_cpu_wr_data;
                        req_byte_en  <= i_cpu_byte_en;

                        req_index <=
                            i_cpu_addr[
                                INDEX_BITS + WORD_BITS + 1 :
                                WORD_BITS + 2
                            ];

                        req_word <=
                            i_cpu_addr[
                                WORD_BITS + 1 :
                                2
                            ];

                        req_tag <=
                            i_cpu_addr[
                                31 :
                                INDEX_BITS + WORD_BITS + 2
                            ];

                        word_count <= '0;

                        if (i_cpu_uncached)
                            state <= S_UNCACHED;
                        else
                            state <= S_LOOKUP;
                    end
                end

                S_LOOKUP: begin
                    if (req_hit) begin
                        if (req_write) begin
                            dirty_array[req_index] <= 1'b1;
                            state <= S_RESPONSE;
                        end else begin
                            state <= S_RESPONSE;
                        end
                    end else begin
                        victim_tag <= tag_array[req_index];
                        word_count <= '0;

                        if (
                            valid_array[req_index] &&
                            dirty_array[req_index]
                        )
                            state <= S_WRITEBACK_READ;
                        else
                            state <= S_REFILL;
                    end
                end

                S_WRITEBACK_READ: begin
                    state <= S_WRITEBACK_SEND;
                end

                S_WRITEBACK_SEND: begin
                    if (i_mem_ready) begin
                        if (word_count == WORDS_PER_LINE - 1) begin
                            word_count <= '0;
                            state      <= S_REFILL;
                        end else begin
                            word_count <= word_count + 1'b1;
                            state      <= S_WRITEBACK_READ;
                        end
                    end
                end

                S_REFILL: begin
                    if (i_mem_ready) begin
                        if (word_count == WORDS_PER_LINE - 1) begin
                            tag_array[req_index]   <= req_tag;
                            valid_array[req_index] <= 1'b1;
                            dirty_array[req_index] <= 1'b0;
                            word_count             <= '0;

                            if (req_write)
                                state <= S_MISS_WRITE;
                            else
                                state <= S_MISS_READ;
                        end else begin
                            word_count <= word_count + 1'b1;
                        end
                    end
                end

                S_MISS_READ: begin
                    state <= S_RESPONSE;
                end

                S_MISS_WRITE: begin
                    dirty_array[req_index] <= 1'b1;
                    state <= S_RESPONSE;
                end

                S_RESPONSE: begin
                    state <= S_IDLE;
                end

                S_UNCACHED: begin
                    if (i_mem_ready) begin
                        if (!req_write)
                            uncached_rd_data <= i_mem_rd_data;

                        state <= S_RESPONSE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule