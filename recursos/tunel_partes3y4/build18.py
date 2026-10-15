# Monta el mapa 18 (parte 4, la ultima del tunel): tileset 49 "Tunel ruta 4 (4)", entrada por la izquierda
# desde la via de la parte 3, dos objetos en los rincones, y la escalera de salida arriba (sin destino aun).
from montar import *
exec(open('paso18.py').read().replace("if __name__ == '__main__':", "if False:"))
MAPA, TS = 18, 49
W, H = tileset('mapa18_1376.png', P_, TS, 'Tunel ruta 4 (4)', 'TunelRuta4_4')
ev = []
for k, y in enumerate(range(16, 19)):          # izquierda: vuelve a la boca de la via de la parte 3
    ev.append(salto(k + 1, 'VolverParte3', 0, y, 17, 40, 18, 4))
ev.append(objeto(4, 23, 3, 'ESCAPEROPE'))      # rincon del fondo de la galeria
ev.append(objeto(5, 32, 20, 'SUPERPOTION'))    # rincon de la sala de bombas
mapa(MAPA, W, H, TS, ev)
info(MAPA, 'Tunel ruta 4 (4)')
print('mapa 18', W, H, 'eventos', [(e['id'], s(e['name']), e['x'], e['y']) for e in ev])
# la casilla de cada objeto tiene que pisarse (para llegar) y la de llegada desde la parte 3 tambien
for x, y in [(23, 3), (32, 20), (1, 17)]:
    assert P_[y][x] == '.', (x, y)
