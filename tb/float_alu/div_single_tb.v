`timescale 1ns / 1ps
`include "macros.vh"

module div_single_tb ();
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
    $dumpvars(0, div_single_tb);

    $display("");
    $display("                 a          b       result           XZOUI");
    $display("===========================================================");

    clk   = 1;
    rst_n = 0;

    #3 rst_n = 1;

    round_mode = 1'b0;  // nearest even
    mode_fp = 1'b1;  // single

    // Normal cases
    test(`OP_DIV, 32'h41A6_0000, 32'h4010_0000, 32'h4113_8E38);  // 20.75 / 2.25 = 9.222...
    test(`OP_DIV, 32'h4160_0000, 32'hC144_0000, 32'hBF92_4925);  // 14 / (-12.25) = -1.142...
    test(`OP_DIV, 32'h4102_0000, 32'h4104_0000, 32'h3F7C_1F06);  // 8.125 / 8.25 = 0.9848...
    test(`OP_DIV, 32'h40A8_0000, 32'h4194_0000, 32'h3E91_4C1D);  // 5.25 / 18.5 = 28.37
    test(`OP_DIV, 32'h4229_3333, 32'hC188_28F6, 32'hC01F_0F57);  // 42.3 / (-17.02) = -2.485
    test(`OP_DIV, 32'h3DCC_CCCD, 32'h3E4C_CCCD, 32'h3F00_0000);  // 0.1 / 0.2 = 0.5

    round_mode = 1'b1;  // round to zero

    test(`OP_DIV, 32'h4228_0000, 32'h4228_0000, 32'h3F80_0000);  // 42.0 / 42.0 = 1.0
    test(`OP_DIV, 32'h7F7F_FFFF, 32'h7F7F_FFFF, 32'h3F80_0000);  // 3.4e38 / 3.4e38 = 1.0
    test(`OP_DIV, 32'h425A_CCCD, 32'h0E69_999A, 32'h736F_C7E2);  // 54.7 / 2.87e-30 ~= 1.89e31
    test(`OP_DIV, 32'h0000_0040, 32'h0000_0003, 32'h41B4_0000);  // 9e-44 / 4e-45 = 22.5
    test(`OP_DIV, 32'h4049_0FDB, 32'h402D_F854, 32'h3F93_EEE0);  // pi / e = ~1.557

    // Special cases
    test(`OP_DIV, 32'h3F80_0000, `INF, `ZERO);  // 1.0 / Inf = 0.0
    test(`OP_DIV, 32'hC048_F5C3, `INF, `NEG_ZERO);  // -3.14 / Inf = -0.0
    test(`OP_DIV, `ZERO, `ZERO, `NAN);  // 0.0 / 0.0 = NaN
    test(`OP_DIV, `ZERO, `NEG_ZERO, `NAN);  // 0.0 / (-0.0) = NaN
    test(`OP_DIV, `INF, 32'h4010_0000, `INF);  // Inf / 2.25 = Inf
    test(`OP_DIV, `NEG_INF, 32'h4010_0000, `NEG_INF);  // -Inf / 2.25 = -Inf
    test(`OP_DIV, `NAN, 32'hC188_28F6, `NAN);  // NaN / 42.3 = NaN, invalid
    test(`OP_DIV, `NAN, `NAN, `NAN);  // NaN / NaN = NaN, invalid

    $display("");
    #30 $finish();
  end
endmodule
