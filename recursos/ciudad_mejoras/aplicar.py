"""Mejoras de la ciudad del gimnasio (mapa 19, tileset 50 «Ciudad Gimnasio»). Se puede volver a ejecutar sobre
cualquier versión del mapa: lo que ya está hecho no se repite.

  python3 aplicar.py            (con RPG Maker XP cerrado)

- Coches aparcados y furgoneta de comida al 72 %: cada uno se recompone desde sus casillas del tileset, se reduce por
  media de área y cada píxel vuelve al color más parecido de su paleta (sigue siendo pixel art). Se queda en su
  mismo hueco, apoyado abajo y centrado, y sus casillas nuevas van al final del tileset con el mismo paso y prioridad.
  Las que quedan vacías se quitan del mapa: ahí ya se puede pasar.
- Línea discontinua en el centro de las carreteras de dos carriles (no en los cruces ni junto a los pasos de cebra).

Antes de escribir deja copia de Map019.rxdata, Tilesets.rxdata y Ciudad_Gimnasio.png en ./copias/<fecha>/.
"""
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, '/mnt/c/Users/david.martinez/pkmn-devkit')
from devkit.rxdata import marshal          # noqa: E402
from PIL import Image                      # noqa: E402

AQUI = Path(__file__).resolve().parent
JUEGO = AQUI.parent.parent / 'Pokémon Ostinato'
F_MAPA, F_TILESETS = JUEGO / 'Data/Map019.rxdata', JUEGO / 'Data/Tilesets.rxdata'
F_HOJA = JUEGO / 'Graphics/Tilesets/Ciudad_Gimnasio.png'
TILESET, ESCALA = 50, .72
# los vehículos: casilla de arriba a la izquierda en el tileset (id), ancho y alto en casillas
VEHICULOS = {'coche azul': (7512, 4, 2), 'coche rojo': (7612, 4, 2), 'coche rosa': (7624, 4, 3), 'coche verde': (7656, 4, 2),
             'furgoneta': (7264, 5, 4)}
ASFALTO = 7241
LINEA = (232, 230, 220, 255)


def casilla(hoja, t):
    i = t - 384
    return hoja.crop((i % 8 * 32, i // 8 * 32, i % 8 * 32 + 32, i // 8 * 32 + 32))


def reducir(im, f):
    """Media de área y cada píxel al color más parecido de la paleta de la pieza."""
    pal = list({im.getpixel((x, y)) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3] > 200})
    r = im.resize((round(im.width * f), round(im.height * f)), Image.BOX)
    out = Image.new('RGBA', r.size)
    for y in range(r.height):
        for x in range(r.width):
            c = r.getpixel((x, y))
            if c[3] >= 110:
                out.putpixel((x, y), min(pal, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2))
    return out


def main():
    mapa, tilesets = marshal.load_file(F_MAPA), marshal.load_file(F_TILESETS)
    ts, d = tilesets[TILESET], mapa['data']
    hoja = Image.open(F_HOJA).convert('RGBA')
    pas, pri = ts['passages'], ts['priorities']
    tags = ts['terrain_tags']
    nuevas = []                                     # (imagen, paso, prioridad) de las casillas que se añaden

    filas = hoja.height // 32
    existentes = {}                                 # casillas que ya hay en el tileset, por su contenido
    for k in range(filas * 8 - 1, -1, -1):
        existentes[casilla(hoja, 384 + k).tobytes()] = 384 + k

    def id_de(img, paso, prio):
        """La casilla en el tileset: si ya existe una igual (de otra vez que se ejecutó), esa; si no, una nueva."""
        datos = img.tobytes()
        if datos in existentes and existentes[datos] >= 384 + 8:      # la casilla vacía del principio no cuenta
            return existentes[datos]
        for k, (im, _, _) in enumerate(nuevas):
            if im.tobytes() == datos:
                return 384 + filas * 8 + k
        nuevas.append((img, paso, prio))
        return 384 + filas * 8 + len(nuevas) - 1

    cambios = 0
    # --- vehículos más pequeños ---
    for nombre, (arriba, w, h) in VEHICULOS.items():
        bloque = [[arriba + r * 8 + c for c in range(w)] for r in range(h)]
        pieza = Image.new('RGBA', (w * 32, h * 32))
        for r in range(h):
            for c in range(w):
                pieza.alpha_composite(casilla(hoja, bloque[r][c]), (c * 32, r * 32))
        caja = pieza.getbbox()
        chico = reducir(pieza.crop(caja), ESCALA)
        nueva = Image.new('RGBA', pieza.size)
        nueva.alpha_composite(chico, ((caja[0] + caja[2] - chico.width) // 2, caja[3] - chico.height))   # centrado y apoyado
        ids = [[None] * w for _ in range(h)]
        for r in range(h):
            for c in range(w):
                trozo = nueva.crop((c * 32, r * 32, c * 32 + 32, r * 32 + 32))
                ids[r][c] = 0 if trozo.getbbox() is None else id_de(trozo, pas[bloque[r][c]], pri[bloque[r][c]])
        for z in range(d.zsize):
            for y in range(d.ysize - h + 1):
                for x in range(d.xsize - w + 1):
                    if all(d[x + c, y + r, z] == bloque[r][c] for r in range(h) for c in range(w)):
                        for r in range(h):
                            for c in range(w):
                                d.values[(x + c) + (y + r) * d.xsize + z * d.xsize * d.ysize] = ids[r][c]
                        print(f'{nombre}: en ({x}, {y}), capa {z}, al {round(ESCALA * 100)} %')
                        cambios += 1

    # --- línea del centro de la carretera ---
    asfalto = casilla(hoja, ASFALTO)
    v = asfalto.copy()                      # carril izquierdo de una carretera vertical: raya en su borde derecho
    h_ = asfalto.copy()                     # carril de arriba de una horizontal: raya en su borde de abajo
    for k in range(6, 26):
        for g in (29, 30, 31):
            v.putpixel((g, k), LINEA)
            h_.putpixel((k, g), LINEA)
    id_v, id_h = id_de(v, pas[ASFALTO], pri[ASFALTO]), id_de(h_, pas[ASFALTO], pri[ASFALTO])
    a = lambda x, y: 0 <= x < d.xsize and 0 <= y < d.ysize and d[x, y, 0] in (ASFALTO, id_v, id_h)
    vert, hori = set(), set()
    for y in range(d.ysize):
        for x in range(d.xsize):
            if d[x, y, 0] != ASFALTO:
                continue
            # vertical: dos carriles de ancho (x, x+1), con bordillo a los lados y asfalto dos casillas arriba y abajo
            if a(x + 1, y) and not a(x - 1, y) and not a(x + 2, y) and all(a(x, y + k) and a(x + 1, y + k) for k in (-2, -1, 1, 2)) \
                    and not any(a(x - 1, y + k) or a(x + 2, y + k) for k in (-2, -1, 1, 2)):
                vert.add((x, y))
            elif a(x, y + 1) and not a(x, y - 1) and not a(x, y + 2) and all(a(x + k, y) and a(x + k, y + 1) for k in (-2, -1, 1, 2)) \
                    and not any(a(x + k, y - 1) or a(x + k, y + 2) for k in (-2, -1, 1, 2)):
                hori.add((x, y))
    # solo tramos de 3 casillas o más: una raya suelta en medio del asfalto queda rara
    tramo = lambda s, x, y, dx, dy: sum(1 for k in range(-2, 3) if (x + k * dx, y + k * dy) in s and all((x + j * dx, y + j * dy) in s for j in range(min(0, k), max(0, k) + 1)))
    raya = 0
    for (x, y) in vert:
        if tramo(vert, x, y, 0, 1) >= 3:
            d.values[x + y * d.xsize] = id_v
            raya += 1
    for (x, y) in hori:
        if tramo(hori, x, y, 1, 0) >= 3:
            d.values[x + y * d.xsize] = id_h
            raya += 1
    print('línea del centro:', raya, 'casillas')

    if not cambios and not raya and not nuevas:
        print('Nada que hacer: ya estaba aplicado.')
        return
    copia = AQUI / 'copias' / time.strftime('%Y%m%d_%H%M%S')
    copia.mkdir(parents=True)
    for f in (F_MAPA, F_TILESETS, F_HOJA):
        shutil.copy2(f, copia / f.name)
    if nuevas:
        filas = hoja.height // 32
        extra = (len(nuevas) + 7) // 8
        grande = Image.new('RGBA', (256, (filas + extra) * 32))
        grande.paste(hoja, (0, 0))
        for k, (im, _, _) in enumerate(nuevas):
            grande.paste(im, (k % 8 * 32, (filas + k // 8) * 32))
        grande.save(F_HOJA)
        total = 384 + (filas + extra) * 8
        for tabla in (pas, pri, tags):
            tabla.values.extend([0] * (total - len(tabla.values)))
            tabla.xsize = total
        for k, (_, paso, prio) in enumerate(nuevas):
            pas.values[384 + filas * 8 + k], pri.values[384 + filas * 8 + k] = paso, prio
        print('casillas nuevas en el tileset:', len(nuevas), f'(filas {filas}-{filas + extra - 1}, alto {grande.height} px)')
    marshal.dump_file(F_TILESETS, tilesets)
    marshal.dump_file(F_MAPA, mapa)
    print('copia en', copia)


if __name__ == '__main__':
    main()
