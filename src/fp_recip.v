`include "macros.vh"

// LUT para aproximación inicial de 1/x
module x0 #(
    parameter M_WIDTH = 24
) (
    input wire [9:0] in,
    output wire [M_WIDTH-1:0] out
);
  reg [6:0] ROM[0:1023];
  wire [6:0] seven;

  initial begin
    $readmemh("data/x0.hex", ROM);
  end

  assign seven = ROM[in];
  assign out = (in == 0) ? {1'b1, seven, {(M_WIDTH - 8) {1'b0}}} : {2'b01, seven, {(M_WIDTH - 9) {1'b0}}};
endmodule

module fp_recip (
    input  wire [31:0] in_bits,
    output reg  [31:0] out_bits,
    output reg  [ 4:0] except_flags
);
  // Bit format
  parameter EXP = 8;
  parameter FRAC = 23;
  parameter BIAS = 127;

  // Anchos internos
  parameter K = 10;
  parameter M_WIDTH = 1 + FRAC;
  parameter Y_WIDTH = M_WIDTH + 4;

  // Extracción de campos
  wire            sign_in = in_bits[31];
  wire [ EXP-1:0] exp_in = in_bits[FRAC+EXP-1:FRAC];
  wire [FRAC-1:0] frac_in = in_bits[FRAC-1:0];

  wire            is_exp_all_zero = (exp_in == 0);
  wire            is_exp_all_one = (exp_in == {EXP{1'b1}});
  wire            is_frac_zero = (frac_in == 0);

  localparam [Y_WIDTH-1:0] ONE_FIXED = (32'd1 << FRAC);
  localparam [Y_WIDTH-1:0] TWO_FIXED = (32'd2 << FRAC);

  // Señales internas
  reg [M_WIDTH-1:0] m_int, tmp;
  reg [Y_WIDTH-1:0] y0, y1, y2, y_norm;
  reg [2*Y_WIDTH-1:0] prod_my, prod_ycorr;
  reg [Y_WIDTH-1:0] correction, prod_my_shr;
  reg [EXP-1:0] out_exp;
  reg [FRAC-1:0] out_frac;
  reg out_sign;
  reg special_out_done;
  reg adj;
  integer exp_unbiased, exp_out_i, shift_count, i;

  // LUT x0
  wire [K-1:0] x0_index;
  wire [M_WIDTH-1:0] x0_lut_out;
  assign x0_index = m_int[M_WIDTH-2:M_WIDTH-1-K];

  x0 x0_inst (
      .in (x0_index),
      .out(x0_lut_out)
  );

  // Lógica principal
  always @(*) begin
    // Valores por defecto
    out_bits = 0;
    except_flags = 0;
    special_out_done = 0;
    out_sign = sign_in;
    out_exp = 0;
    out_frac = 0;
    adj = 0;

    // --- Casos especiales: Inf / NaN / 0 ---
    if (is_exp_all_one) begin
      if (is_frac_zero) begin
        // Inf -> 0
        out_exp  = 0;
        out_frac = 0;
      end else begin
        // NaN -> NaN
        out_exp = {EXP{1'b1}};
        out_frac = {1'b1, {(FRAC - 1) {1'b0}}};
        except_flags[`F_INVALID] = 1'b1;
      end
      special_out_done = 1;
    end else if (is_exp_all_zero && is_frac_zero) begin
      // 0 -> Inf
      out_exp = {EXP{1'b1}};
      out_frac = 0;
      except_flags[`F_DIVIDE_BY_ZERO] = 1'b1;
      special_out_done = 1;
    end

    // --- Normalización y Newton-Raphson ---
    if (!special_out_done) begin
      // Preparar mantisa y exponente
      if (!is_exp_all_zero) begin
        m_int = {1'b1, frac_in};
        exp_unbiased = exp_in - BIAS;
      end else begin
        tmp = {1'b0, frac_in};
        shift_count = 0;
        for (i = 0; i < M_WIDTH; i = i + 1) begin
          if (tmp[M_WIDTH-1-i]) begin
            shift_count = i;
            i = M_WIDTH;
          end
        end
        m_int = tmp << shift_count;
        exp_unbiased = 1 - BIAS - shift_count;
      end

      // Aproximación inicial
      y0 = x0_lut_out;

      // Newton-Raphson iteración 1
      prod_my = m_int * y0;
      prod_my_shr = prod_my >> FRAC;
      correction = TWO_FIXED - prod_my_shr;
      prod_ycorr = y0 * correction;
      y1 = prod_ycorr >> FRAC;

      // Newton-Raphson iteración 2
      prod_my = m_int * y1;
      prod_my_shr = prod_my >> FRAC;
      correction = TWO_FIXED - prod_my_shr;
      prod_ycorr = y1 * correction;
      y2 = prod_ycorr >> FRAC;

      y_norm = y2;
      if (y_norm < ONE_FIXED) begin
        y_norm = y_norm << 1;
        adj = 1;
      end

      // Exponente de salida
      exp_out_i = BIAS - exp_unbiased - adj;

      if (exp_out_i >= ((1 << EXP) - 1)) begin
        out_exp = {EXP{1'b1}};
        out_frac = 0;
        except_flags[`F_OVERFLOW] = 1'b1;
      end else if (exp_out_i <= 0) begin
        out_exp = 0;
        out_frac = 0;
        except_flags[`F_UNDERFLOW] = 1'b1;
      end else begin
        out_exp = exp_out_i[EXP-1:0];
        out_frac = y_norm[FRAC-1:0];
        except_flags[`F_INEXACT] = 1'b1;
      end

      out_bits = {out_sign, out_exp, out_frac};
    end
  end
endmodule
