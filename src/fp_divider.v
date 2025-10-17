module fp_divider (
    input wire clk,
    input wire rst_n,

    input wire [31:0] op_a,
    input wire [31:0] op_b,
    input wire mode_fp,
    input wire round_mode,

    input  wire start,
    input  wire ready_in,
    output wire valid_out,
    output wire ready_out,

    output wire [31:0] result,
    output wire [ 4:0] flags
);
  wire [31:0] b_inv;

  recip_fp recip (
      .in_bits (op_b),
      .out_bits(b_inv)
  );

  fp_multiplier multiplier (
      .clk  (clk),
      .rst_n(rst_n),

      .op_a(op_a),
      .op_b(b_inv),
      .mode_fp(mode_fp),
      .round_mode(round_mode),

      .start(start),
      .ready_in(ready_in),
      .valid_out(valid_out),
      .ready_out(ready_out),

      .result(result),
      .flags (flags)
  );
endmodule
