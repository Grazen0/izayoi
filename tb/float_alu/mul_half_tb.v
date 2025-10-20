`timescale 1ns / 1ps
`include "macros.vh"

module mul_half_tb ();
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
    #1;
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
    $dumpvars(0, mul_half_tb);

    $display("");
    $display("                 a          b       result           XZOUI");
    $display("===========================================================");

    clk   = 1;
    rst_n = 0;

    #3 rst_n = 1;

    round_mode = 1'b0;  // nearest even
    mode_fp = 1'b0;  // half

    // Normal cases
    test(`OP_MUL, 32'h4D30, 32'h4080, 32'h51D6);  // 20.75 * 2.25 = 46.7
    test(`OP_MUL, 32'h4080, 32'h4D30, 32'h51D6);  // 2.25 * 20.75 = 46.7
    test(`OP_MUL, 32'h4B00, 32'hCA20, 32'hD95C);  // 14 * (-12.25) = -171.5
    test(`OP_MUL, 32'hCA20, 32'h4B00, 32'hD95C);  // (-12.25) * 14 = -171.5
    test(`OP_MUL, 32'h4810, 32'h4820, 32'h5431);  // 8.125 * 8.25 = 67.1
    test(`OP_MUL, 32'h4540, 32'h4CA0, 32'h5612);  // 5.25 * 18.5 = 97.13
    test(`OP_MUL, 32'h5149, 32'hCC41, 32'hE19F);  // 42.3 * (-17.02) = -719.5
    test(`OP_MUL, 32'h2E66, 32'h3266, 32'h251E);  // 0.1 * 0.2 = 0.02 (inexact)

    round_mode = 1'b1;  // round to zero

    test(`OP_MUL, 32'h7BFF, 32'h7BFF, `INF_H);  // 65504 * 65504 = Inf (overflow)
    test(`OP_MUL, 32'h52D6, 32'h0006, 32'h013E);  // 54.7 * 3.6e-7 = 1.9e-5
    test(`OP_MUL, 32'h0001, 32'h0002, `ZERO);  // 5.97e-8 * 1.2e-7 = 0.0 (underflow, inexact)
    test(`OP_MUL, 32'h4248, 32'h416F, 32'h4844);  // pi * e = ~8.532 (inexact)

    // Special cases
    test(`OP_MUL, `ZERO_H, `ZERO_H, `ZERO_H);  // 0.0 * 0.0 = 0.0
    test(`OP_MUL, `ZERO_H, `NEG_ZERO_H, `NEG_ZERO_H);  // 0.0 * (-0.0) = -0.0
    test(`OP_MUL, `INF_H, 32'h4080, `INF_H);  // Inf * 2.25 = Inf
    test(`OP_MUL, 32'h4080, `INF_H, `INF_H);  // 2.25 * Inf = Inf
    test(`OP_MUL, `INF_H, `NEG_INF_H, `NEG_INF_H);  // Inf * (-Inf) = -Inf
    test(`OP_MUL, `NEG_INF_H, 32'h4080, `NEG_INF_H);  // -Inf * 2.25 = -Inf
    test(`OP_MUL, `NAN_H, 32'h5149, `NAN_H);  // NaN * 42.3 = NaN, invalid
    test(`OP_MUL, `NAN_H, `NAN_H, `NAN_H);  // NaN * NaN = NaN, invalid

    $display("");
    #30 $finish();
  end
endmodule
