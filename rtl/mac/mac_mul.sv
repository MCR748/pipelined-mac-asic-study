module mac_mul #(
        parameter INPUT_WIDTH = 16,
        parameter OUTPUT_WIDTH = INPUT_WIDTH * 2
    ) (
        input wire i_clk,
        input wire i_rst,
        input wire [INPUT_WIDTH -  1 : 0] i_mul_a,
        input wire [INPUT_WIDTH -  1 : 0] i_mul_b,
        input wire i_mul_valid,
        output wire [OUTPUT_WIDTH - 1 : 0] o_mul_val,
        output wire o_mul_valid
    );
    reg [INPUT_WIDTH - 1 : 0] r_a;
    reg [INPUT_WIDTH - 1 : 0] r_b;
    reg r_i_valid;

    reg [OUTPUT_WIDTH - 1 : 0] r_stg0 [0 : INPUT_WIDTH - 1];
    reg r_stg0_valid;

    wire [OUTPUT_WIDTH - 1 : 0] w_stg1_sum [0 : 5];
    wire [OUTPUT_WIDTH - 1 : 0] w_stg1_carry [0 : 5];

    wire [OUTPUT_WIDTH - 1 : 0] w_stg1 [0 : 10];

    wire [OUTPUT_WIDTH-1:0] w_stg2_sum [0:2];
    wire [OUTPUT_WIDTH-1:0] w_stg2_carry [0:2];

    reg [OUTPUT_WIDTH - 1 : 0] r_stg1 [0 : 7];
    reg r_stg1_valid;

    wire [OUTPUT_WIDTH - 1 : 0] w_stg3_sum [0 : 2];
    wire [OUTPUT_WIDTH - 1 : 0] w_stg3_carry [0 : 2];

    wire [OUTPUT_WIDTH - 1 : 0] w_stg3 [0 : 5];

    wire [OUTPUT_WIDTH - 1 : 0] w_stg4_sum [0 : 1];
    wire [OUTPUT_WIDTH - 1 : 0] w_stg4_carry [0 : 1];

    reg [OUTPUT_WIDTH-1:0] r_stg2 [0:3];
    reg r_stg2_valid;

    wire [OUTPUT_WIDTH - 1 : 0] w_stg5_sum;
    wire [OUTPUT_WIDTH - 1 : 0] w_stg5_carry;

    wire [OUTPUT_WIDTH - 1 : 0] w_stg5 [0 : 2];

    wire [OUTPUT_WIDTH - 1 : 0] w_stg6_sum;
    wire [OUTPUT_WIDTH - 1 : 0] w_stg6_carry;

    reg [OUTPUT_WIDTH - 1 : 0] r_stg3 [0 : 1];
    reg r_stg3_valid;

    reg [OUTPUT_WIDTH - 1 : 0] r_adder_a;
    reg [OUTPUT_WIDTH - 1 : 0] r_adder_b;
    reg r_adder_valid;


    reg [OUTPUT_WIDTH - 1 : 0] r_o_val;
    reg r_o_valid;

    integer i;
    genvar g;

    always @(posedge i_clk)
    begin
        if (i_rst)
        begin
            r_a <= '0;
            r_b <= '0;
            r_i_valid <= 1'b0;

            for (i = 0; i < INPUT_WIDTH; i = i + 1)
            begin
                r_stg0[i] <= '0;
            end
            r_stg0_valid <= 1'b0;

            for (i = 0; i < 8; i = i + 1)
            begin
                r_stg1[i] <= '0;
            end
            r_stg1_valid <= 1'b0;

            for (i = 0; i < 4; i = i + 1)
            begin
                r_stg2[i] <= '0;
            end
            r_stg2_valid <= 1'b0;

            for (i = 0; i < 2; i = i + 1)
            begin
                r_stg3[i] <= '0;
            end
            r_stg3_valid <= 1'b0;

            r_adder_a <= '0;
            r_adder_b <= '0;
            r_adder_valid <= 0;


            r_o_val <= '0;
            r_o_valid <= 1'b0;
        end
        else
        begin
            // Input stage
            r_a <= i_mul_a;
            r_b <= i_mul_b;
            r_i_valid <= i_mul_valid;

            // Stage 0
            for (i = 0; i < INPUT_WIDTH; i = i + 1)
            begin
                r_stg0[i] <= ( { {INPUT_WIDTH{1'b0}}, r_a } & {OUTPUT_WIDTH{r_b[i]}} ) << i;
            end
            r_stg0_valid <= r_i_valid;


            // Stage 1
            r_stg1[0] <= w_stg2_sum[0];
            r_stg1[1] <= w_stg2_carry[0] << 1;

            r_stg1[2] <= w_stg2_sum[1];
            r_stg1[3] <= w_stg2_carry[1] << 1;

            r_stg1[4] <= w_stg2_sum[2];
            r_stg1[5] <= w_stg2_carry[2] << 1;

            r_stg1[6] <= w_stg1[9];
            r_stg1[7] <= w_stg1[10];

            r_stg1_valid <= r_stg0_valid;

            // Stage 2
            r_stg2[0] <= w_stg4_sum[0];
            r_stg2[1] <= w_stg4_carry[0] << 1;

            r_stg2[2] <= w_stg4_sum[1];
            r_stg2[3] <= w_stg4_carry[1] << 1;

            r_stg2_valid <= r_stg1_valid;

            // Stage 3
            r_stg3[0] <= w_stg6_sum;
            r_stg3[1] <= w_stg6_carry << 1;

            r_stg3_valid <= r_stg2_valid;

            r_adder_a <= r_stg3[0];
            r_adder_b <= r_stg3[1];
            r_adder_valid <= r_stg3_valid;
            
            // Stage 4
            r_o_val <= r_adder_a + r_adder_b;
            r_o_valid <= r_adder_valid;
        end
    end

    generate
        for (g = 0; g < 5; g = g + 1)
        begin : CSA_L1
            mac_csa #(.WIDTH(OUTPUT_WIDTH)) u_csa (
                        .i_add_a (r_stg0[3*g]), .i_add_b (r_stg0[3*g + 1]), .i_add_c (r_stg0[3*g + 2]),
                        .o_add_sum   (w_stg1_sum[g]), .o_add_carry (w_stg1_carry[g])
                    );
        end
    endgenerate

    // Wire Stage 1
    assign w_stg1[0] = w_stg1_sum[0];
    assign w_stg1[1] = w_stg1_carry[0] << 1;

    assign  w_stg1[2] = w_stg1_sum[1];
    assign  w_stg1[3] = w_stg1_carry[1] << 1;

    assign w_stg1[4] = w_stg1_sum[2];
    assign w_stg1[5] = w_stg1_carry[2] << 1;

    assign w_stg1[6] = w_stg1_sum[3];
    assign w_stg1[7] = w_stg1_carry[3] << 1;

    assign w_stg1[8] = w_stg1_sum[4];
    assign w_stg1[9] = w_stg1_carry[4] << 1;

    assign w_stg1[10] = r_stg0[15];

    generate
        for (g = 0; g < 3; g = g + 1)
        begin : CSA_L2
            mac_csa #(.WIDTH(OUTPUT_WIDTH)) u_csa (
                        .i_add_a (w_stg1[3*g]), .i_add_b (w_stg1[3*g + 1]), .i_add_c (w_stg1[3*g + 2]),
                        .o_add_sum   (w_stg2_sum[g]), .o_add_carry (w_stg2_carry[g])
                    );
        end
    endgenerate

    generate
        for (g = 0; g < 3; g = g + 1)
        begin : CSA_L3
            mac_csa #(.WIDTH(OUTPUT_WIDTH)) u_csa (
                        .i_add_a (r_stg1[3*g]), .i_add_b (r_stg1[3*g + 1]), .i_add_c (r_stg1[3*g + 2]),
                        .o_add_sum   (w_stg3_sum[g]), .o_add_carry (w_stg3_carry[g])
                    );
        end
    endgenerate

    // Wire Stage 3
    assign w_stg3[0] = w_stg3_sum[0];
    assign w_stg3[1] = w_stg3_carry[0] << 1;

    assign  w_stg3[2] = w_stg3_sum[1];
    assign  w_stg3[3] = w_stg3_carry[1] << 1;

    assign w_stg3[4] = r_stg1[6];
    assign w_stg3[5] = r_stg1[7];

    generate
        for (g = 0; g < 2; g = g + 1)
        begin : CSA_L4
            mac_csa #(.WIDTH(OUTPUT_WIDTH)) u_csa (
                        .i_add_a (w_stg3[3*g]), .i_add_b (w_stg3[3*g + 1]), .i_add_c (w_stg3[3*g + 2]),
                        .o_add_sum   (w_stg4_sum[g]), .o_add_carry (w_stg4_carry[g])
                    );
        end
    endgenerate

    mac_csa #(.WIDTH(OUTPUT_WIDTH)) u_csa_5 (
                .i_add_a (r_stg2[0]), .i_add_b (r_stg2[1]), .i_add_c (r_stg2[2]),
                .o_add_sum   (w_stg5_sum), .o_add_carry (w_stg5_carry)
            );

    // Wire Stage 5
    assign w_stg5[0] = w_stg5_sum;
    assign w_stg5[1] = w_stg5_carry << 1;

    assign  w_stg5[2] = r_stg2[3];
    
    mac_csa #(.WIDTH(OUTPUT_WIDTH)) u_csa_6 (
                .i_add_a (w_stg5[0]), .i_add_b (w_stg5[1]), .i_add_c (w_stg5[2]),
                .o_add_sum   (w_stg6_sum), .o_add_carry (w_stg6_carry)
            );


    assign o_mul_val = r_o_val;
    assign o_mul_valid = r_o_valid;

endmodule
