"""Baja el guardarropa de sala_v7.png sin redibujarlo (solo mover pixeles de la propia imagen).
   python3 perchero.py <sala_v7.png> <salida_A.png> <salida_B.png>
El guardarropa (x 38-476, y 1405-1755) ya toca la pared de abajo: se baja D px quitando D filas lisas de su parte de
abajo (el brazo de madera y la moqueta de dentro de la L, que son iguales fila a fila), y el hueco de arriba se rellena
con moqueta de la propia sala.
  A: se dibujan enteros los tres taburetes de debajo de la barra (copiados de los de la derecha).
  B: sin esos tres taburetes: queda un pasillo libre entre la barra y el guardarropa.
"""
import sys
from PIL import Image

SRC, OUT_A, OUT_B = sys.argv[1:4]
im = Image.open(SRC).convert("RGB")
X0, X1 = 38, 516                            # con la sombra de la derecha
TOP, CORTE, FONDO = 1411, 1605, 1755      # arriba del guardarropa, empiezan las filas lisas, pared de abajo
D = 105                                    # lo que baja (1,3 casillas de 78,7 px)

moqueta = im.crop((560, 1480, 620, 1540))  # trozo liso de moqueta (sin rayas: varia 1,6 de fila a fila)


def bajar(img):
    out = img.copy()
    arriba = img.crop((X0, TOP, X1, CORTE))                  # mostrador y perchero, se mueven enteros
    abajo = img.crop((X0, CORTE + D, X1, FONDO))             # lo de abajo, sin las D filas lisas
    for y in range(TOP, TOP + D, moqueta.height):            # hueco nuevo: moqueta
        for x in range(X0, X1, moqueta.width):
            out.paste(moqueta, (x, y))
    out.paste(arriba, (X0, TOP + D))
    out.paste(abajo, (X0, CORTE + D))
    return out


b = bajar(im)
# B: quitar las puntas de los taburetes viejos que asomaban bajo la barra (frente de la barra y moqueta debajo)
frente = im.crop((185, 1383, 215, 1400))
for x0, x1 in ((84, 156), (227, 299), (369, 441)):
    for x in range(x0, x1, frente.width):
        b.paste(frente.crop((0, 0, min(frente.width, x1 - x), frente.height)), (x, 1383))
    for x in range(x0, x1, moqueta.width):
        b.paste(moqueta.crop((0, 0, min(moqueta.width, x1 - x), TOP - 1400)), (x, 1400))
b.save(OUT_B)

a = b.copy()
taburete = im.crop((510, 1281, 594, 1390)).convert("RGBA")   # taburete entero de la columna de la derecha
fondo = moqueta.resize((1, 1), Image.BOX).getpixel((0, 0))   # color medio de la moqueta
px = taburete.load()
for y in range(taburete.height):                             # la moqueta de alrededor, transparente
    for x in range(taburete.width):
        r, g, bb, _ = px[x, y]
        if abs(r - fondo[0]) + abs(g - fondo[1]) + abs(bb - fondo[2]) < 45:
            px[x, y] = (0, 0, 0, 0)
a = a.convert("RGBA")
for cx in (120, 263, 405):                                   # centros de los tres taburetes de abajo
    a.alpha_composite(taburete, (cx - 42, 1381))
a = a.convert("RGB")
a.save(OUT_A)
print("hecho")
