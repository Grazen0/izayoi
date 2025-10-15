`timescale 1ns / 1ps

module float_alu_tb ();
  reg clk, rst_n, start;
  reg [31:0] op_a, op_b;
  reg [2:0] op_code;

  wire [31:0] result;
  wire valid_out;
  wire [4:0] flags;

  reg [31:0] result_reg;
  reg [4:0] flags_reg;

  always #5 clk = ~clk;

  float_alu alu (
      .clk(clk),
      .rst_n(rst_n),
      .op_a(op_a),
      .op_b(op_b),
      .op_code(op_code),
      .round_mode(1'b0),  // Nearest even
      .start(start),
      .result(result),
      .valid_out(valid_out),
      .flags(flags)
  );

  initial begin
    $dumpvars(0, float_alu_tb);

    clk   = 1;
    rst_n = 0;
    #3 rst_n = 1;

    send_op(32'h41A6_0000, 32'h4010_0000, 3'b000);  // 20.75 + 2.25 = 41B8_0000 (23.0)

    send_op(32'h4102_0000, 32'hC104_0000, 3'b000);  // 8.125 - 8.25 = BE00_0000 (-0.125)

    send_op(32'h4160_0000, 32'hC144_0000, 3'b000);  // 14 - 12.25 = 3FE0_0000 (1.75)

    send_op(32'h40A8_0000, 32'h4194_0000, 3'b000);  // 5.25 + 18.5 = 41BE_0000 (23.75)

    send_op(32'h40A8_0000, 32'h4194_0000, 3'b000);  // 5.25 + 18.5 = 41BE_0000 (23.75)

    send_op(32'h0000_0000, 32'h0000_0000, 3'b000);  // 0.0 + 0.0 = 0000_0000 (0.0)
    send_op(32'h0000_0000, 32'h8000_0000, 3'b000);  // 0.0 - 0.0 = 0000_0000 (0.0)
    send_op(32'h8000_0000, 32'h0000_0000, 3'b000);  // -0.0 + 0.0 = 8000_0000 (-0.0)
    send_op(32'h8000_0000, 32'h8000_0000, 3'b000);  // -0.0 - 0.0 = 8000_0000 (-0.0)

    send_op(32'h0000_0002, 32'h0000_0002, 3'b000);  // 1.0e-38 + 1.0e-38 = 0000_0004

    send_op(32'h7F80_0000, 32'h7F80_0000, 3'b000);  // inf + inf = 7F80_0000 (inf)

    send_op(32'h7F80_0000, 32'hFF80_0000, 3'b000);  // inf - inf = 7FC0_0000 (nan)

    // op_a = 32'b0_10000001_01010000000000000000000;  // 5.25
    // op_b = 32'b0_10000011_00101000000000000000000;  // 18.5
    // #10;

    #100 $finish();
  end

  task send_op(input [31:0] aval, input [31:0] bval, input [2:0] op);
    begin
      @(negedge clk);

      op_a = aval;
      op_b = bval;
      op_code = op;
      start = 1'b1;
      @(posedge clk);
      start = 1'b0;

      // Wait for valid_out
      while (!valid_out) @(posedge clk);

      result_reg = result;
      flags_reg  = flags;

      $display("a = %h, b = %h op=%0d  =>  result = %h", aval, bval, op_code, result);
    end
  endtask
endmodule
