module hex_to_7_segment (
    input  wire [3:0] digit,
    output reg  [7:0] seg
);
  always @(*)
    case (digit)
      4'h0: seg <= 8'b0000_0011;
      4'h1: seg <= 8'b1001_1111;
      4'h2: seg <= 8'b0010_0101;
      4'h3: seg <= 8'b0000_1101;
      4'h4: seg <= 8'b1001_1001;
      4'h5: seg <= 8'b0100_1001;
      4'h6: seg <= 8'b0100_0001;
      4'h7: seg <= 8'b0001_1111;
      4'h8: seg <= 8'b0000_0001;
      4'h9: seg <= 8'b0000_1001;
      4'hA: seg <= 8'b0001_0001;
      4'hB: seg <= 8'b1100_0001;
      4'hC: seg <= 8'b0110_0011;
      4'hD: seg <= 8'b1000_0101;
      4'hE: seg <= 8'b0110_0001;
      4'hF: seg <= 8'b0111_0001;
    endcase
endmodule

module h_fsm (
    input wire clk,
    input wire rst_n,
    input wire [15:0] data,
    input wire enable,
    output reg [3:0] digit,
    output reg [3:0] anode
);
  reg [1:0] state;

  always @(posedge clk, negedge rst_n)
    if (!rst_n) state <= 2'b00;
    else state <= state + 1;

  always @(*) begin
    digit = data[(state*4)+:4];

    if (enable) begin
      anode = ~(4'b0001 << state);
    end else begin
      anode = 4'b1111;
    end
  end
endmodule

module hex_display (
    input wire clk,
    input wire rst_n,
    input wire [15:0] data,
    input wire enable,
    output wire [3:0] anode,
    output wire [7:0] seg
);
  wire [3:0] digit;

  h_fsm h (
      .clk(clk),
      .rst_n(rst_n),
      .data(data),
      .enable(enable),
      .digit(digit),
      .anode(anode)
  );

  hex_to_7_segment h27 (
      .digit(digit),
      .seg  (seg)
  );
endmodule
