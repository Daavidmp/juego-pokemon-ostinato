# Dibuja fotogramas del simulador (estado de cada sprite) como los veria el juego
import json, sys, os
import numpy as np
from PIL import Image
J = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/Pokémon Ostinato/"
data = json.load(open(sys.argv[1]))
cache = {}
def bm(s):
    if s["p"]:
        if s["p"] not in cache: cache[s["p"]] = Image.open(J + s["p"]).convert("RGBA")
        return cache[s["p"]]
    im = Image.new("RGBA", (s["bw"], s["bh"]), (0, 0, 0, 0))
    for f in s["fill"] or []:
        x, y, w, h, c = f[0], f[1], f[2], f[3], f[4]
        im.paste((40, 30, 34, 255), (x, y, x + w, y + h))
    if not s["fill"]: im = Image.new("RGBA", (s["bw"], s["bh"]), (0, 0, 0, 255))
    return im
def pintar(fr, escala=0.5):
    W, H = int(1920 * escala), int(1080 * escala)
    can = np.zeros((H, W, 3), np.float32)
    orden = sorted(enumerate(fr["s"]), key=lambda t: (t[1]["vz"], t[1]["z"], t[0]))
    for _, s in orden:
        im = bm(s)
        x0, y0, w, h = s["sr"]
        if w <= 0 or h <= 0: continue
        im = im.crop((x0, y0, x0 + w, y0 + h))
        if s["m"]: im = im.transpose(Image.FLIP_LEFT_RIGHT)
        zx, zy = s["zx"] * escala, s["zy"] * escala
        nw, nh = max(1, round(w * zx)), max(1, round(h * zy))
        im = im.resize((nw, nh), Image.NEAREST)
        ox, oy = s["ox"] * zx, s["oy"] * zy
        if s["m"]: ox = nw - ox
        if s["a"]:
            # gira alrededor del origen (ox, oy), sentido contrario a las agujas como RGSS
            big = Image.new("RGBA", (nw * 3, nh * 3)); big.paste(im, (int(nw * 1.5 - ox), int(nh * 1.5 - oy)))
            im = big.rotate(s["a"], resample=Image.NEAREST, center=(nw * 1.5, nh * 1.5)); ox, oy = nw * 1.5, nh * 1.5
        a = np.asarray(im).astype(np.float32)
        rgb, al = a[..., :3], a[..., 3:] / 255.0 * (s["o"] / 255.0)
        c = s["c"]
        if c[3] > 0: rgb = rgb + (np.array(c[:3], np.float32) - rgb) * (c[3] / 255.0)
        t = s["t"]
        if any(t):
            g = rgb.mean(axis=2, keepdims=True)
            rgb = rgb + (g - rgb) * (t[3] / 255.0)
            rgb = rgb + np.array(t[:3], np.float32)
        rgb = np.clip(rgb, 0, 255)
        px, py = int(round(s["x"] * escala - ox)), int(round(s["y"] * escala - oy))
        x1, y1 = max(px, 0), max(py, 0); x2, y2 = min(px + im.width, W), min(py + im.height, H)
        if x2 <= x1 or y2 <= y1: continue
        sub = (slice(y1 - py, y2 - py), slice(x1 - px, x2 - px))
        dst = can[y1:y2, x1:x2]
        if s["bl"] == 1: dst += rgb[sub] * al[sub]
        else: dst[:] = dst * (1 - al[sub]) + rgb[sub] * al[sub]
        np.clip(dst, 0, 255, out=dst)
    return Image.fromarray(can.astype(np.uint8))
frames = data["frames"]
# un fotograma en mitad de cada subtitulo
dis = [(int(l.split()[1]), l.split()[2]) for l in data["log"] if l.startswith("DI")]
sel = []
for f0, cod in dis:
    cand = [fr for fr in frames if fr["f"] >= f0 + 20]
    if cand: sel.append((cod, cand[0]))
os.makedirs(sys.argv[2], exist_ok=True)
for i in range(0, len(sel), 12):
    hoja = Image.new("RGB", (4 * 480, 3 * 290), (30, 30, 30))
    for k, (cod, fr) in enumerate(sel[i:i + 12]):
        im = pintar(fr, 0.25)
        hoja.paste(im, ((k % 4) * 480, (k // 4) * 290))
        from PIL import ImageDraw
        ImageDraw.Draw(hoja).text(((k % 4) * 480 + 4, (k // 4) * 290 + 272), "%s f%d" % (cod, fr["f"]), fill=(255, 255, 0))
    hoja.save(os.path.join(sys.argv[2], "hoja%d.png" % (i // 12)))
print(len(sel), "fotogramas")
