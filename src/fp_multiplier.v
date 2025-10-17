`default_nettype none

module mul_decode (
    input wire [31:0] op_a,
    input wire [31:0] op_b,

    input wire mode_fp,

    output reg sign_a,
    output reg sign_b,
    output reg [7:0] exp_a,
    output reg [7:0] exp_b,
    output reg [22:0] mant_a,
    output reg [22:0] mant_b,

    output wire is_zero_a,
    output wire is_zero_b,
    output wire is_nan_a,
    output wire is_nan_b,
    output wire is_inf_a,
    output wire is_inf_b
);
  always @(*) begin
    if (mode_fp == `FP_HALF) begin
      sign_a = op_a[15];
      sign_b = op_b[15];

      exp_a  = {3'b0, op_a[14:10]} + 8'd112;
      exp_b  = {3'b0, op_b[14:10]} + 8'd112;

      mant_a = {op_a[9:0], 13'b0};
      mant_b = {op_b[9:0], 13'b0};
    end else begin
      sign_a = op_a[31];
      sign_b = op_b[31];

      exp_a  = op_a[30:23];
      exp_b  = op_b[30:23];

      mant_a = op_a[22:0];
      mant_b = op_b[22:0];
    end
  end

  assign is_zero_a = (exp_a == 8'b0) && (mant_a == 23'b0);
  assign is_zero_b = (exp_b == 8'b0) && (mant_b == 23'b0);

  assign is_nan_a  = (exp_a == 8'b11111111) && (mant_a != 23'b0);
  assign is_nan_b  = (exp_b == 8'b11111111) && (mant_b != 23'b0);

  assign is_inf_a  = (exp_a == 8'b11111111) && (mant_a == 23'b0);
  assign is_inf_b  = (exp_b == 8'b11111111) && (mant_b == 23'b0);

endmodule

module mul_exception (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire is_zero_a,
    input wire is_zero_b,
    input wire is_nan_a,
    input wire is_nan_b,
    input wire is_inf_a,
    input wire is_inf_b,

    input wire initial_flags;

    output reg [31:0] spec_result,
    output reg [4:0] spec_flags,
    output reg spec_override,

    input wire sign_a_in,
    input wire sign_b_in,
    input wire [7:0] exp_a_in,
    input wire [7:0] exp_b_in,
    input wire [22:0] mant_a_in,
    input wire [22:0] mant_b_in,

    output reg sign_a_out,
    output reg sign_b_out,
    output reg [7:0] exp_a_out,
    output reg [7:0] exp_b_out,
    output reg [22:0] mant_a_out,
    output reg [22:0] mant_b_out
);

  wire final_sign = sign_a_in ^ sign_b_in;
  assign ready_out = !valid_out || ready_in;

  reg sign_a_out_next, sign_b_out_next;
  reg [7:0] exp_a_out_next, exp_b_out_next;
  reg [22:0] mant_a_out_next, mant_b_out_next;
  reg [31:0] spec_result_next;
  reg [4:0] spec_flags_next;
  reg spec_override_next;

  always @(*) begin
    sign_a_out_next    = sign_a_out;
    sign_b_out_next    = sign_b_out;
    exp_a_out_next     = exp_a_out;
    exp_b_out_next     = exp_b_out;
    mant_a_out_next    = mant_a_out;
    mant_b_out_next    = mant_b_out;

    spec_result_next   = spec_result;
    spec_flags_next    = spec_flags;
    spec_override_next = spec_override;

    if (valid_in && ready_out) begin
      sign_a_out_next    = sign_a_in;
      sign_b_out_next    = sign_b_in;
      exp_a_out_next     = exp_a_in;
      exp_b_out_next     = exp_b_in;
      mant_a_out_next    = mant_a_in;
      mant_b_out_next    = mant_b_in;

      spec_override_next = 1'b0;
      spec_result_next   = 32'b0;
      spec_flags_next    = initial_flags;

      if (is_nan_a || is_nan_b) begin
        spec_override_next = 1'b1;
        spec_result_next = {1'b0, 8'hFF, 23'h400000};
        spec_flags_next[`F_INVALID] = 1'b1;
      end else if ((is_inf_a && is_zero_b) || (is_inf_b && is_zero_a)) begin
        spec_override_next = 1'b1;
        spec_result_next = {1'b1, 8'hFF, 23'h400000};
        spec_flags_next[`F_INVALID] = 1'b1;
      end else if (is_inf_a || is_inf_b) begin
        spec_override_next = 1'b1;
        spec_result_next   = {final_sign, 8'hFF, 23'h0};
      end else if (is_zero_a || is_zero_b) begin
        spec_override_next = 1'b1;
        spec_result_next   = {final_sign, 31'h0};
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out     <= 1'b0;
      spec_result   <= 32'b0;
      spec_flags    <= 5'b0;
      spec_override <= 1'b0;
      sign_a_out    <= 1'b0;
      sign_b_out    <= 1'b0;
      exp_a_out     <= 8'b0;
      exp_b_out     <= 8'b0;
      mant_a_out    <= 23'b0;
      mant_b_out    <= 23'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
      end
      sign_a_out    <= sign_a_out_next;
      sign_b_out    <= sign_b_out_next;
      exp_a_out     <= exp_a_out_next;
      exp_b_out     <= exp_b_out_next;
      mant_a_out    <= mant_a_out_next;
      mant_b_out    <= mant_b_out_next;
      spec_result   <= spec_result_next;
      spec_flags    <= spec_flags_next;
      spec_override <= spec_override_next;
    end
  end

endmodule

module mul_prod (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire sign_a,
    input wire sign_b,
    input wire [7:0] exp_a,
    input wire [7:0] exp_b,
    input wire [22:0] mant_a,
    input wire [22:0] mant_b,

    output reg final_sign,
    output reg [8:0] exp_sum,
    output reg [47:0] mant_prod,

    input wire spec_override_in,
    input wire [31:0] spec_result_in,
    input wire [4:0] spec_flags_in,

    output reg spec_override_out,
    output reg [31:0] spec_result_out,
    output reg [4:0] spec_flags_out
);

  assign ready_out = !valid_out || ready_in;
  wire [23:0] mant_a_full = (exp_a == 0) ? {1'b0, mant_a} : {1'b1, mant_a};
  wire [23:0] mant_b_full = (exp_b == 0) ? {1'b0, mant_b} : {1'b1, mant_b};

  reg final_sign_next;
  reg [8:0] exp_sum_next;
  reg [47:0] mant_prod_next;

  reg spec_override_out_next;
  reg [31:0] spec_result_out_next;
  reg [4:0] spec_flags_out_next;

  always @(*) begin
    final_sign_next        = final_sign;
    exp_sum_next           = exp_sum;
    mant_prod_next         = mant_prod;

    spec_override_out_next = spec_override_out;
    spec_result_out_next   = spec_result_out;
    spec_flags_out_next    = spec_flags_out;

    if (valid_in && ready_out) begin
      final_sign_next        = sign_a ^ sign_b;
      exp_sum_next           = {1'b0, exp_a} + {1'b0, exp_b} - 9'd127;
      mant_prod_next         = mant_a_full * mant_b_full;

      spec_override_out_next = spec_override_in;
      spec_result_out_next   = spec_result_in;
      spec_flags_out_next    = spec_flags_in;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out         <= 1'b0;
      final_sign        <= 1'b0;
      exp_sum           <= 9'b0;
      mant_prod         <= 48'b0;
      spec_override_out <= 1'b0;
      spec_result_out   <= 32'b0;
      spec_flags_out    <= 5'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
      end
      final_sign        <= final_sign_next;
      exp_sum           <= exp_sum_next;
      mant_prod         <= mant_prod_next;
      spec_override_out <= spec_override_out_next;
      spec_result_out   <= spec_result_out_next;
      spec_flags_out    <= spec_flags_out_next;
    end
  end

endmodule

module mul_norm (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire [ 8:0] exp_sum,
    input wire [47:0] mant_prod,

    output reg [ 8:0] exp_norm,
    output reg [47:0] mant_norm,

    input  wire final_sign_in,
    output reg  final_sign_out,

    input wire spec_override_in,
    input wire [31:0] spec_result_in,
    input wire [4:0] spec_flags_in,

    output reg spec_override_out,
    output reg [31:0] spec_result_out,
    output reg [4:0] spec_flags_out
);

  assign ready_out = !valid_out || ready_in;

  reg        final_sign_out_next;
  reg [ 8:0] exp_norm_next;
  reg [47:0] mant_norm_next;

  reg        spec_override_out_next;
  reg [31:0] spec_result_out_next;
  reg [ 4:0] spec_flags_out_next;

  always @(*) begin
    exp_norm_next          = exp_norm;
    mant_norm_next         = mant_norm;

    final_sign_out_next    = final_sign_out;
    spec_override_out_next = spec_override_out;
    spec_result_out_next   = spec_result_out;
    spec_flags_out_next    = spec_flags_out;

    if (valid_in && ready_out) begin

      exp_norm_next          = mant_prod[47] ? exp_sum + 9'd1 : exp_sum;
      mant_norm_next         = mant_prod[47] ? (mant_prod >> 1) : mant_prod;

      final_sign_out_next    = final_sign_in;
      spec_override_out_next = spec_override_in;
      spec_result_out_next   = spec_result_in;
      spec_flags_out_next    = spec_flags_in;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out         <= 1'b0;
      exp_norm          <= 8'b0;
      mant_norm         <= 48'b0;
      spec_override_out <= 1'b0;
      spec_result_out   <= 32'b0;
      spec_flags_out    <= 5'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
      end
      exp_norm          <= exp_norm_next;
      mant_norm         <= mant_norm_next;

      final_sign_out    <= final_sign_out_next;
      spec_override_out <= spec_override_out_next;
      spec_result_out   <= spec_result_out_next;
      spec_flags_out    <= spec_flags_out_next;
    end
  end

endmodule

module mul_round (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire [ 8:0] exp_norm,
    input wire [47:0] mant_norm,

    output reg [ 7:0] final_exp,
    output reg [22:0] final_mant,

    input  wire final_sign_in,
    output reg  final_sign_out,

    input wire spec_override_in,
    input wire [31:0] spec_result_in,
    input wire [4:0] spec_flags_in,

    output reg spec_override_out,
    output reg [31:0] spec_result_out,
    output reg [4:0] spec_flags_out
);
  assign ready_out = !valid_out || ready_in;

  reg  [ 7:0] final_exp_next;
  reg  [22:0] final_mant_next;
  reg         final_sign_out_next;
  reg         spec_override_out_next;
  reg  [31:0] spec_result_out_next;
  reg  [ 4:0] spec_flags_out_next;

  wire        mant_lsb = mant_norm[23];
  wire        G = mant_norm[22];
  wire        R = mant_norm[21];
  wire        S = |mant_norm[20:0];
  wire        round_up = G && (R | S | mant_lsb);
  wire [24:0] mant_rounded = mant_norm[46:23] + {23'b0, round_up};

  wire [ 8:0] exp_post = mant_rounded[24] ? exp_norm + 9'd1 : exp_norm;
  wire [22:0] mant_post = mant_rounded[24] ? mant_rounded[23:1] : mant_rounded[22:0];

  wire        overflow = (exp_post[8] || exp_post[7:0] == 8'hFF);
  wire        underflow = (exp_post[7:0] == 8'h00) && (mant_post != 0);
  wire        inexact = (G | R | S);

  always @(*) begin
    final_exp_next         = final_exp;
    final_mant_next        = final_mant;
    final_sign_out_next    = final_sign_out;
    spec_override_out_next = spec_override_out;
    spec_result_out_next   = spec_result_out;
    spec_flags_out_next    = spec_flags_out;

    if (valid_in && ready_out) begin
      final_exp_next = overflow ? 8'hFF : exp_post[7:0];
      final_mant_next = overflow ? 23'h0 : mant_post;
      final_sign_out_next = final_sign_in;
      spec_override_out_next = spec_override_in;
      spec_result_out_next = spec_result_in;
      spec_flags_out_next    = spec_flags_in |
        (overflow ? `FLAG_OF : 5'b0) |
        (underflow ? `FLAG_UF : 5'b0) |
        (inexact ? `FLAG_NX : 5'b0);
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out         <= 1'b0;
      final_exp         <= 8'b0;
      final_mant        <= 23'b0;
      final_sign_out    <= 1'b0;
      spec_override_out <= 1'b0;
      spec_result_out   <= 32'b0;
      spec_flags_out    <= 5'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
      end
      final_exp         <= final_exp_next;
      final_mant        <= final_mant_next;
      final_sign_out    <= final_sign_out_next;
      spec_override_out <= spec_override_out_next;
      spec_result_out   <= spec_result_out_next;
      spec_flags_out    <= spec_flags_out_next;
    end
  end

endmodule

module mul_pack (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire final_sign,
    input wire [7:0] final_exp,
    input wire [22:0] final_mant,

    input wire spec_override,
    input wire [31:0] spec_result,
    input wire [4:0] spec_flags,

    output reg [31:0] result,
    output reg [ 4:0] flags
);

  wire [31:0] final_result = {final_sign, final_exp, final_mant};

  wire [31:0] result_next;
  wire [ 4:0] flags_next;

  assign result_next = spec_override ? spec_result : final_result;
  assign flags_next  = spec_flags;

  assign ready_out   = !valid_out || ready_in;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out <= 1'b0;
      result    <= 32'b0;
      flags     <= 5'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
        result    <= result_next;
        flags     <= flags_next;
      end
    end
  end

endmodule

module fp_multiplier (
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

    input wire [4:0] initial_flags;

    output wire [31:0] result,
    output wire [ 4:0] flags
);

  //s0
  wire sign_a, sign_b;
  wire [7:0] exp_a, exp_b;
  wire [22:0] mant_a, mant_b;
  wire is_zero_a, is_zero_b, is_nan_a, is_nan_b, is_inf_a, is_inf_b;

  mul_decode s0 (
      .op_a   (op_a),
      .op_b   (op_b),
      .mode_fp(mode_fp),

      .sign_a(sign_a),
      .sign_b(sign_b),
      .exp_a (exp_a),
      .exp_b (exp_b),
      .mant_a(mant_a),
      .mant_b(mant_b),

      .is_zero_a(is_zero_a),
      .is_zero_b(is_zero_b),
      .is_nan_a (is_nan_a),
      .is_nan_b (is_nan_b),
      .is_inf_a (is_inf_a),
      .is_inf_b (is_inf_b)
  );

  //s1
  wire s1_valid, s1_ready;
  wire [31:0] spec_result;
  wire [4:0] spec_flags;
  wire spec_override;

  wire sign_a_s1;
  wire sign_b_s1;
  wire [7:0] exp_a_s1, exp_b_s1;
  wire [22:0] mant_a_s1, mant_b_s1;

  mul_exception s1 (
      .clk      (clk),
      .rst_n    (rst_n),
      .valid_in (start),
      .ready_in (s2_ready),
      .valid_out(s1_valid),
      .ready_out(s1_ready),

      .is_zero_a(is_zero_a),
      .is_zero_b(is_zero_b),
      .is_nan_a (is_nan_a),
      .is_nan_b (is_nan_b),
      .is_inf_a (is_inf_a),
      .is_inf_b (is_inf_b),

      .initial_flags(initial_flags),

      .spec_result  (spec_result),
      .spec_flags   (spec_flags),
      .spec_override(spec_override),

      .sign_a_in(sign_a),
      .sign_b_in(sign_b),
      .exp_a_in (exp_a),
      .exp_b_in (exp_b),
      .mant_a_in(mant_a),
      .mant_b_in(mant_b),

      .sign_a_out(sign_a_s1),
      .sign_b_out(sign_b_s1),
      .exp_a_out (exp_a_s1),
      .exp_b_out (exp_b_s1),
      .mant_a_out(mant_a_s1),
      .mant_b_out(mant_b_s1)
  );

  //s2
  wire s2_valid, s2_ready;
  wire final_sign;
  wire [8:0] exp_sum;
  wire [47:0] mant_prod;

  wire spec_override_s2;
  wire [31:0] spec_result_s2;
  wire [4:0] spec_flags_s2;

  mul_prod s2 (
      .clk      (clk),
      .rst_n    (rst_n),
      .valid_in (s1_valid),
      .ready_in (s3_ready),
      .valid_out(s2_valid),
      .ready_out(s2_ready),

      .sign_a(sign_a_s1),
      .sign_b(sign_b_s1),
      .exp_a (exp_a_s1),
      .exp_b (exp_b_s1),
      .mant_a(mant_a_s1),
      .mant_b(mant_b_s1),

      .final_sign(final_sign),
      .exp_sum   (exp_sum),
      .mant_prod (mant_prod),

      .spec_override_in(spec_override),
      .spec_result_in  (spec_result),
      .spec_flags_in   (spec_flags),

      .spec_override_out(spec_override_s2),
      .spec_result_out  (spec_result_s2),
      .spec_flags_out   (spec_flags_s2)
  );

  //s3
  wire s3_valid, s3_ready;
  wire [8:0] exp_norm;
  wire [47:0] mant_norm;

  wire final_sign_s3;
  wire spec_override_s3;
  wire [31:0] spec_result_s3;
  wire [4:0] spec_flags_s3;

  mul_norm s3 (
      .clk      (clk),
      .rst_n    (rst_n),
      .valid_in (s2_valid),
      .ready_in (s4_ready),
      .valid_out(s3_valid),
      .ready_out(s3_ready),

      .exp_sum  (exp_sum),
      .mant_prod(mant_prod),
      .exp_norm (exp_norm),
      .mant_norm(mant_norm),

      .final_sign_in (final_sign),
      .final_sign_out(final_sign_s3),

      .spec_override_in(spec_override_s2),
      .spec_result_in  (spec_result_s2),
      .spec_flags_in   (spec_flags_s2),

      .spec_override_out(spec_override_s3),
      .spec_result_out  (spec_result_s3),
      .spec_flags_out   (spec_flags_s3)
  );

  //s4
  wire s4_valid, s4_ready;
  wire [7:0] final_exp;
  wire [22:0] final_mant;

  wire final_sign_s4;
  wire spec_override_s4;
  wire [31:0] spec_result_s4;
  wire [4:0] spec_flags_s4;

  mul_round s4 (
      .clk      (clk),
      .rst_n    (rst_n),
      .valid_in (s3_valid),
      .ready_in (s5_ready),
      .valid_out(s4_valid),
      .ready_out(s4_ready),

      .exp_norm  (exp_norm),
      .mant_norm (mant_norm),
      .final_exp (final_exp),
      .final_mant(final_mant),

      .final_sign_in (final_sign_s3),
      .final_sign_out(final_sign_s4),

      .spec_override_in(spec_override_s3),
      .spec_result_in  (spec_result_s3),
      .spec_flags_in   (spec_flags_s3),

      .spec_override_out(spec_override_s4),
      .spec_result_out  (spec_result_s4),
      .spec_flags_out   (spec_flags_s4)
  );

  //s5
  wire s5_ready;

  mul_pack s5 (
      .clk(clk),
      .rst_n(rst_n),
      .valid_in(s4_valid),
      .ready_in(ready_in),
      .valid_out(valid_out),
      .ready_out(s5_ready),

      .final_sign(final_sign_s4),
      .final_exp (final_exp),
      .final_mant(final_mant),

      .spec_override(spec_override_s4),
      .spec_result(spec_result_s4),
      .spec_flags(spec_flags_s4),

      .result(result),
      .flags (flags)
  );

  assign ready_out = s1_ready;
endmodule
