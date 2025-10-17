`ifndef IZAYOI_MACROS_VH
`define IZAYOI_MACROS_VH

`define OP_ADD 3'b000
`define OP_SUB 3'b001
`define OP_MUL 3'b010
`define OP_DIV 3'b100

`define F_INEXACT 0
`define F_UNDERFLOW 1
`define F_OVERFLOW 2
`define F_DIVIDE_BY_ZERO 3
`define F_INVALID 4

`define FP_HALF 0
`define FP_SINGLE 1

`endif
