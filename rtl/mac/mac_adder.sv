module mac_adder #(
  parameter INPUT_WIDTH = 32
) (
  input wire i_clk,
  input wire i_rst,
  input wire [INPUT_WIDTH - 1 : 0] i_adder_a,
  input wire [INPUT_WIDTH - 1 : 0] i_adder_b,
  input wire i_adder_valid,
  output wire [INPUT_WIDTH - 1 : 0] o_adder_val,
  output wire o_adder_valid
);

  reg [INPUT_WIDTH / 2 - 1 : 0] r_a0_l;
  reg [INPUT_WIDTH / 2 - 1 : 0] r_b0_l;

  reg [INPUT_WIDTH / 2 - 1 : 0] r_a0_h;
  reg [INPUT_WIDTH / 2 - 1 : 0] r_b0_h;

  reg r_valid0;

  reg [INPUT_WIDTH / 2 - 1 : 0] r_adder1_l;
  reg r_adder1_carry;

  reg [INPUT_WIDTH / 2 - 1 : 0] r_adder1_h_c0;
  reg [INPUT_WIDTH / 2 - 1 : 0] r_adder1_h_c1;

  reg r_valid1;
  
  reg [INPUT_WIDTH -  1 : 0] r_adder_out;
  reg r_valid_out;

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_a0_l <= '0;
      r_b0_l <= '0;
      r_a0_h <= '0;
      r_b0_h <= '0;
      r_valid0 <= 0;

      r_adder1_l <= '0;
      r_adder1_carry <= 0;
      r_adder1_h_c0 <= '0;
      r_adder1_h_c1 <= '0;
      r_valid1 <= 0;

      r_adder_out <= '0;
      r_valid_out <= 0;
    end else begin

      // Stage 0
      r_a0_l <= i_adder_a[INPUT_WIDTH / 2 - 1 : 0];
      r_b0_l <= i_adder_b[INPUT_WIDTH / 2 - 1 : 0];

      r_a0_h <= i_adder_a[INPUT_WIDTH - 1 : INPUT_WIDTH / 2];
      r_b0_h <= i_adder_b[INPUT_WIDTH - 1 : INPUT_WIDTH / 2];

      r_valid0 <= i_adder_valid;

      //Stage 1
      {r_adder1_carry, r_adder1_l} <= r_a0_l + r_b0_l;

      r_adder1_h_c0 <= r_a0_h + r_b0_h;
      r_adder1_h_c1 <= r_a0_h + r_b0_h + 1'b1;

      r_valid1 <= r_valid0;

      // Stage 2
      r_adder_out <={(r_adder1_carry ? r_adder1_h_c1 : r_adder1_h_c0), r_adder1_l};
      r_valid_out <= r_valid1;
    end
    
  end

  assign o_adder_val = r_adder_out;
  assign o_adder_valid = r_valid_out;
endmodule