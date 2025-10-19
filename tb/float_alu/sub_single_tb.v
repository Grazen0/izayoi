`timescale 1ns / 1ps
`include "macros.vh"

module sub_single_tb ();
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
    $dumpvars(0, sub_single_tb);

    $display("");
    $display("                 a          b       result           XZOUI");
    $display("===========================================================");

    clk   = 1;
    rst_n = 0;

    #3 rst_n = 1;

    round_mode = 1'b0;  // nearest even
    mode_fp = 1'b1;  // single

    // Normal cases
    test(`OP_SUB, 32'h41A6_0000, 32'h4010_0000, 32'h4194_0000);  // 20.75 - 2.25 = 18.5
    test(`OP_SUB, 32'h4160_0000, 32'hC144_0000, 32'h41D2_0000);  // 14 - (-12.25) = 26.25
    test(`OP_SUB, 32'h4102_0000, 32'h4104_0000, 32'hBE00_0000);  // 8.125 - 8.25 = -0.125
    test(`OP_SUB, 32'h40A8_0000, 32'h4194_0000, 32'hC154_0000);  // 5.25 - 18.5 = -13.25
    test(`OP_SUB, 32'h4229_3333, 32'hC188_28F6, 32'h426D_47AE);  // 42.3 - (-17.02) = 59.32
    test(`OP_SUB, 32'h3DCC_CCCD, 32'h3E4C_CCCD, 32'hBDCC_CCCD);  // 0.1 - 0.2 = -0.1

    round_mode = 1'b1;  // round to zero

    test(`OP_SUB, 32'hFF69_999A, 32'h7F69_999A, `NEG_INF);  // -3.1e38 - 3.1e38 = -Inf
    test(`OP_SUB, 32'h7F69_999A, 32'h0E69_999A, 32'h7F69_999A);  // 3.1e38 - (-2.87e-30) = 3.1e38
    test(`OP_SUB, 32'h0000_0040, 32'h0000_0003, 32'h0000_003D);  // 9e-44 - 4e-45 = 8.5e-44
    test(`OP_SUB, 32'h4049_0FDB, 32'h402D_F854, 32'h3ED8_BC38);  // pi - e = ~0.423

    // Special cases
    test(`OP_SUB, `ZERO, `ZERO, `ZERO);  // 0.0 - 0.0 = 0.0
    test(`OP_SUB, `ZERO, `NEG_ZERO, `ZERO);  // 0.0 - (-0.0) = 0.0
    test(`OP_SUB, `INF, 32'h4010_0000, `INF);  // Inf - 2.25 = Inf
    test(`OP_SUB, `NEG_INF, 32'h4010_0000, `NEG_INF);  // -Inf - 2.25 = -Inf
    test(`OP_SUB, `NEG_INF, `NEG_INF, `NAN);  // -Inf - (-Inf) = NaN

    test(`OP_SUB, `NAN, 32'hC188_28F6, `NAN);  // NaN - 42.3 = NaN, invalid
    test(`OP_SUB, `NAN, `NAN, `NAN);  // NaN - NaN = NaN, invalid

    $display("");
    #30 $finish();
  end
endmodule
