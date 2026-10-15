# Plano de la parte 3 del tunel: 43x24 casillas de 32 px (1376x768). Entrada abajo, salida a la derecha.
from PIL import Image, ImageDraw
W, H = 43, 24
g = [[' '] * W for _ in range(H)]
def sala(x0, y0, x1, y1, c='.'):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H: g[y][x] = c
sala(2, 3, 19, 20)          # 1 la carretera que viene de la parte 2
sala(5, 21, 11, 23)         #   entrada por abajo
sala(20, 11, 25, 16)        # 2 el puente sobre el arroyo
sala(21, 5, 23, 21, '~')    #   el arroyo que baja por una grieta
sala(26, 2, 40, 10)         # 3 el campamento abandonado
sala(30, 11, 34, 12)        #   pasillo al anden
sala(26, 13, 42, 21)        # 4 el anden de mantenimiento, sale por la derecha
suelo = {'.', '~'}
# canto del muro alrededor de todo lo excavado (no en los bordes abiertos)
for y in range(H):
    for x in range(W):
        if g[y][x] != ' ': continue
        if any(0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] in suelo
               for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            g[y][x] = '='
# cara del muro: las dos filas de debajo de cada canto de arriba
for y in range(1, H):
    for x in range(W):
        if g[y][x] == '.' and g[y - 1][x] == '=':
            g[y][x] = '#'
            if y + 1 < H and g[y + 1][x] == '.': g[y + 1][x] = '#'
def poner(c, x0, y0, x1=None, y1=None):
    sala(x0, y0, x1 if x1 is not None else x0, y1 if y1 is not None else y0, c)
# 1 carretera: asfalto con raya amarilla, derrumbe con luz del techo y un autobus viejo
poner('a', 6, 8, 10, 23)
for y in range(9, 24, 2): poner('y', 8, y)
poner('X', 4, 5, 12, 7)                 # derrumbe que corta la carretera arriba
poner('g', 12, 7, 17, 10); poner('W', 13, 5, 16, 8)   # rayo de luz por un agujero del techo
poner('C', 13, 12, 17, 16)              # autobus abandonado
poner('K', 11, 10); poner('K', 11, 19); poner('K', 5, 15)
poner('B', 3, 18, 4, 19)                # bidones
poner('L', 3, 3); poner('L', 18, 3); poner('L', 10, 3)
# 2 puente de madera sobre el arroyo, cascada que sale de la pared arriba
poner('b', 21, 12, 23, 15)
poner('W', 22, 5)                       # el chorro de agua que cae de la grieta
# 3 campamento: tienda, hoguera apagada, sacos, cajas, generador, farolillos
poner('T', 28, 5, 31, 7)
poner('F', 34, 7)
poner('s', 33, 9, 35, 9)
poner('B', 38, 4, 39, 5); poner('G', 36, 4, 37, 5)
poner('L', 27, 2); poner('L', 39, 2); poner('L', 33, 2)
poner('X', 26, 9, 27, 10)
# 4 anden: borde amarillo, via vieja que se mete en el tunel de la derecha, vagoneta
poner('y', 26, 16, 41, 16)
poner('r', 26, 17, 42, 19)
poner('M', 30, 17, 32, 19)
poner('D', 41, 17, 42, 19)              # la boca oscura de la via: la salida de este mapa
for y in (13, 14, 15, 16, 20, 21): g[y][42] = '='   # el resto del lado derecho es muro
poner('L', 28, 13); poner('L', 38, 13)
poner('B', 26, 20, 27, 21)
COL = {' ': (0, 0, 0), '=': (222, 206, 170), '#': (80, 80, 86), '.': (150, 150, 144), 'a': (58, 58, 64),
       'y': (232, 198, 40), '~': (58, 122, 112), 'g': (92, 160, 70), 'W': (252, 252, 240), 'L': (255, 222, 80),
       'b': (128, 80, 40), 'X': (122, 100, 88), 'C': (214, 140, 40), 'K': (240, 110, 30), 'T': (60, 120, 186),
       'F': (204, 64, 36), 's': (160, 60, 124), 'B': (172, 122, 60), 'G': (110, 112, 58), 'r': (96, 66, 48),
       'M': (220, 210, 60), 'D': (14, 14, 26)}
im = Image.new('RGB', (W * 32, H * 32)); d = ImageDraw.Draw(im)
for y in range(H):
    for x in range(W):
        c = g[y][x]; d.rectangle([x * 32, y * 32, x * 32 + 31, y * 32 + 31], fill=COL[c])
        if c in '.a': d.rectangle([x * 32, y * 32, x * 32 + 31, y * 32 + 31], outline=tuple(v - 18 for v in COL[c]))
        if c == 'r':
            d.rectangle([x * 32, y * 32 + 6, x * 32 + 31, y * 32 + 9], fill=(170, 170, 176))
            d.rectangle([x * 32, y * 32 + 22, x * 32 + 31, y * 32 + 25], fill=(170, 170, 176))
im.save('plano_parte3_43x24.png')
print('\n'.join(''.join(r) for r in g))
