`timescale 1ns / 1ps

module top_tb ();
  reg clk, rst;
  reg  [15:0] sw;

  wire [15:0] led;

  top t (
      .clk(clk),
      .rst(rst),
      .sw (sw),
      .led(led)
  );

  always #5 clk = ~clk;

  initial begin
    $dumpvars(0, top_tb);

    clk = 1;
    rst = 1;

    #5 rst = 0;

    // 5.25 + 18.5 = 41BE_0000 (23.75)

    // op_a = 0x40A8_0000
    sw = 16'b0000_0000_0000_0000;
    #10;
    sw = 16'b0100_0000_1010_1000;
    #10;

    // op_b = 0x4194_0000
    sw = 16'b0000_0000_0000_0000;
    #10;
    sw = 16'b0100_0001_1001_0100;
    #10;

    // op_code = 0b000, mode_fp = 1, round_mode = 0
    sw = 16'b0000_0000_0000_1000;

    #120 $finish();
  end
endmodule
