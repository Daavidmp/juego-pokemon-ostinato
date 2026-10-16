# Las bolas de objetos del principio del juego (rojas: objetos; amarillas: MT)
from montar import *
from rincones import rejilla, bfs
ROJA, MT = 'Object ball', 'Object ball MT'
BOLAS = [  # mapa, x, y, objeto, cantidad, donde
    (2, 37, 16, 'POTION', 1, 'Preludio: detras de la casa roja de la derecha, entre el tejado y los arboles'),
    (9, 17, 19, 'POKEBALL', 3, 'Ruta 1: final del caminito sin salida de la derecha'),
    (10, 35, 11, 'TM54', 1, 'Ruta 2: hueco entre los arboles, abajo a la derecha'),
    (10, 27, 5, 'ORANBERRY', 1, 'Ruta 2: orilla del rio, junto al banco'),
    (11, 12, 0, 'TM39', 1, 'Ruta 3: detras de la caravana, en la meseta'),
    (11, 24, 8, 'GREATBALL', 1, 'Ruta 3: esquina de la meseta, junto a la hierba alta'),
    (12, 5, 13, 'TM78', 1, 'Bambalina: rincon entre la casa del tejado verde y el cortado'),
    (13, 9, 8, 'STARPIECE', 1, 'Teatro: lateral del escenario, junto al telon'),
    (14, 54, 38, 'TM17', 1, 'Ruta 4: junto a los bidones de la caravana'),
    (14, 54, 44, 'SUPERPOTION', 1, 'Ruta 4: borde del campo de combate'),
    (15, 21, 18, 'PARALYZEHEAL', 1, 'Tunel 1: junto a los bidones del canal'),
    (16, 19, 36, 'TM28', 1, 'Tunel 2: oficina de mantenimiento, entre la mesa y el archivador'),
    (17, 32, 4, 'TM70', 1, 'Tunel 3: campamento, entre la tienda y las cajas'),
]
for mid, x, y, item, n, donde in BOLAS:
    m0 = P.load_map(mid, reload=True)
    if any(e['x'] == x and e['y'] == y and 'Objeto' in str(getattr(e['name'], 'value', e['name'])) for e in m0['events'].values()):
        print('ya puesta:', mid, x, y, item); continue
    m, G, saltos, otros = rejilla(mid)
    assert G[y][x], ('no se pisa', mid, x, y)
    assert not any(e['x'] == x and e['y'] == y for e in m['events'].values()), ('ya hay un evento', mid, x, y)
    ent = [c for c in saltos if G[c[1]][c[0]]] or saltos
    alc = bfs(G, ent[0])
    assert (x, y) in alc or mid == 13, ('no se llega', mid, x, y)
    G[y][x] = False
    tras = bfs(G, ent[0])
    assert len(tras) >= len(alc) - 1, ('corta el paso', mid, x, y)
    eid = max(m['events']) + 1
    e = objeto(eid, x, y, item, n, MT if item.startswith('TM') else ROJA)
    m['events'][eid] = e
    P.save_map(mid, m)
    print('mapa %2d (%2d,%2d) ev %2d  %-12s x%d  %s' % (mid, x, y, eid, item, n, donde))
