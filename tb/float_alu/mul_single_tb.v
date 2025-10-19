`timescale 1ns / 1ps
`include "macros.vh"

module mul_single_tb ();
  `include "tasks.vh"

  reg clk, rst_n, start;
  reg [31:0] op_a, op_b;
  reg [2:0] op_code;
  reg round_mode, mode_fp;

  wire [31:0] result;
  wire valid_out, ready_out;
  wire [ 4:0] flags;

  reg  [31:0] result_reg;
  reg  [ 4:0] flags_reg;

  always #5 clk = ~clk;

  always @(posedge valid_out) begin
    result_reg <= result;
    flags_reg  <= flags;
  end

  float_alu izayoi (
      .clk  (clk),
      .rst_n(rst_n),

      .op_a(op_a),
      .op_b(op_b),
      .op_code(op_code),
      .round_mode(round_mode),
      .mode_fp(mode_fp),
      .start(start),
      .ready_in(1'b1),

      .valid_out(valid_out),
      .ready_out(ready_out),
      .result(result),
      .flags(flags)
  );

  initial begin
    $dumpvars(0, mul_single_tb);

    $display("");
    $display("                 a          b       result           XZOUI");
    $display("===========================================================");

    clk   = 1;
    rst_n = 0;

    #3 rst_n = 1;

    round_mode = 1'b0;  // nearest even
    mode_fp = 1'b1;  // single

    // Normal cases
    test(`OP_MUL, 32'h41A6_0000, 32'h4010_0000, 32'h423A_C000);  // 20.75 * 2.25 = 46.6875
    test(`OP_MUL, 32'h4010_0000, 32'h41A6_0000, 32'h423A_C000);  // 2.25 * 20.75 = 46.6875
    test(`OP_MUL, 32'h4160_0000, 32'hC144_0000, 32'hC32B_8000);  // 14 * (-12.25) = -171.5
    test(`OP_MUL, 32'hC144_0000, 32'h4160_0000, 32'hC32B_8000);  // (-12.25) * 14 = -171.5
    test(`OP_MUL, 32'h4102_0000, 32'h4104_0000, 32'h4286_1000);  // 8.125 * 8.25 = 67.03125
    test(`OP_MUL, 32'h40A8_0000, 32'h4194_0000, 32'h42C2_4000);  // 5.25 * 18.5 = 97.125
    test(`OP_MUL, 32'h4229_3333, 32'hC188_28F6, 32'hC433_FC8B);  // 42.3 * (-17.02) = -719.946
    test(`OP_MUL, 32'h3DCC_CCCD, 32'h3E4C_CCCD, 32'h3CA3_D70B);  // 0.1 * 0.2 = ~0.02 (inexact)

    round_mode = 1'b1;  // round to zero

    test(`OP_MUL, 32'h3DCC_CCCD, 32'h3E4C_CCCD, 32'h3CA3_D70B);  // 0.1 * 0.2 = ~0.3 (inexact)
    test(`OP_MUL, 32'h7F7F_FFFF, 32'h7F7F_FFFF, `INF);  // 3.4e38 * 3.4e38 = Inf (overflow)
    test(`OP_MUL, 32'h425A_CCCD, 32'h0E69_999A, 32'h1147_A7AF);  // 54.7 * 2.87e-30 = 1.5e-28
    test(`OP_MUL, 32'h0000_0040, 32'h0000_0003,
         `ZERO);  // 9e-44 * 4e-45 = 3.6e-88 (underflow, inexact)
    test(`OP_MUL, 32'h4049_0FDB, 32'h402D_F854, 32'h4108_A2C0);  // pi * e = ~8.539 (inexact)

    // Special cases
    test(`OP_MUL, `ZERO, `ZERO, `ZERO);  // 0.0 * 0.0 = 0.0
    test(`OP_MUL, `ZERO, `NEG_ZERO, `NEG_ZERO);  // 0.0 * (-0.0) = -0.0
    test(`OP_MUL, `INF, 32'h4010_0000, `INF);  // Inf * 2.25 = Inf
    test(`OP_MUL, 32'h4010_0000, `INF, `INF);  // 2.25 * Inf = Inf
    test(`OP_MUL, `INF, `NEG_INF, `NEG_INF);  // Inf * (-Inf) = -Inf
    test(`OP_MUL, `NEG_INF, 32'h4010_0000, `NEG_INF);  // -Inf * 2.25 = -Inf
    test(`OP_MUL, `NAN, 32'hC188_28F6, `NAN);  // NaN * 42.3 = NaN, invalid
    test(`OP_MUL, `NAN, `NAN, `NAN);  // NaN * NaN = NaN, invalid

    $display("");
    #30 $finish();
  end
endmodule
