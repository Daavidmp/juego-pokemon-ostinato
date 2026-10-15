# Que casillas se pisan en el mapa 18 (parte 4 del tunel). 43x24. '.' se pasa, '#' no.
exec(open('plano4.py').read().split("COL = {")[0])
P_ = [['#'] * 43 for _ in range(24)]
pasa = set('.yrgWbEf')
for y in range(24):
    for x in range(43):
        if g[y][x] in pasa: P_[y][x] = '.'
def bloquear(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): P_[y][x] = '#'
def abrir(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): P_[y][x] = '.'
# --- corregido con lo que dibujo Firefly ---
# galeria
bloquear(3, 2, 4, 4); bloquear(15, 3, 15, 4); bloquear(17, 3, 18, 3); bloquear(8, 5, 10, 6); bloquear(11, 6, 14, 6)
# estacion: banco, taquilla, tope de la via
abrir(9, 13, 11, 14); bloquear(7, 12, 8, 13); bloquear(10, 12, 11, 13); bloquear(9, 16, 10, 18)
# pasillo de abajo: el banco
bloquear(14, 20, 16, 20)
# cruce: taquillas y la pila de cajas (cierra el paso a la sala de bombas)
abrir(21, 16, 22, 17); bloquear(21, 16, 22, 18); bloquear(22, 19, 22, 22); bloquear(20, 21, 21, 22)
# sala hundida: el tocon y la columna caida en diagonal
bloquear(16, 10, 18, 11)
for c in [(23, 12), (24, 12), (24, 13), (25, 13), (25, 14), (26, 14), (26, 15), (27, 15)]: bloquear(c[0], c[1], c[0], c[1])
abrir(26, 14, 27, 14); bloquear(26, 14, 26, 15)
# plataforma de salida: raices, helechos grandes, la tuberia de la derecha
bloquear(33, 6, 35, 8); bloquear(33, 8, 34, 9); bloquear(41, 6, 41, 9); bloquear(40, 10, 41, 12); bloquear(34, 13, 35, 13)
# sala de bombas: las bombas bajan hasta el suelo
bloquear(24, 20, 24, 20); bloquear(35, 20, 35, 20)
if __name__ == '__main__':
    for y in range(24): print('%2d ' % y + ''.join(P_[y]))
