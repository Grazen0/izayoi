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

`define INF 32'h7F80_0000
`define NEG_INF 32'hFF80_0000
`define NAN 32'h7FC0_0000

`define INF_H 32'h7C00
`define NEG_INF_H 32'hFC00
`define NAN_H 32'h7E00

`endif
