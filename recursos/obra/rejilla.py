# mide el periodo y la fase de la rejilla de pixel de una imagen de Firefly y la reduce a su tamano real
from PIL import Image
import numpy as np, sys
def medir(e, lo, hi):
    e = e - e.mean(); n = len(e); mejor = None
    for p in np.arange(lo, hi, 0.005):
        ph = np.exp(2j * np.pi * np.arange(n) / p); c = (e * ph).sum()
        if mejor is None or abs(c) > mejor[0]: mejor = (abs(c), p, np.angle(c))
    _, p, ang = mejor
    borde = (ang / (2 * np.pi)) * p % p      # donde caen los bordes (diferencias)
    return p, borde
def reducir(path, lo, hi, out):
    im = Image.open(path).convert('RGB'); a = np.array(im).astype(float)
    gx = np.abs(np.diff(a, axis=1)).sum(axis=(0, 2)); gy = np.abs(np.diff(a, axis=0)).sum(axis=(1, 2))
    px, bx = medir(gx, lo[0], hi[0]); py, by = medir(gy, lo[1], hi[1])
    # los bordes estan entre i e i+1 -> el centro de la celda queda medio periodo despues
    cx = np.arange(bx + 0.5 + px / 2, im.width, px); cy = np.arange(by + 0.5 + py / 2, im.height, py)
    xs = np.clip(np.round(cx).astype(int), 0, im.width - 1); ys = np.clip(np.round(cy).astype(int), 0, im.height - 1)
    nat = a[ys][:, xs].astype(np.uint8)
    Image.fromarray(nat).save(out)
    print(path, 'periodo', round(px, 3), round(py, 3), 'fase', round(bx, 2), round(by, 2), '->', nat.shape[1], 'x', nat.shape[0])
if __name__ == '__main__':
    reducir(sys.argv[1], (float(sys.argv[2]), float(sys.argv[4])), (float(sys.argv[3]), float(sys.argv[5])), sys.argv[6])
