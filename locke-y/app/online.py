"""Pokelocke online: cuentas, quién está conectado, la sala de Citra y el PokéHex a distancia.

Un Pokelocke hace de servidor (el del anfitrión, con un interruptor en la app): escucha en el puerto
PUERTO_SERVIDOR, abre él solo los puertos en el router por UPnP y arranca citra-room para jugar online
(combates e intercambios por «juego inalámbrico» de Pokémon X/Y). Los demás Pokelocke se conectan a la
dirección de app/online.json, entran con su usuario y mandan un latido cada pocos segundos.

El PokéHex de otro jugador: solo la cuenta de administrador («admin» en app/online.json) y con la contraseña
del PokéHex. El servidor deja el encargo al Pokelocke de ese jugador, que lo hace en su partida y contesta.
"""
import hashlib
import hmac
import json
import re
import secrets
import shutil
import socket
import ssl
import subprocess
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urljoin

import errores

PUERTO_SERVIDOR = 8766          # TCP http: solo /descargar y /version (la primera descarga, desde el navegador)
PUERTO_SEGURO = 8767            # TCP https: todo lo demás, con el certificado propio del anfitrión
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
    for proto, puerto in (('TCP', PUERTO_SERVIDOR), ('TCP', PUERTO_SEGURO), ('UDP', PUERTO_SALA)):
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
    for proto, puerto in (('TCP', PUERTO_SERVIDOR), ('TCP', PUERTO_SEGURO), ('UDP', PUERTO_SALA)):
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


# ---------- el cuadro del torneo ----------
# Cada partido sabe de dónde salen sus dos jugadores («fuentes»): {'j': nombre}, {'gana': id} (el ganador de otro
# partido) o {'pierde': id} (el perdedor). Con jugadores impares, el que se queda sin rival en la primera ronda espera
# al ganador de la repesca: los perdedores de la primera ronda juegan entre ellos al mejor de 1 (normas del Mega
# Pokelocke). Si una ronda posterior sale impar, el primero pasa directo a la siguiente (sin partido vacío).

def _partido(partidos, fase, ronda, fuentes, mejor_de=3, plaza=False):
    pid = f'{fase[0]}{ronda}-{sum(1 for q in partidos if q["fase"] == fase and q["ronda"] == ronda)}'
    partidos.append({'id': pid, 'fase': fase, 'ronda': ronda, 'mejor_de': mejor_de, 'plaza': plaza,
                     'fuentes': list(fuentes), 'ab': [None, None], 'gana': None, 'vivo': False, 'ma': '', 'mb': ''})
    return pid


def _eliminatoria(partidos, fuentes, fase, ronda, mejor_de):
    """Empareja las fuentes ronda a ronda hasta que queda una: la del ganador."""
    while len(fuentes) > 1:
        directo = [fuentes.pop(0)] if len(fuentes) % 2 else []
        fuentes = directo + [{'gana': _partido(partidos, fase, ronda, fuentes[k:k + 2], mejor_de)}
                             for k in range(0, len(fuentes), 2)]
        ronda += 1
    return fuentes[0]


def _cuadro(jugadores):
    """Partidos del torneo con los jugadores al azar."""
    js = list(jugadores)
    secrets.SystemRandom().shuffle(js)
    partidos = []
    sin_rival = js.pop() if len(js) % 2 else None
    primera = [_partido(partidos, 'principal', 0, [{'j': js[k]}, {'j': js[k + 1]}]) for k in range(0, len(js), 2)]
    entran = [{'gana': pid} for pid in primera]
    if sin_rival:
        perdedores = [{'pierde': pid} for pid in primera]
        repesca = _eliminatoria(partidos, perdedores, 'repesca', 0, 1)
        entran.append({'gana': _partido(partidos, 'principal', 0, [{'j': sin_rival}, repesca], plaza=True)})
    final = _eliminatoria(partidos, entran, 'principal', 1, 3)
    _propagar(partidos)
    return partidos, final['gana']


def _jugador(partidos, fuente):
    if not fuente:
        return None
    if 'j' in fuente:
        return fuente['j']
    q = next(q for q in partidos if q['id'] == (fuente.get('gana') or fuente.get('pierde')))
    if q['gana'] is None:
        return None
    return q['ab'][q['gana'] if 'gana' in fuente else 1 - q['gana']]


def _propagar(partidos):
    """Rehace quién juega cada partido desde los resultados. Si un partido cambia de jugadores, su resultado se
    borra. Van en orden: cada partido solo depende de los de antes."""
    for p in partidos:
        nuevos = [_jugador(partidos, f) for f in p['fuentes']]
        if nuevos != p['ab']:
            p.update(ab=nuevos, gana=None, vivo=False, ma='', mb='')


def _al_dia(t):
    """Un torneo guardado con el formato de antes (rondas fijas y pases directos) pasa al de ahora con sus resultados."""
    if not t or 'partidos' in t:
        return t
    partidos = []
    for r, ronda in enumerate(t['rondas']):
        for i, p in enumerate(ronda):
            fuentes = ([{'j': n} if n else None for n in p['ab']] if r == 0
                       else [{'gana': f'p{r - 1}-{2 * i}'}, {'gana': f'p{r - 1}-{2 * i + 1}'}])
            partidos.append({'id': f'p{r}-{i}', 'fase': 'principal', 'ronda': r, 'mejor_de': 3, 'plaza': False,
                             'fuentes': fuentes, 'ab': p['ab'], 'gana': p.get('gana'), 'vivo': p.get('vivo', False),
                             'ma': p.get('ma', ''), 'mb': p.get('mb', '')})
    t = {k: v for k, v in t.items() if k != 'rondas'}
    t.update(partidos=partidos, final=partidos[-1]['id'])        # la última ronda tiene un partido: la final
    return t


def _hash(clave, sal):
    return hashlib.pbkdf2_hmac('sha256', clave.encode(), bytes.fromhex(sal), 200_000).hex()


class Servidor:
    def __init__(self, carpeta, citra_room=None, admin=''):
        self.carpeta = Path(carpeta)
        self.carpeta.mkdir(parents=True, exist_ok=True)
        self.f_usuarios = self.carpeta / 'usuarios.json'
        self.usuarios = json.loads(self.f_usuarios.read_text(encoding='utf-8')) if self.f_usuarios.exists() else {}
        # el administrador es la cuenta con ese nombre, y solo esa (también en las cuentas ya creadas)
        self.admin = admin.lower()
        for nombre, u in self.usuarios.items():
            u['admin'] = nombre.lower() == self.admin
        self.lock = threading.Lock()
        self.sesiones = {}               # token -> usuario
        self.vistos = {}                 # usuario -> (hora, estado)
        self.tareas = {}                 # usuario -> [tarea]
        self.respuestas = {}             # id -> (Event, resultado)
        self.fallos = {}                 # ip -> [horas de intentos fallidos]
        self.registros = {}              # ip -> hora del último registro
        self.clave_sala = secrets.token_hex(6)
        # solo existe en la memoria del Pokelocke anfitrión: la cuenta del administrador solo se puede crear desde él,
        # para que en un servidor nuevo nadie se registre antes con ese nombre
        self.clave_anfitrion = secrets.token_hex(16)
        self.citra_room = citra_room
        self.sala = None
        self.http = None

    # --- cuentas ---
    def _guardar(self):
        tmp = self.f_usuarios.with_suffix('.tmp')
        tmp.write_text(json.dumps(self.usuarios, indent=1), encoding='utf-8')
        tmp.replace(self.f_usuarios)

    MAX_CUENTAS, ESPERA_REGISTRO = 64, 60

    def registrar(self, usuario, clave, ip='', anfitrion=''):
        # el usuario es también el apodo de la sala de Citra, que no deja entrar con menos de 4
        if not re.fullmatch(r'[A-Za-z0-9_]{4,16}', usuario or ''):
            raise ValueError('El usuario tiene que tener de 4 a 16 letras, números o _')
        if not isinstance(clave, str) or not 4 <= len(clave) <= 128:
            raise ValueError('La contraseña tiene que tener de 4 a 128 caracteres')
        anfitrion = hmac.compare_digest(str(anfitrion or ''), self.clave_anfitrion)
        admin = bool(self.admin) and usuario.lower() == self.admin
        if admin and not anfitrion:
            raise ValueError('Ese nombre está reservado')
        with self.lock:
            # el servidor da a internet: sin límite, cualquiera podría llenarlo de cuentas
            if not anfitrion and time.time() - self.registros.get(ip, 0) < self.ESPERA_REGISTRO:
                raise ValueError('Espera un minuto antes de crear otra cuenta')
            if len(self.usuarios) >= self.MAX_CUENTAS:
                raise ValueError('El servidor ya tiene el máximo de cuentas')
            if usuario.lower() in (u.lower() for u in self.usuarios):
                raise ValueError('Ese usuario ya existe')
            self.registros[ip] = time.time()
            sal = secrets.token_hex(16)
            self.usuarios[usuario] = {'sal': sal, 'hash': _hash(clave, sal), 'admin': admin}
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
                'sala': {'puerto': PUERTO_SALA, 'clave': self.clave_sala, 'activa': self.sala_viva()}}

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

    def pokehex(self, token, objetivo, que, datos):
        u = self._usuario(token)
        if not self.usuarios.get(u, {}).get('admin'):
            raise PermissionError('Solo el administrador puede abrir el PokéHex de otro jugador')
        return self._encargar(objetivo, que, datos)

    def pedir_log(self, token, objetivo):
        """El registro de errores (pokelocke.log) de un jugador conectado, para el administrador."""
        u = self._usuario(token)
        if not self.usuarios.get(u, {}).get('admin'):
            raise PermissionError('Solo el administrador puede ver el registro de otro jugador')
        return self._encargar(objetivo, 'log', {})

    def _encargar(self, objetivo, que, datos):
        """Deja un encargo al Pokelocke de un jugador conectado (lo recoge en su siguiente latido) y espera su respuesta."""
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

    # --- foto de perfil: un JPEG pequeño en base64 que recorta y reduce la app antes de mandarlo ---
    def poner_foto(self, token, imagen):
        u = self._usuario(token)
        if not isinstance(imagen, str) or not imagen.startswith('data:image/jpeg;base64,') or len(imagen) > 200_000:
            raise ValueError('La foto tiene que ser una imagen pequeña')
        with self.lock:
            self.usuarios[u]['foto'] = imagen
            self._guardar()
        return {'ok': True}

    # --- torneo (eliminatoria con repesca): lo ven todos, lo cambia solo el administrador ---
    # {'nombre', 'tope', 'jugadores', 'partidos': [ver _cuadro], 'final': id del partido final}
    def _torneo_f(self):
        return self.carpeta / 'torneo.json'

    def torneo(self, token):
        u = self._usuario(token)
        f = self._torneo_f()
        t = _al_dia(json.loads(f.read_text(encoding='utf-8'))) if f.exists() else None
        with self.lock:
            fotos = {k: v['foto'] for k, v in self.usuarios.items() if v.get('foto')}
            return {'torneo': t, 'fotos': fotos, 'usuarios': sorted(self.usuarios), 'yo': u,
                    'admin': self.usuarios.get(u, {}).get('admin', False)}

    def editar_torneo(self, token, que, d):
        u = self._usuario(token)
        if not self.usuarios.get(u, {}).get('admin'):
            raise PermissionError('Solo el administrador puede cambiar el torneo')
        f = self._torneo_f()
        t = _al_dia(json.loads(f.read_text(encoding='utf-8'))) if f.exists() else None
        if que == 'crear':
            jugadores = [j for j in (d.get('jugadores') or []) if j in self.usuarios]
            if len(jugadores) < 2:
                raise ValueError('Hacen falta al menos 2 jugadores')
            if len(jugadores) > 64:
                raise ValueError('Como mucho 64 jugadores')
            partidos, final = _cuadro(jugadores)
            t = {'nombre': str(d.get('nombre') or 'Gran torneo')[:60], 'tope': d.get('tope'),
                 'jugadores': jugadores, 'partidos': partidos, 'final': final}
        elif que == 'reiniciar':
            f.unlink(missing_ok=True)
            return {'ok': True}
        elif not t:
            raise ValueError('Aún no hay torneo')
        elif que == 'randomizar':
            t['partidos'], t['final'] = _cuadro(t['jugadores'])
        elif que in ('ganador', 'vivo', 'marcador'):
            p = next((q for q in t['partidos'] if q['id'] == d.get('id')), None)
            if not p:
                raise ValueError('Ese partido no existe')
            if que == 'vivo':
                p['vivo'] = not p.get('vivo')
            elif que == 'marcador':
                p['ma'], p['mb'] = str(d.get('ma', ''))[:3], str(d.get('mb', ''))[:3]
            else:
                lado = d.get('lado')
                if lado not in (0, 1, None) or (lado is not None and not all(p['ab'])):
                    raise ValueError('Ese partido aún no tiene sus dos jugadores')
                p['gana'] = None if p.get('gana') == lado else lado
                p['vivo'] = False
                _propagar(t['partidos'])
        else:
            raise ValueError('Acción desconocida')
        tmp = f.with_suffix('.tmp')
        tmp.write_text(json.dumps(t, indent=1), encoding='utf-8')
        tmp.replace(f)
        return {'ok': True}

    # --- arrancar y parar ---
    def arrancar(self):
        srv = self
        cert, clave = self.carpeta / 'cert.pem', self.carpeta / 'clave.pem'
        if not cert.exists() or not clave.exists():
            raise RuntimeError(f'Falta el certificado del servidor (cert.pem y clave.pem en {self.carpeta}). Se crea al '
                               'construir el instalador en este PC con app/empaquetar.py.')
        contexto = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        contexto.minimum_version = ssl.TLSVersion.TLSv1_2
        contexto.load_cert_chain(cert, clave)

        class Descargas(BaseHTTPRequestHandler):
            """En http (PUERTO_SERVIDOR): solo la primera descarga del instalador y su versión."""
            def log_message(self, *a):
                pass

            def do_POST(self):
                cuerpo = json.dumps({'error': 'Este servidor ya solo atiende por conexión cifrada: actualiza Pokelocke '
                                              'con el instalador del anfitrión'}).encode()
                self.send_response(426)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(cuerpo)))
                self.end_headers()
                self.wfile.write(cuerpo)

            def do_GET(self):
                # /version: la versión del instalador que se reparte y su huella (cada Pokelocke la compara con la suya
                # y comprueba con la huella lo que se descarga)
                if self.path.split('?')[0] == '/version':
                    f = Path(sys.executable).parent / 'PokelockeSetup.version'
                    cuerpo = json.dumps({'version': f.read_text(encoding='utf-8').strip() if f.exists() else None,
                                         'sha256': huella_instalador()}).encode()
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(cuerpo)))
                    self.end_headers()
                    self.wfile.write(cuerpo)
                    return
                # /descargar: el instalador del anfitrión (PokelockeSetup.exe junto a su Pokelocke.exe; lo deja
                # ahí app/empaquetar.py), para repartirlo con un enlace
                exe = Path(sys.executable).parent / 'PokelockeSetup.exe'
                if self.path.split('?')[0] != '/descargar' or not exe.exists():
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'application/octet-stream')
                self.send_header('Content-Disposition', 'attachment; filename="PokelockeSetup.exe"')
                self.send_header('Content-Length', str(exe.stat().st_size))
                self.end_headers()
                with open(exe, 'rb') as f:
                    shutil.copyfileobj(f, self.wfile, 1 << 20)

        class Peticion(Descargas):
            """En https (PUERTO_SEGURO): todo."""
            def do_POST(self):
                try:
                    largo = min(int(self.headers.get('Content-Length') or 0), 1_000_000)
                    d = json.loads(self.rfile.read(largo) or b'{}')
                    ruta, ip = self.path, self.client_address[0]
                    if not isinstance(d, dict):
                        raise ValueError('Petición no válida')
                    if ruta == '/registro':
                        srv.registrar(d.get('usuario'), d.get('clave'), ip, d.get('anfitrion'))
                        r = srv.entrar(d.get('usuario'), d.get('clave'), ip)
                    elif ruta == '/entrar':
                        r = srv.entrar(d.get('usuario'), d.get('clave'), ip)
                    elif ruta == '/latido':
                        r = srv.latido(d.get('token'), d.get('estado'))
                    elif ruta == '/salir':
                        r = srv.salir(d.get('token')) or {'ok': True}
                    elif ruta == '/resultado':
                        r = srv.resultado(d.get('token'), d.get('id'), d.get('resultado')) or {'ok': True}
                    elif ruta == '/torneo':
                        r = srv.torneo(d.get('token'))
                    elif ruta == '/torneo/editar':
                        r = srv.editar_torneo(d.get('token'), d.get('que'), d)
                    elif ruta == '/foto':
                        r = srv.poner_foto(d.get('token'), d.get('imagen'))
                    elif ruta == '/log':
                        r = srv.pedir_log(d.get('token'), d.get('usuario'))
                    elif ruta == '/pokehex':
                        r = srv.pokehex(d.get('token'), d.get('usuario'), d.get('que'), d.get('datos') or {})
                    else:
                        raise ValueError('No existe')
                    codigo = 200
                except SinSesion as e:
                    r, codigo = {'error': str(e), 'sesion': False}, 401
                except PermissionError as e:
                    r, codigo = {'error': str(e)}, 403
                except (ValueError, KeyError, TypeError) as e:
                    r, codigo = {'error': str(e)}, 400
                except Exception as e:              # un error inesperado no deja la petición sin respuesta
                    r, codigo = {'error': errores.describir(e, f'Servidor online {self.path}',
                                                            registro='el pokelocke.log del anfitrión')}, 500
                cuerpo = json.dumps(r).encode()
                self.send_response(codigo)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(cuerpo)))
                self.end_headers()
                self.wfile.write(cuerpo)

        class Cifrado(ThreadingHTTPServer):
            allow_reuse_address = False

            def get_request(self):
                # el saludo TLS se hace en el hilo de cada petición, no aquí: un cliente lento no frena a los demás
                s, direccion = self.socket.accept()
                s.settimeout(30)
                return contexto.wrap_socket(s, server_side=True, do_handshake_on_connect=False), direccion

            def handle_error(self, request, client_address):
                pass                                    # conexiones cortadas o sin cifrar: no llenan el registro

        ThreadingHTTPServer.allow_reuse_address = False
        self.http = ThreadingHTTPServer(('0.0.0.0', PUERTO_SERVIDOR), Descargas)
        self.https = Cifrado(('0.0.0.0', PUERTO_SEGURO), Peticion)
        for s in (self.http, self.https):
            threading.Thread(target=s.serve_forever, daemon=True).start()
        if self.citra_room and Path(self.citra_room).exists():
            # si Pokelocke se cerró de golpe, la sala de antes sigue viva con el puerto cogido y la nueva no podría abrirlo
            subprocess.run(['taskkill', '/F', '/IM', Path(self.citra_room).name], capture_output=True, creationflags=0x08000000)
            self._abrir_sala()
            threading.Thread(target=self._vigilar_sala, daemon=True).start()

    def _abrir_sala(self):
        self.sala = subprocess.Popen([str(self.citra_room), '--room-name', 'Pokelocke', '--port', str(PUERTO_SALA),
                                      '--max_members', '16',
                                      '--preferred-game', 'Pokemon Y', '--preferred-game-id', '0004000000055E00',
                                      '--room-description', 'Sala de Pokelocke'],
                                     creationflags=0x08000000)

    def sala_viva(self):
        return self.sala is not None and self.sala.poll() is None

    def _vigilar_sala(self):
        """Si la sala se cae se abre otra; mientras no vuelva, sala_viva() lo dice y la ventana lo avisa."""
        while self.sala is not None:
            time.sleep(10)
            if self.sala is not None and not self.sala_viva():
                self._abrir_sala()

    def parar(self):
        for nombre in ('http', 'https'):
            s = getattr(self, nombre, None)
            if s:
                s.shutdown()
                s.server_close()
                setattr(self, nombre, None)
        sala, self.sala = self.sala, None
        if sala:
            sala.terminate()


# ---------- el cliente (en todos los Pokelocke) ----------

# el certificado del anfitrión: el único en que confía el cliente. Lo pone main.py (va en app/online.json del
# instalador, que lo mete empaquetar.py; en el PC anfitrión vale también el suyo de datos/servidor)
certificado = lambda: None                              # noqa: E731


class SinCertificado(OSError):
    pass


def abrir(direccion, ruta, datos=None, espera=10):
    """Una petición https al servidor, que solo vale si contesta con el certificado del anfitrión: nadie puede hacerse
    pasar por él ni leer lo que va y viene (contraseñas, registros, el instalador)."""
    pem = certificado()
    if not pem:
        raise SinCertificado('este Pokelocke no tiene el certificado del servidor; instálalo con el instalador del anfitrión')
    contexto = ssl.create_default_context(cadata=pem)
    contexto.check_hostname = False                     # el certificado ya es el que tiene que ser, venga de la IP que venga
    req = urllib.request.Request(f'https://{direccion}:{PUERTO_SEGURO}{ruta}',
                                 None if datos is None else json.dumps(datos).encode(), {'Content-Type': 'application/json'})
    return urllib.request.urlopen(req, timeout=espera, context=contexto)


def huella_instalador(_cache={}):
    """SHA-256 de PokelockeSetup.exe (el que se reparte), guardada mientras el archivo no cambie."""
    exe = Path(sys.executable).parent / 'PokelockeSetup.exe'
    if not exe.exists():
        return None
    clave = (exe.stat().st_size, exe.stat().st_mtime_ns)
    if _cache.get('clave') != clave:
        h = hashlib.sha256()
        with open(exe, 'rb') as f:
            for trozo in iter(lambda: f.read(1 << 20), b''):
                h.update(trozo)
        _cache.update(clave=clave, huella=h.hexdigest())
    return _cache['huella']


def peticion(direccion, ruta, datos, espera=10):
    try:
        with abrir(direccion, ruta, datos, espera) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        try:
            return json.load(e)
        except ValueError:
            return {'error': f'Error {e.code} del servidor'}
