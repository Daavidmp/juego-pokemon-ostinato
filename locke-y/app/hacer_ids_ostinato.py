"""Crea app/ids_ostinato.json: de los números de Pokémon X/Y (los de la partida) a los nombres internos del motor de
Pokémon Ostinato (Essentials), para el combate en línea con su motor (2.4.0).

  tools/python312/python.exe app/hacer_ids_ostinato.py <datos de Showdown> <ids.json sacado del motor>

Los datos de Showdown (pokedex.json, moves.json, abilities.js, items.js) dan número -> nombre en inglés; el nombre interno
de Essentials es ese nombre en mayúsculas y sin signos (con sus excepciones). ids.json es la lista de nombres que
existen en el motor (motor/ids.rb).
"""
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SD, IDS = Path(sys.argv[1]), Path(sys.argv[2])
ids = json.loads(IDS.read_text(encoding='utf-8'))
existe = {k: set(e[0] if isinstance(e, list) else e for e in v) for k, v in ids.items()}


def js(nombre):
    texto = (SD / nombre).read_text(encoding='utf-8')
    # cada entrada: ...name:"Nombre"... num:N (puede haber llaves dentro, así que se busca el num más cercano)
    salida = {}
    for m in re.finditer(r'name:"([^"]+)"', texto):
        n = re.search(r'num:(-?\d+)', texto[m.end():m.end() + 2000])
        if n:
            salida.setdefault(m[1], {'num': int(n[1]), 'name': m[1]})
    return salida


def interno(nombre):
    return re.sub('[^A-Z0-9]', '', nombre.upper().replace('É', 'E').replace('♀', 'F').replace('♂', 'M'))


ESPECIALES = {'especies': {29: 'NIDORANfE', 32: 'NIDORANmA'}, 'ataques': {237: 'HIDDENPOWER', 165: 'STRUGGLE'}}
salida, faltan = {}, {}
fuentes = {
    'especies': ({d['num']: d['name'] for d in json.loads((SD / 'pokedex.json').read_text(encoding='utf-8')).values()
                  if not d.get('forme') and 0 < d.get('num', 0) <= 721}),
    'ataques': {m['num']: m['name'] for m in json.loads((SD / 'moves.json').read_text(encoding='utf-8')).values()
                if 0 < m.get('num', 0) <= 621 and not m.get('isZ') and not m.get('isMax')},
    'habilidades': {d['num']: d['name'] for d in js('abilities.js').values() if 0 < d['num'] <= 191},
    'objetos': {d['num']: d['name'] for d in js('items.js').values() if 0 < d['num'] <= 775},
}
for tipo, tabla in fuentes.items():
    salida[tipo], faltan[tipo] = {}, []
    for num, nombre in sorted(tabla.items()):
        i = ESPECIALES.get(tipo, {}).get(num) or interno(nombre)
        if i in existe[tipo]:
            salida[tipo][num] = i
        else:
            faltan[tipo].append(f'{num} {nombre} ({i})')
salida['naturalezas'] = ids['naturalezas']
(RAIZ / 'app' / 'ids_ostinato.json').write_text(json.dumps(salida, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
for tipo in fuentes:
    print(f'{tipo}: {len(salida[tipo])} de {len(fuentes[tipo])}; faltan {len(faltan[tipo])}: {", ".join(faltan[tipo][:25])}')
