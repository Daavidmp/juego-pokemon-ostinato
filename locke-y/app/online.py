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
DUELO_MEDALLA = 4               # los duelos acaban al llegar al 4.º gimnasio (el gran torneo, a mitad de aventura)
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

def _renombrar(valor, viejo, nuevo):
    """El mismo dato (el torneo, los duelos) con un jugador renombrado, solo donde el texto (o la clave) es exactamente su nombre."""
    if isinstance(valor, dict):
        return {(nuevo if k == viejo else k): _renombrar(v, viejo, nuevo) for k, v in valor.items()}
    if isinstance(valor, list):
        return [_renombrar(v, viejo, nuevo) for v in valor]
    return nuevo if valor == viejo else valor


def huella_evento(anterior, e):
    """La huella de un evento, encadenada con la del anterior: cambiar o quitar uno descuadra los siguientes."""
    cuerpo = {k: e[k] for k in ('n', 't', 'tipo', 'nivel', 'texto')}
    return hashlib.sha256((anterior + json.dumps(cuerpo, sort_keys=True, ensure_ascii=False)).encode()).hexdigest()


class SinSesion(PermissionError):
    """El token no vale (servidor reiniciado o sesión cerrada): hay que volver a entrar."""


# ---------- el cuadro del torneo ----------
# Cada partido sabe de dónde salen sus dos jugadores («fuentes»): {'j': nombre}, {'gana': id} (el ganador de otro
# partido) o {'pierde': id} (el perdedor). Normas del Mega Pokelocke (1.3.3):
#   - Nadie pasa de ronda sin combatir. Si en una ronda quedan impares, el que se queda sin rival juega al mejor de 3
#     contra el perdedor de uno de los combates de esa misma ronda («segunda oportunidad», 'segunda': True); quien
#     gane pasa a la siguiente. Con 10: 5 combates; 2 + 1 de segunda oportunidad; 1 + 1; y la final.
#   - Los que pierden en semifinales se juegan el 3.er puesto al mejor de 1 ('tercero': True, en la columna de la
#     final). Si las semifinales son de 3 (una de segunda oportunidad), no hace falta: el 3.º es quien pierde esa.
#   - Para que se repitan los menos enfrentamientos posibles, se prueban muchas formas de montarlo (ver _cuadro).

def _partido(partidos, fase, ronda, fuentes, mejor_de=3, **marca):
    pid = f'{fase[0]}{ronda}-{sum(1 for q in partidos if q["fase"] == fase and q["ronda"] == ronda)}'
    partidos.append({'id': pid, 'fase': fase, 'ronda': ronda, 'mejor_de': mejor_de, 'plaza': False, **marca,
                     'fuentes': list(fuentes), 'ab': [None, None], 'gana': None, 'vivo': False, 'ma': '', 'mb': ''})
    return pid


def _armar(js, azar):
    """Un cuadro posible: azar elige quién se queda sin rival en cada ronda impar, contra el perdedor de qué combate
    juega y dónde sigue su ganador."""
    partidos = []
    fuentes = [{'j': n} for n in js]
    ronda = 0
    semis = []
    while len(fuentes) > 2:
        sobra = fuentes.pop(azar.randrange(len(fuentes))) if len(fuentes) % 2 else None
        semis = [_partido(partidos, 'principal', ronda, fuentes[k:k + 2]) for k in range(0, len(fuentes), 2)]
        siguen = [{'gana': pid} for pid in semis]
        if sobra:
            choque = semis[azar.randrange(len(semis))]
            otra = _partido(partidos, 'principal', ronda, [sobra, {'pierde': choque}], segunda=True)
            siguen.insert(azar.randrange(len(siguen) + 1), {'gana': otra})
            semis = []                       # semifinales de 3: el 3.º es quien pierde la segunda oportunidad
        fuentes = siguen
        ronda += 1
    final = _partido(partidos, 'principal', ronda, fuentes)
    if len(semis) == 2:
        _partido(partidos, 'principal', ronda, [{'pierde': s} for s in semis], mejor_de=1, tercero=True)
    return partidos, final


def _repetidos(partidos, veces, azar):
    """En qué parte de los torneos (con resultados al azar) se repite algún enfrentamiento."""
    sitio = {q['id']: k for k, q in enumerate(partidos)}
    malos = 0
    for _ in range(veces):
        ab, gana, vistos = [], [], set()
        for q in partidos:
            par = []
            for f in q['fuentes']:
                if 'j' in f:
                    par.append(f['j'])
                else:
                    k = sitio[f.get('gana') or f.get('pierde')]
                    par.append(ab[k][gana[k] if 'gana' in f else 1 - gana[k]])
            ab.append(par)
            gana.append(azar.randrange(2))
            vistos.add(frozenset(par))
        malos += len(vistos) < len(partidos)
    return malos / veces


def _cuadro(jugadores):
    """Partidos del torneo con los jugadores al azar. Con impares hay muchas formas de montar las segundas
    oportunidades: se prueban unas cuantas y se queda la que menos veces repite un enfrentamiento (con 10, de un 82 %
    de torneos con alguno repetido a un 65 %; el resto no se puede evitar: quien gana su segunda oportunidad puede
    volver a cruzarse con quien le ganó)."""
    js = list(jugadores)
    secrets.SystemRandom().shuffle(js)
    partidos, final = _cuadro_vacio(len(js))
    for k, n in enumerate(js):
        _poner(partidos, k, n)
    _propagar(partidos)
    return partidos, final


def _cuadro_vacio(n):
    """El cuadro de n jugadores sin nombres (1.3.3: los nombres salen de la máquina de bolas, uno a uno). Cada hueco de
    la primera ronda lleva su número ('hueco': 0, 1…) en el orden en que se ve, de arriba abajo: la bola k va al k."""
    js = [f'#{i}' for i in range(n)]
    azar = secrets.SystemRandom()
    if n & (n - 1) == 0:                                 # 2, 4, 8, 16…: sin impares, un solo cuadro
        partidos, final = _armar(js, azar)
    else:
        veces = max(20, min(200, 2_000_000 // (200 * n)))
        partidos, final = min((_armar(js, azar) for _ in range(200)), key=lambda c: _repetidos(c[0], veces, azar))
    # el orden en pantalla: recorriendo desde la final (como ordenCuadro en app.html)
    por, orden = {p['id']: p for p in partidos}, []

    def visita(pid):
        if pid in orden:
            return
        orden.append(pid)
        for f in por[pid]['fuentes']:
            if f and 'gana' in f:
                visita(f['gana'])
    visita(final)
    hueco = 0
    for pid in sorted((p['id'] for p in partidos if p['ronda'] == 0), key=orden.index):
        for f in por[pid]['fuentes']:
            if 'j' in f:
                f.update(j=None, hueco=hueco)
                hueco += 1
    _propagar(partidos)
    return partidos, final


def _poner(partidos, hueco, nombre):
    """El nombre que ha salido de la máquina, en su hueco (en grupos, el 3.º de cada grupo está en dos combates)."""
    puesto = False
    for p in partidos:
        for f in p['fuentes']:
            if f and f.get('hueco') == hueco:
                f['j'] = nombre
                puesto = True
    if not puesto:
        raise ValueError('Ese hueco no existe')


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


# ---------- formato de grupos (2.1.0, para 12 jugadores) ----------
# 4 grupos de 3 (A-D), todos contra todos al mejor de 3: 1 contra 2, 3 contra quien pierde y 3 contra quien gana.
# Con 2 victorias se pasa 1.º, con 1 se pasa 2.º y con 0 se queda fuera. Con 1-1-1 ordena quién ha ganado más
# combates en sus Bo3 (el marcador); si aún hay empate, desempate al mejor de 1 ('desempate'). Pasan 8 a cuartos:
# los 1.º entre ellos y los 2.º entre ellos (sorteado, siempre de grupos distintos), montado para que en semifinales
# tampoco se crucen dos del mismo grupo. Semifinales, 3.er puesto (al mejor de 3) y final.
LETRAS = 'ABCD'


def _nuevo(pid, fase, ronda, fuentes, mejor_de=3, **marca):
    return {'id': pid, 'fase': fase, 'ronda': ronda, 'mejor_de': mejor_de, 'plaza': False, **marca,
            'fuentes': list(fuentes), 'ab': [None, None], 'gana': None, 'vivo': False, 'ma': '', 'mb': ''}


def _grupos_vacios():
    """Los 12 combates de grupo sin nombres: la bola k va al grupo k // 3, puesto k % 3."""
    partidos = []
    for g, L in enumerate(LETRAS):
        b = 3 * g
        uno = _nuevo(f'g{L}1', 'grupo', 0, [{'j': None, 'hueco': b}, {'j': None, 'hueco': b + 1}], grupo=L)
        partidos += [uno, _nuevo(f'g{L}2', 'grupo', 1, [{'j': None, 'hueco': b + 2}, {'pierde': uno['id']}], grupo=L),
                     _nuevo(f'g{L}3', 'grupo', 2, [{'j': None, 'hueco': b + 2}, {'gana': uno['id']}], grupo=L)]
    _propagar(partidos)
    return partidos


def _num(x):
    try:
        return int(str(x).strip())
    except ValueError:
        return None


def _desempate_necesario(orden, c):
    """Con 1-1-1, qué empate queda después de contar los combates ganados (c): 'tres' (los tres igual: tres Bo1),
    'arriba' (empatan los dos primeros), 'abajo' (empatan los dos últimos) o None. orden va de más a menos."""
    x, y, z = orden
    if c[x] == c[y] == c[z]:
        return 'tres'
    if c[x] == c[y]:
        return 'arriba'
    if c[y] == c[z]:
        return 'abajo'
    return None


def _grupos_al_dia(t):
    """Después de cada cambio: la clasificación de cada grupo, sus desempates y el cuadro final (que se monta o se
    rehace solo cuando cambia quién pasa y en qué puesto)."""
    ps = t['partidos']
    grupo = [p for p in ps if p['fase'] == 'grupo']
    desempates = [p for p in ps if p['fase'] == 'desempate']
    nuevos_desempates, clasif = [], {}
    azar = secrets.SystemRandom()
    for L in LETRAS:
        suyos = [p for p in grupo if p['grupo'] == L]
        info = {'orden': None, 'falta_marcador': False}
        clasif[L] = info
        if any(p['gana'] is None for p in suyos):
            continue
        js = list(dict.fromkeys(n for p in suyos for n in p['ab']))
        v, c = {j: 0 for j in js}, {j: 0 for j in js}
        for p in suyos:
            v[p['ab'][p['gana']]] += 1
            for k, m in enumerate((p['ma'], p['mb'])):
                c[p['ab'][k]] += _num(m) or 0
        if sorted(v.values()) == [0, 1, 2]:
            info['orden'] = sorted(js, key=lambda j: -v[j])
            continue
        if any(_num(p['ma']) is None or _num(p['mb']) is None for p in suyos):
            info['falta_marcador'] = True                 # sin el marcador de los tres no se sabe quién va delante
            continue
        orden = sorted(js, key=lambda j: -c[j])
        caso = _desempate_necesario(orden, c)
        if not caso:
            info['orden'] = orden
            continue
        viejos = [p for p in desempates if p['grupo'] == L]
        x, y, z = orden
        if caso == 'tres':
            mismos = (len(viejos) == 3 and viejos[0].get('caso') == 'tres'
                      and {viejos[0]['fuentes'][0]['j'], viejos[0]['fuentes'][1]['j'], viejos[1]['fuentes'][0]['j']} == {x, y, z})
            if not mismos:                                # quién empieza y quién espera, por sorteo
                a, b, libre = azar.sample([x, y, z], 3)
                d1 = _nuevo(f'd{L}1', 'desempate', 0, [{'j': a}, {'j': b}], mejor_de=1, grupo=L, caso='tres')
                d2 = _nuevo(f'd{L}2', 'desempate', 1, [{'j': libre}, {'pierde': d1['id']}], mejor_de=1, grupo=L, caso='tres')
                d3 = _nuevo(f'd{L}3', 'desempate', 2, [{'gana': d1['id']}, {'gana': d2['id']}], mejor_de=1, grupo=L, caso='tres')
                viejos = [d1, d2, d3]
            nuevos_desempates += viejos
            d1, d2, d3 = viejos
            if d3['gana'] is not None and d2['gana'] is not None:
                info['orden'] = [d3['ab'][d3['gana']], d3['ab'][1 - d3['gana']], d2['ab'][1 - d2['gana']]]
        else:
            par = [x, y] if caso == 'arriba' else [y, z]
            if not (len(viejos) == 1 and viejos[0].get('caso') == caso and {viejos[0]['fuentes'][k]['j'] for k in (0, 1)} == set(par)):
                viejos = [_nuevo(f'd{L}1', 'desempate', 0, [{'j': par[0]}, {'j': par[1]}], mejor_de=1, grupo=L, caso=caso)]
            nuevos_desempates += viejos
            d = viejos[0]
            if d['gana'] is not None:
                g, p_ = d['ab'][d['gana']], d['ab'][1 - d['gana']]
                info['orden'] = [g, p_, z] if caso == 'arriba' else [x, g, p_]
    # el cuadro final: solo cuando los cuatro grupos tienen su orden
    principal = [p for p in ps if p['fase'] == 'principal']
    firma = None
    if all(clasif[L]['orden'] for L in LETRAS):
        firma = [[clasif[L]['orden'][0], clasif[L]['orden'][1]] for L in LETRAS]
    if firma != t.get('firma_cuadro'):
        principal = []
        t['firma_cuadro'], t['final'] = firma, None
        if firma:
            primero = {L: firma[k][0] for k, L in enumerate(LETRAS)}
            segundo = {L: firma[k][1] for k, L in enumerate(LETRAS)}
            p, q, r, s = azar.sample(LETRAS, 4)
            # semifinal 1: (1.º p – 1.º q) contra (2.º r – 2.º s); semifinal 2: (1.º r – 1.º s) contra (2.º p – 2.º q).
            # Así en semifinales nunca se juntan dos del mismo grupo
            cuartos = [_nuevo('c1', 'principal', 0, [{'j': primero[p]}, {'j': primero[q]}]),
                       _nuevo('c2', 'principal', 0, [{'j': segundo[r]}, {'j': segundo[s]}]),
                       _nuevo('c3', 'principal', 0, [{'j': primero[r]}, {'j': primero[s]}]),
                       _nuevo('c4', 'principal', 0, [{'j': segundo[p]}, {'j': segundo[q]}])]
            semis = [_nuevo('s1', 'principal', 1, [{'gana': 'c1'}, {'gana': 'c2'}]),
                     _nuevo('s2', 'principal', 1, [{'gana': 'c3'}, {'gana': 'c4'}])]
            principal = cuartos + semis + [_nuevo('f', 'principal', 2, [{'gana': 's1'}, {'gana': 's2'}]),
                                           _nuevo('t3', 'principal', 2, [{'pierde': 's1'}, {'pierde': 's2'}], tercero=True)]
            t['final'] = 'f'
    t['partidos'] = grupo + nuevos_desempates + principal
    t['clasif'] = clasif
    _propagar(t['partidos'])


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
        f = self._duelos_f()
        self.duelos = json.loads(f.read_text(encoding='utf-8')) if f.exists() else []
        self.lock = threading.Lock()
        self.lock_torneo = threading.Lock()         # dos organizadores sacando bola a la vez no se pisan
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
        self.eventos = {}                # usuario -> {'hasta': último evento recibido, 'h': su huella}
        self.lock_eventos = threading.Lock()

    # --- cuentas ---
    def _guardar(self):
        tmp = self.f_usuarios.with_suffix('.tmp')
        tmp.write_text(json.dumps(self.usuarios, indent=1), encoding='utf-8')
        tmp.replace(self.f_usuarios)

    MAX_CUENTAS, ESPERA_REGISTRO = 64, 60

    @staticmethod
    def _nombre_valido(usuario):
        if not isinstance(usuario, str) or not re.fullmatch(r'[A-Za-z0-9_]{4,16}', usuario):
            raise ValueError('El usuario tiene que tener de 4 a 16 letras, números o _')

    @staticmethod
    def _clave_valida(clave):
        if not isinstance(clave, str) or not 4 <= len(clave) <= 128:
            raise ValueError('La contraseña tiene que tener de 4 a 128 caracteres')

    def registrar(self, usuario, clave, ip='', anfitrion=''):
        # el usuario es también el apodo de la sala de Citra, que no deja entrar con menos de 4
        self._nombre_valido(usuario)
        self._clave_valida(clave)
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

    def _comprobar_clave(self, u, clave, ip):
        """Cambiar algo de la cuenta pide la contraseña, con el mismo límite de intentos que entrar."""
        ahora = time.time()
        with self.lock:
            intentos = [t for t in self.fallos.get(ip, []) if ahora - t < 60]
            self.fallos[ip] = intentos
            if len(intentos) >= 8:
                raise ValueError('Demasiados intentos: espera un minuto')
            c = self.usuarios[u]
            if not isinstance(clave, str) or not hmac.compare_digest(c['hash'], _hash(clave, c['sal'])):
                self.fallos[ip].append(ahora)
                raise ValueError('La contraseña no es correcta')

    def cambiar_clave(self, token, actual, nueva, ip):
        u = self._usuario(token)
        self._clave_valida(nueva)
        self._comprobar_clave(u, actual, ip)
        sal = secrets.token_hex(16)
        with self.lock:
            self.usuarios[u].update(sal=sal, hash=_hash(nueva, sal))
            self._guardar()
            # las otras sesiones de esa cuenta se cierran: si alguien la usaba, deja de poder
            self.sesiones = {t: n for t, n in self.sesiones.items() if n != u or t == token}
        return {'ok': True}

    def cambiar_nombre(self, token, nuevo, clave, ip):
        u = self._usuario(token)
        if self.usuarios[u].get('admin'):
            raise ValueError('El nombre del administrador no se puede cambiar')
        self._nombre_valido(nuevo)
        if nuevo == u:
            raise ValueError('Ya te llamas así')
        if self.admin and nuevo.lower() == self.admin:
            raise ValueError('Ese nombre está reservado')
        self._comprobar_clave(u, clave, ip)
        with self.lock:
            if any(k.lower() == nuevo.lower() and k != u for k in self.usuarios):
                raise ValueError('Ese usuario ya existe')
            self.usuarios = {(nuevo if k == u else k): v for k, v in self.usuarios.items()}
            self._guardar()
            self.sesiones = {t: (nuevo if n == u else n) for t, n in self.sesiones.items()}
            if u in self.vistos:
                self.vistos[nuevo] = self.vistos.pop(u)
            if u in self.tareas:
                self.tareas[nuevo] = self.tareas.pop(u)
            self.duelos = _renombrar(self.duelos, u, nuevo)
            self._guardar_duelos()
            f = self._torneo_f()
            if f.exists():
                f.write_text(json.dumps(_renombrar(json.loads(f.read_text(encoding='utf-8')), u, nuevo), ensure_ascii=False, indent=1),
                             encoding='utf-8')
        with self.lock_eventos:                # su actividad sigue con él, y queda apuntado el cambio
            if self._f_eventos(u).exists():
                self._f_eventos(u).replace(self._f_eventos(nuevo))
            if u in self.eventos:
                self.eventos[nuevo] = self.eventos.pop(u)
            self._f_eventos(nuevo).parent.mkdir(parents=True, exist_ok=True)
            with open(self._f_eventos(nuevo), 'a', encoding='utf-8') as a:
                a.write(json.dumps({'t': time.strftime('%Y-%m-%d %H:%M:%S'), 'tipo': 'servidor', 'nivel': 'aviso',
                                    'texto': f'Cambia su nombre: de {u} a {nuevo}'}, ensure_ascii=False) + '\n')
        return {'usuario': nuevo}

    def yo(self, token):
        """Quién es el dueño de una sesión, dicho por el servidor (el PokéHex solo se abre a DUENO_POKEHEX)."""
        u = self._usuario(token)
        return {'usuario': u, 'admin': self.usuarios.get(u, {}).get('admin', False)}

    def _usuario(self, token):
        u = self.sesiones.get(token or '')
        if not u:
            raise SinSesion('Vuelve a entrar')
        return u

    # --- presencia y encargos ---
    def latido(self, token, estado, eventos=None, total=None):
        u = self._usuario(token)
        ahora = time.time()
        hasta = self.recibir_eventos(u, eventos, total)
        estado = dict(estado) if isinstance(estado, dict) else {}
        tablero = self._casilla(estado.pop('tablero', None))
        cuentas = self._cuentas(estado.pop('locke', None))
        with self.lock:
            if tablero and self.usuarios.get(u, {}).get('tablero') != tablero:
                self.usuarios[u]['tablero'] = tablero
                self._guardar()
            if cuentas and self.usuarios.get(u, {}).get('locke') != cuentas:
                self.usuarios[u]['locke'] = cuentas
                self._guardar()
                self._mirar_duelos()
            self.vistos[u] = (ahora, estado)
            tareas, self.tareas[u] = self.tareas.get(u, []), []
            conectados = [{'usuario': k, 'admin': self.usuarios.get(k, {}).get('admin', False), **v[1], 'foto': self._foto_v(k)}
                          for k, v in sorted(self.vistos.items()) if ahora - v[0] < CONECTADO]
            en_linea = {c['usuario'] for c in conectados}
            tablero = [{'usuario': k, 'foto': self._foto_v(k), 'conectado': k in en_linea, **v['tablero']}
                       for k, v in sorted(self.usuarios.items()) if v.get('tablero')]
            coronas = self.coronas()
            duelos = self._duelos_de(u)
        return {'conectados': conectados, 'tareas': tareas, 'eventos_hasta': hasta, 'tablero': tablero, 'coronas': coronas,
                'duelos': duelos}

    @staticmethod
    def _casilla(t):
        """La casilla del tablero que manda cada jugador, limpia: viene de fuera."""
        if not isinstance(t, dict):
            return None
        try:
            return {'hito': str(t.get('hito', ''))[:24], 'n': max(0, min(99, int(t.get('n', 0)))),
                    'medallas': max(0, min(8, int(t.get('medallas', 0)))), 'vidas': max(0, min(999, int(t.get('vidas', 0))))}
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _cuentas(c):
        """Medallas y vidas perdidas del locke, en directo (con el juego abierto también): vienen de fuera."""
        if not isinstance(c, dict):
            return None
        try:
            return {'medallas': max(0, min(8, int(c.get('medallas', 0)))), 'perdidas': max(0, min(999, int(c.get('perdidas', 0))))}
        except (TypeError, ValueError):
            return None

    # --- duelos: un jugador reta a otro; quien pierda menos vidas hasta el 4.º gimnasio (el gran torneo) gana ---
    # [{'id', 'de', 'a', 'estado': pendiente|en_marcha|cerrado|rechazado|cancelado|caducado, 'base': {u: perdidas al
    #   empezar}, 'fin': {u: vidas perdidas al llegar a la medalla}, 'ganador': u o None (empate), 'fecha'}]
    # Cada uno se cierra al llegar a la medalla DUELO_MEDALLA (queda su cuenta); con los dos, se decide solo. El premio
    # (un huevo) y el castigo (una vida) los apunta cada Pokelocke en su partida al ver el duelo cerrado.
    def _duelos_f(self):
        return self.carpeta / 'duelos.json'

    def _guardar_duelos(self):
        tmp = self._duelos_f().with_suffix('.tmp')
        tmp.write_text(json.dumps(self.duelos, ensure_ascii=False, indent=1), encoding='utf-8')
        tmp.replace(self._duelos_f())

    def _duelos_de(self, u):
        """Los duelos de un jugador, con lo que lleva perdido cada uno (con self.lock)."""
        res = []
        for d in self.duelos:
            if u not in (d['de'], d['a']):
                continue
            van = {}
            for p in (d['de'], d['a']):
                c = self.usuarios.get(p, {}).get('locke') or {}
                van[p] = d['fin'].get(p, max(0, c.get('perdidas', 0) - d['base'].get(p, 0)) if d['estado'] == 'en_marcha' else 0)
            res.append({**d, 'van': van, 'medallas': {p: (self.usuarios.get(p, {}).get('locke') or {}).get('medallas', 0)
                                                       for p in (d['de'], d['a'])}})
        return res

    def _mirar_duelos(self):
        """Tras cada cambio en las cuentas de alguien (con self.lock): quien llega al 4.º gimnasio cierra su cuenta y,
        con las dos cerradas, gana el que menos vidas ha perdido (con las mismas, empate)."""
        cambio = False
        for d in self.duelos:
            cuentas = {p: self.usuarios.get(p, {}).get('locke') or {} for p in (d['de'], d['a'])}
            if d['estado'] == 'pendiente' and any(c.get('medallas', 0) >= DUELO_MEDALLA for c in cuentas.values()):
                d['estado'], cambio = 'caducado', True
            if d['estado'] != 'en_marcha':
                continue
            for p, c in cuentas.items():
                if p not in d['fin'] and c.get('medallas', 0) >= DUELO_MEDALLA:
                    d['fin'][p], cambio = max(0, c.get('perdidas', 0) - d['base'].get(p, 0)), True
            if len(d['fin']) == 2:
                a, b = d['fin'][d['de']], d['fin'][d['a']]
                d['estado'], d['ganador'] = 'cerrado', None if a == b else d['de'] if a < b else d['a']
        if cambio:
            self._guardar_duelos()

    def retar(self, token, a):
        u = self._usuario(token)
        with self.lock:
            if a == u or a not in self.usuarios:
                raise ValueError('Ese jugador no existe')
            for p in (u, a):
                c = self.usuarios[p].get('locke')
                if not c:
                    raise ValueError(f'{p} aún no tiene un locke empezado con esta versión de Pokelocke')
                if c['medallas'] >= DUELO_MEDALLA:
                    raise ValueError(f'{"Ya tienes" if p == u else p + " ya tiene"} la medalla {DUELO_MEDALLA}: el duelo es hasta el gran torneo')
                if any(p in (d['de'], d['a']) and d['estado'] in ('pendiente', 'en_marcha') for d in self.duelos):
                    raise ValueError(f'{"Ya tienes" if p == u else p + " ya tiene"} un duelo en marcha o por aceptar')
            self.duelos.append({'id': secrets.token_hex(4), 'de': u, 'a': a, 'estado': 'pendiente', 'base': {}, 'fin': {},
                                   'ganador': None, 'fecha': time.strftime('%Y-%m-%d %H:%M')})
            self._guardar_duelos()
            return {'duelos': self._duelos_de(u)}

    def responder_duelo(self, token, ident, si):
        """El retado acepta o rechaza; el que reta puede retirarlo mientras no se acepte."""
        u = self._usuario(token)
        with self.lock:
            d = next((x for x in self.duelos if x['id'] == ident and x['estado'] == 'pendiente'), None)
            if not d or u not in (d['de'], d['a']):
                raise ValueError('Ese duelo ya no está pendiente')
            if u == d['de']:
                d['estado'] = 'cancelado'
            elif not si:
                d['estado'] = 'rechazado'
            else:
                d['estado'] = 'en_marcha'
                d['base'] = {p: (self.usuarios.get(p, {}).get('locke') or {}).get('perdidas', 0) for p in (d['de'], d['a'])}
                d['empieza'] = time.strftime('%Y-%m-%d %H:%M')
            self._guardar_duelos()
            return {'duelos': self._duelos_de(u)}

    def _foto_v(self, u):
        """Una huella de su foto: pesa poco, va en cada latido y la foto solo se pide si cambia."""
        foto = self.usuarios.get(u, {}).get('foto')
        return hashlib.sha1(foto.encode()).hexdigest()[:10] if foto else None

    def fotos(self, token, usuarios):
        self._usuario(token)
        with self.lock:
            return {'fotos': {u: {'v': self._foto_v(u), 'imagen': self.usuarios[u]['foto']}
                              for u in (usuarios if isinstance(usuarios, list) else [])[:64]
                              if isinstance(u, str) and self.usuarios.get(u, {}).get('foto')}}

    def salir(self, token):
        with self.lock:
            u = self.sesiones.pop(token or '', None)
            self.vistos.pop(u, None)

    # --- la actividad de cada jugador (ver vigia.py): lo que llega aquí ya no se puede borrar desde su PC ---
    def _f_eventos(self, u):
        return self.carpeta / 'eventos' / f'{u}.jsonl'

    def _leer_eventos(self, u):
        try:
            with open(self._f_eventos(u), encoding='utf-8') as f:
                return [json.loads(l) for l in f if l.strip()]
        except (OSError, ValueError):
            return []

    def recibir_eventos(self, u, eventos, total):
        """Apunta los eventos nuevos de un jugador y dice hasta cuál tiene. Si su archivo no cuadra con lo recibido, lo
        apunta también: es lo que delata que lo ha borrado o cambiado."""
        ahora = time.strftime('%Y-%m-%d %H:%M:%S')
        with self.lock_eventos:
            s = self.eventos.get(u)
            if s is None:
                previos = [e for e in self._leer_eventos(u) if e.get('n')]
                s = self.eventos[u] = {'hasta': previos[-1]['n'] if previos else 0, 'h': previos[-1]['h'] if previos else ''}
            nuevos = []

            def aviso(texto):
                nuevos.append({'t': ahora, 'tipo': 'servidor', 'nivel': 'sospecha', 'texto': texto})

            if isinstance(total, int) and total < s['hasta']:
                aviso(f'Su registro ha vuelto atrás: el servidor tenía {s["hasta"]} eventos y su PC dice {total}. Lo ha borrado o ha cambiado de PC')
                s.update(hasta=total, h='')
            for e in (eventos if isinstance(eventos, list) else [])[:100]:
                if not isinstance(e, dict) or not isinstance(e.get('n'), int) or not all(isinstance(e.get(k), str) for k in ('t', 'tipo', 'nivel', 'texto', 'h')):
                    continue
                if e['n'] <= s['hasta']:
                    continue
                if e['n'] > s['hasta'] + 1:
                    aviso(f'Faltan los eventos {s["hasta"] + 1} a {e["n"] - 1}: los ha quitado de su registro')
                elif huella_evento(s['h'], e) != e['h']:
                    aviso(f'El evento {e["n"]} no cuadra con el anterior: su registro está modificado')
                s.update(hasta=e['n'], h=e['h'])
                nuevos.append({k: e[k] for k in ('n', 't', 'tipo', 'nivel', 'h')} | {'texto': e['texto'][:300], 'llego': ahora})
            if nuevos:
                self._f_eventos(u).parent.mkdir(parents=True, exist_ok=True)
                with open(self._f_eventos(u), 'a', encoding='utf-8') as f:
                    f.writelines(json.dumps(e, ensure_ascii=False) + '\n' for e in nuevos)
            return s['hasta']

    def actividad(self, token, objetivo):
        """Para el administrador: los eventos de un jugador, o sin jugador, el resumen de todos."""
        u = self._usuario(token)
        if not self.usuarios.get(u, {}).get('admin'):
            raise PermissionError('Solo el administrador puede ver la actividad de los jugadores')
        if objetivo:
            if objetivo not in self.usuarios:
                raise ValueError('Ese jugador no existe')
            return {'usuario': objetivo, 'eventos': self._leer_eventos(objetivo)[-3000:]}
        resumen = []
        for nombre in sorted(self.usuarios, key=str.lower):
            ev = self._leer_eventos(nombre)
            resumen.append({'usuario': nombre, 'eventos': len(ev), 'sospechas': sum(e['nivel'] == 'sospecha' for e in ev),
                            'avisos': sum(e['nivel'] == 'aviso' for e in ev), 'ultimo': ev[-1]['t'] if ev else None})
        return {'jugadores': resumen}

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
        with self.lock_torneo:
            t = _al_dia(json.loads(f.read_text(encoding='utf-8'))) if f.exists() else None
        if t and t.get('sorteo'):
            t = {**t, 'sorteo': {k: v for k, v in t['sorteo'].items() if k != 'bombo'}}     # lo que queda dentro, no se ve
        with self.lock:
            fotos = {k: v['foto'] for k, v in self.usuarios.items() if v.get('foto')}
            admin = self.usuarios.get(u, {}).get('admin', False)
            return {'torneo': t, 'fotos': fotos, 'usuarios': sorted(self.usuarios), 'yo': u, 'coronas': self.coronas(),
                    'admin': admin, 'puede': admin or bool(t and u in t.get('gestores', []))}

    # quién puede qué (1.3.3): crear y borrar el torneo, solo el administrador; lo demás (sortear, remover, sacar bola,
    # vaciar el cuadro y marcar resultados), también los organizadores que eligió al crearlo ('gestores')
    SOLO_ADMIN = ('crear', 'reiniciar')

    def editar_torneo(self, token, que, d):
        with self.lock_torneo:
            return self._editar_torneo(token, que, d)

    def _editar_torneo(self, token, que, d):
        u = self._usuario(token)
        admin = self.usuarios.get(u, {}).get('admin')
        f = self._torneo_f()
        t = _al_dia(json.loads(f.read_text(encoding='utf-8'))) if f.exists() else None
        if not admin and (que in self.SOLO_ADMIN or not t or u not in t.get('gestores', [])):
            raise PermissionError('Solo el administrador y los organizadores del torneo pueden cambiarlo'
                                  if que not in self.SOLO_ADMIN else 'Solo el administrador puede crear o borrar el torneo')
        if que == 'crear':
            jugadores = list(dict.fromkeys(j for j in (d.get('jugadores') or []) if j in self.usuarios))
            if len(jugadores) < 2:
                raise ValueError('Hacen falta al menos 2 jugadores')
            if len(jugadores) > 64:
                raise ValueError('Como mucho 64 jugadores')
            formato = 'grupos' if d.get('formato') == 'grupos' else 'eliminatoria'
            if formato == 'grupos' and len(jugadores) != 3 * len(LETRAS):
                raise ValueError(f'El formato de grupos es para {3 * len(LETRAS)} jugadores (has elegido {len(jugadores)})')
            partidos, final = (_grupos_vacios(), None) if formato == 'grupos' else _cuadro_vacio(len(jugadores))
            t = {'nombre': str(d.get('nombre') or 'Gran torneo')[:60], 'tope': d.get('tope'), 'formato': formato,
                 'jugadores': jugadores, 'partidos': partidos, 'final': final, 'id': time.strftime('%Y%m%d%H%M%S'),
                 'gestores': list(dict.fromkeys(g for g in (d.get('gestores') or []) if g in self.usuarios)),
                 'sorteo': self._sorteo_nuevo(jugadores)}
        elif que == 'reiniciar':
            f.unlink(missing_ok=True)
            return {'ok': True}
        elif not t:
            raise ValueError('Aún no hay torneo')
        elif que in ('vaciar', 'randomizar'):            # el cuadro otra vez vacío, para volver a sortear
            if t.get('formato') == 'grupos':
                t['partidos'], t['final'], t['firma_cuadro'] = _grupos_vacios(), None, None
            else:
                t['partidos'], t['final'] = _cuadro_vacio(len(t['jugadores']))
            t['sorteo'] = self._sorteo_nuevo(t['jugadores'])
        elif que in ('sortear', 'cerrar_sorteo', 'remover', 'sacar'):
            s = t.get('sorteo')
            if not s:
                raise ValueError('Este cuadro ya está sorteado')
            if que == 'sortear':
                s['abierto'] = True
            elif que == 'cerrar_sorteo':
                s['abierto'] = False
            elif que == 'remover':
                s['removido'] = s.get('removido', 0) + 1
            else:
                if not s['bombo']:
                    raise ValueError('Ya no quedan bolas')
                nombre = s['bombo'].pop(secrets.randbelow(len(s['bombo'])))
                hueco = len(s['sacados'])
                _poner(t['partidos'], hueco, nombre)
                s['sacados'].append({'nombre': nombre, 'hueco': hueco, 't': time.time()})
                _propagar(t['partidos'])
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
        if t.get('formato') == 'grupos':
            _grupos_al_dia(t)
        t.setdefault('id', time.strftime('%Y%m%d%H%M%S'))       # los torneos de antes no lo tenían
        self._coronar(t)
        tmp = f.with_suffix('.tmp')
        tmp.write_text(json.dumps(t, indent=1), encoding='utf-8')
        tmp.replace(f)
        return {'ok': True}

    @staticmethod
    def _sorteo_nuevo(jugadores):
        """La máquina de bolas llena: una bola por jugador. 'bombo' (lo que queda dentro) no sale del servidor."""
        return {'abierto': False, 'removido': 0, 'sacados': [], 'bombo': list(jugadores), 'total': len(jugadores)}

    @staticmethod
    def _podio(t):
        """Los puestos del torneo una vez decidida la final: 1 el que la gana, 2 el que la pierde y 3 el que gana el
        duelo por el tercer puesto (o, con semifinales de 3, el que pierde la segunda oportunidad; en los torneos de
        antes, sin ese duelo, los dos que pierden las semifinales). Sin final decidida, nadie."""
        partidos = {p['id']: p for p in t['partidos']}
        final = partidos.get(t.get('final'))
        if not final or final.get('gana') is None:
            return {}
        puestos = {final['ab'][final['gana']]: 1, final['ab'][1 - final['gana']]: 2}
        tercero = next((p for p in partidos.values() if p.get('tercero')), None)
        segunda = next((p for p in partidos.values() if p.get('segunda') and p['ronda'] == final['ronda'] - 1), None)
        if tercero or segunda:
            p = tercero or segunda
            if p.get('gana') is not None:
                puestos.setdefault(p['ab'][1 - p['gana'] if segunda and not tercero else p['gana']], 3)
            return puestos
        for f in final['fuentes']:
            semi = partidos.get((f or {}).get('gana'))
            if semi and semi['fase'] == 'principal' and semi['ronda'] == final['ronda'] - 1 and semi.get('gana') is not None:
                puestos.setdefault(semi['ab'][1 - semi['gana']], 3)
        return puestos

    def _coronar(self, t):
        """Las coronas del podio (oro, plata y bronce): en cuanto se decide la final se apuntan en sus cuentas, y se
        quitan o cambian si el resultado se deshace o cambia. Se quedan aunque luego se borre el torneo."""
        puestos = self._podio(t)
        with self.lock:
            cambio = False
            for k, v in self.usuarios.items():
                antes = v.get('coronas', [])
                ahora = [c for c in antes if c['id'] != t['id']] + ([{'id': t['id'], 'nombre': t['nombre'], 'puesto': puestos[k]}] if k in puestos else [])
                if ahora != antes:
                    cambio = True
                    if ahora:
                        v['coronas'] = ahora
                    else:
                        v.pop('coronas', None)
            if cambio:
                self._guardar()

    def coronas(self):
        """Quién tiene corona, de qué torneos y en qué puesto (va en cada latido y con el torneo)."""
        return {k: [{'nombre': c['nombre'], 'puesto': c.get('puesto', 1)} for c in v['coronas']]
                for k, v in self.usuarios.items() if v.get('coronas')}

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
                        r = srv.latido(d.get('token'), d.get('estado'), d.get('eventos'), d.get('total'))
                    elif ruta == '/salir':
                        r = srv.salir(d.get('token')) or {'ok': True}
                    elif ruta == '/resultado':
                        r = srv.resultado(d.get('token'), d.get('id'), d.get('resultado')) or {'ok': True}
                    elif ruta == '/torneo':
                        r = srv.torneo(d.get('token'))
                    elif ruta == '/torneo/editar':
                        r = srv.editar_torneo(d.get('token'), d.get('que'), d)
                    elif ruta == '/yo':
                        r = srv.yo(d.get('token'))
                    elif ruta == '/duelo/retar':
                        r = srv.retar(d.get('token'), d.get('usuario'))
                    elif ruta == '/duelo/responder':
                        r = srv.responder_duelo(d.get('token'), d.get('id'), bool(d.get('si')))
                    elif ruta == '/fotos':
                        r = srv.fotos(d.get('token'), d.get('usuarios'))
                    elif ruta == '/foto':
                        r = srv.poner_foto(d.get('token'), d.get('imagen'))
                    elif ruta == '/cuenta/nombre':
                        r = srv.cambiar_nombre(d.get('token'), d.get('nuevo'), d.get('clave'), ip)
                    elif ruta == '/cuenta/clave':
                        r = srv.cambiar_clave(d.get('token'), d.get('clave'), d.get('nueva'), ip)
                    elif ruta == '/actividad':
                        r = srv.actividad(d.get('token'), d.get('usuario'))
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


def abrir(direccion, ruta, datos=None, espera=10, pem=None):
    """Una petición https al servidor, que solo vale si contesta con el certificado del anfitrión: nadie puede hacerse
    pasar por él ni leer lo que va y viene (contraseñas, registros, el instalador)."""
    pem = pem or certificado()
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


def peticion(direccion, ruta, datos, espera=10, pem=None):
    try:
        with abrir(direccion, ruta, datos, espera, pem) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        try:
            return json.load(e)
        except ValueError:
            return {'error': f'Error {e.code} del servidor'}
