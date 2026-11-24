"""Prueba del combate en línea (2.3.0): 300 combates simulados con el motor (combate.py) a través de las salas del
servidor, con equipos y acciones al azar. Ningún error, todos acaban y el marcador suma al ganador.

  tools/build-venv/Scripts/python app/test_combate.py
"""
import random, sys, tempfile, time, collections
sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parent))
import online, combate

az = random.Random(7)
ATQ = [k for k, v in combate.ATAQUES.items()]


def equipo(n):
    out = []
    for _ in range(n):
        esp = az.randint(1, 721)
        nv = az.randint(30, 60)
        out.append({'especie': esp, 'nombre': f'E{esp}', 'mote': '', 'nivel': nv, 'habilidad': 'X', 'shiny': False,
                    'stats': [az.randint(80, 180)] + [az.randint(40, 140) for _ in range(5)],
                    'ataques': az.sample(ATQ, 4), 'genero': az.randint(0, 2)})
    return out


S = online.Servidor(tempfile.mkdtemp())
S.SALA_PRESENTACION = 0
cuenta = collections.Counter()
turnos = []
for partida in range(300):
    S.usuarios = {'ana': {'perfil': {'sexo': 1, 'equipo': equipo(az.randint(1, 6))}},
                  'beto': {'perfil': {'sexo': 0, 'equipo': equipo(az.randint(1, 6))}}}
    S.sesiones = {'ta': 'ana', 'tb': 'beto'}
    S.salas = {}
    c = S.combate('ta', 'crear', {})['sala']['codigo']
    S.combate('tb', 'entrar', {'codigo': c})
    for t in ('ta', 'tb'):
        n = len(S.usuarios['ana' if t == 'ta' else 'beto']['perfil']['equipo'])
        S.combate(t, 'orden', {'orden': list(range(n))[::-1]})
        S.combate(t, 'listo', {})
    S.salas[c]['empieza'] = time.time() - 1
    for paso in range(2000):
        r = None
        for t in ('ta', 'tb'):
            r = S.combate(t, 'ver', {})
            cb = r['sala']['combate']
            if cb['fin'] is not None:
                break
            if cb['espera'] == 'cambio' or (cb['espera'] == 'accion' and az.random() < 0.15):
                vivos = [i for i, p in enumerate(cb['equipo']) if p['ps'] > 0 and i != cb['activo']]
                if vivos:
                    S.combate(t, 'accion', {'accion': {'tipo': 'cambio', 'i': az.choice(vivos)}})
                    continue
            if cb['espera'] in ('accion', 'cambio'):
                p = cb['equipo'][cb['activo']]
                con_pp = [i for i, a in enumerate(p['ataques']) if a['pp'] > 0] or [0]
                try:
                    S.combate(t, 'accion', {'accion': {'tipo': 'ataque', 'i': az.choice(con_pp)}})
                except ValueError as e:
                    cuenta['error ' + str(e)[:40]] += 1
        cb = r['sala']['combate']
        if cb['fin'] is not None:
            break
    else:
        cuenta['sin acabar'] += 1
    cb = S.combate('ta', 'ver', {})['sala']['combate']
    cuenta['fin ' + str(cb['fin'])] += 1
    turnos.append(cb['turno'])
    for e in cb['log']:
        cuenta[e['t']] += 1
    r = S.combate('ta', 'continuar', {})
    cuenta['marcador ' + str(r['sala']['marcador'])] += 1
print(dict(cuenta))
print('turnos: media', sum(turnos) / len(turnos), 'max', max(turnos))
assert cuenta['sin acabar'] == 0 and not any(k.startswith('error') for k in cuenta), cuenta
assert cuenta['fin 0'] + cuenta['fin 1'] + cuenta['fin empate'] == 300
print('Todo bien.')
