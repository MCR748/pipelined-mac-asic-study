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

    wire [OUTPUT_WIDTH-1:0] w_acc_val;
    wire                    w_acc_valid;

    reg [OUTPUT_WIDTH-1:0] r__padded_product;
    reg                    r_product_val;

    reg [OUTPUT_WIDTH-1:0] r_acc_sum;
    reg [OUTPUT_WIDTH-1:0] r_acc_carry;
    reg r_acc_valid;

    reg [OUTPUT_WIDTH - 1 : 0] r_o_val;
    reg r_o_valid;

    always @(posedge i_clk)
    begin
        if (i_rst)
        begin
            r_a <= '0;
            r_b <= '0;
            r_o_val <= '0;
            r_i_valid <= 0;

            r__padded_product <= '0;
            r_product_val <= 0;

            r_acc_sum <= '0;
            r_acc_carry <= '0;
            r_acc_valid <= 0;
                        
            r_o_valid <= 0;
        end
        else
        begin
            // Input stage
            r_a <= i_a;
            r_b <= i_b;
            r_i_valid <= i_valid;

            r__padded_product <= w_mul_valid ? {8'b0, w_mul_val} : '0;
            r_product_val <= w_mul_valid;

            r_acc_sum   <= r_acc_sum ^ r_acc_carry ^ r__padded_product;
            r_acc_carry <= ((r_acc_sum & r_acc_carry) | (r_acc_sum & r__padded_product) | (r_acc_carry & r__padded_product)) << 1;
            r_acc_valid <= r_product_val;

            // Accumulator stage
            r_o_val <= w_acc_val;
            r_o_valid <= w_acc_valid;
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

    mac_accumulator #(
                        .INPUT_WIDTH (OUTPUT_WIDTH)
                    ) u_mac_acc (
                        .i_clk         (i_clk),
                        .i_rst         (i_rst),
                        .i_adder_a     (r_acc_carry),
                        .i_adder_b     (r_acc_sum),
                        .i_adder_valid (r_acc_valid),
                        .o_adder_val   (w_acc_val),
                        .o_adder_valid (w_acc_valid)
                    );

endmodule
