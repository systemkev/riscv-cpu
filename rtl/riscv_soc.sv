module riscv_soc #(
    parameter int IMEM_DEPTH = 4096,
    parameter int DMEM_DEPTH = 4096,

    parameter string IMEM_INIT_FILE = "program.mem",
    parameter string DMEM_INIT_FILE = ""
)(
    input  logic        i_clk,
    input  logic        i_rst,

    // Temporary debug outputs
    output logic [31:0] o_debug_addr,
    output logic [31:0] o_debug_data,
    output logic        o_debug_write
);

    // ========================================================================
    // Instruction memory
    // ========================================================================

    logic [31:0] imem_addr;
    logic [31:0] imem_data;

    // ========================================================================
    // Data memory
    // ========================================================================

    logic [31:0] dmem_addr;
    logic [31:0] dmem_wr_data;
    logic        dmem_wr_en;
    logic [3:0]  dmem_byte_en;
    logic [31:0] dmem_rd_data;

    // ========================================================================
    // CPU
    // ========================================================================

    riscv_core u_core (
        .i_clk              (i_clk),
        .i_rst              (i_rst),

        .o_imem_addr        (imem_addr),
        .i_imem_data        (imem_data),

        .o_dmem_addr        (dmem_addr),
        .o_dmem_wr_data     (dmem_wr_data),
        .o_dmem_wr_en       (dmem_wr_en),
        .o_dmem_byt_en      (dmem_byte_en),

        .i_dmem_data        (dmem_rd_data)
    );

    // ========================================================================
    // Instruction memory
    // ========================================================================

    instruction_memory #(
        .DEPTH_WORDS (IMEM_DEPTH),
        .INIT_FILE   (IMEM_INIT_FILE)
    ) u_imem (
        .i_clk  (i_clk),
        .i_addr (imem_addr),
        .o_data (imem_data)
    );

    // ========================================================================
    // Data memory
    // ========================================================================

    data_memory #(
        .DEPTH_WORDS (DMEM_DEPTH),
        .INIT_FILE   (DMEM_INIT_FILE)
    ) u_dmem (
        .i_clk      (i_clk),
        .i_addr     (dmem_addr),
        .i_wr_data  (dmem_wr_data),
        .i_wr_en    (dmem_wr_en),
        .i_byte_en  (dmem_byte_en),
        .o_rd_data  (dmem_rd_data)
    );

    // ========================================================================
    // Temporary externally-visible debug interface.
    //
    // Prevents synthesis from removing the CPU while doing utilization /
    // timing analysis.
    // ========================================================================

    assign o_debug_addr  = dmem_addr;
    assign o_debug_data  = dmem_wr_data;
    assign o_debug_write = dmem_wr_en;

endmodule