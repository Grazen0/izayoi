# Genera X0.hex y X0.v para el módulo de aproximación inicial (LUT) del reciprocal.

# --- CONFIGURACIÓN ---
N_INPUT_BITS = 10
N_LUT_BITS = 7
HEX_FILE = "X0.hex"
V_FILE = "X0.v"

# --- GENERAR VALORES DEL LUT ---
# Calcula el recíproco de 1.x (en binario) → almacena los 7 bits más altos
r = [((1 << 18) // x) & ((1 << N_LUT_BITS) - 1)
     for x in range(0b1_0000000000, 0b10_0000000000)]

# --- GUARDAR ARCHIVO HEX ---
with open(HEX_FILE, "w") as f:
    for val in r:
        f.write(f"{val:02X}\n")

print(f"✅ Archivo {HEX_FILE} generado con {len(r)} entradas ({N_LUT_BITS} bits cada una).")

# --- GENERAR ARCHIVO VERILOG ---
verilog_code = f"""// X0.v
// LUT para aproximación inicial de 1/x (IEEE-754 compatible)
module X0 #(
    parameter NEXP = 5,
    parameter NSIG = 11
)(
    input  wire [{N_INPUT_BITS-1}:0] in,
    output wire [NSIG+1:0] out
);

  reg [{N_LUT_BITS-1}:0] ROM [0:{len(r)-1}];
  wire [{N_LUT_BITS-1}:0] seven;

  initial begin
    $readmemh("{HEX_FILE}", ROM);
  end

  assign seven = ROM[in];

  assign out = (in == 0)
      ? {{1'b1, seven, {{(NSIG-6){{1'b0}}}}}}
      : {{2'b01, seven, {{(NSIG-7){{1'b0}}}}}};

endmodule
"""

with open(V_FILE, "w") as f:
    f.write(verilog_code)

print(f"✅ Archivo {V_FILE} generado correctamente ({V_FILE}).")

