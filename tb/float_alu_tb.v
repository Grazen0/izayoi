module float_alu_tb ();
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

      $display("got result: %h", result);
    end
  end

  float_alu izayoi (
      .clk  (clk),
      .rst_n(rst_n),

      .op_a(op_a),
      .op_b(op_b),
      .op_code(op_code),
      .round_mode(round_mode),
      .mode_fp(mode_fp),
      .start(start),
      .ready_in(1'b1),

      .valid_out(valid_out),
      .ready_out(ready_out),
      .result(result),
      .flags(flags)
  );

  initial begin
    $dumpvars(0, float_alu_tb);

    clk   = 1;
    rst_n = 0;

    #3 rst_n = 1;

    send_op(32'h41A6_0000, 32'h4010_0000, 3'b010);  // 20.75 + 2.25 = 41B8_0000 (23.0)
    send_op(32'h4160_0000, 32'hC144_0000, 3'b010);  // 14 - 12.25 = 3FE0_0000 (1.75)
    send_op(32'h4102_0000, 32'hC104_0000, 3'b010);  // 8.125 - (-8.25) = 4183_0000 (16.375)
    send_op(32'h40A8_0000, 32'h4194_0000, 3'b010);  // 5.25 + 18.5 = 41BE_0000 (23.75)
    send_op(32'h4229_3333, 32'h4188_28F6, 3'b010);  // 42.3 - 17.02 = 41CA_3D70 (~25.27999)

    #100 $finish();
  end

  task send_op(input reg [31:0] a, input reg [31:0] b, input reg [2:0] op);
    begin
      op_a = a;
      op_b = b;
      op_code = op;
      round_mode = 1'b0;  // nearest even
      mode_fp = 1'b1;  // single

      start = 1'b1;
      @(posedge clk);
      #2 start = 1'b0;
      #1;

      while (!valid_out) begin
        @(posedge clk);
        #1;
      end
    end
  endtask
endmodule
