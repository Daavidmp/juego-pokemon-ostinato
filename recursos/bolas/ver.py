# Dibuja un mapa con su tileset (autotiles incluidos de forma simple), lo que se pisa y sus eventos
from comun import *
from PIL import Image, ImageDraw
import sys, os
AUTO = {}
def autotile(nombre):
    if nombre not in AUTO:
        p = JUEGO + "/Graphics/Autotiles/" + nombre + ".png"
        AUTO[nombre] = Image.open(p).convert("RGBA") if nombre and os.path.exists(p) else None
    return AUTO[nombre]
def pintar(mid, out, rejilla=True):
    m = P.load_map(mid); ts = marshal.load_file(JUEGO + "/Data/Tilesets.rxdata")[m["tileset_id"]]
    img = Image.open(JUEGO + "/Graphics/Tilesets/" + s(ts["tileset_name"]) + ".png").convert("RGBA")
    an = [s(a) for a in ts["autotile_names"]]
    d = m["data"]; W, H = m["width"], m["height"]
    can = Image.new("RGBA", (W * 32, H * 32), (0, 0, 0, 255))
    for z in range(3):
        for y in range(H):
            for x in range(W):
                t = d[x, y, z]
                if t >= 384:
                    t -= 384; can.alpha_composite(img.crop(((t % 8) * 32, (t // 8) * 32, (t % 8) * 32 + 32, (t // 8) * 32 + 32)), (x * 32, y * 32))
                elif t >= 48:
                    a = autotile(an[t // 48 - 1])
                    if a: can.alpha_composite(a.crop((0, 0, 32, 32)) if a.height == 32 else a.crop((32, 64, 64, 96)), (x * 32, y * 32))
    capa = Image.new("RGBA", can.size); dr = ImageDraw.Draw(capa)
    for y in range(H):
        for x in range(W):
            libre = True
            for z in (2, 1, 0):
                t = d[x, y, z]
                if t == 0: continue
                if ts["passages"][t] & 0x0f == 0x0f: libre = False; break
                if ts["priorities"][t] == 0: break
            if not libre: dr.rectangle([x*32, y*32, x*32+31, y*32+31], fill=(255, 0, 0, 55))
            if rejilla and (x % 5 == 0 or y % 5 == 0): dr.text((x*32+2, y*32+2), "%d,%d" % (x, y), fill=(255, 255, 0, 255))
    for k, e in m["events"].items():
        dr.rectangle([e["x"]*32+3, e["y"]*32+3, e["x"]*32+28, e["y"]*32+28], outline=(0, 255, 255, 255), width=2)
    Image.alpha_composite(can, capa).save(out)
    return W, H
if __name__ == "__main__":
    for mid in map(int, sys.argv[1:]):
        print(mid, pintar(mid, "v%d.png" % mid))
