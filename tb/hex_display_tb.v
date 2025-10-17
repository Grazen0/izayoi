`timescale 1ns / 1ps

module hex_display_tb ();
  reg clk, rst_n, enable;
  reg [15:0] data;

  always #5 clk = ~clk;

  wire [3:0] anode;
  wire [7:0] seg;

  hex_display display (
      .clk(clk),
      .rst_n(rst_n),
      .data(data),
      .enable(enable),
      .seg(seg),
      .anode(anode)
  );

  initial begin
    $dumpvars(0, hex_display_tb);

    clk = 1;
    rst_n = 0;
    data = 16'hAF64;
    enable = 1'b1;

    #5 rst_n = 1;

    #100 enable = 1'b0;

    #50 enable = 1'b1;

    #60 $finish();
  end
endmodule
