module mac_accumulator #(
        parameter INPUT_WIDTH = 40
    )(
        input  wire                     i_clk,
        input  wire                     i_rst,
        input  wire [INPUT_WIDTH-1:0]   i_adder_a,
        input  wire [INPUT_WIDTH-1:0]   i_adder_b,
        input  wire                     i_adder_valid,
        output reg  [INPUT_WIDTH-1:0]   o_adder_val,
        output reg                      o_adder_valid
    );

    reg  [INPUT_WIDTH-1:0] r_p0, r_g0;
    reg                    r_valid0;

    wire [INPUT_WIDTH-1:0] gn1, pp1;
    reg  [INPUT_WIDTH-1:0] r_gn1, r_pp1, r_p1;
    reg                    r_valid1;

    wire [INPUT_WIDTH-1:0] gn2, pp2;
    reg  [INPUT_WIDTH-1:0] r_gn2, r_pp2, r_p2;
    reg                    r_valid2;

    wire [INPUT_WIDTH-1:0] gn3, pp3;
    reg  [INPUT_WIDTH-1:0] r_gn3, r_pp3, r_p3;
    reg                    r_valid3;

    wire [INPUT_WIDTH-1:0] gn4, pp4;
    reg  [INPUT_WIDTH-1:0] r_gn4, r_p4;
    reg                    r_valid4;

    /* verilator lint_off UNUSED */
    reg [INPUT_WIDTH - 1:0] r_gn5,r_pp4;
    /* verilator lint_on UNUSED */

    wire [INPUT_WIDTH-1:0] gn5;
    reg  [INPUT_WIDTH-1:0] r_p5;
    reg                    r_valid5;

    reg  [INPUT_WIDTH-1:0] r_o_val;
    reg                    r_o_valid;

    always @(posedge i_clk)
    begin
        if (i_rst)
        begin
            r_p0 <= '0;
            r_g0 <= '0;
            r_valid0 <= 1'b0;

            r_gn1 <= '0;
            r_pp1 <= '0;
            r_p1 <= '0;
            r_valid1 <= 1'b0;

            r_gn2 <= '0;
            r_pp2 <= '0;
            r_p2 <= '0;
            r_valid2 <= 1'b0;

            r_gn3 <= '0;
            r_pp3 <= '0;
            r_p3 <= '0;
            r_valid3 <= 1'b0;

            r_gn4 <= '0;
            r_pp4 <= '0;
            r_p4 <= '0;
            r_valid4 <= 1'b0;

            r_gn5 <= '0;
            r_p5 <= '0;
            r_valid5 <= 1'b0;

            r_o_val <= '0;
            r_o_valid <= 1'b0;
        end
        else
        begin
            r_p0 <= i_adder_a ^ i_adder_b;
            r_g0 <= i_adder_a & i_adder_b;
            r_valid0 <= i_adder_valid;

            r_gn1 <= gn1;
            r_pp1 <= pp1;
            r_p1 <= r_p0;
            r_valid1 <= r_valid0;

            r_gn2 <= gn2;
            r_pp2 <= pp2;
            r_p2 <= r_p1;
            r_valid2 <= r_valid1;

            r_gn3 <= gn3;
            r_pp3 <= pp3;
            r_p3 <= r_p2;
            r_valid3 <= r_valid2;

            r_gn4 <= gn4;
            r_pp4 <= pp4;
            r_p4 <= r_p3;
            r_valid4 <= r_valid3;

            r_gn5 <= gn5;
            r_p5 <= r_p4;
            r_valid5 <= r_valid4;

            r_o_val   <= r_p5 ^ { r_gn5[INPUT_WIDTH-2:0], 1'b0 };
            r_o_valid <= r_valid5;
        end
    end

    assign o_adder_val   = r_o_val;
    assign o_adder_valid = r_o_valid;

    genvar i;

    generate
        for (i = 0; i < INPUT_WIDTH; i = i + 1)
        begin : lvl1
            if (i == 0)
            begin
                assign gn1[i] = r_g0[i];
                assign pp1[i] = r_p0[i];
            end
            else
            begin
                assign gn1[i] = r_g0[i] | (r_p0[i] & r_g0[i-1]);
                assign pp1[i] = r_p0[i] & r_p0[i-1];
            end
        end
    endgenerate

    generate
        for (i = 0; i < INPUT_WIDTH; i = i + 1)
        begin : lvl2
            if (i < 2)
            begin
                assign gn2[i] = r_gn1[i];
                assign pp2[i] = r_pp1[i];
            end
            else
            begin
                assign gn2[i] = r_gn1[i] | (r_pp1[i] & r_gn1[i-2]);
                assign pp2[i] = r_pp1[i] & r_pp1[i-2];
            end
        end
    endgenerate

    generate
        for (i = 0; i < INPUT_WIDTH; i = i + 1)
        begin : lvl3
            if (i < 4)
            begin
                assign gn3[i] = r_gn2[i];
                assign pp3[i] = r_pp2[i];
            end
            else
            begin
                assign gn3[i] = r_gn2[i] | (r_pp2[i] & r_gn2[i-4]);
                assign pp3[i] = r_pp2[i] & r_pp2[i-4];
            end
        end
    endgenerate

    generate
        for (i = 0; i < INPUT_WIDTH; i = i + 1)
        begin : lvl4
            if (i < 8)
            begin
                assign gn4[i] = r_gn3[i];
                assign pp4[i] = r_pp3[i];
            end
            else
            begin
                assign gn4[i] = r_gn3[i] | (r_pp3[i] & r_gn3[i-8]);
                assign pp4[i] = r_pp3[i] & r_pp3[i-8];
            end
        end
    endgenerate

    generate
        for (i = 0; i < INPUT_WIDTH; i = i + 1)
        begin : lvl5
            if (i < 16)
            begin
                assign gn5[i] = r_gn4[i];
            end
            else
            begin
                assign gn5[i] = r_gn4[i] | (r_pp4[i] & r_gn4[i-16]);
            end
        end
    endgenerate

endmodule
