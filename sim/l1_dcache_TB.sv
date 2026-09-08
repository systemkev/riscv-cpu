`timescale 1ns/1ps

module l1_dcache_TB;

    localparam int LINES = 4;
    localparam int WORDS_PER_LINE = 4;
    localparam int MEM_WORDS = 256;
    localparam int MEM_AW = $clog2(MEM_WORDS);
    localparam time CLK_PERIOD = 10ns;

    logic        i_clk;
    logic        i_rst;

    logic        i_cpu_valid;
    logic        i_cpu_write;
    logic        i_cpu_uncached;
    logic [31:0] i_cpu_addr;
    logic [31:0] i_cpu_wr_data;
    logic [3:0]  i_cpu_byte_en;

    logic [31:0] o_cpu_rd_data;
    logic        o_cpu_ready;
    logic        o_cpu_stall;

    logic        o_mem_valid;
    logic        o_mem_write;
    logic [31:0] o_mem_addr;
    logic [31:0] o_mem_wr_data;
    logic [3:0]  o_mem_byte_en;

    logic        i_mem_ready;
    logic [31:0] i_mem_rd_data;

    logic [31:0] backing_mem [0:MEM_WORDS-1];

    logic        backend_pending;
    logic        backend_write;
    logic [31:0] backend_addr;
    logic [31:0] backend_wr_data;
    logic [3:0]  backend_byte_en;

    int mem_read_count;
    int mem_write_count;

    int tests_run;
    int tests_failed;

    integer i;

    l1_dcache #(
        .LINES(LINES),
        .WORDS_PER_LINE(WORDS_PER_LINE)
    ) dut (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_cpu_valid    (i_cpu_valid),
        .i_cpu_write    (i_cpu_write),
        .i_cpu_uncached (i_cpu_uncached),
        .i_cpu_addr     (i_cpu_addr),
        .i_cpu_wr_data  (i_cpu_wr_data),
        .i_cpu_byte_en  (i_cpu_byte_en),
        .o_cpu_rd_data  (o_cpu_rd_data),
        .o_cpu_ready    (o_cpu_ready),
        .o_cpu_stall    (o_cpu_stall),
        .o_mem_valid    (o_mem_valid),
        .o_mem_write    (o_mem_write),
        .o_mem_addr     (o_mem_addr),
        .o_mem_wr_data  (o_mem_wr_data),
        .o_mem_byte_en  (o_mem_byte_en),
        .i_mem_ready    (i_mem_ready),
        .i_mem_rd_data  (i_mem_rd_data)
    );

    initial i_clk = 1'b0;

    always #(CLK_PERIOD / 2) i_clk = ~i_clk;

    assign i_mem_ready = backend_pending;

    always_comb begin
        i_mem_rd_data = 32'hDEAD_BEEF;

        if (
            backend_pending &&
            !backend_write &&
            ((backend_addr >> 2) < MEM_WORDS)
        ) begin
            i_mem_rd_data =
                backing_mem[backend_addr[MEM_AW+1:2]];
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            backend_pending <= 1'b0;
            backend_write   <= 1'b0;
            backend_addr    <= 32'd0;
            backend_wr_data <= 32'd0;
            backend_byte_en <= 4'd0;
            mem_read_count  <= 0;
            mem_write_count <= 0;
        end else begin
            if (backend_pending) begin
                if (
                    backend_write &&
                    ((backend_addr >> 2) < MEM_WORDS)
                ) begin
                    if (backend_byte_en[0])
                        backing_mem[backend_addr[MEM_AW+1:2]][7:0]
                            <= backend_wr_data[7:0];

                    if (backend_byte_en[1])
                        backing_mem[backend_addr[MEM_AW+1:2]][15:8]
                            <= backend_wr_data[15:8];

                    if (backend_byte_en[2])
                        backing_mem[backend_addr[MEM_AW+1:2]][23:16]
                            <= backend_wr_data[23:16];

                    if (backend_byte_en[3])
                        backing_mem[backend_addr[MEM_AW+1:2]][31:24]
                            <= backend_wr_data[31:24];
                end

                backend_pending <= 1'b0;
            end else if (o_mem_valid) begin
                backend_pending <= 1'b1;
                backend_write   <= o_mem_write;
                backend_addr    <= o_mem_addr;
                backend_wr_data <= o_mem_wr_data;
                backend_byte_en <= o_mem_byte_en;

                if (o_mem_write)
                    mem_write_count <= mem_write_count + 1;
                else
                    mem_read_count <= mem_read_count + 1;
            end
        end
    end

    task automatic expect1(
        input string name,
        input logic actual,
        input logic expected
    );
        begin
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "%s expected=%b got=%b",
                    name,
                    expected,
                    actual
                );
            end else begin
                $display("[PASS] %s", name);
            end
        end
    endtask

    task automatic expect32(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "%s expected=%08h got=%08h",
                    name,
                    expected,
                    actual
                );
            end else begin
                $display("[PASS] %s", name);
            end
        end
    endtask

    task automatic expect_int(
        input string name,
        input integer actual,
        input integer expected
    );
        begin
            tests_run++;

            if (actual != expected) begin
                tests_failed++;
                $error(
                    "%s expected=%0d got=%0d",
                    name,
                    expected,
                    actual
                );
            end else begin
                $display("[PASS] %s", name);
            end
        end
    endtask

    task automatic clear_cpu;
        begin
            i_cpu_valid    = 1'b0;
            i_cpu_write    = 1'b0;
            i_cpu_uncached = 1'b0;
            i_cpu_addr     = 32'd0;
            i_cpu_wr_data  = 32'd0;
            i_cpu_byte_en  = 4'd0;
        end
    endtask

    task automatic reset_dut;
        begin
            @(negedge i_clk);

            i_rst = 1'b1;

            clear_cpu();

            repeat (3) begin
                @(posedge i_clk);
                #1;
            end

            @(negedge i_clk);

            i_rst = 1'b0;

            #1;
        end
    endtask

    task automatic cpu_read(
        input logic [31:0] addr,
        input logic uncached,
        output logic [31:0] data
    );

        integer cycles;
        logic done;

        begin
            @(negedge i_clk);

            i_cpu_valid    = 1'b1;
            i_cpu_write    = 1'b0;
            i_cpu_uncached = uncached;
            i_cpu_addr     = addr;
            i_cpu_wr_data  = 32'd0;
            i_cpu_byte_en  = 4'd0;

            #1;

            done   = 1'b0;
            cycles = 0;
            data   = 32'd0;

            while (!done && cycles < 200) begin
                if (o_cpu_ready) begin
                    done = 1'b1;
                end else begin
                    @(negedge i_clk);
                    #1;
                    cycles = cycles + 1;
                end
            end

            if (!done)
                $fatal(1, "CPU read timeout addr=%08h", addr);

            @(posedge i_clk);
            #1;

            data = o_cpu_rd_data;

            @(negedge i_clk);

            clear_cpu();
        end
    endtask

    task automatic cpu_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0] byte_en,
        input logic uncached
    );

        integer cycles;
        logic done;

        begin
            @(negedge i_clk);

            i_cpu_valid    = 1'b1;
            i_cpu_write    = 1'b1;
            i_cpu_uncached = uncached;
            i_cpu_addr     = addr;
            i_cpu_wr_data  = data;
            i_cpu_byte_en  = byte_en;

            #1;

            done   = 1'b0;
            cycles = 0;

            while (!done && cycles < 200) begin
                if (o_cpu_ready) begin
                    done = 1'b1;
                end else begin
                    @(negedge i_clk);
                    #1;
                    cycles = cycles + 1;
                end
            end

            if (!done)
                $fatal(1, "CPU write timeout addr=%08h", addr);

            @(posedge i_clk);
            #1;

            @(negedge i_clk);

            clear_cpu();
        end
    endtask

    initial begin

        logic [31:0] rd_data;
        integer reads_before;
        integer writes_before;

        tests_run    = 0;
        tests_failed = 0;

        i_rst = 1'b0;

        clear_cpu();

        for (i = 0; i < MEM_WORDS; i = i + 1)
            backing_mem[i] = 32'h1000_0000 + i;

        backing_mem[32'h040 >> 2] = 32'h1111_1111;
        backing_mem[32'h044 >> 2] = 32'h2222_2222;
        backing_mem[32'h048 >> 2] = 32'h3333_3333;
        backing_mem[32'h04C >> 2] = 32'h4444_4444;

        backing_mem[32'h080 >> 2] = 32'hAAAA_0000;
        backing_mem[32'h084 >> 2] = 32'hAAAA_0001;
        backing_mem[32'h088 >> 2] = 32'hAAAA_0002;
        backing_mem[32'h08C >> 2] = 32'hAAAA_0003;

        backing_mem[32'h0C0 >> 2] = 32'h3333_3333;
        backing_mem[32'h0C4 >> 2] = 32'h3333_4444;
        backing_mem[32'h0C8 >> 2] = 32'h3333_5555;
        backing_mem[32'h0CC >> 2] = 32'h3333_6666;

        backing_mem[32'h100 >> 2] = 32'h0102_0304;
        backing_mem[32'h104 >> 2] = 32'h1122_3344;
        backing_mem[32'h108 >> 2] = 32'h5566_7788;
        backing_mem[32'h10C >> 2] = 32'h99AA_BBCC;

        backing_mem[32'h154 >> 2] = 32'hCAFE_BABE;
        backing_mem[32'h168 >> 2] = 32'h1111_2222;

        reset_dut();

        expect1(
            "Idle ready after reset",
            o_cpu_ready,
            1'b0
        );

        expect1(
            "Idle stall after reset",
            o_cpu_stall,
            1'b0
        );

        reads_before = mem_read_count;

        cpu_read(
            32'h0000_0040,
            1'b0,
            rd_data
        );

        expect32(
            "Cold miss data",
            rd_data,
            32'h1111_1111
        );

        expect_int(
            "Cold miss refills four words",
            mem_read_count - reads_before,
            4
        );

        reads_before = mem_read_count;

        cpu_read(
            32'h0000_0044,
            1'b0,
            rd_data
        );

        expect32(
            "Same line hit data",
            rd_data,
            32'h2222_2222
        );

        expect_int(
            "Same line hit has no backing reads",
            mem_read_count - reads_before,
            0
        );

        cpu_write(
            32'h0000_0040,
            32'hDEAD_BEEF,
            4'b1111,
            1'b0
        );

        cpu_read(
            32'h0000_0040,
            1'b0,
            rd_data
        );

        expect32(
            "Write hit updates cache",
            rd_data,
            32'hDEAD_BEEF
        );

        expect32(
            "Write-back cache does not update memory on hit",
            backing_mem[32'h040 >> 2],
            32'h1111_1111
        );

        reads_before  = mem_read_count;
        writes_before = mem_write_count;

        cpu_read(
            32'h0000_0080,
            1'b0,
            rd_data
        );

        expect32(
            "Conflicting line refill data",
            rd_data,
            32'hAAAA_0000
        );

        expect_int(
            "Dirty eviction writes complete line",
            mem_write_count - writes_before,
            4
        );

        expect_int(
            "Replacement line refills four words",
            mem_read_count - reads_before,
            4
        );

        expect32(
            "Dirty word reached backing memory",
            backing_mem[32'h040 >> 2],
            32'hDEAD_BEEF
        );

        reads_before  = mem_read_count;
        writes_before = mem_write_count;

        cpu_write(
            32'h0000_00C0,
            32'hCAFE_BABE,
            4'b1111,
            1'b0
        );

        expect_int(
            "Write miss refills line",
            mem_read_count - reads_before,
            4
        );

        expect_int(
            "Clean victim does not write back",
            mem_write_count - writes_before,
            0
        );

        cpu_read(
            32'h0000_00C0,
            1'b0,
            rd_data
        );

        expect32(
            "Write allocate data visible",
            rd_data,
            32'hCAFE_BABE
        );

        expect32(
            "Write allocate remains dirty in cache",
            backing_mem[32'h0C0 >> 2],
            32'h3333_3333
        );

        reads_before  = mem_read_count;
        writes_before = mem_write_count;

        cpu_read(
            32'h0000_0100,
            1'b0,
            rd_data
        );

        expect32(
            "Next conflicting line data",
            rd_data,
            32'h0102_0304
        );

        expect_int(
            "Write-allocated dirty line evicted",
            mem_write_count - writes_before,
            4
        );

        expect_int(
            "Next line refill count",
            mem_read_count - reads_before,
            4
        );

        expect32(
            "Write-allocated word reaches memory on eviction",
            backing_mem[32'h0C0 >> 2],
            32'hCAFE_BABE
        );

        cpu_write(
            32'h0000_0106,
            32'h00AA_0000,
            4'b0100,
            1'b0
        );

        cpu_read(
            32'h0000_0104,
            1'b0,
            rd_data
        );

        expect32(
            "Byte write hit",
            rd_data,
            32'h11AA_3344
        );

        reads_before = mem_read_count;

        cpu_read(
            32'h0000_0154,
            1'b1,
            rd_data
        );

        expect32(
            "Uncached read data",
            rd_data,
            32'hCAFE_BABE
        );

        expect_int(
            "Uncached read is one backing transaction",
            mem_read_count - reads_before,
            1
        );

        backing_mem[32'h154 >> 2] = 32'hFACE_CAFE;

        reads_before = mem_read_count;

        cpu_read(
            32'h0000_0154,
            1'b0,
            rd_data
        );

        expect32(
            "Cached access after uncached read sees new memory value",
            rd_data,
            32'hFACE_CAFE
        );

        expect_int(
            "Uncached read did not allocate line",
            mem_read_count - reads_before,
            4
        );

        writes_before = mem_write_count;

        cpu_write(
            32'h0000_0168,
            32'h1234_5678,
            4'b1111,
            1'b1
        );

        expect_int(
            "Uncached write is one backing transaction",
            mem_write_count - writes_before,
            1
        );

        expect32(
            "Uncached write updates backing memory",
            backing_mem[32'h168 >> 2],
            32'h1234_5678
        );

        reset_dut();

        reads_before = mem_read_count;

        cpu_read(
            32'h0000_0154,
            1'b0,
            rd_data
        );

        expect32(
            "Read after cache reset",
            rd_data,
            32'hFACE_CAFE
        );

        expect_int(
            "Reset invalidated cached line",
            mem_read_count - reads_before,
            4
        );

        $display("");
        $display("====================================================");
        $display("L1 DCACHE TESTBENCH COMPLETE");
        $display("====================================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_run - tests_failed);
        $display("Tests failed : %0d", tests_failed);
        $display("====================================================");

        if (tests_failed == 0) begin
            $display("[PASS] ALL L1 DCACHE TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "[FAIL] L1 DCACHE TESTBENCH FAILED");
        end
    end

endmodule