`default_nettype none
`include "macros.vh"

module fp_decoder (
    input wire [2:0] op_code,
    input wire start,
    input wire ready_in,
    output wire adder_start,
    output wire adder_ready_in,
    output wire multiplier_start,
    output wire multiplier_ready_in
);
  assign adder_start = start && (op_code == `OP_ADD || op_code == `OP_SUB);
  assign adder_ready_in = ready_in || (op_code != `OP_ADD && op_code != `OP_SUB);

  assign multiplier_start = start && (op_code == `OP_MUL || op_code == `OP_DIV);
  assign multiplier_ready_in = ready_in || (op_code != `OP_MUL && op_code != `OP_DIV);

endmodule

module fp_unpacker #(
    parameter P_SINGLE = 23,
    parameter E_SINGLE = 8,
    parameter N_SINGLE = P_SINGLE + E_SINGLE + 1,
    parameter P_HALF   = 10,
    parameter E_HALF   = 5,
    parameter N_HALF   = P_HALF + E_HALF + 1
) (
    input wire [N_SINGLE-1:0] op_a,
    input wire [N_SINGLE-1:0] op_b,
    input wire mode_fp,

    output wire sign_a,
    output wire sign_b,
    output wire [E_SINGLE-1:0] exp_a,
    output wire [E_SINGLE-1:0] exp_b,
    output wire [P_SINGLE-1:0] mant_a,
    output wire [P_SINGLE-1:0] mant_b
);
  localparam BIAS_HALF = 2 ** (E_HALF - 1) - 1;
  localparam BIAS_SINGLE = 2 ** (E_SINGLE - 1) - 1;

  wire fp_single = (mode_fp == `FP_SINGLE);

  wire sign_a_half = op_a[N_HALF-1];
  wire sign_b_half = op_b[N_HALF-1];
  wire sign_a_single = op_a[N_SINGLE-1];
  wire sign_b_single = op_b[N_SINGLE-1];

  wire [E_HALF-1:0] exp_a_half = op_a[N_HALF-2:P_HALF];
  wire [E_HALF-1:0] exp_b_half = op_b[N_HALF-2:P_HALF];
  wire [E_SINGLE-1:0] exp_a_single = op_a[N_SINGLE-2:P_SINGLE];
  wire [E_SINGLE-1:0] exp_b_single = op_b[N_SINGLE-2:P_SINGLE];

  wire [P_HALF-1:0] mant_a_half = op_a[P_HALF-1:0];
  wire [P_HALF-1:0] mant_b_half = op_b[P_HALF-1:0];
  wire [P_SINGLE-1:0] mant_a_single = op_a[P_SINGLE-1:0];
  wire [P_SINGLE-1:0] mant_b_single = op_b[P_SINGLE-1:0];

  assign sign_a = fp_single ? sign_a_single : sign_a_half;
  assign sign_b = fp_single ? sign_b_single : sign_b_half;

  assign exp_a  = fp_single
    ? exp_a_single
    : (exp_a_half == 0 ? 0 : (exp_a_half - BIAS_HALF + BIAS_SINGLE));
  assign exp_b  = fp_single
    ? exp_b_single
    : (exp_b_half == 0 ? 0 : (exp_b_half - BIAS_HALF + BIAS_SINGLE));

  assign mant_a = fp_single ? mant_a_single : (mant_a_half << 13);
  assign mant_b = fp_single ? mant_b_single : (mant_b_half << 13);
endmodule

module fp_packer #(
    parameter P_SINGLE = 23,
    parameter E_SINGLE = 8,
    parameter N_SINGLE = P_SINGLE + E_SINGLE + 1,
    parameter P_HALF   = 10,
    parameter E_HALF   = 5,
    parameter N_HALF   = P_HALF + E_HALF + 1
) (
    input wire sign,
    input wire [E_SINGLE-1:0] exp,
    input wire [P_SINGLE+3:0] mant,
    input wire [4:0] flags_in,
    input wire mode_fp,

    output reg [N_SINGLE-1:0] result,
    output reg [4:0] flags_out
);
  localparam BIAS_HALF = 2 ** (E_HALF - 1) - 1;
  localparam BIAS_SINGLE = 2 ** (E_SINGLE - 1) - 1;

  wire [E_HALF-1:0] exp_half = exp - BIAS_SINGLE + BIAS_HALF;
  wire [P_HALF-1:0] mant_half = mant[P_SINGLE+2-:P_HALF] + mant[P_SINGLE-P_HALF+2];  // round to nearest

  always @(*) begin
    flags_out = flags_in;

    if (mode_fp == `FP_SINGLE) begin
      result = {sign, exp, mant[P_SINGLE+2:3]};
    end else begin
      result = {{(N_SINGLE - N_HALF) {1'b0}}, sign, exp_half, mant_half};

      if (|mant[P_SINGLE-P_HALF-1:0]) begin
        flags_out[`F_INEXACT] = 1'b1;
      end
    end
  end
endmodule


module float_alu #(
    parameter P = 23,
    parameter E = 8,
    parameter N = P + E + 1
) (
    input wire clk,
    input wire rst_n,
    input wire [N-1:0] op_a,
    input wire [N-1:0] op_b,
    input wire [2:0] op_code,
    input wire mode_fp,
    input wire round_mode,
    input wire start,
    input wire ready_in,

    output reg valid_out,
    output reg ready_out,
    output wire [N-1:0] result,
    output wire [4:0] flags
);
  wire [N-1:0] op_a_unpacked, op_b_unpacked;

  fp_unpacker unpacker (
      .op_a(op_a),
      .op_b(op_b),
      .mode_fp(mode_fp),

      .sign_a(op_a_unpacked[N-1]),
      .sign_b(op_b_unpacked[N-1]),
      .exp_a (op_a_unpacked[N-2:P]),
      .exp_b (op_b_unpacked[N-2:P]),
      .mant_a(op_a_unpacked[P-1:0]),
      .mant_b(op_b_unpacked[P-1:0])
  );

  wire adder_start, adder_ready_in;
  wire multiplier_start, multiplier_ready_in;

  fp_decoder decoder (
      .op_code(op_code),
      .start(start),
      .ready_in(ready_in),
      .adder_start(adder_start),
      .adder_ready_in(adder_ready_in),
      .multiplier_start(multiplier_start),
      .multiplier_ready_in(multiplier_ready_in)
  );

  wire adder_valid, adder_ready;
  wire adder_result;
  wire adder_sign;
  wire [E-1:0] adder_exp;
  wire [P+3:0] adder_mant;
  wire [4:0] adder_flags;
  wire adder_mode_fp;

  fp_adder adder (
      .clk(clk),
      .rst_n(rst_n),
      .op_a(op_a_unpacked),
      .op_b(op_b_unpacked),
      .mode_fp(mode_fp),
      .round_mode(round_mode),
      .sub(op_code[0]),
      .start(adder_start),
      .ready_in(adder_ready_in),

      .valid_out(adder_valid),
      .ready_out(adder_ready),
      .sign_out(adder_sign),
      .exp_out(adder_exp),
      .mant_out(adder_mant),
      .flags(adder_flags),
      .mode_fp_out(adder_mode_fp)
  );

  wire multiplier_valid, multiplier_ready;
  wire multiplier_result;
  wire multiplier_sign;
  wire [E-1:0] multiplier_exp;
  wire [P+3:0] multiplier_mant;
  wire [4:0] multiplier_flags;
  wire multiplier_mode_fp;

  wire [N-1:0] op_b_inv;
  wire [4:0] recip_flags;

  fp_recip recip (
      .in_bits(op_b_unpacked),
      .out_bits(op_b_inv),
      .except_flags(recip_flags)
  );

  fp_multiplier multiplier (
      .clk(clk),
      .rst_n(rst_n),
      .op_a(op_a_unpacked),
      .op_b(op_code == `OP_MUL ? op_b_unpacked : op_b_inv),
      .mode_fp(mode_fp),
      .round_mode(round_mode),
      .initial_flags(op_code == `OP_MUL ? 5'b0 : recip_flags),
      .start(multiplier_start),
      .ready_in(multiplier_ready_in),

      .valid_out(multiplier_valid),
      .ready_out(multiplier_ready),
      .sign_out(multiplier_sign),
      .exp_out(multiplier_exp),
      .mant_out(multiplier_mant),
      .flags(multiplier_flags),
      .mode_fp_out(multiplier_mode_fp)
  );

  reg result_sign;
  reg [E-1:0] result_exp;
  reg [P+3:0] result_mant;
  reg [4:0] result_flags;
  reg result_mode_fp;

  always @(*) begin
    case (op_code)
      `OP_ADD, `OP_SUB: begin
        valid_out = adder_valid;
        ready_out = adder_ready;

        result_sign = adder_sign;
        result_exp = adder_exp;
        result_mant = adder_mant;

        result_flags = adder_flags;
        result_mode_fp = adder_mode_fp;
      end
      `OP_MUL, `OP_DIV: begin
        valid_out = multiplier_valid;
        ready_out = multiplier_ready;

        result_sign = multiplier_sign;
        result_exp = multiplier_exp;
        result_mant = multiplier_mant;

        result_flags = multiplier_flags;
        result_mode_fp = multiplier_mode_fp;
      end
      default: begin
        valid_out = 1'b0;
        ready_out = 1'b0;

        result_sign = 1'b0;
        result_exp = 8'b0;
        result_mant = 27'b0;

        result_flags = 5'b0;
        result_mode_fp = 1'b0;
      end
    endcase
  end

  fp_packer packer (
      .sign(result_sign),
      .exp(result_exp),
      .mant(result_mant),
      .flags_in(result_flags),
      .mode_fp(result_mode_fp),

      .result(result),
      .flags_out(flags)
  );
endmodule

