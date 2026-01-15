module mac_top #(
        parameter INPUT_WIDTH = 16,
        parameter OUTPUT_WIDTH = 40
    ) (
        input wire i_clk,
        input wire i_rst,
        input wire [INPUT_WIDTH -  1 : 0] i_a,
        input wire [INPUT_WIDTH -  1 : 0] i_b,
        input wire i_valid,
        output wire [OUTPUT_WIDTH - 1 : 0] o_val,
        output wire o_valid
    );
    reg [INPUT_WIDTH - 1 : 0] r_a;
    reg [INPUT_WIDTH - 1 : 0] r_b;
    reg r_i_valid;

    wire [INPUT_WIDTH*2-1:0] w_mul_val;
    wire w_mul_valid;

    reg [OUTPUT_WIDTH - 1 : 0] r_o_val;
    reg r_o_valid;

    always @(posedge i_clk)
    begin
        if (i_rst)
        begin
            r_a <= 0;
            r_b <= 0;
            r_o_val <= 0;
            r_i_valid <= 0;
            r_o_valid <= 0;
        end
        else
        begin
            // Input stage
            r_a <= i_a;
            r_b <= i_b;
            r_i_valid <= i_valid;


            // Accumulator stage
            r_o_val <= {w_mul_val << 8, 8'b0};
            r_o_valid <= w_mul_valid;
        end
    end

    assign o_val = r_o_val;
    assign o_valid = r_o_valid;

    mac_mul #(
        .INPUT_WIDTH (INPUT_WIDTH),
        .OUTPUT_WIDTH(INPUT_WIDTH*2)
    ) u_mac_mul (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_mul_a     (r_a),
        .i_mul_b     (r_b),
        .i_mul_valid (r_i_valid),
        .o_mul_val   (w_mul_val),
        .o_mul_valid (w_mul_valid)
    );


endmodule
