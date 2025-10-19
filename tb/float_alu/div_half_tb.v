`timescale 1ns / 1ps
`include "macros.vh"

module div_half_tb ();
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
    $dumpvars(0, div_half_tb);

    $display("");
    $display("                 a          b       result           XZOUI");
    $display("===========================================================");

    clk   = 1;
    rst_n = 0;

    #3 rst_n = 1;

    round_mode = 1'b0;  // nearest even
    mode_fp = 1'b0;  // half

    // Normal cases
    test(`OP_DIV, 32'h4D30, 32'h4080, 32'h489C);  // 20.75 / 2.25 = 9.22
    test(`OP_DIV, 32'h4B00, 32'hCA20, 32'hBC92);  // 14 / (-12.25) = -1.143
    test(`OP_DIV, 32'h4810, 32'h4820, 32'h3BE1);  // 8.125 / 8.25 = 0.985
    test(`OP_DIV, 32'h4540, 32'h4CA0, 32'h348A);  // 5.25 / 18.5 = 0.2837
    test(`OP_DIV, 32'h5149, 32'hCC41, 32'hC0F8);  // 42.3 / (-17.02) = -2.485
    test(`OP_DIV, 32'h2E66, 32'h3266, 32'h3800);  // 0.1 / 0.2 = 0.5

    round_mode = 1'b1;  // round to zero

    test(`OP_DIV, 32'h5140, 32'h5140, 32'h3C00);  // 42.0 / 42.0 = 1.0
    test(`OP_DIV, 32'h7C00, 32'h7C00, 32'h3C00);  // 3.4e38 / 3.4e38 = 1.0
    test(`OP_DIV, 32'h52D6, 32'h0001, `INF_H);  // 54.7 / 5.97e-7 = Inf
    test(`OP_DIV, 32'h4248, 32'h416F, 32'h3CA0);  // pi / e = ~1.157

    // Special cases
    test(`OP_DIV, 32'h3C00, `INF_H, `ZERO_H);  // 1.0 / Inf = 0.0
    test(`OP_DIV, 32'hC247, `INF_H, `NEG_ZERO_H);  // -3.14 / Inf = -0.0
    test(`OP_DIV, `ZERO_H, `ZERO_H, `NAN_H);  // 0.0 / 0.0 = NaN
    test(`OP_DIV, `ZERO_H, `NEG_ZERO_H, `NAN_H);  // 0.0 / (-0.0) = NaN
    test(`OP_DIV, `INF_H, 32'h4080, `INF_H);  // Inf / 2.25 = Inf
    test(`OP_DIV, `NEG_INF_H, 32'h4080, `NEG_INF_H);  // -Inf / 2.25 = -Inf
    test(`OP_DIV, `NAN_H, 32'h5149, `NAN_H);  // NaN / 42.3 = NaN, invalid
    test(`OP_DIV, `NAN_H, `NAN_H, `NAN_H);  // NaN / NaN = NaN, invalid

    $display("");
    #30 $finish();
  end
endmodule
