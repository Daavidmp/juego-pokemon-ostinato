# Simulacion (sin el motor) de 030_OjosTunel en el mapa 18, con su misma logica, para verla en video
import math, subprocess, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg
J = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/"
T = J + "Pokémon Ostinato/Graphics/Pictures/Tunel/"
mapa = Image.open(J + "recursos/tunel_partes3y4/mapa18_1376.png").convert("RGBA")
oscuro = Image.open(T + "oscuro_18.png").convert("RGBA")
luz = Image.open(T + "luz.png").convert("RGBA"); luz_fria = Image.open(T + "luz_fria.png").convert("RGBA")
ojos = Image.open(T + "ojos.png").convert("RGB"); sombra = Image.open(T + "sombra_ojos.png").convert("RGBA")
nube = Image.open(T + "nube.png").convert("RGBA")
kaia = Image.open(J + "Pokémon Ostinato/Graphics/Characters/kaia.png").convert("RGBA")
G = open("paso18.txt").read().split("\n")
LAMPARAS = [[145, 48, 'c'], [752, 48, 'p'], [80, 370, 'c'], [400, 368, 'c'], [558, 302, 'c'], [815, 240, 'c'], [1103, 145, 'c'], [880, 592, 'f']]
VW, VH = 682, 384
DETECTA, VEL, CW, CH = 3.5, 4.0, 24, 12

def camino(x, y, px, py):
    ini = (x, y); meta = {(px+1, py), (px-1, py), (px, py+1), (px, py-1)}
    de = {ini: None}; cola = [ini]
    while cola:
        p = cola.pop(0)
        for dx, dy in ((0, 1), (-1, 0), (1, 0), (0, -1)):
            q = (p[0]+dx, p[1]+dy)
            if q in de or q == (px, py) or not (0 <= q[0] < 43 and 0 <= q[1] < 24) or G[q[1]][q[0]] != '.': continue
            de[q] = p
            if q in meta:
                l = [q]
                while de[l[0]] and de[l[0]] != ini: l.insert(0, de[l[0]])
                return l
            cola.append(q)
    return None

def sumar(base, img, x, y, op=1.0):          # mezcla aditiva
    x, y = int(x), int(y)
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, base.shape[1]), min(y + h, base.shape[0])
    if x1 <= x0 or y1 <= y0: return
    s = a[y0-y:y1-y, x0-x:x1-x]
    base[y0:y1, x0:x1] += s[..., :3] * (s[..., 3:] / 255.0) * op

def poner(base, img, x, y, op=1.0):          # mezcla normal
    x, y = int(x), int(y)
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, base.shape[1]), min(y + h, base.shape[0])
    if x1 <= x0 or y1 <= y0: return
    s = a[y0-y:y1-y, x0-x:x1-x]; al = s[..., 3:] / 255.0 * op
    base[y0:y1, x0:x1] = base[y0:y1, x0:x1] * (1 - al) + s[..., :3] * al

# --- guion de Kaia: entra por la via y baja al pasillo de debajo del anden ---
ruta_kaia = [(2, 17), (2, 18), (2, 19)] + [(x, 19) for x in range(3, 11)]
kx, ky, kdir = 1.0, 17.0, 6
ojo = [  # los de detras del vagon (amarillos: Zubat) y otros al fondo del anden (lilas)
    {"tipo": 0, "x": 12.0, "y": 17.0, "estado": "aparece", "t": 0, "parpadeo": 40, "lado": 0, "esp": "Zubat", "niv": 10},
    {"tipo": 2, "x": 4.0, "y": 14.0, "estado": "aparece", "t": 0, "parpadeo": 130, "lado": 20, "esp": "", "niv": 0}]
frames = []; bloqueado = False; paso_t = 0; espera_ini = 220; fin = None; combate = None
for f in range(60 * 16):
    # Kaia anda (16 fotogramas por casilla), salvo si la han visto
    if f >= espera_ini and not bloqueado and ruta_kaia and combate is None:
        tx, ty = ruta_kaia[0]
        kdir = 6 if tx > kx else 4 if tx < kx else (2 if ty > ky else 8)
        kx += (tx - kx) / max(1, 16 - paso_t); ky += (ty - ky) / max(1, 16 - paso_t); paso_t += 1
        if paso_t >= 16:
            kx, ky = float(tx), float(ty); ruta_kaia.pop(0); paso_t = 0
    andando = paso_t > 0
    px, py = round(kx), round(ky)
    for o in ojo:
        o["t"] += 1
        if o["estado"] == "aparece" and o["t"] >= 36: o["estado"] = "espera"
        elif o["estado"] == "espera":
            o["parpadeo"] -= 1
            if o["parpadeo"] <= 0:
                o["parpadeo"] = 22 if ((f // 5) % 3 == 0 and not o.get("doble")) else 120 + (f * 37) % 180
                o["doble"] = o["parpadeo"] == 22; o["lado"] = 20 if (f // 7) % 3 == 0 else 0
            if not bloqueado and not andando and math.hypot(o["x"] - kx, o["y"] - ky) <= DETECTA:
                o["estado"] = "alerta"; o["t"] = 0; bloqueado = True
        elif o["estado"] == "alerta" and o["t"] >= 30:
            o["ruta"] = camino(round(o["x"]), round(o["y"]), px, py); o["estado"] = "caza"; o["t"] = 0
        elif o["estado"] == "caza":
            paso = VEL / 60.0
            if not o["ruta"]: o["estado"] = "nube"; o["t"] = 0
            else:
                dx = o["ruta"][0][0] - o["x"]; dy = o["ruta"][0][1] - o["y"]; d = math.hypot(dx, dy)
                if d <= paso: o["x"], o["y"] = map(float, o["ruta"].pop(0))
                else: o["x"] += dx / d * paso; o["y"] += dy / d * paso
        elif o["estado"] == "nube" and o["t"] >= 20 and combate is None:
            combate = (f, o)
    if combate and f - combate[0] > 75: break
    if f % 2: continue                       # video a 30 fps
    # camara centrada en Kaia, sin salirse del mapa
    cx = min(max(kx * 32 + 16 - VW / 2, 0), mapa.width - VW); cy = min(max(ky * 32 + 16 - VH / 2, 0), mapa.height - VH)
    base = np.asarray(mapa.crop((int(cx), int(cy), int(cx) + VW, int(cy) + VH)).convert("RGB")).astype(np.float32)
    # Kaia (cuadro de 64 anclado por los pies)
    fila = {2: 0, 4: 1, 6: 2, 8: 3}[kdir]; col = (f // 8) % 4 if andando else 0
    poner(base, kaia.crop((col * 64, fila * 64, col * 64 + 64, fila * 64 + 64)), kx * 32 + 16 - 32 - cx, ky * 32 + 32 - 64 - cy)
    # la oscuridad del tunel y sus luces
    poner(base, oscuro.crop((int(cx), int(cy), int(cx) + VW, int(cy) + VH)), 0, 0)
    for lx, ly, tipo in LAMPARAS:
        b = luz_fria if tipo in "fp" else luz; z = 0.9 if tipo == "f" else 1.15
        im = b.resize((int(b.width * z), int(b.height * z)))
        op = (150 + 14 * math.sin(f / 30 + lx)) / 255 * (0.2 if tipo == "p" and (f // 9) % 11 == 0 else 1)
        sumar(base, im, lx - im.width / 2 - cx, ly - im.height / 2 - cy, op)
    kl = luz.resize((int(luz.width * 0.75), int(luz.height * 0.75)))
    sumar(base, kl, kx * 32 + 16 - kl.width / 2 - cx, ky * 32 - kl.height / 2 - cy, 110 / 255)
    # los ojos, su niebla y la nube
    for o in ojo:
        if o["estado"] == "fuera": continue
        ox, oy = o["x"] * 32 + 16 - cx, o["y"] * 32 + 16 - cy
        a = {"aparece": min(255, o["t"] * 7), "nube": max(0, 255 - o["t"] * 12)}.get(o["estado"], 255) / 255
        fs = (o["t"] // 12) % 4
        poner(base, sombra.crop((fs * 84, 0, fs * 84 + 84, 60)), ox - 42, oy - 12 - 33, a * 0.95)
        cuadro = 0
        if o["estado"] == "espera":
            p = o["parpadeo"]; cuadro = 1 if (p <= 4 or 11 < p <= 16) else (2 if p <= 11 else 0)
            if o["lado"] > 0 and 50 < p < 50 + o["lado"] * 3: cuadro = 3
        par = ojos.crop((cuadro * CW, o["tipo"] * CH, cuadro * CW + CW, o["tipo"] * CH + CH)).convert("RGBA")
        z = 1.4 * (1.2 if o["estado"] == "alerta" else 1.0)
        par = par.resize((round(24 * z), round(12 * z)), Image.NEAREST)
        sumar(base, par, ox - par.width / 2, oy - 12 - par.height / 2, a)
        if o["estado"] == "nube":
            w = nube.height; fr = nube.crop((min(o["t"] // 4, 4) * w, 0, min(o["t"] // 4, 4) * w + w, w)).resize((int(w * 1.6), int(w * 1.6)), Image.NEAREST)
            poner(base, fr, ox - fr.width / 2, oy - 6 - fr.height / 2)
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).resize((VW * 2, VH * 2), Image.NEAREST)
    d = ImageDraw.Draw(img)
    try: fnt = ImageFont.truetype("/mnt/c/Windows/Fonts/cambriab.ttf", 30)
    except Exception: fnt = None
    # rotulos para seguir lo que pasa
    estado = next((o["estado"] for o in ojo if o["estado"] in ("alerta", "caza", "nube")), None)
    rot = {"alerta": "¡Te ha visto! Kaia no se puede mover", "caza": "Va a por Kaia esquivando el vagón", "nube": "¡Ataca!"}.get(estado, "Ojos en la oscuridad: si te acercas, te ven")
    if combate:
        k = (f - combate[0]) / 75
        neg = Image.new("RGB", img.size, (0, 0, 0)); img = Image.blend(img, neg, min(1, k * 1.6)); d = ImageDraw.Draw(img)
        rot = "¡Un %s salvaje! (Nv. %d) · empieza el combate" % (combate[1]["esp"], combate[1]["niv"])
    d.rectangle([0, 0, img.width, 50], fill=(0, 0, 0)); d.text((20, 9), rot, fill=(240, 220, 160), font=fnt)
    d.text((img.width - 330, img.height - 30), "simulacion sin abrir el juego · mapa 18", fill=(150, 150, 150))
    frames.append(np.asarray(img))
salida = "/mnt/c/Users/david.martinez/Downloads/ojos_tunel_prueba.mp4"
ff = imageio_ffmpeg.get_ffmpeg_exe()
p = subprocess.Popen([ff, "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (VW * 2, VH * 2), "-r", "30", "-i", "-",
                      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", salida], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
for fr in frames: p.stdin.write(fr.tobytes())
p.stdin.close(); p.wait()
Image.fromarray(frames[len(frames) // 2]).save("fotograma_medio.png")
print("fotogramas", len(frames), "->", salida, os.path.getsize(salida) // 1024, "KB")
