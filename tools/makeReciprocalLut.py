# Genera X0.hex y X0.v para el módulo de aproximación inicial (LUT) del reciprocal.

# --- CONFIGURACIÓN ---
N_INPUT_BITS = 10
N_LUT_BITS = 7
HEX_FILE = "X0.hex"

# --- GENERAR VALORES DEL LUT ---
# Calcula el recíproco de 1.x (en binario) → almacena los 7 bits más altos
r = [((1 << 18) // x) & ((1 << N_LUT_BITS) - 1)
     for x in range(0b1_0000000000, 0b10_0000000000)]

# --- GUARDAR ARCHIVO HEX ---
with open(HEX_FILE, "w") as f:
    for val in r:
        f.write(f"{val:02X}\n")

print(f"✅ Archivo {HEX_FILE} generado con {len(r)} entradas ({N_LUT_BITS} bits cada una).")

