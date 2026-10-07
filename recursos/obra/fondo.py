# quita el fondo verde liso de Firefly (color de la esquina, con tolerancia)
import numpy as np
def quitar_fondo(a, tol=40):
    a = a[..., :3].astype(int)
    c = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), axis=0)
    d = np.abs(a - c).sum(axis=2)
    verde = (a[..., 1] > a[..., 0] + 30) & (a[..., 1] > a[..., 2] + 20)
    alfa = np.where((d < tol) | (verde & (d < tol * 2.5)), 0, 255).astype(np.uint8)
    return np.dstack([a.astype(np.uint8), alfa]), c

def quitar_sueltos(rgba, minimo=12):
    # borra los trocitos sueltos (rayas de movimiento, motas) de menos de 'minimo' pixeles
    h, w = rgba.shape[:2]; visto = np.zeros((h, w), bool); borrados = 0
    for y in range(h):
        for x in range(w):
            if rgba[y, x, 3] == 0 or visto[y, x]: continue
            pila = [(y, x)]; grupo = []; visto[y, x] = True
            while pila:
                cy, cx = pila.pop(); grupo.append((cy, cx))
                for ny, nx in ((cy+1, cx), (cy-1, cx), (cy, cx+1), (cy, cx-1)):
                    if 0 <= ny < h and 0 <= nx < w and not visto[ny, nx] and rgba[ny, nx, 3]:
                        visto[ny, nx] = True; pila.append((ny, nx))
            if len(grupo) < minimo:
                for cy, cx in grupo: rgba[cy, cx, 3] = 0
                borrados += len(grupo)
    return borrados
