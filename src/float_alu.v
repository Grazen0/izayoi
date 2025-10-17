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
  localparam OP_ADD = 3'b000;
  localparam OP_SUB = 3'b001;
  localparam OP_MUL = 3'b010;
  localparam OP_DIV = 3'b100;

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
      .start(start && (op_code == OP_ADD || op_code == OP_SUB)),
      .ready_in(ready_in || (op_code != OP_ADD && op_code != OP_SUB)),

      .valid_out(adder_valid),
      .ready_out(adder_ready),
      .result(adder_result),
      .flags(adder_flags)
  );

  always @(*) begin
    case (op_code)
      OP_ADD: begin
        valid_out = adder_valid;
        ready_out = adder_ready;
        result = adder_result;
        flags = adder_flags;
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

