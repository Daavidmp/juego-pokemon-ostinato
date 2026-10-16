import numpy as np
from PIL import Image
D = "/mnt/c/Users/david.martinez/Downloads/entrenadores_tunel/"
G = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/Pokémon Ostinato/Graphics/Characters/"
def nativo(path):
    a = np.array(Image.open(path).convert("RGB")).astype(float)
    best = None
    for o in range(8):
        c = a[o + 4::8, o + 4::8][:128, :128]
        c2 = a[o + 5::8, o + 5::8][:128, :128]
        e = np.abs(c[:c2.shape[0], :c2.shape[1]] - c2).mean()
        if best is None or e < best[0]: best = (e, o)
    o = best[1]
    c = a[o + 4::8, o + 4::8][:128, :128]
    if c.shape[0] < 128 or c.shape[1] < 128:      # al borde le falta una fila: se repite la del fondo
        c = np.pad(c, ((0, 128 - c.shape[0]), (0, 128 - c.shape[1]), (0, 0)), mode="edge")
    return c.astype(np.uint8)
def sin_verde(c):
    x = c.astype(int)
    fondo = (x[..., 1] > x[..., 0] + 25) & (x[..., 1] > x[..., 2] + 15) & (x[..., 1] > 150)
    return np.dstack([c, np.where(fondo, 0, 255)]).astype(np.uint8)
def celda(a, f, c): return a[f * 32:(f + 1) * 32, c * 32:(c + 1) * 32]
def parecido(x, y):
    m = (x[..., 3] > 0) | (y[..., 3] > 0)
    return -np.abs(x[..., :3].astype(int) - y[..., :3].astype(int))[m].mean() - 40 * np.abs((x[..., 3] > 0).astype(int) - (y[..., 3] > 0))[m].mean()
for n in ["espeleologa", "operario_tunel", "fotografo", "campista_chico", "campista_chica", "chaval_linterna", "montanero_veterano"]:
    a = sin_verde(nativo(D + n + "_mapa.png"))
    if n == "chaval_linterna":
        # Firefly le cambia la linterna de mano entre pasos: se rehacen las filas con los cuadros que cuadran
        orig = a.copy()
        def pon(f, cuadros):
            for col, (ff, cc) in enumerate(cuadros): a[f * 32:(f + 1) * 32, col * 32:(col + 1) * 32] = celda(orig, ff, cc)
        pon(0, [(0, 0), (0, 3), (0, 0), (0, 3)])
        pon(1, [(1, 0), (1, 2), (1, 0), (1, 3)])
    # fila 3 (derecha): si se parece mas a la fila 2 tal cual que a la fila 2 en espejo, es que mira a la izquierda
    r2 = celda(a, 1, 0); r3 = celda(a, 2, 0)
    igual, espejo = parecido(r3, r2), parecido(r3, r2[:, ::-1])
    arreglo = ""
    if igual > espejo:
        for col in range(4): a[64:96, col * 32:(col + 1) * 32] = celda(a, 1, col)[:, ::-1]
        arreglo = " (fila derecha rehecha en espejo)"
    Image.fromarray(a, "RGBA").resize((256, 256), Image.NEAREST).save(G + n + ".png")
    print(n, "derecha: igual %.1f espejo %.1f" % (igual, espejo) + arreglo)
