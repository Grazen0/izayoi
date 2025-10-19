`default_nettype none
`include "macros.vh"

module fp_align #(
    parameter P = 23,
    parameter E = 8
) (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire ready_in,
    input wire [P-1:0] mant_a,
    input wire [E-1:0] exp_a,
    input wire [P-1:0] mant_b,
    input wire [E-1:0] exp_b,

    output reg valid_out,
    output wire ready_out,
    output reg [P+3:0] mant_a_aligned,
    output reg [P+3:0] mant_b_aligned,
    output reg [E-1:0] bigger_exp,
    output reg is_a_nan,
    output reg is_b_nan,
    output reg is_a_inf,
    output reg is_b_inf,

    input  wire sign_a_in,
    output reg  sign_a_out,
    input  wire sign_b_in,
    output reg  sign_b_out,
    input  wire round_mode_in,
    output reg  round_mode_out,
    input  wire mode_fp_in,
    output reg  mode_fp_out
);
  assign ready_out = ready_in;

  reg [P+3:0] mant_a_aligned_next, mant_b_aligned_next;
  reg [E-1:0] bigger_exp_next;

  reg sign_a_aligned_next, sign_b_aligned_next, round_mode_out_next, mode_fp_out_next;
  reg is_a_nan_next, is_b_nan_next, is_a_inf_next, is_b_inf_next;

  wire signed [8:0] exp_diff = exp_a - exp_b;
  wire [P:0] mant_a_full = exp_a == 0 ? {1'b0, mant_a} : {1'b1, mant_a};
  wire [P:0] mant_b_full = exp_b == 0 ? {1'b0, mant_b} : {1'b1, mant_b};

  reg [$clog2(P+4):0] shamt;

  always @(*) begin
    if (valid_in && ready_out) begin
      shamt = 0;

      sign_a_aligned_next = sign_a_in;
      sign_b_aligned_next = sign_b_in;
      round_mode_out_next = round_mode_in;
      mode_fp_out_next = mode_fp_in;

      is_a_nan_next = (exp_a == 8'hFF) && (mant_a != 0);
      is_b_nan_next = (exp_b == 8'hFF) && (mant_b != 0);
      is_a_inf_next = (exp_a == 8'hFF) && (mant_a == 0);
      is_b_inf_next = (exp_b == 8'hFF) && (mant_b == 0);

      if (exp_diff >= 0) begin
        // a >= b
        shamt = exp_diff[$clog2(P+4):0];

        bigger_exp_next = exp_a;
        mant_a_aligned_next = {mant_a_full, 3'b000};
        mant_b_aligned_next = {mant_b_full, 3'b000} >> shamt;
      end else begin
        // a < b
        shamt = -exp_diff[$clog2(P+4):0];

        bigger_exp_next = exp_b;
        mant_a_aligned_next = {mant_a_full, 3'b000} >> shamt;
        mant_b_aligned_next = {mant_b_full, 3'b000};
      end
    end else begin
      // Keep current outputs
      bigger_exp_next = bigger_exp;
      mant_a_aligned_next = mant_a_aligned;
      mant_b_aligned_next = mant_b_aligned;

      sign_a_aligned_next = sign_a_out;
      sign_b_aligned_next = sign_b_out;
      round_mode_out_next = round_mode_out;
      mode_fp_out_next = mode_fp_out;
    end
  end


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mant_a_aligned <= {(P + 4) {1'b0}};
      mant_b_aligned <= {(P + 4) {1'b0}};
      bigger_exp     <= 8'b0;
      is_a_nan       <= 1'b0;
      is_b_nan       <= 1'b0;
      is_a_inf       <= 1'b0;
      is_b_inf       <= 1'b0;

      valid_out      <= 1'b0;

      sign_a_out     <= 1'b0;
      sign_b_out     <= 1'b0;
      round_mode_out <= 1'b0;
      mode_fp_out    <= 1'b0;

    end else begin
      mant_a_aligned <= mant_a_aligned_next;
      mant_b_aligned <= mant_b_aligned_next;
      bigger_exp <= bigger_exp_next;
      is_a_nan  <= is_a_nan_next;
      is_b_nan  <= is_b_nan_next;
      is_a_inf  <= is_a_inf_next;
      is_b_inf  <= is_b_inf_next;

      valid_out <= !ready_in ? valid_out : valid_in;

      sign_a_out <= sign_a_aligned_next;
      sign_b_out <= sign_b_aligned_next;
      round_mode_out <= round_mode_out_next;
      mode_fp_out    <= mode_fp_out_next;
    end
  end
endmodule

module fp_addsub #(
    parameter P = 23,
    parameter E = 8
) (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire ready_in,
    input wire [P+3:0] mant_a_aligned,
    input wire [P+3:0] mant_b_aligned,
    input wire sign_a,
    input wire sign_b,
    input wire is_a_nan,
    input wire is_b_nan,
    input wire is_a_inf,
    input wire is_b_inf,

    output reg valid_out,
    output wire ready_out,
    output reg [P+3:0] sum,
    output reg carry_out,
    output reg sign_out,

    input wire [E-1:0] exp_in,
    output reg [E-1:0] exp_out,
    input wire round_mode_in,
    output reg round_mode_out,
    input wire mode_fp_in,
    output reg mode_fp_out
);
  assign ready_out = ready_in;

  reg [P+3:0] sum_next;
  reg carry_out_next, sign_out_next;

  reg [P+3:0] mant_big, mant_small;
  reg sign_big;

  reg [E-1:0] exp_out_next;
  reg round_mode_out_next, mode_fp_out_next;

  always @(*) begin
    if (valid_in && ready_out) begin
      exp_out_next = exp_in;
      round_mode_out_next = round_mode_in;
      mode_fp_out_next = mode_fp_in;

      if (is_a_nan || is_b_nan) begin
        // Result must be NaN
        exp_out_next = 8'hFF;
        sum_next = {2'b11, {(P + 2) {1'b0}}};
        carry_out_next = 1'b0;
        sign_out_next = 1'b0;
      end else if (is_a_inf && is_b_inf && sign_a != sign_b) begin
        // Result must be NaN (again)
        exp_out_next = 8'hFF;
        sum_next = {2'b11, {(P + 2) {1'b0}}};
        carry_out_next = 1'b0;
        sign_out_next = 1'b0;
      end else if (is_a_inf) begin
        // Result must be Inf (towards A)
        exp_out_next = 8'hFF;
        sum_next = {1'b1, {P{1'b0}}, 3'b000};
        carry_out_next = 1'b0;
        sign_out_next = sign_a;
      end else if (is_b_inf) begin
        // Result must be Inf (towards B)
        exp_out_next = 8'hFF;
        sum_next = {1'b1, {P{1'b0}}, 3'b000};
        carry_out_next = 1'b0;
        sign_out_next = sign_b;
      end else begin
        // Regular operations

        if (mant_a_aligned >= mant_b_aligned) begin
          mant_big   = mant_a_aligned;
          mant_small = mant_b_aligned;
          sign_big   = sign_a;
        end else begin
          mant_big   = mant_b_aligned;
          mant_small = mant_a_aligned;
          sign_big   = sign_b;
        end

        if (sign_a == sign_b) begin
          {carry_out_next, sum_next} = mant_a_aligned + mant_b_aligned;
          sign_out_next = sign_a;
        end else begin
          sum_next = mant_big - mant_small;
          carry_out_next = 1'b0;
          sign_out_next = sign_big;
        end
      end

    end else begin
      // Keep current outputs
      sum_next = sum;
      carry_out_next = carry_out;
      sign_out_next = sign_out;

      exp_out_next = exp_out;
      round_mode_out_next = round_mode_out;
      mode_fp_out_next = mode_fp_out;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum            <= {(P + 3) {1'b0}};
      carry_out      <= 1'b0;
      sign_out       <= 1'b0;

      valid_out      <= 1'b0;

      exp_out        <= 8'b0;
      round_mode_out <= 1'b0;
      mode_fp_out    <= 1'b0;
    end else begin
      sum            <= sum_next;
      carry_out      <= carry_out_next;
      sign_out       <= sign_out_next;

      valid_out      <= !ready_in ? valid_out : valid_in;

      exp_out        <= exp_out_next;
      round_mode_out <= round_mode_out_next;
      mode_fp_out    <= mode_fp_out_next;
    end
  end
endmodule

module fp_normalize #(
    parameter P = 23,
    parameter E = 8
) (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire ready_in,
    input wire [P+3:0] mant_in,
    input wire [E-1:0] exp_in,
    input wire carry,
    input wire [4:0] flags_in,

    output reg valid_out,
    output wire ready_out,
    output reg [P+3:0] mant_out,
    output reg [E-1:0] exp_out,
    output reg [4:0] flags_out,

    input  wire sign_in,
    output reg  sign_out,
    input  wire round_mode_in,
    output reg  round_mode_out,
    input  wire mode_fp_in,
    output reg  mode_fp_out
);
  reg busy;

  reg [P+3:0] mant_next;
  reg [E-1:0] exp_next;
  reg [4:0] flags_next;

  reg valid_out_next, busy_next;

  reg sign_out_next, round_mode_out_next, mode_fp_out_next;

  assign ready_out = !busy && ready_in;

  always @(*) begin
    if (valid_in && ready_out) begin
      // Use stage inputs
      flags_next = flags_in;

      sign_out_next = sign_in;
      round_mode_out_next = round_mode_in;
      mode_fp_out_next = mode_fp_in;

      if (carry) begin
        if (exp_in != 8'hFF) begin
          // Shift mantissa right
          mant_next = {1'b1, mant_in[P+3:1]};
          exp_next  = exp_in + 1;

          if (mant_in[0]) begin
            // Shifted out a 1
            flags_next[`F_INEXACT] = 1'b1;
          end
        end

        if (exp_next == 8'hFF) begin
          // Got infinity
          mant_next = {(P + 4) {1'b0}};
          flags_next[`F_OVERFLOW] = 1'b1;
        end
      end else begin
        mant_next = mant_in;
        exp_next  = exp_in;
      end
    end else begin
      // Work with current data
      flags_next = flags_out;

      sign_out_next = sign_out;
      round_mode_out_next = round_mode_out;
      mode_fp_out_next = mode_fp_out;

      if (valid_out) begin
        mant_next = mant_out;
        exp_next  = exp_out;
      end else begin
        mant_next = mant_out << 1;
        exp_next  = exp_out - 1;
      end

      if (exp_next == 8'h00) begin
        flags_next[`F_UNDERFLOW] = 1'b1;
        flags_next[`F_INEXACT]   = 1'b1;
      end
    end

    if (exp_next == 0 && flags_next[`F_INEXACT]) begin
      flags_next[`F_UNDERFLOW] = 1'b1;
    end

    valid_out_next =
      (busy || (valid_in && ready_out)) &&
      (mant_next == 0 || mant_next[P+3] || exp_next == 0 || exp_next == 8'hFF);
    busy_next = (busy || (valid_in && ready_out)) && !valid_out_next;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mant_out <= {(P + 4) {1'b0}};
      exp_out <= 8'b0;
      flags_out <= 5'b0;

      valid_out <= 1'b0;
      busy <= 1'b0;

      sign_out <= 1'b0;
      round_mode_out <= 1'b0;
      mode_fp_out <= 1'b0;
    end else begin
      mant_out <= mant_next;
      exp_out <= exp_next;
      flags_out <= flags_next;

      valid_out <= valid_out_next;
      busy <= busy_next;

      sign_out <= sign_out_next;
      round_mode_out <= round_mode_out_next;
      mode_fp_out <= mode_fp_out_next;
    end
  end
endmodule

module fp_round #(
    parameter P = 23,
    parameter E = 8
) (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire ready_in,
    input wire [P+3:0] mant_in,
    input wire round_mode,

    output reg valid_out,
    output wire ready_out,
    output reg [P+3:0] mant_rounded,
    output reg carry_out,
    input wire [4:0] flags_in,
    output reg [4:0] flags_out,

    input wire [E-1:0] exp_in,
    output reg [E-1:0] exp_out,
    input wire sign_in,
    output reg sign_out,
    input wire mode_fp_in,
    output reg mode_fp_out
);
  localparam ROUND_NEAREST_EVEN = 1'b0;
  localparam ROUND_ZERO = 1'b1;

  reg [P+3:0] mant_rounded_next;
  reg carry_out_next;

  reg [E-1:0] exp_out_next;
  reg sign_out_next;
  reg [4:0] flags_out_next;
  reg mode_fp_out_next;

  wire rr = mant_in[3];
  wire m0 = mant_in[2];
  wire ss = |mant_in[1:0];

  reg round;

  assign ready_out = ready_in;

  always @(*) begin
    if (valid_in && ready_out) begin
      // Use stage inputs
      flags_out_next = flags_in;

      exp_out_next = exp_in;
      sign_out_next = sign_in;
      mode_fp_out_next = mode_fp_in;

      case (round_mode)
        ROUND_NEAREST_EVEN: round = rr & (m0 | ss);
        ROUND_ZERO: round = 1'b0;
      endcase

      if (rr | ss) begin
        flags_out_next[`F_INEXACT] = 1'b1;
      end

      if (round) begin
        flags_out_next[`F_INEXACT] = 1'b1;
        {carry_out_next, mant_rounded_next} = mant_in + 'b1000;
      end else begin
        mant_rounded_next = mant_in;
        carry_out_next = 1'b0;
      end
    end else begin
      // Use existing data
      mant_rounded_next = mant_rounded;
      carry_out_next = carry_out;
      flags_out_next = flags_out;

      exp_out_next = exp_out;
      sign_out_next = sign_out;
      mode_fp_out_next = mode_fp_out;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mant_rounded <= {(P + 4) {1'b0}};
      carry_out    <= 1'b0;
      flags_out    <= 5'b0;

      valid_out    <= 1'b0;

      exp_out      <= 8'b0;
      sign_out     <= 1'b0;
      mode_fp_out  <= 1'b0;
    end else begin
      mant_rounded <= mant_rounded_next;
      carry_out <= carry_out_next;
      flags_out <= flags_out_next;

      valid_out <= !ready_in ? valid_out : valid_in;

      exp_out <= exp_out_next;
      sign_out <= sign_out_next;
      mode_fp_out <= mode_fp_out_next;
    end
  end
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

module fp_adder #(
    parameter P = 23,
    parameter E = 8,
    parameter N = P + E + 1
) (
    input wire clk,
    input wire rst_n,
    input wire [N-1:0] op_a,
    input wire [N-1:0] op_b,
    input wire sub,
    input wire mode_fp,
    input wire round_mode,
    input wire start,
    input wire ready_in,

    output wire valid_out,
    output wire ready_out,
    output wire [N-1:0] result,
    output wire [4:0] flags
);
  wire sign_a, sign_b;
  wire [E-1:0] exp_a, exp_b;
  wire [P-1:0] mant_a, mant_b;

  fp_unpacker unpacker (
      .op_a(op_a),
      .op_b(op_b),
      .mode_fp(mode_fp),

      .sign_a(sign_a),
      .sign_b(sign_b),
      .exp_a (exp_a),
      .exp_b (exp_b),
      .mant_a(mant_a),
      .mant_b(mant_b)
  );

  wire sign_b_corrected = sign_b ^ sub;

  wire align_valid, addsub_ready;

  wire [P+3:0] mant_a_aligned, mant_b_aligned;
  wire [E-1:0] exp_aligned;
  wire sign_a_aligned, sign_b_aligned;
  wire round_mode_aligned, mode_fp_aligned;
  wire is_a_nan, is_b_nan, is_a_inf, is_b_inf;

  fp_align align (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(start),
      .ready_in(addsub_ready),
      .mant_a(mant_a),
      .exp_a(exp_a),
      .mant_b(mant_b),
      .exp_b(exp_b),

      .valid_out(align_valid),
      .ready_out(ready_out),
      .mant_a_aligned(mant_a_aligned),
      .mant_b_aligned(mant_b_aligned),
      .bigger_exp(exp_aligned),
      .is_a_nan(is_a_nan),
      .is_b_nan(is_b_nan),
      .is_a_inf(is_a_inf),
      .is_b_inf(is_b_inf),

      .sign_a_in(sign_a),
      .sign_a_out(sign_a_aligned),
      .sign_b_in(sign_b_corrected),
      .sign_b_out(sign_b_aligned),
      .round_mode_in(round_mode),
      .round_mode_out(round_mode_aligned),
      .mode_fp_in(mode_fp),
      .mode_fp_out(mode_fp_aligned)
  );

  wire addsub_valid, normalize_ready;
  wire [P+3:0] sum;
  wire sum_carry, sum_sign;

  wire [E-1:0] exp_addsub;
  wire round_mode_addsub, mode_fp_addsub;

  fp_addsub addsub (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(align_valid),
      .ready_in(normalize_ready),
      .mant_a_aligned(mant_a_aligned),
      .mant_b_aligned(mant_b_aligned),
      .sign_a(sign_a_aligned),
      .sign_b(sign_b_aligned),
      .is_a_nan(is_a_nan),
      .is_b_nan(is_b_nan),
      .is_a_inf(is_a_inf),
      .is_b_inf(is_b_inf),

      .valid_out(addsub_valid),
      .ready_out(addsub_ready),
      .sum(sum),
      .carry_out(sum_carry),
      .sign_out(sum_sign),

      .exp_in(exp_aligned),
      .exp_out(exp_addsub),
      .round_mode_in(round_mode_aligned),
      .round_mode_out(round_mode_addsub),
      .mode_fp_in(mode_fp_aligned),
      .mode_fp_out(mode_fp_addsub)
  );

  wire normalize_valid, round_ready;

  wire [P+3:0] mant_normalized;
  wire [E-1:0] exp_normalized;
  wire [  4:0] flags_normalized;
  wire sign_normalized, round_mode_normalized, mode_fp_normalized;

  fp_normalize normalize (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(addsub_valid),
      .ready_in(round_ready),
      .mant_in(sum),
      .exp_in(exp_addsub),
      .carry(sum_carry),
      .flags_in(5'b0),

      .ready_out(normalize_ready),
      .valid_out(normalize_valid),
      .mant_out (mant_normalized),
      .exp_out  (exp_normalized),
      .flags_out(flags_normalized),

      .sign_in(sum_sign),
      .sign_out(sign_normalized),
      .round_mode_in(round_mode_addsub),
      .round_mode_out(round_mode_normalized),
      .mode_fp_in(mode_fp_addsub),
      .mode_fp_out(mode_fp_normalized)
  );

  wire round_valid, renormalize_ready;

  wire [P+3:0] mant_rounded;
  wire round_carry;
  wire [4:0] flags_rounded;

  wire [E-1:0] exp_rounded;
  wire sign_rounded, mode_fp_rounded;

  fp_round round (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(normalize_valid),
      .ready_in(renormalize_ready),
      .mant_in(mant_normalized),
      .round_mode(round_mode_normalized),
      .flags_in(flags_normalized),

      .ready_out(round_ready),
      .valid_out(round_valid),
      .mant_rounded(mant_rounded),
      .carry_out(round_carry),
      .flags_out(flags_rounded),

      .exp_in(exp_normalized),
      .exp_out(exp_rounded),
      .sign_in(sign_normalized),
      .sign_out(sign_rounded),
      .mode_fp_in(mode_fp_normalized),
      .mode_fp_out(mode_fp_rounded)
  );

  wire renormalize_valid;

  wire [P+3:0] mant_renormalized;
  wire [E-1:0] exp_renormalized;
  wire [4:0] flags_renormalized;
  wire sign_renormalized, mode_fp_renormalized;

  fp_normalize renormalize (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(round_valid),
      .ready_in(ready_in),
      .mant_in(mant_rounded),
      .exp_in(exp_rounded),
      .carry(round_carry),
      .flags_in(flags_rounded),

      .ready_out(renormalize_ready),
      .valid_out(renormalize_valid),
      .mant_out (mant_renormalized),
      .exp_out  (exp_renormalized),
      .flags_out(flags_renormalized),

      .sign_in(sign_rounded),
      .sign_out(sign_renormalized),
      .mode_fp_in(mode_fp_rounded),
      .mode_fp_out(mode_fp_renormalized)
  );

  assign valid_out = renormalize_valid;

  fp_packer packer (
      .sign(sign_renormalized),
      .exp(exp_renormalized),
      .mant(mant_renormalized),
      .flags_in(flags_renormalized),
      .mode_fp(mode_fp_renormalized),

      .result(result),
      .flags_out(flags)
  );
endmodule
