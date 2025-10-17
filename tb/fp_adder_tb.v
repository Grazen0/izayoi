`timescale 1ns / 1ps

module fp_adder_tb ();
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

  // No es buena idea sintetizar esto, existe para propósitos de simulación.
  always @(posedge valid_out or posedge clk) begin
    if (valid_out) begin
      result_reg = result;
      flags_reg  = flags;

      $display("result: %h", result);
    end
  end

  fp_adder adder (
      .clk(clk),
      .rst_n(rst_n),
      .op_a(op_a),
      .op_b(op_b),
      .op_code(op_code),
      .mode_fp(mode_fp),
      .round_mode(round_mode),
      .start(start),
      .ready_in(1'b1),

      .valid_out(valid_out),
      .ready_out(ready_out),
      .result(result),
      .flags(flags)
  );

  initial begin
    $dumpvars(0, fp_adder_tb);

    clk   = 1;
    rst_n = 0;
    #3 rst_n = 1;

    // 2.2696568e38 + 1.6221822e-36 = 41B8_0000 (23.0)
    send_op_single(32'h7F2A_C000, 32'h040A_0000, 3'b000);
    // send_op_single(32'h41A6_0000, 32'h4010_0000, 3'b000);  // 20.75 + 2.25 = 41B8_0000 (23.0)
    // send_op_single(32'h4102_0000, 32'hC104_0000, 3'b000);  // 8.125 - 8.25 = BE00_0000 (-0.125)
    // send_op_single(32'h4160_0000, 32'hC144_0000, 3'b000);  // 14 - 12.25 = 3FE0_0000 (1.75)
    // send_op_single(32'h40A8_0000, 32'h4194_0000, 3'b000);  // 5.25 + 18.5 = 41BE_0000 (23.75)
    // send_op_single(32'h0000_0000, 32'h0000_0000, 3'b000);  // 0.0 + 0.0 = 0000_0000 (0.0)
    // send_op_single(32'h0000_0000, 32'h8000_0000, 3'b000);  // 0.0 - 0.0 = 0000_0000 (0.0)
    // send_op_single(32'h8000_0000, 32'h0000_0000, 3'b000);  // -0.0 + 0.0 = 8000_0000 (-0.0)
    // send_op_single(32'h8000_0000, 32'h8000_0000, 3'b000);  // -0.0 - 0.0 = 8000_0000 (-0.0)
    // send_op_single(32'h0000_0002, 32'h0000_0002, 3'b000);  // 1.0e-38 + 1.0e-38 = 0000_0004
    // send_op_single(32'h7F80_0000, 32'h7F80_0000, 3'b000);  // inf + inf = 7F80_0000 (inf)
    // send_op_single(32'h7F80_0000, 32'hFF80_0000, 3'b000);  // inf - inf = 7FC0_0000 (nan)
    //
    // send_op_half(16'h4680, 16'h4EB0, 3'b000);  // 6.5 + 26.75 = 5028 (33.25)
    // send_op_half(16'h3B00, 16'h5702, 3'b000);  // 0.875 + 112.125 = 5710 (113.0)
    // send_op_half(16'h0000, 16'h0000, 3'b000);  // 0.0 + 0.0 = 0000 (0.0) // TODO: never concludes

    #200 $finish();
  end

  task send_op_single(input reg [31:0] a, input reg [31:0] b, input reg [2:0] op);
    begin
      @(negedge clk);

      op_a = a;
      op_b = b;
      op_code = op;
      mode_fp = 1'b1;  // single
      round_mode = 1'b0;  // nearest even

      start = 1'b1;
      @(posedge clk);
      #2 start = 1'b0;

      while (!ready_out) @(posedge clk);
    end
  endtask

  task send_op_half(input reg [15:0] a, input reg [15:0] b, input reg [2:0] op);
    begin
      @(negedge clk);

      op_a = {16'b0, a};
      op_b = {16'b0, b};
      op_code = op;
      mode_fp = 1'b0;  // half
      round_mode = 1'b0;  // nearest even

      start = 1'b1;
      @(posedge clk);
      #2 start = 1'b0;

      while (!ready_out) @(posedge clk);
    end
  endtask
endmodule
