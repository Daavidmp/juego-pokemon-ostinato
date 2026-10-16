# Dibujos de combate de los entrenadores del tunel: a su rejilla, sin fondo, a la altura del resto
# (figura de ~125 px como SECUAZ/LIRA) reduciendo con la paleta del propio dibujo (sin colores nuevos)
import numpy as np
from PIL import Image
D = "/mnt/c/Users/david.martinez/Downloads/entrenadores_tunel/"
G = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/Pokémon Ostinato/Graphics/"
ALTO = 124
def nativo(path, p):
    im = Image.open(path).convert("RGB"); a = np.array(im).astype(float)
    best = None
    for ox in np.arange(0, p, 0.5):
        for oy in np.arange(0, p, 0.5):
            ys = np.arange(oy + p / 2, a.shape[0], p).astype(int); xs = np.arange(ox + p / 2, a.shape[1], p).astype(int)
            # celdas uniformes: el centro se parece a sus vecinos de la misma celda
            c = a[ys][:, xs]; c2 = a[np.clip(ys + int(p / 4), 0, a.shape[0] - 1)][:, np.clip(xs + int(p / 4), 0, a.shape[1] - 1)]
            e = np.abs(c - c2).mean()
            if best is None or e < best[0]: best = (e, c)
    return best[1].astype(np.uint8)
def sin_fondo(c):
    blanco = c.min(axis=2) > 232
    # solo el blanco conectado al borde es fondo (los blancos de dentro se quedan)
    from collections import deque
    H, W = blanco.shape; fondo = np.zeros_like(blanco); q = deque()
    for x in range(W):
        for y in (0, H - 1):
            if blanco[y, x]: fondo[y, x] = True; q.append((y, x))
    for y in range(H):
        for x in (0, W - 1):
            if blanco[y, x] and not fondo[y, x]: fondo[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and blanco[ny, nx] and not fondo[ny, nx]: fondo[ny, nx] = True; q.append((ny, nx))
    return np.dstack([c, np.where(fondo, 0, 255)]).astype(np.uint8)
def reducir(rgba, alto):
    # cada pixel nuevo = el color que mas se repite en su trozo del original (no inventa colores ni mezcla)
    ys, xs = np.where(rgba[..., 3] > 0); rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = rgba.shape[:2]
    if h <= alto: return rgba
    k = h / alto; nw = max(1, round(w / k))
    out = np.zeros((alto, nw, 4), np.uint8)
    for j in range(alto):
        y0, y1 = int(j * k), max(int((j + 1) * k), int(j * k) + 1)
        for i in range(nw):
            x0, x1 = int(i * k), max(int((i + 1) * k), int(i * k) + 1)
            trozo = rgba[y0:y1, x0:x1].reshape(-1, 4)
            op = trozo[trozo[:, 3] > 0]
            if len(op) * 2 < len(trozo): continue
            col, n = np.unique(op[:, :3], axis=0, return_counts=True)
            # a igualdad, el mas oscuro: asi el contorno no se pierde
            orden = sorted(range(len(col)), key=lambda t: (-n[t], int(col[t].sum())))
            out[j, i, :3] = col[orden[0]]; out[j, i, 3] = 255
    return out
def lienzo(fig, ancho):
    h, w = fig.shape[:2]; c = np.zeros((144, max(ancho, w + 4), 4), np.uint8)
    x = (c.shape[1] - w) // 2; y = 142 - h
    c[y:y + h, x:x + w] = fig
    return c
P = {"espeleologa": ("ESPELEOLOGA", 6.0), "operario_tunel": ("OPERARIO_TUNEL", 5.12), "fotografo": ("FOTOGRAFO", 7.5),
     "campistas": ("HERMANOS_CAMPISTAS", 6.0), "chaval_linterna": ("CHAVAL_LINTERNA", 6.0), "montanero_veterano": ("MONTANERO_VETERANO", 6.0)}
hoja = []
for n, (tipo, p) in P.items():
    c = nativo(D + n + "_combate.png", p)
    if n == "chaval_linterna":       # fuera el charco: de la fila 166 abajo solo quedan las dos botas
        for y in range(166, c.shape[0]):
            for x in range(c.shape[1]):
                if y >= 189 or not (52 <= x <= 69 or 79 <= x <= 98):
                    c[y, x] = 255
    rgba = sin_fondo(c)
    fig = reducir(rgba, ALTO if n != "montanero_veterano" else ALTO + 4)
    out = lienzo(fig, 208 if n == "campistas" else 128)
    Image.fromarray(out, "RGBA").save(G + "Trainers/%s.png" % tipo)
    hoja.append((tipo, out))
    print(tipo, "nativo", c.shape[1], "x", c.shape[0], "->", out.shape[1], "x", out.shape[0])
W = sum(o.shape[1] for _, o in hoja) + 10 * len(hoja)
can = Image.new("RGBA", (W, 150), (210, 210, 220, 255)); x = 0
for _, o in hoja: can.alpha_composite(Image.fromarray(o, "RGBA"), (x, 3)); x += o.shape[1] + 10
can.resize((can.width * 3, can.height * 3), Image.NEAREST).save("trainers_hoja.png")
