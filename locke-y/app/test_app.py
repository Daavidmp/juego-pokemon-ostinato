"""Pruebas de la app sin abrirla: seguridad de los dos servidores, copias de la partida y versiones.
    python3 app/test_app.py
"""
import http.client
import json
import shutil
import tempfile
import threading
import time
from http.server import ThreadingHTTPServer
from pathlib import Path

import comun
import conexion
import emulador
import guardado
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

# ---------- versiones ----------
print('Versiones')
ver(conexion.version_tupla('2026.10.30.1203') > conexion.version_tupla('2026.10.30.0959'), 'una versión más nueva se reconoce')
ver(conexion.version_tupla('desarrollo') is None, 'la copia de desarrollo no se compara')

print('\nTodo bien.' if not fallos else f'\n{len(fallos)} fallos.')
raise SystemExit(1 if fallos else 0)
