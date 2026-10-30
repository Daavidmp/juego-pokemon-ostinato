"""Pruebas de la app sin abrirla: seguridad de los dos servidores, copias de la partida y versiones.
    python3 app/test_app.py
"""
import http.client
import json
import tempfile
import threading
from http.server import ThreadingHTTPServer
from pathlib import Path

import main
import online

tmp = Path(tempfile.mkdtemp())
fallos = []


def ver(ok, que):
    print(('  bien   ' if ok else '  FALLO  ') + que)
    if not ok:
        fallos.append(que)


# ---------- servidor local (127.0.0.1) ----------
main.DATOS = tmp / 'datos'
(main.DATOS / 'juegos' / 'abc123').mkdir(parents=True)
fuera = tmp / 'NO_BORRAR.txt'
fuera.write_text('partidas')
main.guardar = lambda: None
main.biblio['juegos'] = [{'id': 'abc123', 'nombre': 'Y', 'ruta': 'x', 'medallas': [False] * 8, 'preparado': True,
                          'huevos': [{'cogido': False, 'shiny': False, 'especie': 1}] * 30}]
srv = ThreadingHTTPServer(('127.0.0.1', 0), main.Servidor)
main.PUERTO = srv.server_port
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
ver(s == 400 and fuera.exists() and main.DATOS.exists(), 'quitar con id «../..» no borra nada')
ver(post('/api/huevos/coger', {'id': 'abc123', 'i': -5})[1].get('error') == 'Ese huevo no existe', 'índices de huevo raros')
ver(post('/api/copias/restaurar', {'id': 'abc123', 'nombre': '../../x'})[0] == 400, 'restaurar una copia que no está en la lista')
main.foto_estado = lambda: 1 / 0
c = http.client.HTTPConnection('127.0.0.1', srv.server_port, timeout=5)
c.request('GET', '/api/estado', headers={'Host': f'127.0.0.1:{srv.server_port}'})
ver(c.getresponse().status == 500, 'un error al armar el estado contesta 500 (no deja la petición colgada)')
srv.shutdown()

# ---------- copias de la partida ----------
print('Copias de la partida')
partida = tmp / 'sdmc' / 'data' / '00000001'
partida.mkdir(parents=True)
(partida / 'main').write_text('partida 0')
j = main.biblio['juegos'][0]
main.pokehex_partida = lambda _j: partida / 'main'
main.jugando = lambda: False
ahora = [0]
main.time.strftime = lambda f, *a: f'20261030_1200{ahora[0]:02d}' if f == '%Y%m%d_%H%M%S' else '12:00:00'
for k in range(12):
    ahora[0] = k
    (partida / 'main').write_text(f'partida {k}')
    main.copiar_partida(j, 'al-cerrar')
copias = main.copias_partida(j)
ver(len(copias) == main.MAX_COPIAS, f'se quedan las {main.MAX_COPIAS} últimas')
mas_vieja = copias[-1]['nombre']
ahora[0] = 50
(partida / 'main').write_text('partida estropeada')
main.restaurar_partida(j, mas_vieja)
ver((partida / 'main').read_text() == 'partida 2', 'restaurar la más vieja funciona (aunque la copia de antes haga sitio)')
ver(any(c['motivo'] == 'Antes de restaurar otra' for c in main.copias_partida(j)), 'antes de restaurar se copia la de ahora')

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

# ---------- versiones ----------
print('Versiones')
ver(main.version_tupla('2026.10.30.1203') > main.version_tupla('2026.10.30.0959'), 'una versión más nueva se reconoce')
ver(main.version_tupla('desarrollo') is None, 'la copia de desarrollo no se compara')

print('\nTodo bien.' if not fallos else f'\n{len(fallos)} fallos.')
raise SystemExit(1 if fallos else 0)
