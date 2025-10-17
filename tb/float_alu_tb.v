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

  initial begin
    $dumpvars(0, float_alu_tb);

    clk   = 1;
    rst_n = 0;

    #5 rst_n = 1;

    $finish();
  end
endmodule
