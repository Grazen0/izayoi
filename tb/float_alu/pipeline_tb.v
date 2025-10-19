`timescale 1ns / 1ps
`include "macros.vh"

module pipeline_tb ();
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

  // Esto claramente no es sintetizable, pero sirve para propósitos de la
  // simulación del testbench.
  always @(posedge valid_out or posedge clk) begin
    #1;

    if (valid_out) begin
      result_reg <= result;
      flags_reg  <= flags;
    end
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
    $dumpvars(0, pipeline_tb);

    clk   = 1;
    rst_n = 0;

    #3 rst_n = 1;

    round_mode = 1'b0;  // nearest even
    mode_fp = 1'b1;  // single

    // Some additions...
    send(`OP_ADD, 32'h41A6_0000, 32'h4010_0000);  // 20.75 + 2.25 = 23.0
    send(`OP_ADD, 32'h3DCC_CCCD, 32'h3E4C_CCCD);  // 0.1 + 0.2 = ~0.3 (inexact)
    send(`OP_ADD, 32'h4049_0FDB, 32'h402D_F854);  // pi + e = ~5.85 (inexact)
    send(`OP_ADD, `INF, 32'h4010_0000);  // Inf + 2.25 = Inf

    #60;

    // A multiplication...
    send(`OP_MUL, 32'h4049_0FDB, 32'h402D_F854);  // pi * e = ~8.539 (inexact)

    #50;

    // Some subtractions...
    send(`OP_SUB, 32'h4102_0000, 32'h4104_0000);  // 8.125 - 8.25 = -0.125
    send(`OP_SUB, 32'h4229_3333, 32'hC188_28F6);  // 42.3 - (-17.02) = 59.32

    #120 $finish();
  end
endmodule
