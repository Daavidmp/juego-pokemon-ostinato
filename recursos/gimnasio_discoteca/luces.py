"""Maqueta en video de las luces de la discoteca (gimnasio 1) sobre sala_v8B_sin_taburetes.png.
   PYTHONPATH=<carpeta con imageio_ffmpeg> python3 luces.py <sala.png> <salida.mp4> [segundos] [--fotos carpeta]
Mismo modelo que las farolas de Villa Bambalina (007_Farolas.rb): la sala se oscurece con un tinte y encima se suma
luz de color. Aqui la luz ademas deja ver la sala por donde pasa (en el juego: un sprite de oscuridad al que se le
restan las luces).
  - ambiente: sala al 20 % con tinte morado de discoteca
  - fuentes que brillan solas: neones, pista (late al ritmo, cada baldosa a su paso), lamparas, pilotos del DJ
  - 6 focos de la tarima: haz de color que barre la sala y charco de luz en el suelo; el color va rotando
  - bola de espejos: gira (sus facetas se desplazan) y lanza puntos de luz que dan vueltas por toda la sala
Todo en coordenadas de la imagen de 2400x1792; el video sale a la mitad (1200x896), 24 fps.
"""
import math
import subprocess
import sys

import imageio_ffmpeg
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
SEG = float(sys.argv[3]) if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else 10.0
FOTOS = sys.argv[sys.argv.index("--fotos") + 1] if "--fotos" in sys.argv else None
K = 0.5                                    # escala del video
FPS = 24

img = Image.open(SRC).convert("RGB")
W, H = int(img.width * K), int(img.height * K)

# --- los 6 focos de la tarima pasan a ser sprites que giran hacia su haz ---
# Se buscan en la imagen grande (gris oscuro sobre la madera naranja), se recortan con su forma y se tapa su sitio
# con la madera de la misma fila un poco a la derecha (las tablas son horizontales: no se nota).
FOCOS = [(735, 645), (905, 645), (1025, 645), (1380, 645), (1500, 645), (1670, 645)]
grande = np.asarray(img).astype(np.int32)
g_mx, g_mn = grande.max(axis=2), grande.min(axis=2)
g_sat = (g_mx - g_mn) / np.maximum(g_mx, 1)
tapada = grande.copy()
SPRITES = []                                             # (sprite RGBA a escala K, pivote x, y, lente x, y) en px del video
for fx, fy in FOCOS:
    x0, x1, y0, y1 = fx - 55, fx + 75, 590, 688
    m = ((g_sat[y0:y1, x0:x1] < 0.42) & (g_mx[y0:y1, x0:x1] < 200)) | (g_mx[y0:y1, x0:x1] < 62)   # con su contorno oscuro
    for _ in range(2):                                                                     # 2 px de margen
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    ys, xs = np.nonzero(m)
    bx0, bx1, by0, by1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    rgba = np.zeros((by1 - by0, bx1 - bx0, 4), np.uint8)
    rgba[..., :3] = grande[y0 + by0:y0 + by1, x0 + bx0:x0 + bx1]
    rgba[..., 3] = m[by0:by1, bx0:bx1] * 255
    # de donde se copia la madera: el desplazamiento cuya zona sea toda madera (naranja), sin otro foco ni cables
    ancho_ = (bx1 - bx0) + 8
    def suciedad(d):
        z = (slice(y0 + by0, y0 + by1), slice(x0 + bx0 + d, x0 + bx1 + d))
        return ((g_sat[z] < 0.42) | (g_mx[z] < 62)).sum()
    dx = min((ancho_, -ancho_, 2 * ancho_, -2 * ancho_), key=suciedad)
    for yy_, xx_ in zip(ys, xs):
        tapada[y0 + yy_, x0 + xx_] = grande[y0 + yy_, x0 + xx_ + dx]
    spr = Image.fromarray(rgba, "RGBA")
    spr = spr.resize((max(1, int(spr.width * K)), max(1, int(spr.height * K))), Image.LANCZOS)
    piv = ((x0 + (bx0 + bx1) / 2) * K, (y0 + by1) * K)                               # abajo en el centro
    lente = ((x0 + bx0 + 0.28 * (bx1 - bx0)) * K, (y0 + by0 + 0.62 * (by1 - by0)) * K)  # la lente, abajo a la izquierda
    SPRITES.append((spr, piv, lente))
img = Image.fromarray(tapada.astype(np.uint8))
base = np.asarray(img.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255.0
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

# --- que brilla solo: saturado y claro, fuera del telon dorado (ese solo brilla si le da un foco) ---
mx, mn = base.max(axis=2), base.min(axis=2)
sat = (mx - mn) / np.maximum(mx, 1e-3)
# solo brillan solos: los neones de la pared del fondo, las lamparas (blanco) y la pista entera.
# (con un umbral de color tambien brillaban taburetes, sofas y la madera, que son rojos y naranjas intensos)
neon = (yy < 215 * K) & (xx > 200 * K) & (xx < 2200 * K) & (sat > 0.45) & (mx > 0.6)   # sin los postes del marco
blanco = (mx > 0.85) & (sat < 0.25)                               # lamparas
PISTA = (846 * K, 984 * K, 1572 * K, 1452 * K)                    # x0, y0, x1, y1 de la pista de colores (dentro del marco)
en_pista = (xx > PISTA[0]) & (xx < PISTA[2]) & (yy > PISTA[1]) & (yy < PISTA[3])
emis = (neon | blanco | en_pista).astype(np.float32)
# cada baldosa de la pista (4x3) late con su propio paso
bx = np.clip(((xx - PISTA[0]) / (PISTA[2] - PISTA[0]) * 4).astype(int), 0, 3)
by = np.clip(((yy - PISTA[1]) / (PISTA[3] - PISTA[1]) * 3).astype(int), 0, 2)
fase_baldosa = ((bx * 7 + by * 13) % 12) / 12.0 * 2 * math.pi

AMB = np.array([0.20, 0.15, 0.27], np.float32)                    # ambiente: oscuro y morado
# lamparas de los sofas (x, y, radio de su luz) en la imagen grande: las de la mesa alumbran mas que las de pared
LAMPARAS = [(2108, 548, 175), (2106, 994, 175), (2108, 1440, 175), (2292, 340, 130), (2294, 782, 130), (2295, 1230, 130)]
CALIDA = np.array([1.0, 0.72, 0.42], np.float32)
luz_lamparas = np.zeros((H, W), np.float32)
brillo_lamparas = np.zeros((H, W), np.float32)
for lx, ly, lr in LAMPARAS:
    d2 = (xx - lx * K) ** 2 + ((yy - ly * K) * 1.15) ** 2
    luz_lamparas += np.exp(-d2 / (lr * K) ** 2) * 0.95
    brillo_lamparas += np.exp(-d2 / (14 * K) ** 2)

# --- colores de los focos ---
COLORES = np.array([[1.0, 0.25, 0.45], [0.3, 0.55, 1.0], [1.0, 0.85, 0.25], [0.35, 1.0, 0.55],
                    [0.85, 0.3, 1.0], [0.25, 0.95, 1.0]], np.float32)

# --- bola: se busca en la imagen (gris claro sin color cerca del centro de la pista) ---
ventana = (slice(int(880 * K), int(1150 * K)), slice(int(1080 * K), int(1340 * K)))
gris = (sat[ventana] < 0.12) & (mx[ventana] > 0.55)
filas = np.nonzero(gris.sum(axis=1) > 6)[0]                      # el cable es fino: no llega a 6 pixeles por fila
gris[:filas.min()] = False
gy, gx = np.nonzero(gris)
BOLA_X = (gx.min() + gx.max()) / 2 + ventana[1].start
BOLA_Y = (gy.min() + gy.max()) / 2 + ventana[0].start
BOLA_R = max(gx.max() - gx.min(), gy.max() - gy.min()) / 2
print(f"bola en {BOLA_X / K:.0f},{BOLA_Y / K:.0f} radio {BOLA_R / K:.0f} (imagen grande)")
dentro_bola = (xx - BOLA_X) ** 2 + (yy - BOLA_Y) ** 2 < BOLA_R ** 2
FACETA = 3.0 * (W / 1200)                                         # tamano de faceta (px del video)
fase_faceta = ((np.floor(xx / FACETA) * 7.31 + np.floor(yy / FACETA) * 3.17) % 6.283).astype(np.float32)
rng = np.random.default_rng(7)
N_PUNTOS = 90
p_ang = rng.uniform(0, 2 * math.pi, N_PUNTOS)
p_rad = np.sqrt(rng.uniform(0.04, 1.0, N_PUNTOS))                 # repartidos por toda la sala
p_tam = rng.uniform(2.2, 4.0, N_PUNTOS) * (W / 1200)
p_col = np.where(rng.uniform(size=(N_PUNTOS, 1)) < 0.75, 1.0, rng.uniform(0.5, 1.0, (N_PUNTOS, 3))).astype(np.float32)


def haz(px, py, tx, ty, ancho_lente, ancho_charco):
    """intensidad de un haz de la lente (px,py) al charco (tx,ty): cono suave + charco brillante"""
    vx, vy = tx - px, ty - py
    largo2 = vx * vx + vy * vy
    t = np.clip(((xx - px) * vx + (yy - py) * vy) / largo2, 0, 1)
    cx, cy = px + t * vx, py + t * vy
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    ancho = ancho_lente + (ancho_charco - ancho_lente) * t
    cono = np.exp(-(d / ancho) ** 2) * (0.26 + 0.24 * t)
    charco = np.exp(-(((xx - tx) / (ancho_charco * 1.25)) ** 2 + ((yy - ty) / ancho_charco) ** 2)) * 0.95
    return np.maximum(cono, charco)


def fotograma(f):
    s = f / FPS
    luz = np.zeros((H, W, 3), np.float32)
    # lamparas calidas (un parpadeo muy leve, como una bombilla)
    luz += (luz_lamparas * (0.96 + 0.04 * math.sin(s * 13.0)))[..., None] * CALIDA
    # focos que barren (cada uno con su ritmo); el color salta cada 2 s al siguiente de la lista.
    # El aparato gira hacia su charco (como mucho unos 25 grados) y el haz sale de la lente ya girada.
    giros = []
    for i, (spr, (pvx, pvy), (lnx, lny)) in enumerate(SPRITES):
        tx = W * 0.5 + W * 0.32 * math.sin(0.55 * s + i * 1.1) * (1 if i % 2 else -1)
        ty = H * 0.62 + H * 0.2 * math.sin(0.8 * s + i * 0.7)
        base_ang = math.atan2(lny - pvy, lnx - pvx)
        ang = math.atan2(ty - pvy, tx - pvx) - base_ang
        ang = (ang + math.pi) % (2 * math.pi) - math.pi
        ang = max(-0.45, min(0.45, ang * 0.6))                # gira poco y suave hacia su charco
        c, sn = math.cos(ang), math.sin(ang)
        ox = pvx + (lnx - pvx) * c - (lny - pvy) * sn
        oy = pvy + (lnx - pvx) * sn + (lny - pvy) * c
        col = COLORES[(i + int(s / 2)) % len(COLORES)]
        luz += haz(ox, oy, tx, ty, 6 * K, 95 * K)[..., None] * col
        giros.append((spr, pvx, pvy, ang, ox, oy, col))
    # puntos de la bola girando por la sala
    giro = 0.35 * s
    for k in range(N_PUNTOS):
        a = p_ang[k] + giro
        px = BOLA_X + math.cos(a) * p_rad[k] * W * 0.55
        py = BOLA_Y + math.sin(a) * p_rad[k] * H * 0.48
        r = p_tam[k]
        x0, x1 = int(max(px - 4 * r, 0)), int(min(px + 4 * r, W))
        y0, y1 = int(max(py - 4 * r, 0)), int(min(py + 4 * r, H))
        if x0 >= x1 or y0 >= y1:
            continue
        g = np.exp(-(((xx[y0:y1, x0:x1] - px) ** 2 + (yy[y0:y1, x0:x1] - py) ** 2) / (r * r)))
        luz[y0:y1, x0:x1] += g[..., None] * p_col[k] * 0.9
    # sala: ambiente + lo que alumbran las luces + un poco de brillo de la propia luz (haze)
    out = base * (AMB + luz * 1.1) + luz * 0.06
    # lo que brilla solo; la pista late a 2 golpes por segundo, cada baldosa a su paso
    pulso = np.where(en_pista, 0.55 + 0.45 * (0.5 + 0.5 * np.sin(2 * math.pi * 2 * s + fase_baldosa)), 0.95)
    out = np.where(emis[..., None] > 0, np.maximum(out, base * pulso[..., None]), out)
    # lamparas: la pantalla brilla
    out += brillo_lamparas[..., None] * CALIDA * 0.5
    # los focos encima, girados sobre su pie, con la luz que les llega y la lente encendida
    for spr, pvx, pvy, ang, ox, oy, col in giros:
        pad = 30
        lienzo = Image.new("RGBA", (spr.width + 2 * pad, spr.height + 2 * pad))
        lienzo.paste(spr, (pad, pad))
        cx_, cy_ = pad + spr.width / 2, pad + spr.height
        rot = np.asarray(lienzo.rotate(-math.degrees(ang), resample=Image.BICUBIC, center=(cx_, cy_))).astype(np.float32) / 255
        X0, Y0 = int(round(pvx - cx_)), int(round(pvy - cy_))
        hh, ww = rot.shape[:2]
        ya, yb, xa, xb = max(Y0, 0), min(Y0 + hh, H), max(X0, 0), min(X0 + ww, W)
        r = rot[ya - Y0:yb - Y0, xa - X0:xb - X0]
        tono = AMB + luz[int(pvy) - 2, int(pvx)] * 0.6 + 0.12
        a = r[..., 3:4]
        out[ya:yb, xa:xb] = out[ya:yb, xa:xb] * (1 - a) + r[..., :3] * tono * a
        g = np.exp(-(((xx - ox) ** 2 + (yy - oy) ** 2) / (5 * K * 2) ** 2))
        out += g[..., None] * col * 0.9
    # bola: no se mueven sus pixeles (se deformaba). Gira con una franja de brillo que la cruza de izquierda a
    # derecha (una vuelta cada 2,5 s) y facetas que parpadean cada una a su paso
    franja_x = BOLA_X - BOLA_R + ((s / 2.5) % 1.0) * 2 * BOLA_R
    franja = 0.45 * np.exp(-((xx - franja_x) / (BOLA_R * 0.35)) ** 2)
    parpadeo = 0.18 * np.sin(fase_faceta + s * 9.0)
    bola = base * (1.05 + parpadeo[..., None]) + franja[..., None]
    out = np.where(dentro_bola[..., None], bola, out)
    # destellos en la bola
    for k in range(3):
        a = 2.1 * s + k * 2.1
        gx_, gy_ = BOLA_X + math.cos(a) * BOLA_R * 0.55, BOLA_Y + math.sin(a * 0.7) * BOLA_R * 0.45
        g = np.exp(-(((xx - gx_) ** 2 + (yy - gy_) ** 2) / (2.5 * K * 4) ** 2))
        out += g[..., None] * (0.6 + 0.4 * math.sin(6 * s + k))
    return (np.clip(out, 0, 1) * 255).astype(np.uint8)


n = int(SEG * FPS)
cmd = [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
       "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium", OUT]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
for f in range(n):
    fr = fotograma(f)
    p.stdin.write(fr.tobytes())
    if FOTOS and f % (FPS * 2) == 0:
        Image.fromarray(fr).save(f"{FOTOS}/luces_{f // FPS:02d}s.png")
p.stdin.close()
p.wait()
print("video:", OUT, n, "fotogramas")
