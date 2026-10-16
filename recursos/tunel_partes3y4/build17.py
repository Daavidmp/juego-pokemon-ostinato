# Monta el mapa 17 (parte 3 del tunel de la ruta 4) desde la imagen de Firefly.
#   tileset 48 "Tunel ruta 4 (3)" (TunelRuta4_3.png, un tile por casilla) con su paso,
#   Map017 de 43x24, saltos con el mapa 16 y la entrada en MapInfos.
import copy, os
import numpy as np
from PIL import Image
from comun import *
from devkit.rxdata.marshal import IvarWrapped, Table
exec(open('paso17.py').read().replace("if __name__ == '__main__':", "if False:"))   # P_ = paso

W, H = 43, 24
MAPA, TS = 17, 48
def w(t): return IvarWrapped(t, {'E': True})

#--- el tileset ----------------------------------------------------------------
img = Image.open('mapa17_1376.png').convert('RGBA')
assert img.size == (W * 32, H * 32)
n = W * H
hoja = Image.new('RGBA', (256, (n + 7) // 8 * 32), (0, 0, 0, 0))
for i in range(n):
    x, y = i % W, i // W
    hoja.paste(img.crop((x * 32, y * 32, x * 32 + 32, y * 32 + 32)), ((i % 8) * 32, (i // 8) * 32))
hoja.save(JUEGO + '/Graphics/Tilesets/TunelRuta4_3.png')

tss_path = JUEGO + '/Data/Tilesets.rxdata'
tss = marshal.load_file(tss_path)
t = copy.deepcopy(tss[39])
t['id'] = TS; t['name'] = w('Tunel ruta 4 (3)'); t['tileset_name'] = w('TunelRuta4_3')
total = 384 + n
paso = [0] * total; prio = [0] * total; terr = [0] * total
for i in range(n):
    x, y = i % W, i // W
    paso[384 + i] = 15 if P_[y][x] == '#' else 0
t['passages'] = Table(1, total, 1, 1, paso)
t['priorities'] = Table(1, total, 1, 1, prio)
t['terrain_tags'] = Table(1, total, 1, 1, terr)
tss[TS] = t
open(tss_path, 'wb').write(marshal.dump(tss))

#--- el mapa -------------------------------------------------------------------
m16 = P.load_map(16)
m = copy.deepcopy(m16)
m['width'] = W; m['height'] = H; m['tileset_id'] = TS
vals = [0] * (W * H * 3)
for i in range(n): vals[i] = 384 + i          # capa 0: el tile de cada casilla
m['data'] = Table(3, W, H, 3, vals)
plantilla = m16['events'][1]                     # un salto de mapa por contacto
def salto(eid, nombre, x, y, mapa, dx, dy, dir):
    e = copy.deepcopy(plantilla)
    e['id'] = eid; e['name'] = w(nombre); e['x'] = x; e['y'] = y
    for c in e['pages'][0]['list']:
        if c['code'] == 201: c['parameters'] = [0, mapa, dx, dy, dir, 1]
    return e
ev = {}
for k, x in enumerate(range(5, 12)):              # abajo: vuelve a la boca de la carretera del 16
    ev[k + 1] = salto(k + 1, 'BajarParte2', x, 23, 16, 17 if x <= 8 else 18, 5, 2)
for k, y in enumerate(range(17, 20)):              # derecha: la via sigue a la parte 4
    ev[8 + k] = salto(8 + k, 'SeguirParte4', 41, y, 18, 1, 17, 6)
from montar import objeto
ev[11] = objeto(11, 32, 4, 'TM70', 1, 'Object ball MT')    # bola amarilla del campamento
m['events'] = ev
P.save_map(MAPA, m)

#--- el 16: la boca de la carretera lleva al 17 -------------------------------
nid = max(m16['events']) + 1
for x in (17, 18):
    if not any(e['x'] == x and e['y'] == 4 for e in m16['events'].values()):
        m16['events'][nid] = salto(nid, 'SubirParte3', x, 4, MAPA, 8, 22, 8); nid += 1
P.save_map(16, m16)

#--- MapInfos --------------------------------------------------------------------
ipath = JUEGO + '/Data/MapInfos.rxdata'
infos = marshal.load_file(ipath)
if MAPA not in infos:
    i = copy.deepcopy(infos[16])
    i['name'] = w('Tunel ruta 4 (3)'); i['parent_id'] = 15
    i['order'] = max(v['order'] for v in infos.values()) + 1
    infos[MAPA] = i
open(ipath, 'wb').write(marshal.dump(infos))
print('tileset', hoja.size, 'mapa', W, H, 'eventos 17', len(ev), 'eventos 16', sorted(m16['events']))
