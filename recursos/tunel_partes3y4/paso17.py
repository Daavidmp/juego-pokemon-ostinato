# Que casillas se pisan en el mapa 17 (parte 3 del tunel). 43x24. '.' se pasa, '#' no.
# Sale del plano (plano3.py) corregido con lo que dibujo Firefly de verdad.
import sys
sys.argv = ['x']
exec(open('plano3.py').read().split("COL = {")[0])   # trae la rejilla g del plano
P_ = [['#'] * 43 for _ in range(24)]
pasa = set('.ayygWrbD')
for y in range(24):
    for x in range(43):
        if g[y][x] in pasa: P_[y][x] = '.'
def bloquear(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): P_[y][x] = '#'
def abrir(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): P_[y][x] = '.'
# sala de la carretera
bloquear(2, 4, 12, 7); bloquear(3, 8, 10, 8)        # el derrumbe
abrir(13, 5, 17, 8)                                   # la luz del techo cae al suelo: se pisa
bloquear(19, 9, 19, 10)                               # tablon apoyado en la pared
bloquear(2, 18, 4, 20)                                # bidones
bloquear(18, 19, 19, 20)                              # piedras
# el autobus esta en diagonal (no donde lo ponia el plano)
abrir(13, 12, 17, 16)
for xs, ys in [((9, 12), (13, 16)), ((13, 14), (12, 16)), ((15, 16), (12, 15)), ((17, 17), (11, 15))]:
    bloquear(xs[0], ys[0], xs[1], ys[1])
bloquear(22, 5, 22, 5)                                # la cascada
bloquear(2, 13, 2, 13)                                # lampara de la pared izquierda
# el puente: solo la tablazon de en medio
bloquear(20, 12, 24, 12); abrir(20, 13, 24, 14); bloquear(21, 15, 23, 16)
# campamento
bloquear(27, 4, 31, 7)    # tienda
bloquear(32, 5, 34, 5)    # saco (la bolsita de al lado se pisa)
bloquear(36, 4, 40, 7)    # cajas y bidon
bloquear(33, 7, 34, 8)    # hoguera
bloquear(29, 8, 30, 9)    # saco
bloquear(26, 9, 27, 10)   # generador
bloquear(36, 8, 40, 10)   # escombros
# anden
bloquear(30, 17, 32, 19)  # vagoneta
bloquear(26, 20, 29, 21)  # cajas
bloquear(40, 13, 42, 23)  # el marco de la boca de la via y lo de detras
abrir(39, 17, 41, 19)     # la via entra en la boca y lleva a la parte 4 (mapa 18)
if __name__ == '__main__':
    for y in range(24): print('%2d ' % y + ''.join(P_[y]))
