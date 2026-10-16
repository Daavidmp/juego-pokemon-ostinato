# Simulacion (sin el motor) de 030_PokemonTunel en el mapa 18, con su misma logica
import math, subprocess, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg
J = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/"
GR = J + "Pokémon Ostinato/Graphics/"
mapa = Image.open(J + "recursos/tunel_partes3y4/mapa18_1376.png").convert("RGBA")
oscuro = Image.open(GR + "Pictures/Tunel/oscuro_18.png").convert("RGBA")
luz = Image.open(GR + "Pictures/Tunel/luz.png").convert("RGBA"); luz_fria = Image.open(GR + "Pictures/Tunel/luz_fria.png").convert("RGBA")
kaia = Image.open(GR + "Characters/kaia.png").convert("RGBA")
FOL = {n: Image.open(GR + "Characters/Followers/%s.png" % n).convert("RGBA") for n in ["WOOBAT", "GASTLY", "WOOPER"]}
G = open("paso18.txt").read().split("\n")
LAMPARAS = [[145, 48, 'c'], [752, 48, 'p'], [80, 370, 'c'], [400, 368, 'c'], [558, 302, 'c'], [815, 240, 'c'], [1103, 145, 'c'], [880, 592, 'f']]
VW, VH = 682, 384
FILA = {2: 0, 4: 1, 6: 2, 8: 3}
PASOS = {2: (0, 1), 4: (-1, 0), 6: (1, 0), 8: (0, -1)}
CERCA = 4
rnd = random.Random(4)

def libre(x, y): return 0 <= x < 43 and 0 <= y < 24 and G[y][x] == '.'

class Cosa:
    def __init__(s, x, y, img, frames_por_casilla):
        s.x, s.y = x, y; s.rx, s.ry = float(x), float(y); s.dir = 2; s.img = img; s.fpc = frames_por_casilla; s.t = 0; s.moviendo = False
    def mover(s, d):
        dx, dy = PASOS[d]; s.dir = d; s.x += dx; s.y += dy; s.moviendo = True
    def update(s):
        s.t += 1
        if s.moviendo:
            v = 1.0 / s.fpc
            s.rx += max(-v, min(v, s.x - s.rx)); s.ry += max(-v, min(v, s.y - s.ry))
            if abs(s.rx - s.x) < 1e-6 and abs(s.ry - s.y) < 1e-6: s.moviendo = False

k = Cosa(0, 17, kaia, 16)
ruta = [6, 6, 8, 8, 6, 6, 6, 6, 6, 6, 6]                 # entra por la via y sube al anden
pk = [  # especie, modo, aletea, x, y
    {"c": Cosa(9, 20, FOL["WOOBAT"], 16), "modo": "curioso", "vuela": True, "esp": "Woobat", "espera": 20, "alfa": 0},
    {"c": Cosa(12, 14, FOL["GASTLY"], 8), "modo": "agresivo", "vuela": True, "esp": "Gastly", "espera": 150, "alfa": 0},
]
for p in pk: G_ = None

def direcciones(p, ex, ey, px, py):
    al = list(PASOS); rnd.shuffle(al)
    if abs(ex - px) + abs(ey - py) > CERCA: return al
    hacia = sorted(PASOS, key=lambda d: abs(ex + PASOS[d][0] - px) + abs(ey + PASOS[d][1] - py))
    if p["modo"] == "miedoso": return hacia[::-1]
    if p["modo"] == "agresivo": return hacia
    return hacia if rnd.random() < 0.5 else al

def sumar(base, img, x, y, op):
    a = np.asarray(img).astype(np.float32); h, w = a.shape[:2]; x, y = int(x), int(y)
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, VW), min(y + h, VH)
    if x1 > x0 and y1 > y0:
        s = a[y0-y:y1-y, x0-x:x1-x]; base[y0:y1, x0:x1] += s[..., :3] * (s[..., 3:] / 255) * op
def poner(base, img, x, y, op=1.0):
    a = np.asarray(img).astype(np.float32); h, w = a.shape[:2]; x, y = int(x), int(y)
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, VW), min(y + h, VH)
    if x1 > x0 and y1 > y0:
        s = a[y0-y:y1-y, x0-x:x1-x]; al = s[..., 3:] / 255 * op; base[y0:y1, x0:x1] = base[y0:y1, x0:x1] * (1 - al) + s[..., :3] * al

try: fnt = ImageFont.truetype("/mnt/c/Windows/Fonts/cambriab.ttf", 30)
except Exception: fnt = None
frames = []; combate = None; rotulo = "Los Pokémon salvajes andan por el túnel"
for f in range(60 * 22):
    # Kaia
    if combate is None and not k.moviendo and ruta and f > 60:
        d = ruta[0]; nx, ny = k.x + PASOS[d][0], k.y + PASOS[d][1]
        if libre(nx, ny) and not any((p["c"].x, p["c"].y) == (nx, ny) for p in pk): k.mover(ruta.pop(0))
        else: ruta.pop(0)
    k.update()
    # Pokemon
    for p in pk:
        c = p["c"]; c.update(); p["alfa"] = min(255, p["alfa"] + 12)
        if combate or c.moviendo: continue
        if p["espera"] > 0: p["espera"] -= 1; continue
        for d in direcciones(p, c.x, c.y, k.x, k.y):
            nx, ny = c.x + PASOS[d][0], c.y + PASOS[d][1]
            if (nx, ny) == (k.x, k.y):                       # lo toca: combate
                c.dir = d; combate = (f, p); break
            if libre(nx, ny) and not any((o["c"].x, o["c"].y) == (nx, ny) for o in pk if o is not p):
                c.mover(d); break
        cerca = abs(c.x - k.x) + abs(c.y - k.y) <= CERCA
        p["espera"] = (4 if p["modo"] == "agresivo" else 10) if cerca else 30 + rnd.randint(0, 60)
        if cerca and p["modo"] == "agresivo": rotulo = "Gastly es agresivo: te persigue"
        elif cerca and p["modo"] == "curioso" and "Gastly" not in rotulo: rotulo = "Woobat es curioso: se acerca a mirar"
    if combate and f - combate[0] > 80: break
    if f % 2: continue
    cx = min(max(k.rx * 32 + 16 - VW / 2, 0), mapa.width - VW); cy = min(max(k.ry * 32 + 16 - VH / 2, 0), mapa.height - VH)
    base = np.asarray(mapa.crop((int(cx), int(cy), int(cx) + VW, int(cy) + VH)).convert("RGB")).astype(np.float32)
    dibujos = []
    for p in pk:
        c = p["c"]; col = (c.t // 8) % 4 if (p["vuela"] or c.moviendo) else 0
        fr = c.img.crop((col * 64, FILA[c.dir] * 64, col * 64 + 64, FILA[c.dir] * 64 + 64))
        dibujos.append((c.ry, fr, c.rx * 32 + 16 - 32 - cx, c.ry * 32 + 32 - 64 - cy, p["alfa"] / 255))
    col = (k.t // 8) % 4 if k.moviendo else 0
    dibujos.append((k.ry, kaia.crop((col * 64, FILA[k.dir] * 64, col * 64 + 64, FILA[k.dir] * 64 + 64)), k.rx * 32 + 16 - 32 - cx, k.ry * 32 + 32 - 64 - cy, 1.0))
    for _, fr, x, y, op in sorted(dibujos, key=lambda d: d[0]): poner(base, fr, x, y, op)
    dibujos = dibujos
    osc = np.asarray(oscuro.crop((int(cx), int(cy), int(cx) + VW, int(cy) + VH))).astype(np.float32).copy()
    pcx, pcy = int(k.rx * 32 + 16 - cx), int(k.ry * 32 + 32 - cy) - 16      # screen_x, screen_y - 16
    R, BO, PA = 80, 16, 4
    for yy in range(-R - BO, R + BO, PA):
        for xx in range(-R - BO, R + BO, PA):
            dd = math.hypot(xx + PA / 2, yy + PA / 2)
            x0, y0 = pcx + xx, pcy + yy
            if x0 < 0 or y0 < 0 or x0 >= VW or y0 >= VH: continue
            if dd < R: osc[y0:y0 + PA, x0:x0 + PA, 3] = 0
            elif dd < R + BO: osc[y0:y0 + PA, x0:x0 + PA, 3] *= (dd - R) / BO
    poner(base, Image.fromarray(osc.astype(np.uint8), "RGBA"), 0, 0)
    for _, fr, x, y, op in dibujos[:-1]: poner(base, fr, x, y, op * 0.75)   # los Pokemon, por encima de la oscuridad
    for lx, ly, tipo in LAMPARAS:
        b = luz_fria if tipo in "fp" else luz; z = 0.9 if tipo == "f" else 1.15
        im = b.resize((int(b.width * z), int(b.height * z)))
        op = (150 + 14 * math.sin(f / 30 + lx)) / 255 * (0.2 if tipo == "p" and (f // 9) % 11 == 0 else 1)
        sumar(base, im, lx - im.width / 2 - cx, ly - im.height / 2 - cy, op)
    kl = luz.resize((int(luz.width * 0.75), int(luz.height * 0.75)))
    sumar(base, kl, k.rx * 32 + 16 - kl.width / 2 - cx, k.ry * 32 - kl.height / 2 - cy, (62 + 6 * math.sin(f / 13)) / 255)
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).resize((VW * 2, VH * 2), Image.NEAREST)
    rot = rotulo
    if combate:
        kk = (f - combate[0]) / 80; img = Image.blend(img, Image.new("RGB", img.size), min(1, kk * 1.5))
        rot = "¡Te ha tocado un %s salvaje! · empieza el combate" % combate[1]["esp"]
    d = ImageDraw.Draw(img); d.rectangle([0, 0, img.width, 50], fill=(0, 0, 0)); d.text((20, 9), rot, fill=(240, 220, 160), font=fnt)
    d.text((img.width - 330, img.height - 30), "simulacion sin abrir el juego · mapa 18", fill=(150, 150, 150))
    frames.append(np.asarray(img))
salida = "/mnt/c/Users/david.martinez/Downloads/pokemon_tunel_prueba.mp4"
p = subprocess.Popen([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (VW * 2, VH * 2), "-r", "30", "-i", "-",
                      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", salida], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
for fr in frames: p.stdin.write(fr.tobytes())
p.stdin.close(); p.wait()
print("fotogramas", len(frames), "combate", combate[0] if combate else None, combate[1]["esp"] if combate else "")
