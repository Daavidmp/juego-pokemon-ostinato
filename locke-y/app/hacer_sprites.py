"""Copia a assets/combate/pk los Pokémon de combate de Pokémon Ostinato (los animados de Graphics/Pokemon/Animados, como
el plugin 033) para el combate en línea (2.4.1), con lo que hace falta para ponerlos igual que el juego.

  tools/build-venv/Scripts/python app/hacer_sprites.py <carpeta del juego>

1. exportar_sprites.rb dice, por especie y forma, qué tira usa el juego para cada sexo, variocolor y lado, su velocidad
   y las medidas de la especie (species_metrics).
2. Aquí se copian las tiras (una vez cada archivo, con nombre seguro) y se mide cada una: cuántos cuadros (cuadrados, del
   alto de la tira) y cuántas filas vacías deja debajo (la menor de todos sus cuadros, como OstTira: el juego apoya los
   pies en el suelo con eso).
3. sprites.json: {"ESPECIE_forma": {back, front, altitud, d: {clave: [archivo, cuadros, lado, vacío, velocidad]}}}
   con clave m/h (macho/hembra) + s (variocolor) + f/b (frente/espalda).
"""
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
JUEGO = Path(sys.argv[1])
SALIDA = RAIZ / 'assets' / 'combate' / 'pk'
shutil.rmtree(SALIDA, ignore_errors=True)
SALIDA.mkdir(parents=True)
tmp = Path(tempfile.mkdtemp())
ids = json.loads((RAIZ / 'app' / 'ids_ostinato.json').read_text(encoding='utf-8'))
(tmp / 'especies.json').write_text(json.dumps(sorted(set(ids['especies'].values()))), encoding='utf-8')
subprocess.run([str(RAIZ / 'tools' / 'ruby' / 'bin' / 'ruby.exe'), '--disable-gems', str(RAIZ / 'app' / 'ostinato' / 'exportar_sprites.rb'),
                str(JUEGO), str(tmp / 'especies.json'), str(tmp / 'sprites.json')], check=True, stderr=subprocess.DEVNULL)
datos = json.loads((tmp / 'sprites.json').read_text(encoding='utf-8'))

medidas = {}


def medir(rel):
    """[archivo copiado, cuadros, lado, filas vacías debajo] de una tira del juego (una vez por archivo)."""
    if rel in medidas:
        return medidas[rel]
    origen = JUEGO / rel
    partes = Path(rel).parts                    # Graphics/Pokemon/Animados/Front shiny/X.png
    carpeta = re.sub(r'[^\w]', '', partes[-2].lower())
    nombre = f'{carpeta}_{re.sub(r"[^\w.-]", "_", partes[-1])}'
    im = Image.open(origen).convert('RGBA')
    lado = im.height
    cuadros = im.width // lado if im.width > lado and im.width % lado == 0 else 1
    ancho = lado if cuadros > 1 else im.width
    alfa = im.getchannel('A')
    vacio = lado
    for i in range(cuadros):
        caja = alfa.crop((i * ancho, 0, (i + 1) * ancho, lado)).getbbox()
        vacio = min(vacio, lado - caja[3] if caja else lado)
    shutil.copy2(origen, SALIDA / nombre)
    medidas[rel] = [nombre, cuadros, ancho, lado, vacio]
    return medidas[rel]


salida = {}
for clave, d in datos.items():
    dibujos = {}
    for k, x in d['dibujos'].items():
        rel = x['anim'] or x['fijo']
        if rel:
            archivo, cuadros, ancho, lado, vacio = medir(rel)
            dibujos[k] = [archivo, cuadros, ancho, lado, vacio, x['vel'], bool(x['anim'])]
    salida[clave] = {'back': d['back'], 'front': d['front'], 'altitud': d['altitud'], 'sombra_x': d['sombra_x'], 'sombra': d['sombra'], 'd': dibujos}
# las sombras del rival (Graphics/Pokemon/Shadow/1-3)
for n in (1, 2, 3):
    if (JUEGO / 'Graphics' / 'Pokemon' / 'Shadow' / f'{n}.png').exists():
        shutil.copy2(JUEGO / 'Graphics' / 'Pokemon' / 'Shadow' / f'{n}.png', SALIDA / f'sombra_{n}.png')
(SALIDA / 'sprites.json').write_text(json.dumps(salida, separators=(',', ':')), encoding='utf-8')
peso = sum(f.stat().st_size for f in SALIDA.iterdir())
print(f'{len(salida)} especies y formas, {len(medidas)} tiras, {peso / 2**20:.1f} MB')
