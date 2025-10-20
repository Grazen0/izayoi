`timescale 1ns / 1ps
`include "macros.vh"

module sub_half_tb ();
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
    $dumpvars(0, sub_half_tb);

    $display("");
    $display("                 a          b       result           XZOUI");
    $display("===========================================================");

    clk   = 1;
    rst_n = 0;

    #3 rst_n = 1;

    round_mode = 1'b0;  // nearest even
    mode_fp = 1'b0;  // half

    // Normal cases
    test(`OP_SUB, 32'h4D30, 32'h4080, 32'h4CA0);  // 20.75 - 2.25 = 18.5
    test(`OP_SUB, 32'h4080, 32'h4D30, 32'hCCA0);  // 2.25 - 20.75  = -18.5
    test(`OP_SUB, 32'h4B00, 32'hCA20, 32'h4E90);  // 14 - (-12.25) = 26.25
    test(`OP_SUB, 32'h4810, 32'h4820, 32'hB000);  // 8.125 - 8.25 = -0.125
    test(`OP_SUB, 32'h4540, 32'h4CA0, 32'hCAA0);  // 5.25 - 18.5 = -13.25
    test(`OP_SUB, 32'h5149, 32'hCC41, 32'h536A);  // 42.3 - (-17.02) = 59.32
    test(`OP_SUB, 32'h2E66, 32'h3266, 32'hAE66);  // 0.1 - 0.2 = -0.1 (inexact)

    round_mode = 1'b1;  // round to zero

    test(`OP_SUB, 32'h8BBF, 32'h7BBF, `INF_H);  // -32768 - 42912 = Inf (overflow)
    test(`OP_SUB, 32'h7B7C, 32'h81BC, 32'h7B7C);  // 61312 - (-2.65e-5) = 61312
    test(`OP_SUB, 32'h0002, 32'h0003, 32'h8001);  // 1.2e-7 - 1.8e-7 = -0.6e-7
    test(`OP_SUB, 32'h4248, 32'h416F, 32'h36C8);  // pi - e = ~4.24 (inexact)

    // Special cases
    test(`OP_SUB, `ZERO_H, `ZERO_H, `ZERO_H);  // 0.0 - 0.0 = 0.0
    test(`OP_SUB, `ZERO_H, `NEG_ZERO_H, `ZERO_H);  // 0.0 - (-0.0) = 0.0
    test(`OP_SUB, `INF_H, 32'h4010_0000, `INF_H);  // Inf - 2.25 = Inf
    test(`OP_SUB, `NEG_INF_H, 32'h4010_0000, `NEG_INF_H);  // -Inf - 2.25 = -Inf
    test(`OP_SUB, `NAN_H, 32'hC188_28F6, `NAN_H);  // NaN - 42.3 = NaN, invalid
    test(`OP_SUB, `NAN_H, `NAN_H, `NAN_H);  // NaN - NaN = NaN, invalid

    $display("");
    #30 $finish();
  end
endmodule
