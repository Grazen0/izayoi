reg [7:0] ch;

task test(input reg [2:0] op, input reg [31:0] a, input reg [31:0] b, input reg [31:0] expected);
  begin
    op_a = a;
    op_b = b;
    op_code = op;

    start = 1'b1;
    @(posedge clk);
    #1 start = 1'b0;

    while (!valid_out) @(posedge clk);

    case (op)
      `OP_ADD: ch = "+";
      `OP_SUB: ch = "-";
      `OP_MUL: ch = "*";
      `OP_DIV: ch = "/";
      default: ch = "?";
    endcase

    if (result == expected) begin
      $display("[ CORRECT ]  %h %s %h = %h, flags = %b", a, ch, b, result, flags);
    end else begin
      $display("[INCORRECT]  %h %s %h = %h, flags = %b (got %h)", a, ch, b, expected, flags,
               result);
    end
  end
endtask
