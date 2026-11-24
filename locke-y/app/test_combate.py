"""Prueba del combate en línea con el motor de Pokémon Ostinato (2.4.0): combates entre equipos al azar (números de
Pokémon X/Y, como los que manda cada Pokelocke) a través de las salas del servidor, con acciones al azar. Ningún error
del motor, todos acaban y el marcador suma al ganador. Necesita tools/ruby y el juego (o tools/ostinato).

  tools/build-venv/Scripts/python app/test_combate.py [combates]
"""
import collections
import json
import random
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import motor_ostinato  # noqa: E402
import online  # noqa: E402

az = random.Random(7)
IDS = motor_ostinato.IDS
ESPECIES = [int(k) for k in IDS['especies']]
ATAQUES = [int(k) for k in IDS['ataques']]
HABILIDADES = [int(k) for k in IDS['habilidades']]
OBJETOS = [int(k) for k in IDS['objetos']] + [0] * 200


def equipo(n):
    return [{'especie': az.choice(ESPECIES), 'nombre': 'X', 'mote': '', 'nivel': az.randint(30, 60), 'habilidad': '',
             'shiny': False, 'stats': [1] * 6, 'ataques': az.sample(ATAQUES, 4), 'genero': az.randint(0, 2),
             'ivs': [az.randint(0, 31) for _ in range(6)], 'evs': [az.randint(0, 80) for _ in range(6)],
             'naturaleza': az.randint(0, 24), 'habilidad_n': az.choice(HABILIDADES), 'objeto': az.choice(OBJETOS),
             'pp_up': [0, 0, 0, 0], 'forma': 0} for _ in range(n)]


S = online.Servidor(tempfile.mkdtemp())
S.SALA_PRESENTACION = 0
cuenta = collections.Counter()
veces = int(sys.argv[1]) if len(sys.argv) > 1 else 40
t0 = time.time()
for partida in range(veces):
    S.usuarios = {'ana': {'perfil': {'sexo': 1, 'equipo': equipo(az.randint(1, 6))}},
                  'beto': {'perfil': {'sexo': 0, 'equipo': equipo(az.randint(1, 6))}}}
    S.sesiones = {'ta': 'ana', 'tb': 'beto'}
    S.salas = {}
    c = S.combate('ta', 'crear', {})['sala']['codigo']
    S.combate('tb', 'entrar', {'codigo': c})
    for t, u in (('ta', 'ana'), ('tb', 'beto')):
        S.combate(t, 'orden', {'orden': list(range(len(S.usuarios[u]['perfil']['equipo'])))})
        S.combate(t, 'listo', {})
    S.salas[c]['empieza'] = time.time() - 1
    for paso in range(3000):
        hizo = False
        for t in ('ta', 'tb'):
            r = S.combate(t, 'ver', {})
            cb = r['sala']['combate']
            if cb['fin'] is not None:
                break
            e = cb['espera']
            try:
                if e == 'cambio' or (e == 'accion' and az.random() < 0.1 and cb.get('puede_cambiar')):
                    vivos = [i for i, p in enumerate(cb['equipo']) if p['ps'] > 0 and i != cb['activo']]
                    if vivos:
                        S.combate(t, 'accion', {'accion': {'tipo': 'cambio', 'i': az.choice(vivos)}}); hizo = True
                        continue
                if e in ('accion', 'cambio'):
                    p = cb['equipo'][cb['activo']]
                    ok = [i for i, a in enumerate(p['ataques']) if a['pp'] > 0 and a.get('elegible', True)] or [0]
                    S.combate(t, 'accion', {'accion': {'tipo': 'ataque', 'i': az.choice(ok)}}); hizo = True
            except ValueError as err:
                cuenta['rechazada: ' + str(err)[:50]] += 1
        cb = S.combate('ta', 'ver', {})['sala']['combate']
        if cb['fin'] is not None:
            break
        if not hizo:
            cuenta['atascado'] += 1
            print('ATASCADO', cb['espera'], S.combate('tb', 'ver', {})['sala']['combate']['espera'], [x.get('txt') for x in cb['log'][-5:]])
            break
    cb = S.combate('ta', 'ver', {'desde': 0})['sala']['combate']
    cuenta['fin ' + str(cb['fin'])] += 1
    for e in cb['log']:
        if e['t'] == 'msg' and 'Error del motor' in e.get('txt', ''):
            cuenta['ERROR MOTOR'] += 1
            print(e['txt'])
    S.combate('ta', 'continuar', {})
print(dict(cuenta), f'{(time.time() - t0) / veces:.2f} s por combate')
assert cuenta['ERROR MOTOR'] == 0 and cuenta['atascado'] == 0, cuenta
print('Todo bien.')
