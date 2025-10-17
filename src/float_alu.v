`default_nettype none
`include "macros.vh"

module fp_decoder (
    input wire [2:0] op_code,
    input wire start,
    input wire ready_in,
    output wire adder_start,
    output wire adder_ready_in,
    output wire multiplier_start,
    output wire multiplier_ready_in,
    output wire divider_start,
    output wire divider_ready_in
);
    assign adder_start = start && (op_code == `OP_ADD || op_code == `OP_SUB);
    assign adder_ready_in = ready_in || (op_code != `OP_ADD && op_code != `OP_SUB);

    assign multiplier_start = start && op_code == `OP_MUL;
    assign multiplier_ready_in = ready_in || op_code != `OP_MUL;

    assign divider_start = start && op_code == `OP_DIV;
    assign divider_ready_in = ready_in || op_code != `OP_DIV;
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
    output reg [N-1:0] result,
    output reg [4:0] flags
);
    wire adder_start, adder_ready_in, multiplier_start, multiplier_ready_in,
    divider_start, divider_ready_in;

    fp_decoder decoder (
        .op_code(op_code),
        .start(start),
        .ready_in(ready_in),
        .adder_start(adder_start),
        .adder_ready_in(adder_ready_in),
        .multiplier_start(multiplier_start),
        .multiplier_ready_in(multiplier_ready_in),
        .divider_start(divider_start),
        .divider_ready_in(divider_ready_in)
    );

    wire adder_valid, adder_ready;
    wire [N-1:0] adder_result;
    wire [  4:0] adder_flags;

    fp_adder adder (
        .clk(clk),
        .rst_n(rst_n),
        .op_a(op_a),
        .op_b(op_b),
        .mode_fp(mode_fp),
        .round_mode(round_mode),
        .sub(op_code[0]),
        .start(adder_start),
        .ready_in(adder_ready_in),

        .valid_out(adder_valid),
        .ready_out(adder_ready),
        .result(adder_result),
        .flags(adder_flags)
    );

    wire multiplier_valid, multiplier_ready;
    wire [N-1:0] multiplier_result;
    wire [  4:0] multiplier_flags;

    fp_multiplier multiplier (
        .clk(clk),
        .rst_n(rst_n),
        .op_a(op_a),
        .op_b(op_b),
        .mode_fp(mode_fp),
        .round_mode(round_mode),
        .start(multiplier_start),
        .ready_in(multiplier_ready_in),

        .valid_out(multiplier_valid),
        .ready_out(multiplier_ready),
        .result(multiplier_result),
        .flags(multiplier_flags)
    );

    always @(*) begin
        case (op_code)
            `OP_ADD, `OP_SUB: begin
                valid_out = adder_valid;
                ready_out = adder_ready;
                result = adder_result;
                flags = adder_flags;
            end
            `OP_MUL: begin
                valid_out = multiplier_valid;
                ready_out = multiplier_ready;
                result = multiplier_result;
                flags = multiplier_flags;
            end
            default: begin
                valid_out = 1'b0;
                ready_out = 1'b0;
                result = 32'b0;
                flags = 5'b0;
            end
        endcase
    end
endmodule

