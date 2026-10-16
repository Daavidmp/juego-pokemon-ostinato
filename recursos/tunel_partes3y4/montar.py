# Lo comun para montar una parte del tunel desde su imagen (mapas 17 y 18)
import copy
from PIL import Image
from comun import *
from devkit.rxdata.marshal import IvarWrapped, Table
from devkit.rxdata import rpg

def w(t): return IvarWrapped(t, {'E': True})

def tileset(img_path, paso, ts_id, nombre, png):
    """Un tile por casilla (capa 0). paso[y][x] == '#' bloquea. Devuelve (ancho, alto) en casillas."""
    img = Image.open(img_path).convert('RGBA')
    W, H = img.width // 32, img.height // 32
    n = W * H
    hoja = Image.new('RGBA', (256, (n + 7) // 8 * 32), (0, 0, 0, 0))
    for i in range(n):
        x, y = i % W, i // W
        hoja.paste(img.crop((x * 32, y * 32, x * 32 + 32, y * 32 + 32)), ((i % 8) * 32, (i // 8) * 32))
    hoja.save(JUEGO + '/Graphics/Tilesets/' + png + '.png')
    ruta = JUEGO + '/Data/Tilesets.rxdata'
    tss = marshal.load_file(ruta)
    t = copy.deepcopy(tss[39])
    t['id'] = ts_id; t['name'] = w(nombre); t['tileset_name'] = w(png)
    total = 384 + n
    pas = [0] * total
    for i in range(n):
        pas[384 + i] = 15 if paso[i // W][i % W] == '#' else 0
    t['passages'] = Table(1, total, 1, 1, pas)
    t['priorities'] = Table(1, total, 1, 1, [0] * total)
    t['terrain_tags'] = Table(1, total, 1, 1, [0] * total)
    tss[ts_id] = t
    open(ruta, 'wb').write(marshal.dump(tss))
    return W, H

def mapa(mid, W, H, ts_id, eventos):
    m = copy.deepcopy(P.load_map(16))
    m['width'] = W; m['height'] = H; m['tileset_id'] = ts_id
    vals = [0] * (W * H * 3)
    for i in range(W * H): vals[i] = 384 + i
    m['data'] = Table(3, W, H, 3, vals)
    m['events'] = {e['id']: e for e in eventos}
    P.save_map(mid, m)
    return m

def salto(eid, nombre, x, y, a_mapa, dx, dy, dir):
    e = copy.deepcopy(P.load_map(16)['events'][1])        # salto por contacto
    e['id'] = eid; e['name'] = w(nombre); e['x'] = x; e['y'] = y
    for c in e['pages'][0]['list']:
        if c['code'] == 201: c['parameters'] = [0, a_mapa, dx, dy, dir, 1]
    return e

def objeto(eid, x, y, item, cantidad=1, grafico='Object ball'):
    """La bola de un objeto: se recoge con pbItemBall y no vuelve a salir (interruptor local A)."""
    llamada = 'pbItemBall(:%s)' % item if cantidad == 1 else 'pbItemBall(:%s, %d)' % (item, cantidad)
    cmds = [rpg.event_command(111, 0, [12, w(llamada)]),
            rpg.event_command(123, 1, [w('A'), 0]),
            rpg.event_command(0, 1, []),
            rpg.event_command(412, 0, [])]
    p1 = rpg.event_page(cmds, graphic=rpg.page_graphic(w(grafico)), trigger=0)
    p2 = rpg.event_page([], condition=rpg.page_condition(self_switch_valid=True, self_switch_ch=w('A')))
    p2['graphic']['character_name'] = w('')
    return rpg.event(eid, w('Objeto ' + item), x, y, [p1, p2])

def info(mid, nombre, padre=15):
    ruta = JUEGO + '/Data/MapInfos.rxdata'
    infos = marshal.load_file(ruta)
    if mid not in infos:
        i = copy.deepcopy(infos[16])
        i['name'] = w(nombre); i['parent_id'] = padre
        i['order'] = max(v['order'] for v in infos.values()) + 1
        infos[mid] = i
        open(ruta, 'wb').write(marshal.dump(infos))
