module branch_predictor #(
    parameter int ENTRIES = 64
)(
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic [31:0] i_fetch_pc,
    output logic        o_pred_taken,
    output logic [31:0] o_pred_target,
    input  logic        i_resolve_valid,
    input  logic [31:0] i_resolve_pc,
    input  logic        i_resolve_is_branch,
    input  logic        i_resolve_is_jump,
    input  logic        i_resolve_taken,
    input  logic [31:0] i_resolve_target,
    input  logic        i_resolve_pred_taken,
    input  logic [31:0] i_resolve_pred_target,
    output logic        o_mispredict,
    output logic [31:0] o_recovery_pc
);

    localparam int INDEX_BITS = $clog2(ENTRIES);
    localparam int TAG_BITS   = 32 - INDEX_BITS - 2;

    logic [ENTRIES-1:0] btb_valid;

    (* ram_style = "distributed" *)
    logic [TAG_BITS:0] btb_meta [0:ENTRIES-1];

    (* ram_style = "distributed" *)
    logic [31:0] btb_target [0:ENTRIES-1];

    logic [1:0] bht [0:ENTRIES-1];

    logic [INDEX_BITS-1:0] fetch_index;
    logic [INDEX_BITS-1:0] resolve_index;
    logic [TAG_BITS-1:0] fetch_tag;
    logic [TAG_BITS-1:0] resolve_tag;
    logic [TAG_BITS:0] fetch_meta;
    logic [31:0] fetch_target;
    logic [1:0] fetch_bht;
    logic fetch_hit;

    assign fetch_index   = i_fetch_pc[INDEX_BITS+1:2];
    assign resolve_index = i_resolve_pc[INDEX_BITS+1:2];
    assign fetch_tag     = i_fetch_pc[31:INDEX_BITS+2];
    assign resolve_tag   = i_resolve_pc[31:INDEX_BITS+2];

    assign fetch_meta   = btb_meta[fetch_index];
    assign fetch_target = btb_target[fetch_index];
    assign fetch_bht    = bht[fetch_index];

    assign fetch_hit =
        btb_valid[fetch_index] &&
        (fetch_meta[TAG_BITS:1] == fetch_tag);

    always_comb begin
        o_pred_taken  = 1'b0;
        o_pred_target = i_fetch_pc + 32'd4;

        if (fetch_hit) begin
            o_pred_target = fetch_target;

            if (fetch_meta[0])
                o_pred_taken = fetch_bht[1];
            else
                o_pred_taken = 1'b1;
        end
    end

    always_comb begin
        o_mispredict =
            i_resolve_valid &&
            (i_resolve_is_branch || i_resolve_is_jump) &&
            (
                (i_resolve_pred_taken != i_resolve_taken) ||
                (
                    i_resolve_taken &&
                    i_resolve_pred_taken &&
                    (i_resolve_pred_target != i_resolve_target)
                )
            );

        if (i_resolve_taken)
            o_recovery_pc = i_resolve_target;
        else
            o_recovery_pc = i_resolve_pc + 32'd4;
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            btb_valid <= '0;
        end else if (
            i_resolve_valid &&
            (i_resolve_is_branch || i_resolve_is_jump)
        ) begin
            btb_valid[resolve_index]  <= 1'b1;
            btb_meta[resolve_index]   <= {resolve_tag, i_resolve_is_branch};
            btb_target[resolve_index] <= i_resolve_target;

            if (i_resolve_is_branch) begin
                if (!btb_valid[resolve_index]) begin
                    bht[resolve_index] <= i_resolve_taken ? 2'b10 : 2'b01;
                end else begin
                    case (bht[resolve_index])
                        2'b00: bht[resolve_index] <= i_resolve_taken ? 2'b01 : 2'b00;
                        2'b01: bht[resolve_index] <= i_resolve_taken ? 2'b10 : 2'b00;
                        2'b10: bht[resolve_index] <= i_resolve_taken ? 2'b11 : 2'b01;
                        2'b11: bht[resolve_index] <= i_resolve_taken ? 2'b11 : 2'b10;
                        default: bht[resolve_index] <= i_resolve_taken ? 2'b10 : 2'b01;
                    endcase
                end
            end else begin
                bht[resolve_index] <= 2'b01;
            end
        end
    end

endmodule