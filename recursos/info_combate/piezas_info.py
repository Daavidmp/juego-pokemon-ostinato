# Piezas fijas del modal de Info (Y) del combate, sacadas del diseño de Claude Design
# (InfoCombate.dc.html). Todo en coordenadas del panel: x 0-775 (pantalla 1144-1919), y 0-1079.
import json, os, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = os.path.dirname(os.path.abspath(__file__))
OUT = 'C:/Users/ASUS/Music/Pokemon Ostinato/Pokémon Ostinato/Graphics/UI/Ostinato/Combate/info/'
os.makedirs(OUT + 'tipos', exist_ok=True)
SS = 4  # superposicion para suavizar

def hexc(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def capa(w, h):
    return Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))

def baja(im, w, h):
    return im.resize((w, h), Image.LANCZOS)

def poli(d, pts, color):
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=color)

W, H = 776, 1080
panel = Image.open(os.path.join(S, 'panel_info2.png')).convert('RGBA')

# barras gruesas (27 px): gris desde 0 hasta la diagonal izquierda, oscura entre las dos diagonales
L = lambda y: 600.7 - 0.3665 * y
R = lambda y: 779.7 - 0.349 * y
def barras(d, ys):
    for y0 in ys:
        y1 = y0 + 27
        poli(d, [(0, y0), (L(y0), y0), (L(y1), y1), (0, y1)], hexc('706C6C') + (255,))
        poli(d, [(L(y0), y0), (R(y0), y0), (R(y1), y1), (L(y1), y1)], hexc('423E3E') + (255,))

def celda(d, x, y):
    d.rectangle([x * SS, y * SS, (x + 288) * SS - 1, (y + 62) * SS - 1], fill=hexc('D3D3D1') + (255,))

def hoja(base, ys_barras, celdas, extra=None):
    im = base.copy()
    ImageDraw.Draw(im).rectangle([0, 147, W - 1, 1013], fill=(255, 255, 255, 255))
    c = capa(W, H); d = ImageDraw.Draw(c)
    for x, y in celdas: celda(d, x, y)
    if extra: extra(d)
    barras(d, ys_barras)
    im.alpha_composite(baja(c, W, H))
    return im

# 1. grafica: el hexagono gris y los radios blancos (el morado lo pinta el juego)
g = panel.copy()
c = capa(W, H); d = ImageDraw.Draw(c)
HEX = [(360, 233), (514, 316), (514, 483), (360, 566), (206, 483), (206, 316)]
poli(d, HEX, hexc('D3D3D1') + (255,))
for v in HEX:
    d.line([(360 * SS, 400 * SS), (v[0] * SS, v[1] * SS)], fill=(255, 255, 255, 255), width=3 * SS)
g.alpha_composite(baja(c, W, H))
g.save(OUT + 'fondo_grafica.png')

# 2. ruta: barras en 350 y 575, casillas debajo (y de pantalla = la del panel)
hoja(panel, [350, 575], [(0, 377), (0, 602)]).save(OUT + 'fondo_ruta.png')
# 3. cambios: barra en 562; individual 2 casillas, doble 4
hoja(panel, [562], [(0, 147), (0, 589)]).save(OUT + 'fondo_cambios1.png')
hoja(panel, [562], [(0, 147), (388, 147), (0, 589), (388, 589)]).save(OUT + 'fondo_cambios2.png')
# 4. info: barras en 600 y 830, casillas Curiosidad y Debilidades, circulo del retrato
def circulo_retrato(d):
    d.ellipse([238 * SS, 232 * SS, 538 * SS - 1, 532 * SS - 1], fill=hexc('EDEDEB') + (255,))
hoja(panel, [600, 830], [(0, 627), (0, 857)], circulo_retrato).save(OUT + 'fondo_info.png')

# iconos de la barra de arriba: gris (#423E3E) y el de la vista actual en negro
for i in range(1, 5):
    m = np.array(Image.open(os.path.join(S, 'icono%d.png' % i)))[..., 3]
    for suf, col in (('', '423E3E'), ('_sel', '000000')):
        a = np.zeros(m.shape + (4,), np.uint8); a[..., :3] = hexc(col); a[..., 3] = m
        Image.fromarray(a).save(OUT + 'icono%d%s.png' % (i, suf))

# flechitas de los cambios (como el path del diseño) y el puntito
def flecha(nombre, a, w=40):
    c = capa(w, 44); d = ImageDraw.Draw(c)
    x = w / 2
    pts = [(x, 6), (x + a, 24), (x + a * .44, 24), (x + a * .44, 40), (x - a * .44, 40), (x - a * .44, 24), (x - a, 24)]
    sp = [(px * SS, py * SS) for px, py in pts]
    d.polygon(sp, fill=hexc('E24A3B') + (255,))
    d.line(sp + [sp[0]], fill=hexc('7A1F17') + (255,), width=int(1.5 * SS), joint='curve')
    baja(c, w, 44).save(OUT + nombre)
flecha('flecha_g.png', 16)       # individual: a = 16 (paso 72)
flecha('flecha_p.png', 13, 32)   # doble: a = 13 (paso 36)
c = capa(14, 14); ImageDraw.Draw(c).ellipse([1 * SS, 1 * SS, 13 * SS - 1, 13 * SS - 1], fill=hexc('BDBDBA') + (255,))
baja(c, 14, 14).save(OUT + 'punto.png')

# casilla de los Pokemon de la ruta y el circulo de "?"
c = capa(128, 150); ImageDraw.Draw(c).rounded_rectangle([0, 0, 128 * SS - 1, 150 * SS - 1], radius=12 * SS, fill=hexc('EDEDEB') + (255,))
baja(c, 128, 150).save(OUT + 'casilla.png')
c = capa(80, 80); ImageDraw.Draw(c).ellipse([0, 0, 80 * SS - 1, 80 * SS - 1], fill=hexc('C9C9C6') + (255,))
baja(c, 80, 80).save(OUT + 'interrogante.png')

# circulo blanco de 64 (se tine del color del tipo) y su sombra (0 2px 4px rgba(0,0,0,.25))
c = capa(64, 64); ImageDraw.Draw(c).ellipse([0, 0, 64 * SS - 1, 64 * SS - 1], fill=(255, 255, 255, 255))
baja(c, 64, 64).save(OUT + 'circulo_tipo.png')
sh = Image.new('RGBA', (80, 80), (0, 0, 0, 0))
ImageDraw.Draw(sh).ellipse([8, 10, 71, 73], fill=(0, 0, 0, 64))
sh.filter(ImageFilter.GaussianBlur(2)).save(OUT + 'sombra_tipo.png')   # se pone en (x-8, y-8)

# sombra del modal: -6px 0 18px rgba(0,0,0,.35) -> franja a la izquierda del panel
big = Image.new('L', (200, H + 120), 0)
ImageDraw.Draw(big).rectangle([100 - 6, 0, 199, H + 119], fill=int(255 * .35))
big = big.filter(ImageFilter.GaussianBlur(9))
franja = big.crop((40, 60, 100, 60 + H))           # los 60 px de la izquierda del borde
a = np.zeros((H, 60, 4), np.uint8); a[..., 3] = np.array(franja)
Image.fromarray(a).save(OUT + 'sombra_modal.png')

# iconos de los tipos (los blancos de la tabla del .kra), por el id del juego
TIPOS = {'Normal': 'NORMAL', 'Lucha': 'FIGHTING', 'Volador': 'FLYING', 'Veneno': 'POISON', 'Tierra': 'GROUND',
         'Roca': 'ROCK', 'Bicho': 'BUG', 'Fantasma': 'GHOST', 'Acero': 'STEEL', 'Fuego': 'FIRE', 'Agua': 'WATER',
         'Planta': 'GRASS', 'Eléctrico': 'ELECTRIC', 'Psíquico': 'PSYCHIC', 'Hielo': 'ICE', 'Dragón': 'DRAGON',
         'Siniestro': 'DARK', 'Hada': 'FAIRY'}
D = os.path.join(os.path.dirname(S), 'design')
for es, id_ in TIPOS.items():
    Image.open(os.path.join(D, 'assets4', 'tipo_%s.png' % es)).convert('RGBA').resize((46, 46), Image.LANCZOS).save(OUT + 'tipos/%s.png' % id_)
col = json.load(open(os.path.join(D, 'tipos.json'), encoding='utf-8'))
print({TIPOS[k]: v for k, v in col.items()})
print('hecho')
