"""Pruebas de la app sin abrirla: seguridad de los dos servidores, copias de la partida y versiones.
    python3 app/test_app.py
"""
import http.client
import json
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from http.server import ThreadingHTTPServer
from pathlib import Path

import comun
import conexion
import emulador
import guardado
import locke
import online
import web

tmp = Path(tempfile.mkdtemp())
fallos = []


def ver(ok, que):
    print(('  bien   ' if ok else '  FALLO  ') + que)
    if not ok:
        fallos.append(que)


# ---------- servidor local (127.0.0.1) ----------
comun.DATOS = tmp / 'datos'
(comun.DATOS / 'juegos' / 'abc123').mkdir(parents=True)
fuera = tmp / 'NO_BORRAR.txt'
fuera.write_text('partidas')
guardar_de_verdad = comun.guardar
comun.guardar = lambda: None
comun.biblio['juegos'] = [{'id': 'abc123', 'nombre': 'Y', 'ruta': 'x', 'medallas': [False] * 8, 'preparado': True,
                          'huevos': [{'cogido': False, 'shiny': False, 'especie': 1}] * 30}]
srv = ThreadingHTTPServer(('127.0.0.1', 0), web.Servidor)
comun.PUERTO = srv.server_port
threading.Thread(target=srv.serve_forever, daemon=True).start()


def post(ruta, datos, host=None, tipo='application/json'):
    c = http.client.HTTPConnection('127.0.0.1', srv.server_port, timeout=5)
    cuerpo = json.dumps(datos).encode()
    c.request('POST', ruta, cuerpo, {'Host': host or f'127.0.0.1:{srv.server_port}', 'Content-Type': tipo,
                                     'Content-Length': str(len(cuerpo))})
    r = c.getresponse()
    return r.status, json.loads(r.read() or b'{}')


print('Servidor local')
ver(post('/api/quitar', {'id': 'abc123'}, tipo='text/plain')[0] == 403, 'una web cualquiera (sin JSON) no puede mandar acciones')
ver(post('/api/quitar', {'id': 'abc123'}, host='malo.ejemplo.com')[0] == 403, 'otro Host (DNS rebinding) se rechaza')
s, r = post('/api/quitar', {'id': '../..'})
ver(s == 400 and fuera.exists() and comun.DATOS.exists(), 'quitar con id «../..» no borra nada')
import pokehex
ver(len(pokehex.LEGENDARIOS) == 54 and {150, 151, 382, 489, 493, 494, 649, 716, 721} <= pokehex.LEGENDARIOS and not {25, 133, 373, 445, 637, 715} & pokehex.LEGENDARIOS, 'la lista de legendarios y singulares está completa')
ver(not {pokehex.especie_huevo_azar() for _ in range(5000)} & pokehex.LEGENDARIOS, 'un huevo aleatorio nunca es legendario ni singular')
import juego
import struct
pk = bytearray(254)
struct.pack_into('<I', pk, 0, 0x1234ABCD)
struct.pack_into('<H', pk, 8, 25)
struct.pack_into('<I', pk, 0x74, 0xC0000000 | 12345)
pk[0x40:0x4A] = 'Huevo'.encode('utf-16-le')
pk[0xCA] = 120
viejo = bytearray(pk)
viejo[0xCA] = 0
struct.pack_into('<H', viejo, 6, sum(struct.unpack_from('<112H', viejo, 8)) & 0xFFFF)
struct.pack_into('<H', pk, 6, sum(struct.unpack_from('<112H', pk, 8)) & 0xFFFF)
r = juego.huevo_retrasado(bytes(viejo))
ver(r and r[0xCA] == 120 and juego.pokemon(r)['huevo'], 'un huevo con el contador bajo se retrasa y sigue siendo válido')
ver(juego.huevo_retrasado(bytes(pk)) is None, 'uno que ya lo tiene alto no se toca')
abierto = juego.huevo_abierto(bytes(pk), 'Pikachu', 8)
p = juego.pokemon(abierto)
ver(p and not p['huevo'] and p['mote'] == 'Pikachu' and p['especie'] == 25, 'el huevo abierto en memoria es un Pokémon válido, sin marca de huevo')
ver(struct.unpack_from('<I', abierto, 0x74)[0] == 12345 and abierto[0xCA] == 70 and struct.unpack_from('<H', abierto, 0xDA)[0] == 8, 'conserva sus IV y coge amistad y sitio')
ver(juego.descifrar(*juego.cifrar(abierto)[:1], juego.cifrar(abierto)[1][:22])[:232] == abierto[:232], 'se cifra bien para escribirlo en el equipo')
class _Datos:                                           # lo mínimo que pide aplicar(): experiencia y stats base
    tabla_exp = staticmethod(lambda e: [n ** 3 for n in range(101)])
    stats_base = staticmethod(lambda e: [50] * 6)
mio = bytearray(abierto)                                # capturado por ti: el juego usa la amistad de 0xCA
mio[0x93], mio[0xA2] = 0, 0
r = pokehex.aplicar(bytes(mio), {'amistad': 255}, _Datos)
ver(r[0xCA] == 255 and r[0xA2] == 255 and pokehex.detalle(r)['amistad'] == 255, 'la amistad se pone en la que usa el juego (la del entrenador original)')
ajeno = bytearray(mio)                                  # intercambiado: usa la de 0xA2
ajeno[0x93], ajeno[0xCA], ajeno[0xA2] = 1, 10, 99
struct.pack_into('<H', ajeno, 6, sum(struct.unpack_from('<112H', ajeno, 8)) & 0xFFFF)
ver(pokehex.detalle(bytes(ajeno))['amistad'] == 99, 'en uno intercambiado se lee la de su entrenador actual')
r = pokehex.aplicar(bytes(pk), {'amistad': 255}, _Datos)
ver(r[0xCA] == 120, 'en un huevo no se toca: 0xCA son los pasos que le faltan')
# ---------- escribir poco en la memoria del juego (cada escritura arriesga un cuelgue de Citra) ----------
class _Memoria(juego.RPC):
    def __init__(self):
        self.protocolo, self.equipo, self.m, self.trozos = 1, 0x8CE1CE8, bytearray(0x100000), 0
    def _d(self, x): return x - (0x8CE1CE8 + juego.MOCHILA_DESDE_EQUIPO) + 0x1000
    def leer(self, x, n): return bytes(self.m[self._d(x):self._d(x) + n])
    def _escribir_trozo(self, v, x, t):
        assert len(t) <= 24
        self.m[self._d(x):self._d(x) + len(t)] = t
        self.trozos += 1
mem = _Memoria()
objetos = [(4, 10), (17, 3), (3, 5), (25, 1), (2, 7)] + [(100 + k, 1) for k in range(40)]
mem.m[0x1000:0x1000 + 4 * len(objetos)] = b''.join(struct.pack('<HH', *o) for o in objetos)
fuera = juego.esconder_balls(mem)
quedan = [x for x in juego._bolsillo(mem) if x[0]]
ver(sorted(map(tuple, fuera)) == [(2, 7), (3, 5), (4, 10)] and not any(x[0] in juego.BALLS for x in quedan) and len(quedan) == 42, 'esconder las Balls no pierde ningún objeto')
ver(mem.trozos <= 6, f'y escribe poco ({mem.trozos} escrituras; antes, el bolsillo entero: 67)')
juego.devolver_balls(mem, fuera)
todo = [x for x in juego._bolsillo(mem) if x[0]]
ver(sorted(todo) == sorted(objetos), 'al devolverlas está todo como antes')
mem.trozos = 0
juego.devolver_balls(mem, juego.esconder_balls(mem))
ver(mem.trozos <= 4 and sorted(x for x in juego._bolsillo(mem) if x[0]) == sorted(objetos), f'la segunda vez, con las Balls al final, casi nada ({mem.trozos} escrituras)')
mem.trozos = 0
mem.escribir(0x8CE1CE8 + juego.MOCHILA_DESDE_EQUIPO, mem.leer(0x8CE1CE8 + juego.MOCHILA_DESDE_EQUIPO, 1600))
ver(mem.trozos == 0, 'escribir lo mismo que ya hay no manda nada')
import tempfile
reg = Path(tempfile.mkdtemp()) / 'r.log'
reg.write_text("""--Pokemon Base Stats & Types--
292|Shedinja        |BUG/GHOST        |   1|  90|  45|  30|  30|  40|Wonder Guard  |--            |Wonder Guard  |
--Pokemon Movesets--
292 Shedinja ->  (no evolution)
Level 1 : Heart Stamp
Level 1 : Shift Gear
Level 9 : Pound
--Shops--
--Pokelocke 1.2.4: MT al azar y sin Superguarda--
Superguarda -> Levitate (entrada 292, habilidad 1)
Superguarda -> Damp (entrada 292, habilidad 3)
""", encoding='utf-8')
dr = pokehex.Datos(Path(tempfile.mkdtemp()), reg)
ver(dr.movimientos(292, 1)[:3] == [pokehex.NOMBRES['movimientos'].index('Arrumaco'), pokehex.NOMBRES['movimientos'].index('Cambio de Marcha'), 0], 'los huevos salen con los movimientos de la randomización, no los del juego original')
ver(25 not in dr.habilidades(292), 'y sin Superguarda si el parche la ha cambiado')
cb = bytearray(0x2000)
cb[0x100:0x108] = pokehex.MARCA_MT
for k, m in enumerate(range(1, 93)):
    struct.pack_into('<H', cb, 0x108 + 2 * k, m)
for k in range(8):
    struct.pack_into('<H', cb, 0x108 + 97 * 2 + 2 * k, 500 + k)
(reg.parent / 'code.bin').write_bytes(bytes(cb))
mts = pokehex.movimientos_mt(reg.parent / 'code.bin')
ver(len(mts) == 100 and mts[328] == 1 and mts[419] == 92 and mts[618] == 500 and mts[694] == 507, 'el PokéHex sabe qué ataque enseña cada MT de la partida (MT01-100)')
ver(pokehex.movimientos_mt(reg.parent / 'no_existe.bin') == {}, 'y sin code.bin no falla')
part = pokehex.Partida.__new__(pokehex.Partida)
part.d = bytearray(pokehex.TAM_PARTIDA)
struct.pack_into('<II', part.d, pokehex.TAM_PARTIDA - 0x200 + 0x14, 0x300, 0)
struct.pack_into('<II', part.d, pokehex.TAM_PARTIDA - 0x200 + 0x14 + 8, 0x20000, 1)
ver(part._bloque_de(0x16200) == (1, 0x400, 0x20000), 'cada bloque de la partida empieza en múltiplo de 0x200')
class MemoriaFalsa:
    def __init__(self, d): self.d, self.escrito = bytearray(d), None
    def leer(self, x, n): return bytes(self.d[:n])
    def escribir(self, x, b): self.escrito = (x, b); self.d[0] = b[0]
ver(juego.entrenador(abierto) is not None and juego.entrenador(bytes(254)) is None, 'el entrenador del primer Pokémon dice de qué partida es')
jn = {'id': 'n'}
locke.nuevo_locke(jn, 25, 'mega')
ver(jn.get('fijo_puesto') is None, 'un locke nuevo vuelve a poner el Fijo')
m = MemoriaFalsa(bytes.fromhex('61000200'))
ver(juego.poner_fijo(m) and m.escrito == (juego.DIR_OPCIONES, b'\x69'), 'pone el combate en Fijo en la memoria (0x61 -> 0x69)')
m = MemoriaFalsa(bytes.fromhex('69000200'))
ver(juego.poner_fijo(m) and m.escrito is None, 'si ya está en Fijo no escribe nada')
m = MemoriaFalsa(bytes.fromhex('61ff0200'))
ver(not juego.poner_fijo(m) and m.escrito is None, 'si lo leído no parecen las opciones, no toca nada')
jm = {'id': 'm', 'preparado': True, 'medallas': [False] * 8}
viejo_tablero = guardado.tablero
guardado.tablero = lambda j: {'medallas': [True, True] + [False] * 6}
locke.medallas_de_la_partida(jm)
ver(sum(jm['medallas']) == 2, 'con el juego cerrado, las medallas de la partida guardada ponen al día las de la app')
jm['medallas'], jm['reto'] = [False] * 8, {'medalla': 1}
locke.medallas_de_la_partida(jm)
ver(sum(jm['medallas']) == 0, 'con un reto en marcha no se tocan (se resuelve jugando)')
guardado.tablero = viejo_tablero
huevo = {'id': 'A', 'especie': 25, 'huevo': True}
ver([p['id'] for p in locke.huevos_abiertos([huevo, None], [{**huevo, 'huevo': False}, None])] == ['A'], 'se nota cuando un huevo del equipo se abre')
ver(not locke.huevos_abiertos([huevo], [huevo]) and not locke.huevos_abiertos([None], [{**huevo, 'huevo': False}]), 'un huevo sin abrir o un Pokémon nuevo no lanzan nada')
ver(locke._huevo_visible({'cogido': True, 'abierto': False, 'especie': 25, 'shiny': False}) == {'cogido': True, 'abierto': False, 'shiny': False}, 'un huevo sin abrir no dice qué lleva')
ver(locke._huevo_visible({'cogido': True, 'especie': 25, 'shiny': False})['especie'] == 25, 'los cogidos antes de este cambio se siguen viendo')
ver([locke.rol(b)[0] for b in ((50, 90, 50, 50, 60, 50), (50, 60, 50, 50, 90, 50), (50, 40, 90, 50, 40, 60), (50, 40, 60, 50, 40, 90))] == ['Atacante físico', 'Atacante especial', 'Tanque físico', 'Tanque especial'], 'el rol sale de las estadísticas base')
ver(post('/api/huevos/coger', {'id': 'abc123', 'i': -5})[1].get('error') == 'Ese huevo no existe', 'índices de huevo raros')
ver(post('/api/copias/restaurar', {'id': 'abc123', 'nombre': '../../x'})[0] == 400, 'restaurar una copia que no está en la lista')
s, r = post('/api/medalla', {'i': 'x', 'valor': True})
ver(s == 400 and 'ValueError' in r['error'] and 'Código E-' in r['error'], f'un dato roto dice el tipo de error y su código: «{r["error"][:90]}…»')
ver(post('/api/huevos/coger', {'id': 'abc123', 'i': 99})[1]['error'] == 'Ese huevo no existe', 'los mensajes previstos se enseñan tal cual')


def estado_roto():
    return 1 / 0


web.foto_estado = estado_roto
c = http.client.HTTPConnection('127.0.0.1', srv.server_port, timeout=5)
c.request('GET', '/api/estado', headers={'Host': f'127.0.0.1:{srv.server_port}'})
respuesta = c.getresponse()
error = json.loads(respuesta.read())['error']
ver(respuesta.status == 500 and 'ZeroDivisionError' in error and 'test_app.py' in error and 'Código E-' in error,
    f'un error inesperado dice dónde ha fallado y su código: «{error[:100]}…»')
srv.shutdown()

# ---------- copias de la partida ----------
print('Copias de la partida')
partida = tmp / 'sdmc' / 'data' / '00000001'
partida.mkdir(parents=True)
(partida / 'main').write_text('partida 0')
j = comun.biblio['juegos'][0]
guardado.pokehex_partida = lambda _j: partida / 'main'
emulador.jugando = lambda: False
ahora = [0]
time.strftime = lambda f, *a: f'20261030_1200{ahora[0]:02d}' if f == '%Y%m%d_%H%M%S' else '12:00:00'
for k in range(12):
    ahora[0] = k
    (partida / 'main').write_text(f'partida {k}')
    guardado.copiar_partida(j, 'al-cerrar')
copias = guardado.copias_partida(j)
ver(len(copias) == guardado.MAX_COPIAS, f'se quedan las {guardado.MAX_COPIAS} últimas')
mas_vieja = copias[-1]['nombre']
ahora[0] = 50
(partida / 'main').write_text('partida estropeada')
guardado.restaurar_partida(j, mas_vieja)
ver((partida / 'main').read_text() == 'partida 2', 'restaurar la más vieja funciona (aunque la copia de antes haga sitio)')
ver(any(c['motivo'] == 'Antes de restaurar otra' for c in guardado.copias_partida(j)), 'antes de restaurar se copia la de ahora')

# ---------- la randomización en la carpeta de mods del emulador ----------
print('Mods del emulador')
mod = comun.DATOS / 'juegos' / 'abc123' / 'mod' / '0004000000055E00' / 'romfs'
mod.mkdir(parents=True)
(mod / 'a.bin').write_bytes(b'x' * 1000)
emulador.carpeta_mods = lambda: tmp / 'emulador' / 'load' / 'mods'
j['random'] = {'fecha': 'hoy'}
copiados = []
copytree = shutil.copytree
shutil.copytree = lambda *a, **k: (copiados.append(a[0]), copytree(*a, **k))[1]
emulador.poner_mod(j)
emulador.poner_mod(j)
raiz_mod = comun.DATOS / 'juegos' / 'abc123' / 'mod'
ver(copiados.count(raiz_mod) == 1 and (emulador.carpeta_mods() / '0004000000055E00' / 'romfs' / 'a.bin').exists(),
    'la randomización se copia una vez y no se vuelve a copiar si no ha cambiado')
(mod / 'a.bin').write_bytes(b'y' * 1200)
emulador.poner_mod(j)
ver(copiados.count(raiz_mod) == 2, 'si cambia (la fase completa), se vuelve a copiar')
shutil.copytree = copytree

# ---------- la biblioteca no se pierde aunque se rompa al escribirla ----------
print('Biblioteca')
comun.guardar = guardar_de_verdad
comun.BIBLIOTECA = tmp / 'bib' / 'biblioteca.json'
comun.DATOS = comun.BIBLIOTECA.parent
comun.biblio.clear(); comun.biblio.update({'juegos': [{'id': 'uno', 'muertos': [1, 2]}]})
comun.guardar()
comun.biblio['juegos'][0]['muertos'].append(3)
comun.guardar()
comun.BIBLIOTECA.write_text('{"juegos": [{"id": "uno", "mue')          # se cortó la luz a mitad
comun.biblio.clear(); comun.biblio['juegos'] = []
comun.cargar()
ver(comun.biblio['juegos'] and comun.biblio['juegos'][0]['muertos'] == [1, 2], 'una biblioteca a medias se recupera de la copia anterior')
ver(any(f.name.startswith('biblioteca.rota-') for f in comun.DATOS.iterdir()), 'y la rota se guarda aparte para mirarla')

# ---------- servidor online ----------
print('Servidor online')
o = online.Servidor(tmp / 'online', admin='Daavidmp')
try:
    o.registrar('daavidmp', 'clave1', '8.8.8.8')
    ver(False, 'el nombre del administrador está reservado')
except ValueError:
    ver(True, 'el nombre del administrador está reservado')
o.registrar('Daavidmp', 'clave1', '1.1.1.1', anfitrion=o.clave_anfitrion)
o.registrar('Amigo', 'clave2', '2.2.2.2')
ver(o.usuarios['Daavidmp']['admin'] and not o.usuarios['Amigo']['admin'], 'solo Daavidmp es administrador')
try:
    o.registrar('Amigo2', 'clave2', '2.2.2.2')
    ver(False, 'un registro por IP y minuto')
except ValueError:
    ver(True, 'un registro por IP y minuto')
try:
    o.registrar('Ana', 'clave3', '3.3.3.3')
    ver(False, 'un usuario de 3 letras no podría entrar en la sala de Citra')
except ValueError:
    ver(True, 'un usuario de 3 letras no podría entrar en la sala de Citra')
# la corona del campeón: al decidirse la final va a su cuenta, se quita si se deshace y se queda aunque se borre el torneo
tk = o.entrar('Daavidmp', 'clave1', '1.1.1.1')['token']
o.editar_torneo(tk, 'crear', {'jugadores': ['Daavidmp', 'Amigo'], 'nombre': 'Gran torneo'})
tn = o.torneo(tk)['torneo']
ver(all(p['ab'] == [None, None] for p in tn['partidos']) and 'bombo' not in tn['sorteo'],
    'el cuadro sale vacío, y lo que queda en la máquina no se ve (1.3.3)')
try:
    o.editar_torneo(tk, 'ganador', {'id': tn['final'], 'lado': 0})
    ver(False, 'sin sortear no se puede dar la victoria')
except ValueError:
    ver(True, 'sin sortear no se puede dar la victoria')
o.editar_torneo(tk, 'sortear', {})
o.editar_torneo(tk, 'remover', {})
for _ in range(2):
    o.editar_torneo(tk, 'sacar', {})
tn = o.torneo(tk)['torneo']
ver(tn['sorteo']['removido'] == 1 and [b['hueco'] for b in tn['sorteo']['sacados']] == [0, 1], 'las bolas salen una a una, a los huecos 1 y 2')
final = tn['final']
uno, otro = next(q for q in tn['partidos'] if q['id'] == final)['ab']     # el cuadro se sortea
ver({uno, otro} == {'Daavidmp', 'Amigo'}, 'con las dos bolas fuera, la final tiene a los dos')
o.editar_torneo(tk, 'ganador', {'id': final, 'lado': 1})
ver(o.coronas() == {otro: [{'nombre': 'Gran torneo', 'puesto': 1}], uno: [{'nombre': 'Gran torneo', 'puesto': 2}]},
    'el que gana la final se lleva la corona de oro y el otro la de plata')
ver(o.latido(tk, {})['coronas'][otro][0]['puesto'] == 1, 'y todos la ven en el latido')
o.editar_torneo(tk, 'ganador', {'id': final, 'lado': 1})
ver(o.coronas() == {}, 'si se deshace el resultado, la corona se quita')
o.editar_torneo(tk, 'ganador', {'id': final, 'lado': 0})
o.editar_torneo(tk, 'reiniciar', {})
ver(o.coronas()[uno] == [{'nombre': 'Gran torneo', 'puesto': 1}], 'y se queda aunque se borre el torneo')
# los organizadores (1.3.3): pueden sortear y marcar, no crear ni borrar; sin serlo, nada
tk_amigo = o.entrar('Amigo', 'clave2', '2.2.2.2')['token']
o.editar_torneo(tk, 'crear', {'jugadores': ['Daavidmp', 'Amigo'], 'gestores': ['Amigo'], 'nombre': 'Con organizador'})
ver(o.torneo(tk_amigo)['puede'], 'el organizador puede tocar el torneo')
o.editar_torneo(tk_amigo, 'sortear', {})
o.editar_torneo(tk_amigo, 'sacar', {})
ver(len(o.torneo(tk)['torneo']['sorteo']['sacados']) == 1, 'el organizador saca bolas')
for que in ('crear', 'reiniciar'):
    try:
        o.editar_torneo(tk_amigo, que, {'jugadores': ['Daavidmp', 'Amigo']})
        ver(False, f'el organizador no puede {que}')
    except PermissionError:
        ver(True, f'el organizador no puede {que}')
o.editar_torneo(tk, 'crear', {'jugadores': ['Daavidmp', 'Amigo'], 'nombre': 'Sin organizador'})
try:
    o.editar_torneo(tk_amigo, 'sacar', {})
    ver(False, 'sin ser organizador no se saca bola')
except PermissionError:
    ver(not o.torneo(tk_amigo)['puede'], 'sin ser organizador no se saca bola')
o.editar_torneo(tk, 'reiniciar', {})
# el cuadro (1.3.3): nadie pasa de ronda sin combatir; si sobra uno, segunda oportunidad al mejor de 3 contra un
# perdedor de esa ronda; con semifinales de 4, duelo por el 3.er puesto al mejor de 1. Con 10: 5; 2+1; 1+1; final
import random as _azar
ps10, fin10 = online._cuadro([f'J{i}' for i in range(10)])
forma = [(sum(1 for q in ps10 if q['ronda'] == r and not q.get('segunda')), sum(1 for q in ps10 if q['ronda'] == r and q.get('segunda')))
         for r in range(4)]
ver(forma == [(5, 0), (2, 1), (1, 1), (1, 0)], f'el cuadro de 10: 5; 2 y una segunda oportunidad; 1 y otra; la final ({forma})')
ver(all(next(q for q in ps10 if q['id'] == f['gana'])['ronda'] == p['ronda'] - 1 for p in ps10 for f in p['fuentes'] if 'gana' in f),
    'cada ganador juega en la ronda siguiente: nadie se salta una')
ver(all(p['mejor_de'] == 3 for p in ps10) and not any(p.get('tercero') for p in ps10), 'todo al mejor de 3; con semifinales de 3 no hay duelo por el 3.º')
ps8, fin8 = online._cuadro([f'J{i}' for i in range(8)])
tercero = [p for p in ps8 if p.get('tercero')]
ver(len(tercero) == 1 and tercero[0]['mejor_de'] == 1 and all('pierde' in f for f in tercero[0]['fuentes']),
    'con 8: los que pierden en semifinales se juegan el 3.er puesto al mejor de 1')
for n in range(2, 13):
    ps, fin = online._cuadro([f'J{i}' for i in range(n)])
    for q in ps:
        online._propagar(ps)
        if all(q['ab']) and q['gana'] is None:
            q['gana'] = _azar.randint(0, 1)
    online._propagar(ps)
    podio = online.Servidor._podio({'final': fin, 'partidos': ps})
    ver(all(all(q['ab']) for q in ps) and sorted(podio.values()) == ([1, 2, 3] if n >= 3 else [1, 2]),
        f'con {n}: todos los partidos tienen sus dos jugadores y hay oro, plata y bronce')
# con 4: bronce para los dos que pierden las semifinales
podio = online.Servidor._podio({'final': 'p1-0', 'partidos': [
    {'id': 'p0-0', 'fase': 'principal', 'ronda': 0, 'ab': ['A', 'B'], 'gana': 0, 'fuentes': []},
    {'id': 'p0-1', 'fase': 'principal', 'ronda': 0, 'ab': ['C', 'D'], 'gana': 1, 'fuentes': []},
    {'id': 'p1-0', 'fase': 'principal', 'ronda': 1, 'ab': ['A', 'D'], 'gana': 1, 'fuentes': [{'gana': 'p0-0'}, {'gana': 'p0-1'}]}]})
ver(podio == {'D': 1, 'A': 2, 'B': 3, 'C': 3}, 'con 4 jugadores: oro, plata y dos bronces')
ver(not o.sala_viva(), 'sin citra-room, la sala no sale como activa')
o.sala = subprocess.Popen([sys.executable, '-c', 'pass'])
o.sala.wait()
ver(not o.sala_viva(), 'una sala que se ha caído no sale como activa')
o.sala = None
amigo = o.entrar('Amigo', 'clave2', '2.2.2.2')['token']
try:
    o.pedir_log(amigo, 'Daavidmp')
    ver(False, 'solo el administrador ve registros de otros')
except PermissionError:
    ver(True, 'solo el administrador ve registros de otros')
# el recorrido entero: el admin pide el registro, el jugador lo recoge en su latido y contesta
admin = o.entrar('Daavidmp', 'clave1', '1.1.1.1')['token']
o.latido(amigo, {'jugando': False})
respuesta = {}
hilo = threading.Thread(target=lambda: respuesta.update(r=o.pedir_log(admin, 'Amigo')))
hilo.start()
for _ in range(50):
    tareas = o.latido(amigo, {'jugando': False})['tareas']
    if tareas:
        break
    threading.Event().wait(0.05)
ver(tareas and tareas[0]['que'] == 'log', 'el encargo del registro llega al jugador en su latido')
o.resultado(amigo, tareas[0]['id'], {'version': 'x', 'registros': {'pokelocke.log': 'Traceback…'}})
hilo.join(5)
ver(respuesta.get('r', {}).get('registros', {}).get('pokelocke.log') == 'Traceback…', 'y su respuesta le llega al administrador')

# ---------- fotos de perfil ----------
print('Fotos')
foto = 'data:image/jpeg;base64,' + 'QUJD' * 4
o.poner_foto(amigo, foto)
lista = o.latido(amigo, {'jugando': False, 'foto': 'trampa'})['conectados']
yo = next(c for c in lista if c['usuario'] == 'Amigo')
ver(len(yo['foto']) == 10, 'el latido lleva una huella de la foto, no la foto')
ver(o.fotos(amigo, ['Amigo', 'NoExiste'])['fotos']['Amigo']['imagen'] == foto, 'la foto se pide aparte')
try:
    o.fotos('sin sesion', ['Amigo'])
    ver(False, 'las fotos piden sesión')
except PermissionError:
    ver(True, 'las fotos piden sesión')
llamadas = []
online_peticion = online.peticion
online.peticion = lambda d, r, datos, espera=8: (llamadas.append(r), o.fotos(amigo, datos['usuarios']))[1]
comun.red['fotos'] = {}
conexion.traer_fotos('x', amigo, lista)
conexion.traer_fotos('x', amigo, lista)
online.peticion = online_peticion
ver(len(llamadas) == 1, 'una foto que no cambia no se vuelve a pedir')
ver(comun.red['fotos']['Amigo']['imagen'] == b'ABC' * 4, 'se guarda ya como imagen')
srv = ThreadingHTTPServer(('127.0.0.1', 0), web.Servidor)
comun.PUERTO = srv.server_port
threading.Thread(target=srv.serve_forever, daemon=True).start()
c = http.client.HTTPConnection('127.0.0.1', srv.server_port, timeout=5)
c.request('GET', '/foto/Amigo', headers={'Host': f'127.0.0.1:{srv.server_port}'})
respuesta = c.getresponse()
ver(respuesta.status == 200 and respuesta.read() == b'ABC' * 4, 'la ventana la lee de Pokelocke')
srv.shutdown()

# ---------- cambiar el nombre y la contraseña ----------
print('Cuenta')
o.registros.clear()
o.registrar('Paco', 'clave3', '4.4.4.4')
paco = o.entrar('Paco', 'clave3', '4.4.4.4')['token']
o._torneo_f().write_text(json.dumps({'jugadores': ['Paco', 'Amigo'], 'partidos': [{'ab': ['Paco', None], 'nombre': 'Paco y Pacos'}]}))
o.recibir_eventos('Paco', [], 0)
def rechaza(f, *a):
    try:
        f(*a)
        return None
    except ValueError as e:
        return str(e)
ver(rechaza(o.cambiar_nombre, paco, 'Pacote', 'mala', '4.4.4.4') == 'La contraseña no es correcta', 'cambiar el nombre pide la contraseña')
ver(rechaza(o.cambiar_nombre, paco, 'Amigo', 'clave3', '4.4.4.4') == 'Ese usuario ya existe', 'no se puede coger un nombre ocupado')
ver(rechaza(o.cambiar_nombre, paco, 'amigo', 'clave3', '4.4.4.4') == 'Ese usuario ya existe', 'tampoco cambiando mayúsculas')
ver(rechaza(o.cambiar_nombre, paco, 'daavidmp', 'clave3', '4.4.4.4') == 'Ese nombre está reservado', 'ni el del administrador')
ver(rechaza(o.cambiar_nombre, paco, 'Pa', 'clave3', '4.4.4.4') is not None, 'ni uno demasiado corto')
ver(rechaza(o.cambiar_nombre, admin, 'Jefe1', 'clave1', '1.1.1.1') is not None, 'el administrador no puede cambiar el suyo')
o.fallos.clear()
ver(o.cambiar_nombre(paco, 'Pacote', 'clave3', '4.4.4.4') == {'usuario': 'Pacote'}, 'cambia el nombre')
ver(o.sesiones[paco] == 'Pacote', 'la sesión abierta sigue valiendo')
ver('Paco' not in o.usuarios and rechaza(o.entrar, 'Paco', 'clave3', '4.4.4.4') is not None, 'el nombre viejo ya no entra')
ver(o.entrar('Pacote', 'clave3', '4.4.4.4')['usuario'] == 'Pacote', 'el nuevo entra con su contraseña')
t = json.loads(o._torneo_f().read_text(encoding='utf-8'))
ver(t['jugadores'][0] == 'Pacote' and t['partidos'][0]['ab'][0] == 'Pacote' and t['partidos'][0]['nombre'] == 'Paco y Pacos', 'el torneo cambia solo su nombre')
ver(any('de Paco a Pacote' in x['texto'] for x in o.actividad(admin, 'Pacote')['eventos']), 'el cambio queda en su actividad')
o._torneo_f().unlink()
otra = o.entrar('Pacote', 'clave3', '4.4.4.4')['token']
ver(rechaza(o.cambiar_clave, paco, 'mala', 'nueva1', '4.4.4.4') == 'La contraseña no es correcta', 'cambiar la contraseña pide la actual')
ver(rechaza(o.cambiar_clave, paco, 'clave3', 'abc', '4.4.4.4') is not None, 'la nueva no puede ser demasiado corta')
o.fallos.clear()
ver(o.cambiar_clave(paco, 'clave3', 'nueva1', '4.4.4.4') == {'ok': True}, 'cambia la contraseña')
ver(rechaza(o.entrar, 'Pacote', 'clave3', '4.4.4.4') is not None and o.entrar('Pacote', 'nueva1', '4.4.4.4'), 'la vieja deja de valer y la nueva vale')
ver(otra not in o.sesiones and paco in o.sesiones, 'sus otras sesiones se cierran')
o.fallos.clear()
o.registros.clear()
del o.usuarios['Pacote']

# ---------- actividad de los jugadores: lo que llega al servidor no se puede borrar desde el PC ---------
print('Actividad')
import vigia
primero = len(vigia._leer())
vigia.cuenta['n'] = None
e1 = vigia.evento('vidas', 'Se suma una vida con F8', 'sospecha', vidas=26)
e2 = vigia.evento('abrir', 'Abre el juego')
ver(vigia.ultimas_vidas() == 26, 'el registro recuerda las últimas vidas apuntadas')
ver(e2['h'] == online.huella_evento(e1['h'], e2), 'cada evento se encadena con el anterior')
envio, total = vigia.para_mandar(primero)
hasta = o.recibir_eventos('Amigo', envio, total)
ver(hasta == e2['n'], 'el servidor apunta hasta dónde tiene')
ver(o.latido(amigo, {}, [], total)['eventos_hasta'] == e2['n'], 'el latido devuelve hasta dónde tiene')
try:
    o.actividad(amigo, 'Amigo')
    ver(False, 'solo el administrador ve la actividad')
except PermissionError:
    ver(True, 'solo el administrador ve la actividad')
visto = o.actividad(admin, 'Amigo')['eventos']
ver(any(x['nivel'] == 'sospecha' and 'F8' in x['texto'] for x in visto), 'el administrador ve la sospecha')
resumen = next(x for x in o.actividad(admin, None)['jugadores'] if x['usuario'] == 'Amigo')
ver(resumen['sospechas'] >= 1, 'el resumen cuenta las sospechas aunque no esté conectado')
o.recibir_eventos('Amigo', [], 0)
ver(any('vuelto atrás' in x['texto'] for x in o.actividad(admin, 'Amigo')['eventos']), 'si borra su registro, el servidor lo apunta')
falso = dict(e2, n=5, texto='Todo normal')
o.recibir_eventos('Amigo', [falso], 5)
ver(any('Faltan los eventos' in x['texto'] for x in o.actividad(admin, 'Amigo')['eventos']), 'si quita eventos, se nota el hueco')
siguiente = dict(falso, n=6, texto='Editado a mano')
o.recibir_eventos('Amigo', [siguiente], 6)
ver(any('no cuadra' in x['texto'] for x in o.actividad(admin, 'Amigo')['eventos']), 'si cambia un evento, la huella no cuadra')
for valor in (5, 6, 7):
    vigia.contador('capturas', valor)
vigia.contador('capturas', 0)
ver(not any(x['tipo'] == 'retroceso' for x in vigia._leer()), 'la pantalla de título no cuenta como volver atrás')
for _ in range(vigia.LECTURAS_RETROCESO):
    vigia.contador('capturas', 4)
ver(any(x['tipo'] == 'retroceso' for x in vigia._leer()), 'si baja el contador de capturas, ha vuelto atrás')
comun.vivo['sin_guardar'] = [(time.time() + 100, 'muerte de Pikachu')]
vigia.apuntar_sin_guardar('captura en la zona 3')
ver(len(comun.vivo['sin_guardar']) == 2, 'lo que pasa sin guardar se recuerda para cuando cierre')
comun.vivo['niveles'] = {}
bicho = {'id': 'AB', 'nivel': 180, 'ps': 20, 'psmax': 40}
ver(all(vigia.nivel_seguro(bicho) is None for _ in range(3)), 'un nivel imposible (180) no se cree nunca')
ver(vigia.nivel_seguro(dict(bicho, nivel=20, ps=50)) is None, 'con más PS que el máximo, la lectura es basura')
ver(vigia.nivel_seguro(dict(bicho, nivel=53)) is None, 'un nivel leído una sola vez no basta')
ver(vigia.nivel_seguro(dict(bicho, nivel=20)) is None and vigia.nivel_seguro(dict(bicho, nivel=20)) == 20,
    'el nivel leído igual dos veces seguidas sí vale')
vigia.evento('abrir', 'Abre el juego')
ver(vigia.sesion_cortada(), 'abrir sin cerrar después: la sesión se cortó')
vigia.evento('cerrar', 'Cierra el juego')
ver(not vigia.sesion_cortada(), 'abrir y cerrar: la sesión acabó bien')
# ---------- el servidor online va cifrado y solo vale con el certificado del anfitrión ----------
print('Conexión cifrada')
import os
import empaquetar
os.environ['POKELOCKE_SERVIDOR'] = str(tmp / 'cifrado')
empaquetar.subprocess.run = lambda *a, **k: None          # cryptography ya está instalada aquí: sin pip
pem = empaquetar.certificado()
import socket


def puerto_libre():
    with socket.socket() as so:
        so.bind(('127.0.0.1', 0))
        return so.getsockname()[1]


online.PUERTO_SERVIDOR, online.PUERTO_SEGURO = puerto_libre(), puerto_libre()   # sin chocar con otra ejecución
srv_online = online.Servidor(tmp / 'cifrado', admin='Daavidmp')
srv_online.arrancar()
online.certificado = lambda: pem
r = online.peticion('127.0.0.1', '/registro', {'usuario': 'Prueba', 'clave': 'clave1'})
ver('token' in r, 'con el certificado bueno se registra y entra por https')
with online.abrir('127.0.0.1', '/version') as resp:
    ver('sha256' in json.load(resp), '/version da también la huella del instalador')
os.environ['POKELOCKE_SERVIDOR'] = str(tmp / 'impostor')
online.certificado = lambda: empaquetar.certificado()      # otro certificado: alguien haciéndose pasar por el servidor
try:
    online.peticion('127.0.0.1', '/entrar', {'usuario': 'Prueba', 'clave': 'clave1'})
    ver(False, 'con otro certificado se rechaza la conexión')
except OSError as e:
    ver('certificado del anfitrión' in conexion.online_motivo(e), f'con otro certificado se rechaza: «{conexion.online_motivo(e)[:70]}…»')
c = http.client.HTTPConnection('127.0.0.1', online.PUERTO_SERVIDOR, timeout=5)
c.request('POST', '/entrar', b'{}', {'Content-Type': 'application/json'})
ver(c.getresponse().status == 426, 'un Pokelocke viejo (http) recibe «actualiza»')
srv_online.parar()

# ---------- contraseña del PokéHex ----------
print('PokéHex')
guardado.F_POKEHEX = tmp / 'pokehex.json'
try:
    guardado.comprobar_clave_pokehex('ab')
    ver(False, 'la primera contraseña tiene que tener 4 caracteres')
except RuntimeError:
    ver(True, 'la primera contraseña tiene que tener 4 caracteres')
guardado.comprobar_clave_pokehex('mia123')
ver('mia123' not in guardado.F_POKEHEX.read_text(), 'la primera vez se crea, y se guarda cifrada')
try:
    guardado.comprobar_clave_pokehex('Admin123!')
    ver(False, 'la contraseña de antes ya no vale')
except RuntimeError:
    ver(True, 'la contraseña de antes (la del código) ya no vale')
guardado.comprobar_clave_pokehex('mia123')
ver(True, 'la suya sí')

# ---------- modo ligero ----------
print('Modo ligero')
emu = tmp / 'emu' / 'azahar.exe'
ini = emu.parent / 'user' / 'config' / 'qt-config.ini'
ini.parent.mkdir(parents=True)
ini.write_text('[Renderer]\nresolution_factor\\default=false\nresolution_factor=3\n', encoding='utf-8')
emulador.azahar_exe = lambda: emu
comun.encaje = lambda: (1, 0, 0)
comun.biblio['ajustes'] = {'ligero': True}
emulador.configurar_azahar()
ver('resolution_factor=1' in ini.read_text(), 'con el modo ligero, Citra a resolución nativa')
comun.biblio['ajustes']['ligero'] = False
emulador.configurar_azahar()
ver('resolution_factor=3' in ini.read_text(), 'al quitarlo vuelve la resolución que había')

# ---------- retos ----------
print('Retos')
import locke
jugando_antes = emulador.jugando
emulador.jugando = lambda: False
jr = {'id': 'retos', 'reglas': 'mega', 'preparado': True, 'vidas_iniciales': 25, 'ajuste_vidas': 0, 'muertos': [],
      'medallas': [False] * 8, 'huevos': [{'especie': 1, 'shiny': False, 'cogido': False}] * 30}
try:
    locke.aceptar_reto(jr, 'sin_vidas')
    ver(False, 'antes de la 1.ª medalla no hay retos')
except RuntimeError:
    ver(True, 'antes de la 1.ª medalla no hay retos')
jr['medallas'][0] = True
locke.aceptar_reto(jr, 'sin_vidas')
ver(jr['reto']['medalla'] == 2, 'con una medalla, el reto es para la segunda')
comun.vivo['equipo'] = [{'nivel': 20, 'huevo': False}] * 4 + [None, None]
jr['medallas'][1] = True
locke.resolver_reto(jr)
ver(jr['huevos_extra'] == 1 and locke.huevos_disponibles(jr) == 2 and not jr['reto'], 'superado: un huevo extra en la caja')
locke.aceptar_reto(jr, 'tres')
jr['medallas'][2] = True
locke.resolver_reto(jr)
ver(locke.vidas(jr) == 24 and not jr['retos'][-1]['superado'], 'fallado (4 Pokémon con «Solo tres»): una vida menos')
emulador.jugando = lambda: True
try:
    locke.aceptar_reto(jr, 'nivel_bajo')
    ver(False, 'con el juego abierto no se aceptan retos')
except RuntimeError:
    ver(True, 'con el juego abierto no se aceptan retos')
emulador.jugando = jugando_antes
jr2 = {'id': 'retos2', 'reglas': 'mega', 'preparado': True, 'vidas_iniciales': 25, 'ajuste_vidas': 0, 'muertos': [],
       'medallas': [True] + [False] * 7}
comun.vivo['aviso'] = None; comun.vivo['cola_avisos'] = 0       # sin avisos en cola de antes
locke.avisar_reto_nuevo(jr2)
ver(comun.vivo['aviso'] and 'Lino' in comun.vivo['aviso']['texto'] and comun.vivo['aviso']['hasta'] - time.time() <= 2.1,
    'con la 1.ª medalla aparece el reto de Lino y avisa 2 s en el juego')
comun.vivo['aviso'] = None
locke.avisar_reto_nuevo(jr2)
ver(comun.vivo['aviso'] is None, 'el mismo reto no se avisa dos veces')
jr2['medallas'][1] = True                      # gana a Lino sin haber cogido su carta
ver(locke.retos_estado(jr2)['medalla'] == 3, 'un reto que ya no se puede hacer (líder ya vencido) desaparece: pasa al de Corelia')
try:
    locke.aceptar_reto(dict(jr2, medallas=[True] * 8), 'tres')
    ver(False, 'con las 8 medallas no quedan retos')
except RuntimeError:
    ver(True, 'con las 8 medallas no quedan retos')

# ---------- misiones ----------
print('Misiones')
import juego
cont = {'combates': 5, 'capturas': 2, 'centros': 1}
record_antes, curas_antes = juego.record, juego.curas_en_centro
cont['pasos'] = 1000
juego.record = lambda rpc, i: {juego.RECORD_ENTRENADORES: cont['combates'], juego.RECORD_PASOS: cont['pasos']}.get(i, cont['capturas'])
juego.curas_en_centro = lambda rpc: cont['centros']
emulador.jugando = lambda: False
jm = {'id': 'mis', 'reglas': 'mega', 'preparado': True, 'vidas_iniciales': 25, 'ajuste_vidas': 0, 'muertos': [],
      'medallas': [True] + [False] * 7}
comun.vivo['aviso'] = None; comun.vivo['cola_avisos'] = 0; comun.vivo['en_combate'] = False
ofertas = lambda: [o['id'] for o in jm.get('misiones_ofertas', [])]
locke.misiones_tick(jm, None)
ver(not ofertas(), 'con 5 combates aún no hay misión')
cont['combates'] = 30
locke.misiones_tick(jm, None)
ver(ofertas() == ['racha10'] and jm['misiones_ofertas'][0]['hasta'] is None and 'Nueva misión' in comun.vivo['aviso']['texto'],
    'en el combate 30 aparece «Racha de diez», sin límite de gimnasio, y avisa en el juego')
jm['medallas'][1] = True
locke.misiones_tick(jm, None)
ver(ofertas() == ['racha10'], 'una racha no caduca al conseguir otra medalla')
locke.aceptar_mision(jm, 'racha10')
locke.misiones_tick(jm, None)                                  # al volver a jugar se toman los contadores
cont['combates'] = 40
locke.misiones_tick(jm, None)
ver(not jm['mision'] and jm['escamas_pendientes'] == 1 and jm['misiones'][-1]['superada'], 'diez combates sin perder vidas: misión fácil superada, una Escama Corazón')
jm['medallas'][2] = True                                       # 3.ª medalla: «Explorador» (fácil, pasos)
locke.misiones_tick(jm, None)
ver(ofertas() == ['explorador'] and jm['misiones_ofertas'][0]['hasta'] is None, 'con 3 medallas aparece «Explorador», sin límite de gimnasio')
locke.aceptar_mision(jm, 'explorador')
locke.misiones_tick(jm, None)
cont['pasos'] = 15000
locke.misiones_tick(jm, None)
ver(jm['mision']['progreso'] == 14000, 'cuenta los pasos desde que se acepta')
cont['pasos'] = 21000
locke.misiones_tick(jm, None)
ver(jm['escamas_pendientes'] == 2 and jm['misiones'][-1]['superada'], '20.000 pasos sin perder vidas: otra Escama Corazón')
jm['medallas'][3:5] = [True] * 2                               # 5.ª medalla: «Racha de quince» (difícil)
locke.misiones_tick(jm, None)
ver(ofertas() == ['racha15'], 'con 5 medallas aparece «Racha de quince»')
locke.aceptar_mision(jm, 'racha15')
locke.misiones_tick(jm, None)
jm['muertos'].append('X')                                      # muere uno antes de los 15 combates
locke.misiones_tick(jm, None)
ver(not jm['misiones'][-1]['superada'] and locke.vidas(jm) == 23, 'una difícil fallada (pierdes una vida en la racha): una vida menos más')
jm['medallas'][5:7] = [True] * 2
locke.misiones_tick(jm, None)
jm['medallas'][7] = True
locke.misiones_tick(jm, None)
ver(ofertas() == ['racha20'], 'una racha no caduca: «Imparable» sigue ofrecida con las 8 medallas')
juego.record, juego.curas_en_centro, emulador.jugando = record_antes, curas_antes, jugando_antes

# ---------- mochila ----------
print('Mochila')
import struct
import pokehex
memoria = bytearray(pokehex.TAM_MOCHILA)
struct.pack_into('<HH', memoria, 0, 141, 1)                    # una Carta Pregunta en Objetos (de una tienda aleatoria)
lector = type('L', (), {'leer': lambda _, a, n: bytes(memoria[a:a + n]),
                        'escribir': lambda _, a, d: memoria.__setitem__(slice(a, a + len(d)), d)})()
antes = pokehex.leer_mochila(lector, 0)['objetos']
pokehex.escribir_bolsillo(lector, 0, 'objetos', antes + [{'objeto': 93, 'cantidad': 1}], ya={o['objeto'] for o in antes})
ver([o['objeto'] for o in pokehex.leer_mochila(lector, 0)['objetos']] == [141, 93],
    'la Escama Corazón entra aunque en el bolsillo haya una Carta Pregunta (y la carta se queda)')
try:
    pokehex.escribir_bolsillo(lector, 0, 'objetos', [{'objeto': 141, 'cantidad': 1}])
    ver(False, 'un objeto nuevo que no es de ese bolsillo no entra')
except ValueError:
    ver(True, 'un objeto nuevo que no es de ese bolsillo no entra')

# ---------- el PokéHex, solo para Daavidmp ----------
print('PokéHex')
ver(o.yo(o.entrar('Daavidmp', 'clave1', '1.1.1.1')['token'])['usuario'] == 'Daavidmp', 'el servidor dice quién es el dueño de una sesión')
peticion_antes, sesion_antes, direccion_antes = online.peticion, comun.red.get('sesion'), conexion.online_direccion
conexion.online_direccion = lambda: 'servidor'
def puede():
    try:
        conexion.comprobar_dueno_pokehex()
        return True
    except RuntimeError:
        return False
comun.red['sesion'] = None
ver(not puede(), 'sin sesión online no se abre el PokéHex')
comun.red['sesion'] = {'token': 'x', 'usuario': 'Daavidmp', 'admin': True}        # sesión tocada a mano en el PC
online.peticion = lambda *a, **k: {'usuario': 'Amigo', 'admin': False}
ver(not puede(), 'aunque la sesión guardada diga Daavidmp, manda lo que diga el servidor')
online.peticion = lambda *a, **k: {'usuario': 'Daavidmp', 'admin': True}
ver(puede(), 'Daavidmp sí entra')
def sin_red(*a, **k):
    raise OSError('sin red')
online.peticion = sin_red
ver(not puede(), 'sin conexión con el servidor, nadie')
import types
online.peticion = lambda *a, **k: {'usuario': 'Daavidmp', 'admin': True}
sys.modules['huella_oficial'] = types.SimpleNamespace(HUELLA='0' * 64)       # el .exe trae la huella del anfitrión
ver(not puede(), 'otro servidor (montado por un jugador, con su propia cuenta Daavidmp) no vale: no tiene ese certificado')
del sys.modules['huella_oficial']
online.peticion, comun.red['sesion'], conexion.online_direccion = peticion_antes, sesion_antes, direccion_antes

# ---------- duelos ----------
print('Duelos')
td, ta = o.entrar('Daavidmp', 'clave1', '1.1.1.1')['token'], o.entrar('Amigo', 'clave2', '2.2.2.2')['token']
try:
    o.retar(td, 'Amigo')
    ver(False, 'sin las cuentas del locke no se puede retar')
except ValueError:
    ver(True, 'sin las cuentas del locke no se puede retar')
o.latido(td, {'locke': {'medallas': 1, 'perdidas': 2}})
o.latido(ta, {'locke': {'medallas': 2, 'perdidas': 0}})
o.retar(td, 'Amigo')
try:
    o.retar(ta, 'Daavidmp')
    ver(False, 'un duelo a la vez')
except ValueError:
    ver(True, 'un duelo a la vez')
dl = o.latido(ta, {})['duelos']
ver(len(dl) == 1 and dl[0]['estado'] == 'pendiente' and dl[0]['de'] == 'Daavidmp', 'el retado ve el duelo pendiente en su latido')
o.responder_duelo(ta, dl[0]['id'], True)
o.latido(td, {'locke': {'medallas': 3, 'perdidas': 4}})
dl = o.latido(ta, {})['duelos']
ver(dl[0]['estado'] == 'en_marcha' and dl[0]['van'] == {'Daavidmp': 2, 'Amigo': 0}, 'cuenta las vidas perdidas desde que se acepta')
o.latido(td, {'locke': {'medallas': 4, 'perdidas': 5}})
dl = o.latido(ta, {})['duelos']
ver(dl[0]['fin'] == {'Daavidmp': 3} and dl[0]['estado'] == 'en_marcha', 'al llegar al 4.º gimnasio su cuenta se cierra (3 vidas) y espera al otro')
o.latido(td, {'locke': {'medallas': 4, 'perdidas': 9}})
ver(o.latido(ta, {})['duelos'][0]['fin']['Daavidmp'] == 3, 'lo que pierda después ya no cuenta')
# los dos Pokelocke: el aviso de cada paso y el premio o el castigo al cerrarse
jd = {'id': 'duelo', 'preparado': True, 'vidas_iniciales': 25, 'ajuste_vidas': 0, 'muertos': [], 'medallas': [False] * 8}
juegos_antes, jugando_antes = comun.biblio['juegos'], emulador.jugando
comun.biblio['juegos'], emulador.jugando = [jd], lambda: False
comun.vivo['aviso'] = None; comun.vivo['cola_avisos'] = 0
locke.duelos_tick(o.latido(ta, {})['duelos'], 'Amigo')
ver(comun.vivo['aviso'] is None, 'un locke nuevo no avisa de los duelos que ya había')
o.latido(ta, {'locke': {'medallas': 4, 'perdidas': 1}})
locke.duelos_tick(o.latido(ta, {})['duelos'], 'Amigo')
dl = o.latido(ta, {})['duelos']
ver(dl[0]['estado'] == 'cerrado' and dl[0]['ganador'] == 'Amigo', 'con los dos en el 4.º gimnasio gana el que menos ha perdido (1 a 3)')
ver(jd.get('huevos_extra') == 1, 'el ganador se lleva un huevo extra')
locke.duelos_tick(dl, 'Amigo')
ver(jd.get('huevos_extra') == 1, 'y solo una vez')
jd2 = dict(jd, duelos_vistos={dl[0]['id']: {'estado': 'en_marcha', 'fin': ['Daavidmp']}}, huevos_extra=0)
comun.biblio['juegos'] = [jd2]
locke.duelos_tick(o.latido(td, {})['duelos'], 'Daavidmp')
ver(locke.vidas(jd2) == 24, 'el que pierde, una vida menos')
comun.biblio['juegos'], emulador.jugando = juegos_antes, jugando_antes
o.cambiar_nombre(ta, 'Amiga', 'clave2', '2.2.2.2')
ver(o.duelos[0]['ganador'] == 'Amiga' and 'Amiga' in o.duelos[0]['fin'], 'al cambiar de nombre, sus duelos siguen con él')

# ---------- tiendas del segundo dependiente ----------
print('Tiendas al azar')
tmp_t = Path(tempfile.mkdtemp())
datos_antes, correr_antes = comun.DATOS, emulador.correr
fuera = (emulador.upr_jar, emulador.java, emulador.rom_jugable, emulador.clase_pokelocke, comun.guardar)
comun.DATOS = tmp_t
emulador.upr_jar, emulador.java = (lambda: tmp_t / 'upr.jar'), (lambda: 'java')
emulador.rom_jugable, emulador.clase_pokelocke = (lambda j: 'rom.3ds'), (lambda jar, n: [n])
comun.guardar = lambda: None
llamadas = []
def correr_falso(args, cwd):
    llamadas.append(args)
    for c in args:
        if str(c).endswith('code.bin'):
            Path(c).write_bytes(b'nuevo')
    return 'tiendas en la ROM: 11\nHecho 2\n'
emulador.correr = correr_falso
for v in ('mod', 'mod_completo'):
    (tmp_t / 'juegos' / 'tt' / v / '0004000000055E00').mkdir(parents=True)
    (tmp_t / 'juegos' / 'tt' / v / '0004000000055E00' / 'code.bin').write_bytes(b'viejo')
jt = {'id': 'tt', 'reglas': 'mega', 'random': {'avanzado': False, 'opciones': {}}}
jt['firma_mod'] = emulador.firma_mod(jt)
emulador.tiendas_al_azar(jt)
ver(len(llamadas) == 1 and 'TiendasAzar' in llamadas[0] and sum(str(c).endswith('code.bin') for c in llamadas[0]) == 2,
    'una partida Mega pasa sus dos code.bin (fase fácil y completa) por TiendasAzar')
ver(jt['tiendas_parche']['estado'] == 'hecho' and jt['tiendas_parche']['version'] == emulador.TIENDAS_VERSION, 'queda apuntado')
ver(jt['firma_mod'] == emulador.firma_mod(jt), 'la huella de los archivos se renueva: no salta el aviso de archivos tocados')
emulador.tiendas_al_azar(jt)
ver(len(llamadas) == 1, 'solo una vez por partida')
jt2 = {'id': 'tt', 'reglas': None, 'random': {'avanzado': False, 'opciones': {}}}
emulador.tiendas_al_azar(jt2)
ver(len(llamadas) == 1 and 'tiendas_parche' not in jt2, 'sin las normas Mega no se tocan las tiendas')
jt3 = {'id': 'tt', 'reglas': 'mega', 'random': {'avanzado': False}, 'firma_mod': 'otra'}
emulador.tiendas_al_azar(jt3)
ver(jt3['firma_mod'] == 'otra', 'si los archivos ya estaban tocados, la huella no se arregla sola')
llamadas.clear()
jp = {'id': 'tt', 'reglas': 'mega', 'random': {'avanzado': False, 'opciones': {}}}
jp['firma_mod'] = emulador.firma_mod(jp)
emulador.personal_al_azar(jp)
ver(len(llamadas) == 1 and 'PersonalAzar' in llamadas[0] and sum(Path(str(c)).parts[-5:] == ('romfs', 'a', '2', '1', '8') for c in llamadas[0]) == 2,
    'MT al azar y sin Superguarda: pasa los datos de los Pokémon de las dos fases por PersonalAzar')
ver(jp['personal_parche']['version'] == emulador.PERSONAL_VERSION and jp['firma_mod'] == emulador.firma_mod(jp), 'queda apuntado y con la huella al día')
emulador.personal_al_azar(jp)
ver(len(llamadas) == 1, 'solo una vez por partida (llega a todas al actualizar, la primera vez que abren el juego)')
emulador.personal_al_azar({'id': 'tt', 'reglas': None, 'random': {}})
ver(len(llamadas) == 1, 'sin las normas Mega no se toca')
llamadas.clear()
for v in ('mod', 'mod_completo'):
    (tmp_t / 'juegos' / 'tt' / v / '0004000000055E00' / 'romfs' / 'a' / '0' / '7').mkdir(parents=True, exist_ok=True)
(tmp_t / 'juegos' / 'tt' / 'mod' / '0004000000055E00' / 'romfs' / 'a' / '0' / '7' / '4').write_bytes(b'texto facil')
emulador.correr = lambda args, cwd: (llamadas.append(args), 'Hecho')[1]
jm = {'id': 'tt', 'reglas': 'mega', 'fase': 2, 'random': {'avanzado': False}}
emulador.mt_fijas(jm)
ver(not llamadas, 'MT fijas: en la fase completa ya no se toca (la fácil ya no está)')
jm['fase'] = 1
emulador.mt_fijas(jm)
ver(len(llamadas) == 1 and 'MTFijas' in llamadas[0] and str(llamadas[0][-2]).find('mod_completo') < 0 < str(llamadas[0][-1]).find('mod_completo'),
    'en la fase 1 copia las MT de la fácil a la completa')
ver((tmp_t / 'juegos' / 'tt' / 'mod_completo' / '0004000000055E00' / 'romfs' / 'a' / '0' / '7' / '4').read_bytes() == b'texto facil', 'y el texto con sus descripciones')
emulador.mt_fijas(jm)
ver(len(llamadas) == 1, 'solo una vez')
llamadas.clear()
import guardado as _g
_pp, _P = _g.pokehex_partida, pokehex.Partida
class _PartidaMT:
    def __init__(self, ruta): pass
    def mochila(self): return {'mt': [{'objeto': 328, 'cantidad': 1}, {'objeto': 690, 'cantidad': 1}, {'objeto': 420, 'cantidad': 1}]}
_g.pokehex_partida = lambda j: 'main'
pokehex.Partida = _PartidaMT
ja = {'id': 'tt', 'reglas': 'mega', 'random': {'avanzado': False}}
emulador.mt_azar(ja)
ver(len(llamadas) == 1 and 'MTAzar' in llamadas[0] and llamadas[0][llamadas[0].index('MTAzar') + 2] == 'max=69' and llamadas[0][llamadas[0].index('MTAzar') + 3] == '1,96'
    and sum(str(c).endswith('code.bin') for c in llamadas[0]) == 2,
    'MT al azar en las rooms que ya hay: pasa las MT de la mochila (MT01 y MT96) para no cambiarlas, y las dos fases')
emulador.mt_azar(ja)
ver(len(llamadas) == 1 and ja['mt_azar']['guardadas'] == [1, 96], 'solo una vez, y apunta cuáles se guardaron')
def _rota(ruta): raise ValueError('partida rota')
pokehex.Partida = _rota
jb = {'id': 'tt', 'reglas': 'mega', 'random': {'avanzado': False}}
emulador.mt_azar(jb)
ver(len(llamadas) == 1 and 'mt_azar' not in jb, 'si no puede leer la mochila no toca las MT (y lo intenta otra vez)')
_g.pokehex_partida, pokehex.Partida = _pp, _P
llamadas.clear()
emulador.correr = lambda args, cwd: (llamadas.append(args), 'Hecho 2')[1]
emulador.MT_VOLVER['tt'] = (1, '3:209:78 4:347:385')
jv = {'id': 'tt', 'reglas': 'mega', 'random': {'avanzado': False}, 'mt_azar': {'estado': 'hecho'}}
emulador.mt_volver(jv)
ver(len(llamadas) == 1 and 'MTVolver' in llamadas[0] and '3:209:78 4:347:385' in llamadas[0]
    and sum(str(c).endswith('code.bin') for c in llamadas[0]) == 2, 'MT devueltas: la partida de la lista pasa sus cambios y sus code.bin')
emulador.mt_volver(jv)
ver(len(llamadas) == 1 and jv['mt_vuelta']['estado'] == 'hecho', 'y solo una vez')
emulador.mt_volver({'id': 'otra', 'reglas': 'mega', 'random': {}, 'mt_azar': {'estado': 'hecho'}})
emulador.mt_volver({'id': 'tt', 'reglas': 'mega', 'random': {}})
ver(len(llamadas) == 1, 'a las demas partidas no les toca, ni a la de la lista si aun no se sortearon sus MT')
emulador.MT_VOLVER['tt'] = (2, '3:78:209 4:385:347')
emulador.mt_volver(jv)
ver(len(llamadas) == 2 and '3:78:209 4:385:347' in llamadas[1] and jv['mt_vuelta']['version'] == 2, 'una version nueva de los cambios se aplica otra vez (y solo una)')
emulador.mt_volver(jv)
ver(len(llamadas) == 2, 'y no se repite')
ver(not set(emulador.MT_VOLVER) - {'tt'}, 'no quedan cambios de MT a mano pendientes')
del emulador.MT_VOLVER['tt']
# fase completa: las MT que no estan en la mochila se sortean otra vez sin limite de potencia (mt_fuertes)
llamadas.clear()
pokehex.Partida, _g.pokehex_partida = _PartidaMT, (lambda j: 'main')
emulador.correr = lambda args, cwd: (llamadas.append(args), 'Hecho 2')[1]
jr = {'id': 'tt', 'reglas': 'mega', 'random': {'avanzado': False}, 'fase': 1, 'mt_azar': {'estado': 'hecho', 'guardadas': [1]}}
emulador.mt_azar(jr)
ver(not llamadas, 'una partida ya sorteada no repite el sorteo de menos de 70')
emulador.mt_fuertes(jr)
ver(len(llamadas) == 1 and 'max=999' in llamadas[0] and jr['mt_fuertes']['guardadas'] == [1, 96],
    'en cualquier fase: las MT que no estan en la mochila se sortean sin limite de potencia (las de la mochila se respetan)')
emulador.mt_fuertes(jr)
ver(len(llamadas) == 1, 'y solo una vez')
# la mega de la Torre Maestra en las partidas que ya existen
llamadas.clear()
for v in ('mod', 'mod_completo'):
    (tmp_t / 'juegos' / 'tt' / v / '0004000000055E00' / 'romfs' / 'DllField.cro').write_bytes(b'cro')
emulador.correr = lambda args, cwd: (llamadas.append(args), 'Hecho Medicham con Medichamite')[1]
jg = {'id': 'tt', 'reglas': 'mega', 'random': {'avanzado': False}}
emulador.mega_torre(jg)
ver(len(llamadas) == 1 and 'MegaTorre' in llamadas[0] and sum(str(c).endswith('DllField.cro') for c in llamadas[0]) == 2
    and jg['mega_torre']['regalo'] == 'Medicham con Medichamite', 'mega de la Torre Maestra: pasa el DllField.cro de las dos fases y apunta el regalo')
emulador.mega_torre(jg)
emulador.mega_torre({'id': 'tt', 'reglas': None, 'random': {}})
ver(len(llamadas) == 1, 'una sola vez, y solo en las partidas Mega')
_g.pokehex_partida, pokehex.Partida = _pp, _P
comun.DATOS, emulador.correr = datos_antes, correr_antes
emulador.upr_jar, emulador.java, emulador.rom_jugable, emulador.clase_pokelocke, comun.guardar = fuera

# ---------- versiones ----------
print('Versiones')
ver(conexion.version_tupla('2026.10.30.1203') > conexion.version_tupla('2026.10.30.0959'), 'una versión más nueva se reconoce')
ver(conexion.version_tupla('desarrollo') is None, 'la copia de desarrollo no se compara')

# ---------- torneo por grupos (2.1.0) ----------
print('\nTorneo por grupos')
og = online.Servidor(tmp / 'grupos', admin='Daavidmp')
og.registrar('Daavidmp', 'clave1', '1.1.1.1', anfitrion=og.clave_anfitrion)
tg = og.entrar('Daavidmp', 'clave1', '1.1.1.1')['token']
doce = ['Daavidmp'] + [f'Jugador{k}' for k in range(1, 12)]
for k, n in enumerate(doce[1:]):
    og.registrar(n, 'clave1', f'7.7.7.{k}')


def tor():
    return json.loads((og.carpeta / 'torneo.json').read_text(encoding='utf-8'))


def gana(pid, lado, ma='', mb=''):
    if ma != '':
        og.editar_torneo(tg, 'marcador', {'id': pid, 'ma': ma, 'mb': mb})
    og.editar_torneo(tg, 'ganador', {'id': pid, 'lado': lado})


try:
    og.editar_torneo(tg, 'crear', {'jugadores': doce[:11], 'formato': 'grupos'})
    ver(False, 'grupos: con 11 no se crea')
except ValueError:
    ver(True, 'grupos: con 11 no se crea')
og.editar_torneo(tg, 'crear', {'jugadores': doce, 'formato': 'grupos', 'pizarra': True})
ver(tor()['pizarra'] is True, 'grupos: el modo pizarra se guarda al crear (2.2.0)')
og.editar_torneo(tg, 'crear', {'jugadores': doce, 'formato': 'grupos'})
ver(tor()['pizarra'] is False, 'grupos: sin el interruptor, pirámide (2.2.0)')
for _ in range(12):
    og.editar_torneo(tg, 'sacar', {})
ver(all(f['j'] for p in tor()['partidos'] for f in p['fuentes'] if 'hueco' in f) and tor()['final'] is None,
    'grupos: el sorteo llena los 4 grupos (el 3.º de cada grupo está en dos combates)')
for L in 'AB':                                   # 2-1-0
    gana(f'g{L}1', 0, '2', '0'); gana(f'g{L}2', 1, '0', '2'); gana(f'g{L}3', 1, '1', '2')
ver(tor()['clasif']['A']['orden'] is not None, 'grupos: con 2-1-0 el orden sale solo')
gana('gC1', 0); gana('gC2', 1); gana('gC3', 0)    # 1-1-1 sin marcador
ver(tor()['clasif']['C']['falta_marcador'], 'grupos: con 1-1-1 hace falta el marcador')
og.editar_torneo(tg, 'marcador', {'id': 'gC1', 'ma': '2', 'mb': '0'})
og.editar_torneo(tg, 'marcador', {'id': 'gC2', 'ma': '1', 'mb': '2'})
og.editar_torneo(tg, 'marcador', {'id': 'gC3', 'ma': '2', 'mb': '1'})
dc = [p for p in tor()['partidos'] if p['fase'] == 'desempate']
ver(len(dc) == 1 and dc[0]['mejor_de'] == 1, 'grupos: 1-1-1 con dos empatados en combates: un desempate al mejor de 1')
gana('dC1', 0)
gana('gD1', 0, '2', '1'); gana('gD2', 1, '1', '2'); gana('gD3', 0, '2', '1')   # 1-1-1 y los tres con 3 combates
dd = [p for p in tor()['partidos'] if p['fase'] == 'desempate' and p['grupo'] == 'D']
ver(len(dd) == 3 and tor()['final'] is None, 'grupos: empate a tres: tres desempates al mejor de 1 y aún sin cuadro')
gana('dD1', 0); gana('dD2', 0); gana('dD3', 1)
tt = tor()
ver(tt['final'] == 'f' and all(tt['clasif'][L]['orden'] for L in 'ABCD'), 'grupos: con los cuatro grupos acabados sale el cuadro')
de = {n: L for L in 'ABCD' for n in tt['clasif'][L]['orden']}
pos = {n: k for L in 'ABCD' for k, n in enumerate(tt['clasif'][L]['orden'])}
pr = {p['id']: p for p in tt['partidos'] if p['fase'] == 'principal'}
ver(all(de[pr[q]['ab'][0]] != de[pr[q]['ab'][1]] and pos[pr[q]['ab'][0]] == pos[pr[q]['ab'][1]] < 2 for q in ('c1', 'c2', 'c3', 'c4')),
    'grupos: cuartos 1.º contra 1.º y 2.º contra 2.º, de grupos distintos')
semis_ok = True
for bits in range(16):
    gan = {q: pr[q]['ab'][(bits >> k) & 1] for k, q in enumerate(('c1', 'c2', 'c3', 'c4'))}
    semis_ok &= de[gan['c1']] != de[gan['c2']] and de[gan['c3']] != de[gan['c4']]
ver(semis_ok, 'grupos: en semifinales nunca se cruzan dos del mismo grupo')
for q in ('c1', 'c2', 'c3', 'c4', 's1', 's2'):
    gana(q, 0, '2', '0')
gana('t3', 1, '1', '2'); gana('f', 0, '2', '1')
tt = tor()
ver(next(p for p in tt['partidos'] if p.get('tercero'))['mejor_de'] == 3, 'grupos: el 3.er puesto es al mejor de 3')
ver(sorted(og._podio(tt).values()) == [1, 2, 3], 'grupos: podio de oro, plata y bronce')
gana('gA3', 1); gana('gA3', 0, '2', '1')             # cambia quién pasa en el grupo A: el cuadro se rehace
ver(tor()['firma_cuadro'] != tt['firma_cuadro'] and all(p['gana'] is None for p in tor()['partidos'] if p['fase'] == 'principal'),
    'grupos: si cambia quién pasa, el cuadro final se rehace')

print('\nTodo bien.' if not fallos else f'\n{len(fallos)} fallos.')
raise SystemExit(1 if fallos else 0)
