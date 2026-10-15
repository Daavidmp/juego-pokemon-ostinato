# Piezas del ambiente del mapa 17 para 029_TunelVivo: agua_17, brillo_17 y oscuro_17
import numpy as np, random, math
from PIL import Image, ImageDraw
T = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/Pokémon Ostinato/Graphics/Pictures/Tunel/"
mapa = np.array(Image.open('mapa17_1376.png').convert('RGBA'))
# el arroyo: el interior del canal, sin la cascada de arriba ni el puente
AX, AY, AX1, AY1 = 676, 230, 764, 704
PUENTE = (380, 522)
agua = mapa[AY:AY1, AX:AX1].copy()
for y in range(agua.shape[0]):
    if PUENTE[0] <= AY + y < PUENTE[1]: agua[y, :, 3] = 0
Image.fromarray(agua, 'RGBA').save(T + 'agua_17.png')
# los reflejos: 12 fotogramas de aritos claros que bajan con la corriente
h, w = agua.shape[:2]
random.seed(17)
puntos = [(random.uniform(4, w - 8), random.uniform(0, h), random.uniform(0, 12), random.choice([3, 4, 5])) for _ in range(46)]
tira = Image.new('RGBA', (w * 12, h), (0, 0, 0, 0))
for f in range(12):
    cuadro = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(cuadro)
    for x, y, fase, largo in puntos:
        yy = (y + f * 3.0) % h
        if PUENTE[0] - AY - 4 <= yy < PUENTE[1] - AY + 4: continue
        luz = math.sin(math.pi * ((f + fase) % 12) / 12.0)
        a = int(165 * luz)
        if a < 20: continue
        d.ellipse([x, yy, x + largo, yy + 2], outline=(205, 235, 230, a))
    tira.paste(cuadro, (f * w, 0))
tira.save(T + 'brillo_17.png')
# la oscuridad: todo a 205 menos donde hay luz
H, W = mapa.shape[:2]
yy, xx = np.mgrid[0:H, 0:W].astype(float)
luz = np.zeros((H, W))
LAMPARAS = [(110, 110), (335, 110), (592, 110), (72, 430), (880, 82), (1073, 82), (1265, 82), (912, 432), (1232, 432)]
for lx, ly in LAMPARAS:
    luz = np.maximum(luz, 0.78 * np.exp(-((xx - lx) ** 2 + (yy - ly) ** 2) / (2 * 46.0 ** 2)))
# el rayo de luz que entra por el agujero del techo, y la hierba debajo
luz = np.maximum(luz, 0.92 * np.exp(-((xx - 480) ** 2 / (2 * 95.0 ** 2) + (yy - 230) ** 2 / (2 * 130.0 ** 2))))
alfa = (205 * (1 - luz)).clip(16, 205).astype(np.uint8)
osc = np.zeros((H, W, 4), np.uint8); osc[..., 0] = 6; osc[..., 1] = 9; osc[..., 2] = 20; osc[..., 3] = alfa
Image.fromarray(osc, 'RGBA').save(T + 'oscuro_17.png')
print('agua', agua.shape, 'brillo', tira.size, 'oscuro', (W, H), 'alfa', alfa.min(), alfa.max())
# como se ve: el mapa con la oscuridad encima
ver = Image.alpha_composite(Image.fromarray(mapa), Image.fromarray(osc, 'RGBA'))
ver.save('oscuro17_ver.png')
