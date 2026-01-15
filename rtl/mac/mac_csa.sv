module mac_csa #(
        parameter WIDTH = 32
    ) (
        input wire [WIDTH - 1 : 0] i_add_a,
        input wire [WIDTH - 1 : 0] i_add_b,
        input wire [WIDTH - 1 : 0] i_add_c,
        output wire [WIDTH - 1 : 0] o_add_sum,
        output wire [WIDTH - 1 : 0] o_add_carry
    );

    assign o_add_sum = i_add_a ^ i_add_b ^ i_add_c;
    assign o_add_carry = (i_add_a & i_add_b) | (i_add_b & i_add_c) | (i_add_c & i_add_a);
endmodule
