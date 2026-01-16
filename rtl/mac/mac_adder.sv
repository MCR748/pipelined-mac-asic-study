module mac_adder #(
        parameter INPUT_WIDTH = 32
    )(
        input  wire                     i_clk,
        input  wire                     i_rst,
        input  wire [INPUT_WIDTH-1:0]   i_adder_a,
        input  wire [INPUT_WIDTH-1:0]   i_adder_b,
        input  wire                     i_adder_valid,
        output wire [INPUT_WIDTH-1:0]   o_adder_val,
        output wire                     o_adder_valid
    );

    localparam BLOCK_W = INPUT_WIDTH / 4;

    reg [BLOCK_W-1:0] r_stg0_a [0:3];
    reg [BLOCK_W-1:0] r_stg0_b [0:3];
    reg               r_stg0_valid;

    reg [BLOCK_W-1:0] r_stg1_s0;
    reg               r_stg1_c0;

    reg [BLOCK_W-1:0] r_stg1_s10;
    reg [BLOCK_W-1:0] r_stg1_s11;
    reg               r_stg1_c10;
    reg               r_stg1_c11;

    wire [BLOCK_W-1:0] w_stg1_s10;
    wire               w_stg1_c10;
    wire [BLOCK_W-1:0] w_stg1_s11;
    wire               w_stg1_c11;

    reg [BLOCK_W-1:0] r_stg1_s20;
    reg [BLOCK_W-1:0] r_stg1_s21;
    reg               r_stg1_c20;
    reg               r_stg1_c21;

    wire [BLOCK_W-1:0] w_stg1_s20;
    wire [BLOCK_W-1:0] w_stg1_s21;
    wire               w_stg1_c20;
    wire               w_stg1_c21;

    reg [BLOCK_W-1:0] r_stg1_s30;
    reg [BLOCK_W-1:0] r_stg1_s31;

    wire [BLOCK_W-1:0] w_stg1_s30;
    wire [BLOCK_W-1:0] w_stg1_s31;

    reg               r_stg1_valid;

    wire              w_stg2_c16;
    wire              w_stg2_c24;

    wire [BLOCK_W-1:0] w_stg2_s0;
    wire [BLOCK_W-1:0] w_stg2_s1;
    wire [BLOCK_W-1:0] w_stg2_s2;
    wire [BLOCK_W-1:0] w_stg2_s3;

    reg  [INPUT_WIDTH-1:0] r_o_adder_val;
    reg                    r_o_adder_valid;

    integer i;

    always @(posedge i_clk)
    begin
        if (i_rst)
        begin
            // Stage 0
            for (i = 0; i < 4; i = i + 1)
            begin
                r_stg0_a[i] <= '0;
                r_stg0_b[i] <= '0;
            end
            r_stg0_valid <= 1'b0;

            // Stage 1
            r_stg1_s0  <= '0;
            r_stg1_c0  <= 1'b0;

            r_stg1_s10 <= '0;
            r_stg1_s11 <= '0;
            r_stg1_c10 <= 1'b0;
            r_stg1_c11 <= 1'b0;

            r_stg1_s20 <= '0;
            r_stg1_s21 <= '0;
            r_stg1_c20 <= 1'b0;
            r_stg1_c21 <= 1'b0;

            r_stg1_s30 <= '0;
            r_stg1_s31 <= '0;

            r_stg1_valid <= 1'b0;

            // Stage 2
            r_o_adder_val   <= '0;
            r_o_adder_valid <= 1'b0;

        end
        else
        begin
            // Stage 0
            for (i = 0; i < 4; i = i + 1)
            begin
                r_stg0_a[i] <= i_adder_a[(i+1)*BLOCK_W-1 -: BLOCK_W];
                r_stg0_b[i] <= i_adder_b[(i+1)*BLOCK_W-1 -: BLOCK_W];
            end
            r_stg0_valid <= i_adder_valid;

            // Stage 1
            {r_stg1_c0, r_stg1_s0} <=  r_stg0_a[0] + r_stg0_b[0];

            r_stg1_s10 <= w_stg1_s10;
            r_stg1_c10 <= w_stg1_c10;
            r_stg1_s11 <= w_stg1_s11;
            r_stg1_c11 <= w_stg1_c11;

            r_stg1_s20 <= w_stg1_s20;
            r_stg1_c20 <= w_stg1_c20;
            r_stg1_s21 <= w_stg1_s21;
            r_stg1_c21 <= w_stg1_c21;

            r_stg1_s30 <= w_stg1_s30;
            r_stg1_s31 <= w_stg1_s31;

            r_stg1_valid <= r_stg0_valid;

            // -------------------------
            // Stage 2
            // -------------------------
            r_o_adder_val   <= {w_stg2_s3, w_stg2_s2, w_stg2_s1, w_stg2_s0};
            r_o_adder_valid <= r_stg1_valid;
        end
    end

    // Stage 1
    assign {w_stg1_c10, w_stg1_s10} = r_stg0_a[1] + r_stg0_b[1];
    assign w_stg1_s11 = w_stg1_s10 + {{(BLOCK_W-1){1'b0}}, 1'b1};
    assign w_stg1_c11 = w_stg1_c10 | &w_stg1_s10;

    assign {w_stg1_c20, w_stg1_s20} = r_stg0_a[2] + r_stg0_b[2];
    assign w_stg1_s21 = w_stg1_s20 + {{(BLOCK_W-1){1'b0}}, 1'b1};
    assign w_stg1_c21 = w_stg1_c20 | &w_stg1_s20;

    assign w_stg1_s30 = r_stg0_a[3] + r_stg0_b[3];
    assign w_stg1_s31 = w_stg1_s30 + {{(BLOCK_W-1){1'b0}}, 1'b1};

    // Stage 2
    assign w_stg2_c16 = r_stg1_c0 ? r_stg1_c11 : r_stg1_c10;
    assign w_stg2_c24 = w_stg2_c16 ? r_stg1_c21 : r_stg1_c20;

    assign w_stg2_s0 = r_stg1_s0;
    assign w_stg2_s1 = r_stg1_c0   ? r_stg1_s11 : r_stg1_s10;
    assign w_stg2_s2 = w_stg2_c16  ? r_stg1_s21 : r_stg1_s20;
    assign w_stg2_s3 = w_stg2_c24  ? r_stg1_s31 : r_stg1_s30;

    assign o_adder_val   = r_o_adder_val;
    assign o_adder_valid = r_o_adder_valid;
endmodule
