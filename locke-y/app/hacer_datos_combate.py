"""Crea app/datos_combate.json: lo que necesita el combate en línea (2.3.0) para calcular los turnos sin internet.

  tools/python312/python.exe app/hacer_datos_combate.py <carpeta con moves.json, pokedex.json y typechart.js de Showdown>

Sale de los datos de Pokémon Showdown (https://play.pokemonshowdown.com/data/), los nombres de los ataques en español
de app/datos_pkx/Moves.txt (el mismo índice que en el juego) y solo los ataques y especies de la 6.ª generación
(los de Pokémon Y). Por ataque: [nombre, tipo, categoría, potencia, precisión, PP, prioridad, efectos].
"""
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
fuente = Path(sys.argv[1])
MAX_ATAQUE, MAX_ESPECIE = 621, 721

TIPOS = {'Normal': 'NORMAL', 'Fire': 'FIRE', 'Water': 'WATER', 'Electric': 'ELECTRIC', 'Grass': 'GRASS', 'Ice': 'ICE',
         'Fighting': 'FIGHTING', 'Poison': 'POISON', 'Ground': 'GROUND', 'Flying': 'FLYING', 'Psychic': 'PSYCHIC',
         'Bug': 'BUG', 'Rock': 'ROCK', 'Ghost': 'GHOST', 'Dragon': 'DRAGON', 'Dark': 'DARK', 'Steel': 'STEEL', 'Fairy': 'FAIRY'}
STATS = {'atk': 'atk', 'def': 'def', 'spa': 'spa', 'spd': 'spd', 'spe': 'spe', 'accuracy': 'acc', 'evasion': 'eva'}

moves = json.loads((fuente / 'moves.json').read_text(encoding='utf-8'))
dex = json.loads((fuente / 'pokedex.json').read_text(encoding='utf-8'))
tabla = (fuente / 'typechart.js').read_text(encoding='utf-8')
nombres = [l.strip() for l in (RAIZ / 'app' / 'datos_pkx' / 'Moves.txt').read_text(encoding='utf-8-sig').splitlines()]


def subidas(b):
    return {STATS[k]: v for k, v in (b or {}).items() if k in STATS}


ataques = {}
for m in moves.values():
    n = m.get('num', 0)
    if not 0 < n <= MAX_ATAQUE or m.get('isZ') or m.get('isMax') or m['type'] not in TIPOS:
        continue
    ef = {}
    yo = m.get('target') == 'self' or m.get('target') == 'adjacentAllyOrSelf'
    if m.get('boosts'):
        ef['yo' if yo else 'b'] = subidas(m['boosts'])
    if m.get('self') and m['self'].get('boosts'):
        ef['yo'] = subidas(m['self']['boosts'])
    if m.get('status'):
        ef['st'] = m['status']
    if m.get('volatileStatus') == 'confusion':
        ef['conf'] = 1
    sec = m.get('secondary') or (m.get('secondaries') or [None])[0]
    if sec and sec.get('chance'):
        s = {'p': sec['chance']}
        if sec.get('status'):
            s['st'] = sec['status']
        if sec.get('boosts'):
            s['b'] = subidas(sec['boosts'])
        if sec.get('self') and sec['self'].get('boosts'):
            s['yo'] = subidas(sec['self']['boosts'])
        if sec.get('volatileStatus') == 'flinch':
            s['acobardar'] = 1
        if sec.get('volatileStatus') == 'confusion':
            s['conf'] = 1
        if len(s) > 1:
            ef['sec'] = s
    if m.get('drain'):
        ef['dr'] = m['drain'][0] / m['drain'][1]
    if m.get('recoil'):
        ef['rc'] = m['recoil'][0] / m['recoil'][1]
    if m.get('heal'):
        ef['cura'] = m['heal'][0] / m['heal'][1]
    if m.get('multihit'):
        ef['multi'] = m['multihit'] if isinstance(m['multihit'], list) else [m['multihit'], m['multihit']]
    if m.get('critRatio', 1) > 1:
        ef['crit'] = m['critRatio']
    if m.get('damage'):
        ef['fijo'] = m['damage']                  # 'level' (Sísmico, Tinieblas) o un número (Furia Dragón 40)
    if m.get('ohko'):
        ef['ohko'] = 1
    if m.get('stallingMove') and m.get('volatileStatus') == 'protect':
        ef['protege'] = 1
    if m.get('selfdestruct'):
        ef['explota'] = 1
    if (m.get('flags') or {}).get('charge'):
        ef['carga'] = 1
    if (m.get('flags') or {}).get('recharge'):
        ef['recarga'] = 1
    cat = {'Physical': 'F', 'Special': 'E', 'Status': 'S'}[m['category']]
    nombre = nombres[n] if n < len(nombres) and nombres[n] else m['name']
    ataques[n] = [nombre, TIPOS[m['type']], cat, m.get('basePower', 0), 0 if m['accuracy'] is True else m['accuracy'],
                  m.get('pp', 5), m.get('priority', 0), ef]

especies = {}
for d in dex.values():
    n = d.get('num', 0)
    if 0 < n <= MAX_ESPECIE and not d.get('forme') and n not in especies:
        especies[n] = [TIPOS[t] for t in d['types']]

# la tabla de tipos: lo que recibe cada tipo de cada otro (Showdown: 0 normal, 1 débil, 2 resiste, 3 inmune)
efic = {}
for tipo, cuerpo in re.findall(r'(\w+):\{damageTaken:\{([^}]*)\}', tabla):
    t = TIPOS.get(tipo.capitalize())
    if not t:
        continue
    efic[t] = {}
    for at, v in re.findall(r'(\w+):(\d)', cuerpo):
        if at in TIPOS:
            efic[t][TIPOS[at]] = {'0': 1, '1': 2, '2': 0.5, '3': 0}[v]

salida = {'fuente': 'Pokémon Showdown (data/moves.json, pokedex.json, typechart.js)', 'ataques': ataques, 'especies': especies, 'eficacia': efic}
f = RAIZ / 'app' / 'datos_combate.json'
f.write_text(json.dumps(salida, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
print(f, len(ataques), 'ataques', len(especies), 'especies', len(efic), 'tipos', f.stat().st_size // 1024, 'KB')
