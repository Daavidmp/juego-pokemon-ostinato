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
try:
    o.registrar('Ana', 'clave3', '3.3.3.3')
    ver(False, 'un usuario de 3 letras no podría entrar en la sala de Citra')
except ValueError:
    ver(True, 'un usuario de 3 letras no podría entrar en la sala de Citra')
# la corona del campeón: al decidirse la final va a su cuenta, se quita si se deshace y se queda aunque se borre el torneo
tk = o.entrar('Daavidmp', 'clave1', '1.1.1.1')['token']
o.editar_torneo(tk, 'crear', {'jugadores': ['Daavidmp', 'Amigo'], 'nombre': 'Gran torneo'})
tn = o.torneo(tk)['torneo']
final = tn['final']
uno, otro = next(q for q in tn['partidos'] if q['id'] == final)['ab']     # el cuadro se sortea
o.editar_torneo(tk, 'ganador', {'id': final, 'lado': 1})
ver(o.coronas() == {otro: [{'nombre': 'Gran torneo', 'puesto': 1}], uno: [{'nombre': 'Gran torneo', 'puesto': 2}]},
    'el que gana la final se lleva la corona de oro y el otro la de plata')
ver(o.latido(tk, {})['coronas'][otro][0]['puesto'] == 1, 'y todos la ven en el latido')
o.editar_torneo(tk, 'ganador', {'id': final, 'lado': 1})
ver(o.coronas() == {}, 'si se deshace el resultado, la corona se quita')
o.editar_torneo(tk, 'ganador', {'id': final, 'lado': 0})
o.editar_torneo(tk, 'reiniciar', {})
ver(o.coronas()[uno] == [{'nombre': 'Gran torneo', 'puesto': 1}], 'y se queda aunque se borre el torneo')
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

# ---------- versiones ----------
print('Versiones')
ver(conexion.version_tupla('2026.10.30.1203') > conexion.version_tupla('2026.10.30.0959'), 'una versión más nueva se reconoce')
ver(conexion.version_tupla('desarrollo') is None, 'la copia de desarrollo no se compara')

print('\nTodo bien.' if not fallos else f'\n{len(fallos)} fallos.')
raise SystemExit(1 if fallos else 0)
