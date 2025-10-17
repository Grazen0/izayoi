// X0.v
// LUT para aproximación inicial de 1/x (IEEE-754 compatible)
module X0 #(
    parameter NEXP = 5,
    parameter NSIG = 11
) (
    input wire [9:0] in,
    output wire [NSIG+1:0] out
);

  reg [6:0] ROM[0:1023];
  wire [6:0] seven;

  initial begin
    $readmemh("data/X0.hex", ROM);
  end

  assign seven = ROM[in];

  assign out = (in == 0) ? {1'b1, seven, {(NSIG - 6) {1'b0}}} : {2'b01, seven, {(NSIG - 7) {1'b0}}};

endmodule
