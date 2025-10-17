`timescale 1ns / 1ps

module top_tb ();
  reg clk, clk_ext, rst;
  reg  [15:0] sw;

  wire [15:0] led;
  wire [ 3:0] anode;
  wire [ 7:0] seg;

  always #1 clk = ~clk;
  always #5 clk_ext = ~clk_ext;

  top t (
      .clk(clk),
      .clk_ext(clk_ext),
      .rst(rst),
      .sw(sw),

      .led  (led),
      .anode(anode),
      .seg  (seg)
  );

  initial begin
    $dumpvars(0, top_tb);

    clk = 1;
    clk_ext = 1;
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
