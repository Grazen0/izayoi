module recip_fp #(parameter TYPE = 32)(
    input  wire [TYPE-1:0] in_bits,
    output reg  [TYPE-1:0] out_bits,
    output reg  [4:0]      except_flags
);

    parameter EXP  = (TYPE==16) ? 5  : 8;
    parameter FRAC = (TYPE==16) ? 10 : 23;
    parameter BIAS = (TYPE==16) ? 15 : 127;
    parameter NSIG = 11;

    wire sign_in;
    wire [EXP-1:0] exp_in;
    wire [FRAC-1:0] frac_in;

    assign sign_in = in_bits[TYPE-1];
    assign exp_in  = in_bits[FRAC + EXP-1:FRAC];
    assign frac_in = in_bits[FRAC-1:0];

    wire is_exp_all_zero = (exp_in == 0);
    wire is_exp_all_one  = (exp_in == {EXP{1'b1}});
    wire is_frac_zero    = (frac_in == 0);

    parameter M_WIDTH = 1 + FRAC;
    parameter Y_WIDTH = M_WIDTH + 4;
    parameter K = 10;

    reg [M_WIDTH-1:0] m_int;
    reg [M_WIDTH-1:0] tmp;
    reg [31:0] exp_unbiased;
    reg [Y_WIDTH-1:0] y0, y1, y2;
    reg [2*Y_WIDTH-1:0] prod_my;
    reg [Y_WIDTH-1:0] correction;
    reg [2*Y_WIDTH-1:0] prod_ycorr;
    reg [Y_WIDTH-1:0] y_norm;
    reg [EXP-1:0] out_exp;
    reg [FRAC-1:0] out_frac;
    reg out_sign;
    reg special_out_done;
    integer exp_out_i;
    integer adj;
    integer shift_count;
    integer i;

    wire [K-1:0] x0_index;
    wire [NSIG+1:0] x0_lut_out;
    reg  [Y_WIDTH-1:0] x0_out_aligned;

    assign x0_index = m_int[M_WIDTH-2 -: K];

    X0 x0_inst (
        .in(x0_index),
        .out(x0_lut_out)
    );

    always @(*) begin
        x0_out_aligned = 0;
        for (i = 0; i <= NSIG+1; i = i + 1) begin
            x0_out_aligned[Y_WIDTH-1-i] = x0_lut_out[NSIG+1-i];
        end
    end

    parameter F_INEXACT   = 0;
    parameter F_UNDERFLOW = 1;
    parameter F_OVERFLOW  = 2;
    parameter F_DIV_ZERO  = 3;
    parameter F_INVALID   = 4;

    always @(*) begin
        out_bits = 0;
        except_flags = 0;
        special_out_done = 0;
        out_sign = sign_in;
        out_exp = 0;
        out_frac = 0;

        if (is_exp_all_one) begin
            if (is_frac_zero) begin
                out_exp = 0;
                out_frac = 0;
            end else begin
                out_exp = {EXP{1'b1}};
                out_frac = {1'b1, {(FRAC-1){1'b0}}};
                except_flags[F_INVALID] = 1'b1;
            end
            special_out_done = 1;
        end else if (is_exp_all_zero && is_frac_zero) begin
            out_exp = {EXP{1'b1}};
            out_frac = 0;
            except_flags[F_DIV_ZERO] = 1'b1;
            special_out_done = 1;
        end

        if (!special_out_done) begin
            if (!is_exp_all_zero) begin
                m_int = {1'b1, frac_in};
                exp_unbiased = exp_in - BIAS;
            end else begin
                tmp = {1'b0, frac_in};
                shift_count = 0;
                for (i = M_WIDTH-1; i >= 0; i = i - 1) begin
                    if (tmp[i]) begin
                        shift_count = (M_WIDTH-1) - i;
                        i = -1;
                    end
                end
                if (tmp == 0) begin
                    out_bits = {out_sign, {EXP{1'b0}}, {FRAC{1'b0}}};
                    except_flags = 0;
                    special_out_done = 1;
                end else begin
                    m_int = tmp << shift_count;
                    exp_unbiased = 1 - BIAS - shift_count;
                end
            end

            if (!special_out_done) begin
                y0 = x0_out_aligned;

                prod_my = m_int * y0;
                correction = ((1 << FRAC)*2) - (prod_my >> FRAC);
                prod_ycorr = y0 * correction;
                y1 = prod_ycorr >> FRAC;

                prod_my = m_int * y1;
                correction = ((1 << FRAC)*2) - (prod_my >> FRAC);
                prod_ycorr = y1 * correction;
                y2 = prod_ycorr >> FRAC;

                y_norm = y2;
                adj = 0;
                for (i = 0; i < M_WIDTH; i = i + 1) begin
                    if (y_norm == 0) begin
                        adj = 0;
                        i = M_WIDTH;
                    end else if (y_norm >= (1 << FRAC)) begin
                        i = M_WIDTH;
                    end else begin
                        y_norm = y_norm << 1;
                        adj = adj - 1;
                    end
                end

                exp_out_i = -exp_unbiased + BIAS + adj;

                if (exp_out_i >= ((1<<EXP)-1)) begin
                    out_exp = {EXP{1'b1}};
                    out_frac = 0;
                    except_flags[F_OVERFLOW] = 1'b1;
                end else if (exp_out_i <= 0) begin
                    out_exp = 0;
                    out_frac = 0;
                    except_flags[F_UNDERFLOW] = 1'b1;
                end else begin
                    out_exp = exp_out_i[EXP-1:0];
                    out_frac = y_norm[FRAC-1:0];
                    except_flags[F_INEXACT] = 1'b1;
                end

                out_bits = {out_sign, out_exp, out_frac};
            end
        end else begin
            out_bits = {out_sign, out_exp, out_frac};
        end
    end
endmodule

