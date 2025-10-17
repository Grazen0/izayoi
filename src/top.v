// Módulo top para pruebas en la Basys 3
module top (
    input wire clk,
    input wire clk_ext,
    input wire rst,
    input wire [15:0] sw,

    output reg  [15:0] led,
    output wire [ 3:0] anode,
    output wire [ 7:0] seg
);
  localparam S_LOAD_A_LO = 10'd1 << 0;
  localparam S_LOAD_A_HI = 10'd1 << 1;
  localparam S_LOAD_B_LO = 10'd1 << 2;
  localparam S_LOAD_B_HI = 10'd1 << 3;
  localparam S_LOAD_CTRL = 10'd1 << 4;
  localparam S_START = 10'd1 << 5;
  localparam S_WAIT = 10'd1 << 6;
  localparam S_RESULT_LO = 10'd1 << 7;
  localparam S_RESULT_HI = 10'd1 << 8;

  reg [9:0] state, next_state;

  reg [31:0] op_a;
  reg [31:0] op_b;
  reg [2:0] op_code;
  reg mode_fp;
  reg round_mode;

  reg start;

  wire [31:0] result;
  wire [4:0] flags;
  wire valid_out;

  reg [31:0] result_reg;
  reg [4:0] flags_reg;

  wire clk_display;

  clk_divider #(
      .PERIOD(400_000)
  ) div (
      .clk_in (clk),
      .rst_n  (~rst),
      .clk_out(clk_display)
  );

  hex_display hd (
      .clk(clk_display),
      .rst_n(~rst),
      .data(state == S_RESULT_LO ? result_reg[15:0] : result_reg[31:16]),
      .enable(state == S_RESULT_HI || state == S_RESULT_LO),
      .anode(anode),
      .seg(seg)
  );

  fp_adder adder (
      .clk  (clk_ext),
      .rst_n(~rst),

      .op_a(op_a),
      .op_b(op_b),
      .op_code(op_code),
      .mode_fp(mode_fp),
      .round_mode(round_mode),
      .ready_in(1'b1),

      .start(start),
      .result(result),
      .valid_out(valid_out),
      .flags(flags)
  );

  always @(*) begin
    led = state;

    case (state)
      S_LOAD_A_LO: next_state = S_LOAD_A_HI;
      S_LOAD_A_HI: next_state = S_LOAD_B_LO;
      S_LOAD_B_LO: next_state = S_LOAD_B_HI;
      S_LOAD_B_HI: next_state = S_LOAD_CTRL;
      S_LOAD_CTRL: next_state = S_START;
      S_START: next_state = S_WAIT;
      S_WAIT: next_state = !valid_out ? S_WAIT : S_RESULT_LO;
      S_RESULT_LO: begin
        led[15:11] = flags_reg;
        next_state = S_RESULT_HI;
      end
      S_RESULT_HI: begin
        led[15:11] = flags_reg;
        next_state = S_RESULT_LO;
      end
      default: next_state = S_LOAD_A_LO;
    endcase
  end

  always @(posedge clk_ext or posedge rst) begin
    if (rst) begin
      state <= S_LOAD_A_LO;

      op_a <= 32'b0;
      op_b <= 32'b0;
      op_code <= 3'b0;
      mode_fp <= 1'b0;
      start <= 1'b0;
    end else begin
      if (valid_out) begin
        result_reg <= result;
        flags_reg  <= flags;
      end

      case (state)
        S_LOAD_A_LO: op_a[15:0] <= sw;
        S_LOAD_A_HI: op_a[31:16] <= sw;
        S_LOAD_B_LO: op_b[15:0] <= sw;
        S_LOAD_B_HI: op_b[31:16] <= sw;
        S_LOAD_CTRL: begin
          op_code <= sw[2:0];
          mode_fp <= sw[3];
          round_mode <= sw[4];

          start <= 1'b1;
        end
        S_START: start <= 1'b0;
      endcase

      state <= next_state;
    end
  end
endmodule
