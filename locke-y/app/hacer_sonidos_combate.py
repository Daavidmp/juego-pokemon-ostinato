"""Copia a assets/combate/sonidos los sonidos del combate en línea (2.3.2), sacados de Pokémon Ostinato (Audio/SE):

  tools/python312/python.exe app/hacer_sonidos_combate.py <Audio/SE de Ostinato> <pokedex.json y moves.json de Showdown>

- gritos/<especie>.ogg: el grito de cada especie de la 1.ª a la 6.ª generación (Audio/SE/Cries/<NOMBRE>.ogg).
- ataques/<archivo>: el sonido de cada ataque (Audio/SE/Anim/<nombre en inglés>.ogg si existe; si no, uno de su tipo).
- golpe_normal/super/debil, debilitado, vuelve, sube, baja: los del combate de Ostinato.
- mapa.json: {ataque: archivo} para que la app sepa cuál sonar.
"""
import json
import re
import shutil
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SE, SHOWDOWN = Path(sys.argv[1]), Path(sys.argv[2])
SALIDA = RAIZ / 'assets' / 'combate' / 'sonidos'
shutil.rmtree(SALIDA, ignore_errors=True)
(SALIDA / 'gritos').mkdir(parents=True)
(SALIDA / 'ataques').mkdir(parents=True)

# los de siempre del combate
for origen, destino in [('Battle damage normal', 'golpe_normal'), ('Battle damage super', 'golpe_super'), ('Battle damage weak', 'golpe_debil'),
                        ('Pkmn faint', 'debilitado'), ('Battle recall', 'vuelve'), ('Anim/Up', 'sube'), ('Anim/Harden', 'baja'),
                        ('GUI sel cursor', 'cursor'), ('GUI sel decision', 'elige'), ('Anim/Recovery', 'cura'),
                        ('Anim/Paralyze1', 'estado')]:
    shutil.copy2(SE / f'{origen}.ogg', SALIDA / f'{destino}.ogg')

# gritos: el nombre interno de Essentials (en mayúsculas, sin espacios ni signos)
dex = json.loads((SHOWDOWN / 'pokedex.json').read_text(encoding='utf-8'))
ESPECIALES = {29: 'NIDORANfE', 32: 'NIDORANmA'}
gritos = 0
for d in dex.values():
    n = d.get('num', 0)
    if not 0 < n <= 721 or d.get('forme'):
        continue
    nombre = ESPECIALES.get(n) or re.sub('[^A-Z0-9]', '', d['name'].upper().replace('É', 'E'))
    f = SE / 'Cries' / f'{nombre}.ogg'
    if f.exists() and not (SALIDA / 'gritos' / f'{n}.ogg').exists():
        shutil.copy2(f, SALIDA / 'gritos' / f'{n}.ogg')
        gritos += 1

# ataques: el suyo por nombre en inglés; si no hay, uno de su tipo (físico, especial o de estado)
POR_TIPO = {'NORMAL': 'Blow1', 'FIRE': 'Fire3', 'WATER': 'Water1', 'ELECTRIC': 'Thunder1', 'GRASS': 'Slash2', 'ICE': 'Ice2',
            'FIGHTING': 'Blow4', 'POISON': 'Poison', 'GROUND': 'Earth3', 'FLYING': 'Wind1', 'PSYCHIC': 'Saint3', 'BUG': 'Slash3',
            'ROCK': 'Earth5', 'GHOST': 'Darkness2', 'DRAGON': 'Explosion2', 'DARK': 'Darkness6', 'STEEL': 'Sword1', 'FAIRY': 'Saint8'}
TIPOS = {'Normal': 'NORMAL', 'Fire': 'FIRE', 'Water': 'WATER', 'Electric': 'ELECTRIC', 'Grass': 'GRASS', 'Ice': 'ICE',
         'Fighting': 'FIGHTING', 'Poison': 'POISON', 'Ground': 'GROUND', 'Flying': 'FLYING', 'Psychic': 'PSYCHIC',
         'Bug': 'BUG', 'Rock': 'ROCK', 'Ghost': 'GHOST', 'Dragon': 'DRAGON', 'Dark': 'DARK', 'Steel': 'STEEL', 'Fairy': 'FAIRY'}
moves = json.loads((SHOWDOWN / 'moves.json').read_text(encoding='utf-8'))
mapa, propios = {}, 0
for m in moves.values():
    n = m.get('num', 0)
    if not 0 < n <= 621 or m.get('isZ') or m.get('isMax') or m['type'] not in TIPOS:
        continue
    propio = SE / 'Anim' / f'{m["name"]}.ogg'
    if propio.exists():
        archivo = f'{n}.ogg'
        shutil.copy2(propio, SALIDA / 'ataques' / archivo)
        propios += 1
    else:
        base = 'Up' if m['category'] == 'Status' and m.get('target') == 'self' else 'Confuse' if m['category'] == 'Status' else POR_TIPO[TIPOS[m['type']]]
        archivo = f'{base}.ogg'
        if not (SALIDA / 'ataques' / archivo).exists():
            shutil.copy2(SE / 'Anim' / archivo, SALIDA / 'ataques' / archivo)
    mapa[n] = archivo
# también por el nombre interno del motor de Ostinato (los sucesos 'anim' traen el ataque así)
ids = json.loads((RAIZ / 'app' / 'ids_ostinato.json').read_text(encoding='utf-8'))['ataques']
for n, archivo in list(mapa.items()):
    if str(n) in ids:
        mapa[ids[str(n)]] = archivo
(SALIDA / 'mapa.json').write_text(json.dumps(mapa, separators=(',', ':')), encoding='utf-8')
peso = sum(f.stat().st_size for f in SALIDA.rglob('*') if f.is_file())
print(f'{gritos} gritos, {propios} ataques con su sonido ({len(mapa)} en total), {peso / 2**20:.1f} MB')
