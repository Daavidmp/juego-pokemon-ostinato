# -*- coding: utf-8 -*-
"""Prepara las piezas de la obra «La plaza callada» (025_ObraTeatro.rb).

Entrada: Descargas/obra/*_nat.png (lo de Firefly ya pasado a su rejilla de
pixel con rejilla.py y sin fondo con fondo.py).
Salida: Graphics/Titles/Obra/ del juego.

  python3 construir.py

El mundo de la obra mide 1920x1080 (el escenario a pantalla completa). Cada
pieza se amplia aqui con vecino mas cercano a su tamano en ese mundo, y la
camara del juego solo la acerca un poco mas (zoom de 1 a 1,8).
Imprime al final las medidas que usa el script de Ruby (anclas de los faroles).
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from fondo import quitar_sueltos

DESC = os.path.expanduser("/mnt/c/Users/david.martinez/Downloads/obra/")
JUEGO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Pokémon Ostinato")
SAL = os.path.join(JUEGO, "Graphics", "Titles", "Obra")
os.makedirs(SAL, exist_ok=True)

Y = 9.0                      # pixel de escenario -> pixel del mundo (en alto)

def cargar(n):
    return np.array(Image.open(DESC + n).convert("RGBA"))

def guardar(a, n):
    Image.fromarray(a.astype(np.uint8), "RGBA").save(os.path.join(SAL, n))

def ampliar(a, k):
    im = Image.fromarray(a.astype(np.uint8), "RGBA")
    return np.array(im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.NEAREST))

#--- el escenario -----------------------------------------------------------
esc = np.array(Image.open(DESC + "escenario_nat.png").convert("RGB"))
H, W = esc.shape[:2]
muestra = esc[:, 40:52].copy()          # tablas de la cara entre dos candilejas
for y in range(101, H):                  # tapa el canto en diagonal de las esquinas
    for x in range(0, 29):
        esc[y, x] = muestra[y, x % 12]
    for x in range(W - 29, W):
        esc[y, x] = muestra[y, (W - 1 - x) % 12]
Image.fromarray(esc).resize((1920, 1080), Image.NEAREST).save(os.path.join(SAL, "escenario.png"))

#--- los personajes ---------------------------------------------------------
# hoja, fila (y0, y1), columnas de cada pose, pose quieta, alto en el escenario
PJ = {
    "narradora": ("narradora_poses_nat.png", (0, 71), [(1, 23), (31, 53), (56, 74), (80, 98)], 3, 27),
    "panadero":  ("panadero_poses_nat.png", (0, 54), [(8, 40), (54, 93), (103, 135), (146, 182)], 0, 27),
    "vecina":    ("vecina_poses_nat.png", (0, 66), [(5, 25), (29, 53), (57, 86), (86, 119)], 0, 26),
    "nino":      ("nino_obra_poses_nat.png", (0, 73), [(3, 49), (57, 91), (100, 139), (145, 189), (196, 234)], 0, 21),
    "luz":       ("luz_poses_nat.png", (0, 134), [(2, 56), (62, 116), (121, 177), (183, 235)], 0, 27),
    "senora":    ("senora_negro_poses_nat.png", (0, 67), [(8, 48), (66, 106), (121, 167), (176, 231)], 0, 25),
}
medidas = {}

def figuras(nombre):
    hoja, (y0, y1), cols, quieta, alto = PJ[nombre]
    a = cargar(hoja)[y0:y1]
    figs = []
    for (c0, c1) in cols:
        f = a[:, c0:c1].copy()
        quitar_sueltos(f, 25)          # puntas de la pose de al lado
        al = f[..., 3] > 0
        ys = np.where(al.any(axis=1))[0]; xs = np.where(al.any(axis=0))[0]
        f = f[ys[0]:ys[-1] + 1, xs[0]:xs[-1] + 1]
        # el centro de los pies: las 4 filas de abajo
        pies = np.where((f[-4:, :, 3] > 0).any(axis=0))[0]
        figs.append((f, (pies[0] + pies[-1] + 1) / 2.0, (c0 + xs[0], y0 + ys[0])))
    k = Y * alto / figs[quieta][0].shape[0]
    return figs, k

def tira(nombre, figs, k, sufijo=""):
    # todas las poses en celdas iguales, con los pies en el centro de abajo
    izq = max(px for f, px, _ in figs); der = max(f.shape[1] - px for f, px, _ in figs)
    alto = max(f.shape[0] for f, _, _ in figs)
    cw = int(2 * max(izq, der)) + 2
    celdas = []
    for f, px, _ in figs:
        c = np.zeros((alto, cw, 4), np.uint8)
        x = int(round(cw / 2 - px)); y = alto - f.shape[0]
        c[y:y + f.shape[0], x:x + f.shape[1]] = f
        celdas.append(c)
    t = ampliar(np.concatenate(celdas, axis=1), k)
    guardar(t, nombre + sufijo + ".png")
    return cw, alto

for nombre in PJ:
    figs, k = figuras(nombre)
    cw, alto = tira(nombre, figs, k)
    medidas[nombre] = (len(figs), k, cw, alto)

# las seis luces: el blanco puro del farol se pinta del color de cada una
COLORES = {"amarilla": (255, 214, 64), "roja": (236, 64, 56), "morada": (160, 92, 220),
           "rosa": (248, 132, 186), "verde": (88, 206, 100), "azul": (76, 146, 240)}
figs, k = figuras("luz")
faroles = []
for f, px, _ in figs:
    m = (f[..., :3].min(axis=2) >= 245) & (f[..., 3] > 0)
    ys, xs = np.where(m)
    # del centro de la luz del farol a los pies, en pixeles del mundo
    faroles.append((round((xs.mean() + 0.5 - px) * k), round((ys.mean() + 0.5 - f.shape[0]) * k)))
for col, rgb in COLORES.items():
    teñidas = []
    for f, px, o in figs:
        g = f.copy()
        m = (g[..., :3].min(axis=2) >= 245) & (g[..., 3] > 0)
        # el color con un poco de su blanco en el centro, para que brille
        g[m, :3] = [min(255, int(c * 0.85 + 255 * 0.15)) for c in rgb]
        teñidas.append((g, px, o))
    tira("luz_" + col, teñidas, k)

# el farol que cuelga la senora: donde lo lleva en su pose 4 y su tamano
figs_s, ks = figuras("senora")
f4, px4, (ox4, oy4) = figs_s[3]
farol = cargar("farol_apagado_nat.png")
guardar(ampliar(farol, ks), "farol.png")
# el farol se recorto de (175, 38) de la hoja; su sitio respecto a los pies de la pose 4
fx = (175 + 1 + farol.shape[1] / 2.0) - ox4 - px4
fy = (38 + farol.shape[0]) - oy4 - f4.shape[0]
farol_senora = (round(fx * ks), round(fy * ks))

#--- atrezo -------------------------------------------------------------------
puesto = cargar("puesto_pan_nat.png"); guardar(ampliar(puesto, Y * 31 / puesto.shape[0]), "puesto.png")
arbol = cargar("arbol_carton_nat.png"); guardar(ampliar(arbol, Y * 38 / arbol.shape[0]), "arbol.png")

#--- notas musicales (dibujadas a pixel, blancas: el color lo pone el juego) ------
NOTAS = [
    ["....##.", "....#.#", "....#..", "....#..", "..###..", ".####..", ".###...", "......."],
    ["...#...", "...#...", "...#...", "...#...", ".###...", "####...", ".##....", "......."],
    ["..#####", "..#...#", "..#...#", "..#...#", "###.###", "##..##.", ".......", "......."],
]
celdas = []
for n in NOTAS:
    c = np.zeros((10, 9, 4), np.uint8)
    for y, fila in enumerate(n):
        for x, v in enumerate(fila):
            if v == "#":
                c[y + 1, x + 1] = (255, 255, 255, 255)
    # contorno oscuro de un pixel
    al = c[..., 3] > 0
    borde = np.zeros_like(al)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        borde |= np.roll(np.roll(al, dy, 0), dx, 1)
    c[borde & ~al] = (40, 30, 50, 255)
    celdas.append(c)
guardar(ampliar(np.concatenate(celdas, axis=1), 6), "notas.png")

#--- luz: el foco (negro con un hueco suave) y la banda de los subtitulos -----
foco = Image.new("L", (960, 540), 0)
d = ImageDraw.Draw(foco)
d.ellipse((480 - 62, 270 - 70, 480 + 62, 270 + 70), fill=255)
foco = foco.filter(ImageFilter.GaussianBlur(14))
negro = np.zeros((540, 960, 4), np.uint8); negro[..., 3] = 255 - np.array(foco)
guardar(negro, "foco.png")
banda = np.zeros((230, 1920, 4), np.uint8)
for y in range(230):
    banda[y, :, 3] = int(205 * min(1.0, y / 70.0))
banda[..., :3] = (12, 8, 16)
guardar(banda, "banda.png")

print("medidas (poses, escala, celda nativa):", medidas)
print("faroles de la luz (dx, dy desde los pies):", faroles)
print("farol de la senora (dx, dy desde los pies):", farol_senora)
for n in sorted(os.listdir(SAL)):
    print(" ", n, Image.open(os.path.join(SAL, n)).size)
