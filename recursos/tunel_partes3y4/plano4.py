# Plano de la parte 4 (la ultima) del tunel: 43x24 casillas de 32 px (1376x768).
# Entrada por la IZQUIERDA (la via de la parte 3, filas 16-18), salida por ARRIBA (escalera a la calle).
# Caminos que se dividen: estacion -> galeria de arriba / pasillo de abajo -> cruce -> sala hundida o
# sala de bombas -> a la salida por la pasarela del foso o rodeando por el pasillo del este.
from PIL import Image, ImageDraw
W, H = 43, 24
g = [[' '] * W for _ in range(H)]
def sala(x0, y0, x1, y1, c='.'):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H: g[y][x] = c
sala(0, 16, 1, 18)          #   la via entra por la izquierda
sala(2, 11, 12, 21)         # 1 la estacion
sala(3, 1, 5, 10)           #   el pasillo que sube de la estacion
sala(3, 1, 20, 6)           # 2 la galeria de las tuberias (arriba)
sala(21, 1, 24, 4)          #   rincon sin salida al fondo de la galeria (objeto)
sala(18, 7, 20, 9)          #   baja a la sala hundida
sala(16, 9, 28, 15)         # 3 la sala del techo hundido
sala(22, 7, 28, 9)
sala(13, 18, 17, 21)        #   pasillo de abajo desde la estacion
sala(17, 16, 22, 22)        # 4 el cruce (almacen)
sala(23, 18, 32, 22)        # 5 la sala de bombas, medio inundada
sala(29, 9, 32, 14, '-')    #   el foso entre la sala hundida y la salida
sala(29, 11, 32, 12, 'b')   #   y la pasarela que lo cruza
sala(33, 4, 41, 13)         # 6 la plataforma de la salida
sala(36, 0, 39, 3)          #   la escalera que sube a la calle
sala(33, 18, 37, 21)        #   pasillo del este, desde la sala de bombas
sala(37, 14, 39, 21)        #   ...que sube a la plataforma de la salida
suelo = {'.', 'b', '-'}
for y in range(H):
    for x in range(W):
        if g[y][x] != ' ': continue
        if any(0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] in suelo
               for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            g[y][x] = '='
for y in range(1, H):
    for x in range(W):
        if g[y][x] == '.' and g[y - 1][x] == '=':
            g[y][x] = '#'
            if y + 1 < H and g[y + 1][x] == '.': g[y + 1][x] = '#'
def poner(c, x0, y0, x1=None, y1=None):
    sala(x0, y0, x1 if x1 is not None else x0, y1 if y1 is not None else y0, c)
# 1 estacion: anden, via con un vagon viejo y el tope
poner('y', 2, 15, 11, 15)
poner('r', 0, 16, 10, 18)
poner('V', 3, 16, 8, 18)
poner('Z', 10, 16, 10, 18)
poner('n', 7, 13, 8, 13); poner('Q', 9, 13, 11, 14)
poner('S', 7, 11, 10, 11); poner('L', 2, 11); poner('L', 11, 11)
poner('B', 2, 20, 3, 21)
# 2 galeria: tuberias por la pared, cajas, y el rincon del fondo con un objeto
poner('T', 6, 1, 20, 2)                 # tuberias por la cara de la pared
poner('B', 9, 5, 10, 6); poner('X', 14, 6)
OBJETOS = [(23, 3), (32, 20)]          # objetos para recoger: van como eventos, NO en el dibujo
poner('L', 4, 1)
# 3 sala hundida: luz del dia, hierba, raices, columna caida
poner('g', 17, 10, 27, 15); poner('W', 21, 10, 25, 13)
poner('R', 22, 7, 24, 8); poner('R', 16, 9, 17, 10)
poner('X', 26, 14, 27, 15); poner('f', 18, 14); poner('f', 27, 11)
# 4 cruce: cajas y taquillas
poner('B', 21, 16, 22, 17); poner('K', 17, 22, 18, 22)
# 5 sala de bombas: dos bombas viejas, agua con una pasarela, otro objeto en la esquina
poner('~', 25, 20, 30, 22); poner('b', 25, 21, 30, 21)   # el agua corta la sala: se cruza por la pasarela
poner('G', 24, 18, 25, 19); poner('G', 31, 18, 32, 19)
poner('L', 27, 18)
# 6 plataforma de la salida: raices, helechos, la escalera
poner('R', 33, 4, 35, 5); poner('R', 40, 4, 41, 5)
poner('E', 36, 0, 39, 6); poner('W', 36, 0, 39, 0)
poner('f', 34, 9); poner('f', 41, 11); poner('g', 33, 10, 35, 13)
COL = {' ': (0, 0, 0), '=': (222, 206, 170), '#': (80, 80, 86), '.': (150, 150, 144), 'y': (232, 198, 40),
       '~': (58, 122, 112), 'g': (92, 160, 70), 'W': (252, 252, 240), 'L': (255, 222, 80), 'X': (122, 100, 88),
       'B': (172, 122, 60), 'r': (96, 66, 48), 'V': (40, 110, 70), 'Z': (200, 40, 40), 'n': (150, 90, 40),
       'Q': (110, 170, 210), 'S': (235, 235, 235), 'R': (70, 45, 30), 'f': (40, 120, 50), 'E': (196, 196, 188),
       '-': (20, 16, 30), 'b': (128, 80, 40), 'T': (150, 70, 40), 'P': (230, 40, 60), 'G': (110, 112, 58),
       'K': (90, 110, 150)}
im = Image.new('RGB', (W * 32, H * 32)); d = ImageDraw.Draw(im)
for y in range(H):
    for x in range(W):
        c = g[y][x]; d.rectangle([x * 32, y * 32, x * 32 + 31, y * 32 + 31], fill=COL[c])
        if c == '.': d.rectangle([x * 32, y * 32, x * 32 + 31, y * 32 + 31], outline=tuple(v - 18 for v in COL[c]))
        if c == 'r':
            d.rectangle([x * 32, y * 32 + 6, x * 32 + 31, y * 32 + 9], fill=(170, 170, 176))
            d.rectangle([x * 32, y * 32 + 22, x * 32 + 31, y * 32 + 25], fill=(170, 170, 176))
        if c == 'E': d.line([x * 32, y * 32 + 16, x * 32 + 31, y * 32 + 16], fill=(150, 150, 140), width=3)
        if c == 'P': d.ellipse([x * 32 + 8, y * 32 + 8, x * 32 + 24, y * 32 + 24], fill=(255, 255, 255), outline=(30, 30, 30))
im.save('plano_parte4_43x24.png')
print('\n'.join('%2d ' % i + ''.join(r) for i, r in enumerate(g)))
