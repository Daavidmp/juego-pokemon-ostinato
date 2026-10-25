"""Pokelocke online: cuentas, quién está conectado, la sala de Citra y el PokéHex a distancia.

Un Pokelocke hace de servidor (el del anfitrión, con un interruptor en la app): escucha en el puerto
PUERTO_SERVIDOR, abre él solo los puertos en el router por UPnP y arranca citra-room para jugar online
(combates e intercambios por «juego inalámbrico» de Pokémon X/Y). Los demás Pokelocke se conectan a la
dirección de app/online.json, entran con su usuario y mandan un latido cada pocos segundos.

El PokéHex de otro jugador: solo una cuenta de administrador (la primera que se crea) y con la contraseña
del PokéHex. El servidor deja el encargo al Pokelocke de ese jugador, que lo hace en su partida y contesta.
"""
import hashlib
import hmac
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urljoin

PUERTO_SERVIDOR = 8766          # TCP: el servidor de Pokelocke
PUERTO_SALA = 24872             # UDP: la sala de Citra (su puerto de siempre)
LATIDO = 5                      # segundos entre latidos de cada jugador
CONECTADO = 20                  # sin latido en este tiempo, sale como desconectado


# ---------- UPnP: abrir puertos en el router sin tocarlo ----------

def _upnp_control():
    """URL de control y tipo de servicio del router (WANIPConnection o WANPPPConnection), o None."""
    msg = ('M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 2\r\n'
           'ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n\r\n').encode()
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(3)
    try:
        s.sendto(msg, ('239.255.255.250', 1900))
        while True:
            datos, _ = s.recvfrom(4096)
            m = re.search(r'(?i)location:\s*(\S+)', datos.decode(errors='ignore'))
            if not m:
                continue
            xml = urllib.request.urlopen(m[1], timeout=5).read().decode(errors='ignore')
            for b in re.findall(r'<service>(.*?)</service>', xml, re.S):
                tipo = re.search(r'<serviceType>([^<]*)', b)[1]
                if 'WANIPConnection' in tipo or 'WANPPPConnection' in tipo:
                    return urljoin(m[1], re.search(r'<controlURL>([^<]*)', b)[1]), tipo
    except OSError:
        return None
    finally:
        s.close()


def _soap(control, accion, args):
    url, tipo = control
    cuerpo = ''.join(f'<{k}>{v}</{k}>' for k, v in args.items())
    xml = (f'<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
           f's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:{accion} xmlns:u="{tipo}">'
           f'{cuerpo}</u:{accion}></s:Body></s:Envelope>')
    req = urllib.request.Request(url, xml.encode(), {'Content-Type': 'text/xml; charset="utf-8"',
                                                     'SOAPAction': f'"{tipo}#{accion}"'})
    return urllib.request.urlopen(req, timeout=6).read().decode(errors='ignore')


def ip_local():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('192.168.1.1', 9))
        return s.getsockname()[0]
    except OSError:
        return '127.0.0.1'
    finally:
        s.close()


def abrir_puertos():
    """Abre TCP PUERTO_SERVIDOR y UDP PUERTO_SALA hacia este PC. Devuelve (ok, ip_publica)."""
    control = _upnp_control()
    if not control:
        return False, None
    local = ip_local()
    ok = True
    for proto, puerto in (('TCP', PUERTO_SERVIDOR), ('UDP', PUERTO_SALA)):
        try:
            _soap(control, 'AddPortMapping', {'NewRemoteHost': '', 'NewExternalPort': puerto, 'NewProtocol': proto,
                                              'NewInternalPort': puerto, 'NewInternalClient': local, 'NewEnabled': 1,
                                              'NewPortMappingDescription': 'Pokelocke', 'NewLeaseDuration': 0})
        except OSError:
            ok = False
    try:
        ip = re.findall(r'<NewExternalIPAddress>([^<]*)', _soap(control, 'GetExternalIPAddress', {}))[0]
    except (OSError, IndexError):
        ip = None
    return ok, ip


def cerrar_puertos():
    control = _upnp_control()
    if not control:
        return
    for proto, puerto in (('TCP', PUERTO_SERVIDOR), ('UDP', PUERTO_SALA)):
        try:
            _soap(control, 'DeletePortMapping', {'NewRemoteHost': '', 'NewExternalPort': puerto, 'NewProtocol': proto})
        except OSError:
            pass


# ---------- DuckDNS: un nombre fijo que apunta a la IP de ahora del anfitrión ----------

def duckdns(dominio, token):
    """Pone el nombre dominio.duckdns.org en la IP pública de ahora (DuckDNS la ve sola). True si ha ido bien."""
    nombre = dominio.replace('.duckdns.org', '').strip()
    url = f'https://www.duckdns.org/update?domains={nombre}&token={token.strip()}&ip='
    try:
        with urllib.request.urlopen(url, timeout=10) as r:
            return r.read().decode().strip() == 'OK'
    except OSError:
        return False


# ---------- el servidor (solo en el PC del anfitrión) ----------

class SinSesion(PermissionError):
    """El token no vale (servidor reiniciado o sesión cerrada): hay que volver a entrar."""


def _hash(clave, sal):
    return hashlib.pbkdf2_hmac('sha256', clave.encode(), bytes.fromhex(sal), 200_000).hex()


class Servidor:
    def __init__(self, carpeta, citra_room=None):
        self.carpeta = Path(carpeta)
        self.carpeta.mkdir(parents=True, exist_ok=True)
        self.f_usuarios = self.carpeta / 'usuarios.json'
        self.usuarios = json.loads(self.f_usuarios.read_text(encoding='utf-8')) if self.f_usuarios.exists() else {}
        self.lock = threading.Lock()
        self.sesiones = {}               # token -> usuario
        self.vistos = {}                 # usuario -> (hora, estado)
        self.tareas = {}                 # usuario -> [tarea]
        self.respuestas = {}             # id -> (Event, resultado)
        self.fallos = {}                 # ip -> [horas de intentos fallidos]
        self.clave_sala = secrets.token_hex(6)
        self.citra_room = citra_room
        self.sala = None
        self.http = None

    # --- cuentas ---
    def _guardar(self):
        tmp = self.f_usuarios.with_suffix('.tmp')
        tmp.write_text(json.dumps(self.usuarios, indent=1), encoding='utf-8')
        tmp.replace(self.f_usuarios)

    def registrar(self, usuario, clave):
        if not re.fullmatch(r'[A-Za-z0-9_]{3,16}', usuario or ''):
            raise ValueError('El usuario tiene que tener de 3 a 16 letras, números o _')
        if len(clave or '') < 4:
            raise ValueError('La contraseña tiene que tener al menos 4 caracteres')
        with self.lock:
            if usuario.lower() in (u.lower() for u in self.usuarios):
                raise ValueError('Ese usuario ya existe')
            sal = secrets.token_hex(16)
            self.usuarios[usuario] = {'sal': sal, 'hash': _hash(clave, sal), 'admin': not self.usuarios}
            self._guardar()

    def entrar(self, usuario, clave, ip):
        ahora = time.time()
        with self.lock:
            intentos = [t for t in self.fallos.get(ip, []) if ahora - t < 60]
            self.fallos[ip] = intentos
            if len(intentos) >= 8:
                raise ValueError('Demasiados intentos: espera un minuto')
        u = next((self.usuarios[k] | {'nombre': k} for k in self.usuarios if k.lower() == (usuario or '').lower()), None)
        if not u or not hmac.compare_digest(u['hash'], _hash(clave or '', u['sal'])):
            with self.lock:
                self.fallos[ip].append(ahora)
            raise ValueError('Usuario o contraseña incorrectos')
        token = secrets.token_hex(24)
        with self.lock:
            self.sesiones[token] = u['nombre']
        return {'token': token, 'usuario': u['nombre'], 'admin': u['admin'],
                'sala': {'puerto': PUERTO_SALA, 'clave': self.clave_sala, 'activa': self.sala is not None}}

    def _usuario(self, token):
        u = self.sesiones.get(token or '')
        if not u:
            raise SinSesion('Vuelve a entrar')
        return u

    # --- presencia y encargos ---
    def latido(self, token, estado):
        u = self._usuario(token)
        ahora = time.time()
        with self.lock:
            self.vistos[u] = (ahora, estado or {})
            tareas, self.tareas[u] = self.tareas.get(u, []), []
            conectados = [{'usuario': k, 'admin': self.usuarios.get(k, {}).get('admin', False), **v[1]}
                          for k, v in sorted(self.vistos.items()) if ahora - v[0] < CONECTADO]
        return {'conectados': conectados, 'tareas': tareas}

    def salir(self, token):
        with self.lock:
            u = self.sesiones.pop(token or '', None)
            self.vistos.pop(u, None)

    def pokehex(self, token, clave_hex, objetivo, que, datos, clave_correcta):
        u = self._usuario(token)
        if not self.usuarios.get(u, {}).get('admin'):
            raise PermissionError('Solo el administrador puede abrir el PokéHex de otro jugador')
        if not hmac.compare_digest(clave_hex or '', clave_correcta):
            raise PermissionError('Contraseña del PokéHex incorrecta')
        with self.lock:
            visto = self.vistos.get(objetivo)
            if not visto or time.time() - visto[0] > CONECTADO:
                raise ValueError(f'{objetivo} no está conectado')
            ident = secrets.token_hex(8)
            fin = threading.Event()
            self.respuestas[ident] = [fin, None]
            self.tareas.setdefault(objetivo, []).append({'id': ident, 'que': que, 'datos': datos})
        if not fin.wait(LATIDO * 5):
            self.respuestas.pop(ident, None)
            raise ValueError(f'{objetivo} no contesta')
        return self.respuestas.pop(ident)[1]

    def resultado(self, token, ident, res):
        self._usuario(token)
        r = self.respuestas.get(ident)
        if r:
            r[1] = res
            r[0].set()

    # --- arrancar y parar ---
    def arrancar(self, clave_hex):
        srv = self

        class Peticion(BaseHTTPRequestHandler):
            def log_message(self, *a):
                pass

            def do_GET(self):
                # /descargar: el Pokelocke.exe del anfitrión, para repartirlo con un comando
                exe = Path(sys.executable)
                if self.path.split('?')[0] != '/descargar' or not getattr(sys, 'frozen', False):
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'application/octet-stream')
                self.send_header('Content-Disposition', 'attachment; filename="Pokelocke.exe"')
                self.send_header('Content-Length', str(exe.stat().st_size))
                self.end_headers()
                with open(exe, 'rb') as f:
                    shutil.copyfileobj(f, self.wfile, 1 << 20)

            def do_POST(self):
                try:
                    largo = min(int(self.headers.get('Content-Length') or 0), 1_000_000)
                    d = json.loads(self.rfile.read(largo) or b'{}')
                    ruta, ip = self.path, self.client_address[0]
                    if ruta == '/registro':
                        srv.registrar(d.get('usuario'), d.get('clave'))
                        r = srv.entrar(d.get('usuario'), d.get('clave'), ip)
                    elif ruta == '/entrar':
                        r = srv.entrar(d.get('usuario'), d.get('clave'), ip)
                    elif ruta == '/latido':
                        r = srv.latido(d.get('token'), d.get('estado'))
                    elif ruta == '/salir':
                        r = srv.salir(d.get('token')) or {'ok': True}
                    elif ruta == '/resultado':
                        r = srv.resultado(d.get('token'), d.get('id'), d.get('resultado')) or {'ok': True}
                    elif ruta == '/pokehex':
                        r = srv.pokehex(d.get('token'), d.get('clave_hex'), d.get('usuario'), d.get('que'),
                                        d.get('datos') or {}, clave_hex)
                    else:
                        raise ValueError('No existe')
                    codigo = 200
                except SinSesion as e:
                    r, codigo = {'error': str(e), 'sesion': False}, 401
                except PermissionError as e:
                    r, codigo = {'error': str(e)}, 403
                except (ValueError, KeyError, TypeError) as e:
                    r, codigo = {'error': str(e)}, 400
                cuerpo = json.dumps(r).encode()
                self.send_response(codigo)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(cuerpo)))
                self.end_headers()
                self.wfile.write(cuerpo)

        ThreadingHTTPServer.allow_reuse_address = False
        self.http = ThreadingHTTPServer(('0.0.0.0', PUERTO_SERVIDOR), Peticion)
        threading.Thread(target=self.http.serve_forever, daemon=True).start()
        if self.citra_room and Path(self.citra_room).exists():
            self.sala = subprocess.Popen([str(self.citra_room), '--room-name', 'Pokelocke', '--port', str(PUERTO_SALA),
                                          '--max_members', '16',
                                          '--preferred-game', 'Pokemon Y', '--preferred-game-id', '0004000000055E00',
                                          '--room-description', 'Sala de Pokelocke'],
                                         creationflags=0x08000000)

    def parar(self):
        if self.http:
            self.http.shutdown()
            self.http.server_close()
            self.http = None
        if self.sala:
            self.sala.terminate()
            self.sala = None


# ---------- el cliente (en todos los Pokelocke) ----------

def peticion(direccion, ruta, datos, espera=10):
    req = urllib.request.Request(f'http://{direccion}:{PUERTO_SERVIDOR}{ruta}', json.dumps(datos).encode(),
                                 {'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=espera) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        try:
            return json.load(e)
        except ValueError:
            return {'error': f'Error {e.code} del servidor'}
