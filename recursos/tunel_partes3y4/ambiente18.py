# Piezas del ambiente del mapa 18 para 029_TunelVivo: agua_18, brillo_18 y oscuro_18
import numpy as np, random, math
from PIL import Image, ImageDraw
T = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/Pokémon Ostinato/Graphics/Pictures/Tunel/"
mapa = np.array(Image.open('mapa18_1376.png').convert('RGBA'))
# el agua de la sala de bombas, sin la pasarela que la cruza
AX, AY, AX1, AY1 = 802, 646, 990, 736
PUENTE = (668, 706)
agua = mapa[AY:AY1, AX:AX1].copy()
for y in range(agua.shape[0]):
    if PUENTE[0] <= AY + y < PUENTE[1]: agua[y, :, 3] = 0
Image.fromarray(agua, 'RGBA').save(T + 'agua_18.png')
h, w = agua.shape[:2]
random.seed(18)
puntos = [(random.uniform(4, w - 8), random.choice([random.uniform(0, PUENTE[0] - AY - 4), random.uniform(PUENTE[1] - AY + 2, h - 3)]), random.uniform(0, 12), random.choice([3, 4, 5])) for _ in range(26)]
tira = Image.new('RGBA', (w * 12, h), (0, 0, 0, 0))
for f in range(12):
    c = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(c)
    for x, y, fase, largo in puntos:
        a = int(165 * math.sin(math.pi * ((f + fase) % 12) / 12.0))
        if a < 20: continue
        xx = (x + f * 1.5) % (w - 6)                 # agua quieta: los reflejos se mecen de lado
        d.ellipse([xx, y, xx + largo, y + 2], outline=(205, 235, 230, a))
    tira.paste(c, (f * w, 0))
tira.save(T + 'brillo_18.png')
H, W = mapa.shape[:2]
yy, xx = np.mgrid[0:H, 0:W].astype(float)
luz = np.zeros((H, W))
LAMPARAS = [(145, 48), (752, 48), (80, 370), (400, 368), (558, 302), (815, 240), (1103, 145), (880, 592)]
for lx, ly in LAMPARAS:
    luz = np.maximum(luz, 0.78 * np.exp(-((xx - lx) ** 2 + (yy - ly) ** 2) / (2 * 46.0 ** 2)))
# la luz del dia: por el techo hundido de la sala de la hierba, y por la escalera de salida
luz = np.maximum(luz, 0.92 * np.exp(-((xx - 735) ** 2 / (2 * 120.0 ** 2) + (yy - 375) ** 2 / (2 * 85.0 ** 2))))
luz = np.maximum(luz, 0.95 * np.exp(-((xx - 1215) ** 2 / (2 * 75.0 ** 2) + (yy - 60) ** 2 / (2 * 150.0 ** 2))))
alfa = (205 * (1 - luz)).clip(16, 205).astype(np.uint8)
osc = np.zeros((H, W, 4), np.uint8); osc[..., 0] = 6; osc[..., 1] = 9; osc[..., 2] = 20; osc[..., 3] = alfa
Image.fromarray(osc, 'RGBA').save(T + 'oscuro_18.png')
Image.alpha_composite(Image.fromarray(mapa), Image.fromarray(osc, 'RGBA')).save('oscuro18_ver.png')
print('agua', agua.shape, 'brillo', tira.size)
