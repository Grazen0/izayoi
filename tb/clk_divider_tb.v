`timescale 1ns / 1ps

module clk_divider_tb ();
  reg clk_in, rst_n;
  wire clk_out_1, clk_out_2, clk_out_3;

  always #5 clk_in = ~clk_in;

  clk_divider d1 (
      .clk_in (clk_in),
      .rst_n  (rst_n),
      .clk_out(clk_out_1)
  );

  clk_divider #(
      .PERIOD(6)
  ) d2 (
      .clk_in (clk_in),
      .rst_n  (rst_n),
      .clk_out(clk_out_2)
  );

  clk_divider #(
      .PERIOD(10)
  ) d3 (
      .clk_in (clk_in),
      .rst_n  (rst_n),
      .clk_out(clk_out_3)
  );

  initial begin
    $dumpvars(0, clk_divider_tb);

    clk_in = 0;
    rst_n  = 0;
    #1 rst_n = 1;

    #150 $finish();
  end
endmodule
