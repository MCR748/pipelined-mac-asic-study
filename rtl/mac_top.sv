module mac_top #(
    parameter INPUT_WIDTH = 16,
    parameter OUTPUT_WIDTH = 40
  ) (
    input wire clk,
    input wire rstn,
    input wire [INPUT_WIDTH -  1 : 0] input_a,
    input wire [INPUT_WIDTH -  1 : 0] input_b,
    input wire input_valid,
    output wire [OUTPUT_WIDTH - 1 : 0] output_val,
    output wire output_valid
  );
    reg [INPUT_WIDTH - 1 : 0] r_a;
    reg [INPUT_WIDTH - 1 : 0] r_b;
    reg r_input_valid;

    reg r_sel;
    reg [INPUT_WIDTH * 2 - 1 : 0] r_mul;
    reg r_mul_valid;

    reg [OUTPUT_WIDTH - 1 : 0] r_out;
    reg r_out_valid;

    always @(posedge clk, negedge rstn) begin
        if (rstn) begin
            r_a <= 0;
            r_b <= 0;
            r_mul <= 0;
            r_out <= 0;
        end else begin
            if (input_valid) begin
                r_a <= input_a;
                r_b <= input_b;
                r_input_valid <= input_valid;
            end
            
            if (r_sel) begin
                r_mul <= r_a;
            end else begin
                r_mul <= r_b;
            end

        end
    end

endmodule
