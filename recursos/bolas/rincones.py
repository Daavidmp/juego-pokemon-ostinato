# Rincones donde esconder una bola: alcanzables, apartados del camino principal y recogidos
from comun import *
from collections import deque
from PIL import Image, ImageDraw
import sys
def rejilla(mid):
    m = P.load_map(mid); ts = marshal.load_file(JUEGO + "/Data/Tilesets.rxdata")[m["tileset_id"]]
    d = m["data"]; W, H = m["width"], m["height"]
    def libre(x, y):
        for z in (2, 1, 0):
            t = d[x, y, z]
            if t == 0: continue
            if ts["passages"][t] & 0x0f == 0x0f: return False
            if ts["priorities"][t] == 0: return True
        return True
    G = [[libre(x, y) for x in range(W)] for y in range(H)]
    saltos, otros = [], []
    for e in m["events"].values():
        txt = str([c["code"] for p in e["pages"] for c in p["list"]])
        if "201" in txt: saltos.append((e["x"], e["y"]))
        else: otros.append((e["x"], e["y"]))
    for x, y in otros: G[y][x] = False      # los eventos (personas, objetos) ocupan su casilla
    return m, G, saltos, otros
def bfs(G, ini):
    H, W = len(G), len(G[0]); dist = {ini: 0}; q = deque([ini])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            n = (x+dx, y+dy)
            if 0 <= n[0] < W and 0 <= n[1] < H and n not in dist and G[n[1]][n[0]]:
                dist[n] = dist[(x, y)] + 1; q.append(n)
    return dist
def analizar(mid, n=8):
    m, G, saltos, otros = rejilla(mid)
    H, W = len(G), len(G[0])
    ent = [c for c in saltos if G[c[1]][c[0]]] or saltos
    alc = bfs(G, ent[0]) if ent else {}
    # camino principal: union de los caminos mas cortos entre cada par de entradas
    camino = set()
    for a in ent:
        da = bfs(G, a)
        for b in ent:
            if b == a or b not in da: continue
            c = b
            while c != a:
                camino.add(c)
                c = min(((c[0]+dx, c[1]+dy) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)) if (c[0]+dx, c[1]+dy) in da), key=lambda p: da[p])
            camino.add(a)
    dcam = {}
    q = deque(camino); dcam = {c: 0 for c in camino}
    while q:
        x, y = q.popleft()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nn = (x+dx, y+dy)
            if nn in alc and nn not in dcam: dcam[nn] = dcam[(x, y)] + 1; q.append(nn)
    cand = []
    for (x, y) in alc:
        if (x, y) in saltos: continue
        bloq = sum(1 for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)) if not (0 <= x+dx < W and 0 <= y+dy < H) or not G[y+dy][x+dx])
        if bloq < 2: continue
        # que la bola no corte el paso: sin ella se sigue llegando a todo
        G[y][x] = False
        ok = len(bfs(G, ent[0])) == len(alc) - 1 if ent else True
        G[y][x] = True
        if not ok: continue
        cand.append((dcam.get((x, y), 0) * 2 + bloq * 3, x, y, bloq, dcam.get((x, y), 0)))
    cand.sort(reverse=True)
    return m, G, alc, camino, cand[:n]
if __name__ == "__main__":
    for mid in map(int, sys.argv[1:]):
        m, G, alc, camino, cand = analizar(mid, 10)
        print(mid, "alcanzables", len(alc), "camino", len(camino), "rincones:", [(x, y, "lados", b, "aparte", dc) for _, x, y, b, dc in cand])
        im = Image.open("v%d.png" % mid).convert("RGBA"); capa = Image.new("RGBA", im.size); dr = ImageDraw.Draw(capa)
        for c in camino: dr.rectangle([c[0]*32+12, c[1]*32+12, c[0]*32+20, c[1]*32+20], fill=(0, 120, 255, 200))
        for i, (_, x, y, b, dc) in enumerate(cand):
            dr.ellipse([x*32+4, y*32+4, x*32+28, y*32+28], outline=(255, 0, 255, 255), width=4); dr.text((x*32+12, y*32+10), str(i), fill=(255, 255, 255, 255))
        Image.alpha_composite(im, capa).save("r%d.png" % mid)
