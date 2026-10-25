"""PokéHex: ver y cambiar el equipo y la mochila de Pokémon X/Y en la memoria del emulador.

Formato PK6 y mochila: PKHeX (kwsch/PKHeX). Los nombres en español vienen de sus listas
(app/datos_pkx/*.txt, una por línea y la línea n es el número n-1). Las estadísticas base salen del
registro de la randomización del juego (son las que tiene esa ROM) y, si no lo hay, de PokéAPI; la
experiencia por nivel, de PokéAPI. Todo se guarda en tools/ la primera vez.
"""
import json
import re
import struct
import sys
import urllib.request
from pathlib import Path

import juego

# con Pokelocke.exe, los datos están en la carpeta app/ de al lado (como la web)
DATOS = (Path(sys._MEIPASS) / 'app' if getattr(sys, 'frozen', False) else Path(__file__).resolve().parent) / 'datos_pkx'
MAX_ESPECIE, MAX_MOVIMIENTO, MAX_OBJETO, MAX_HABILIDAD = 721, 621, 717, 191      # los de X/Y
STATS = ('ps', 'ataque', 'defensa', 'velocidad', 'at_esp', 'def_esp')           # orden del PK6


def _lista(nombre):
    lineas = (DATOS / f'{nombre}.txt').read_text(encoding='utf-8-sig').splitlines()
    return [l.strip() for l in lineas]


NOMBRES = {
    'especies': _lista('Species')[:MAX_ESPECIE + 1],
    'movimientos': _lista('Moves')[:MAX_MOVIMIENTO + 1],
    'objetos': _lista('Items')[:MAX_OBJETO + 1],
    'habilidades': _lista('Abilities')[:MAX_HABILIDAD + 1],
    'naturalezas': _lista('Natures')[:25],
}
BALLS = {1: 'Master Ball', 2: 'Ultra Ball', 3: 'Super Ball', 4: 'Poké Ball', 5: 'Safari Ball', 6: 'Malla Ball',
         7: 'Buceo Ball', 8: 'Nido Ball', 9: 'Acopio Ball', 10: 'Turno Ball', 11: 'Lujo Ball', 12: 'Honor Ball',
         13: 'Ocaso Ball', 14: 'Sana Ball', 15: 'Veloz Ball', 16: 'Gloria Ball', 17: 'Rápida Ball', 18: 'Nivel Ball',
         19: 'Cebo Ball', 20: 'Peso Ball', 21: 'Amor Ball', 22: 'Amigo Ball', 23: 'Luna Ball', 24: 'Competi Ball',
         25: 'Ensueño Ball'}


# ---------- datos de cada especie ----------

def _json(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Pokelocke'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


class Datos:
    """Estadísticas base y tabla de experiencia por especie (con caché en tools/)."""

    def __init__(self, tools, registro=None):
        self.tools = Path(tools)
        self.base, self.habilidad = {}, {}
        en = [l.strip().lower() for l in (DATOS / 'Abilities_en.txt').read_text(encoding='utf-8-sig').splitlines()]
        if registro and Path(registro).exists():
            for l in Path(registro).read_text(encoding='utf-8', errors='ignore').splitlines():
                m = re.match(r'\s*(\d+)\|[^|]*\|[^|]*\|\s*(\d+)\|\s*(\d+)\|\s*(\d+)\|\s*(\d+)\|\s*(\d+)\|\s*(\d+)\|', l)
                if m and int(m[1]) <= MAX_ESPECIE:
                    ps, at, de, ate, dee, ve = map(int, m.groups()[1:])
                    self.base.setdefault(int(m[1]), (ps, at, de, ve, ate, dee))   # orden del PK6
                    resto = l.split('|')[9:12]                                       # sus 3 habilidades (randomizadas)
                    if len(resto) == 3 and int(m[1]) not in self.habilidad:
                        self.habilidad[int(m[1])] = [en.index(h.strip().lower()) if h.strip().lower() in en else 0 for h in resto]
        self._cache_base = self.tools / 'pkx_base.json'
        if not self.base and self._cache_base.exists():
            self.base = {int(k): tuple(v) for k, v in json.loads(self._cache_base.read_text()).items()}
        self._exp = None

    def stats_base(self, especie):
        if especie not in self.base:
            p = _json(f'https://pokeapi.co/api/v2/pokemon/{especie}')
            s = {x['stat']['name']: x['base_stat'] for x in p['stats']}
            self.base[especie] = (s['hp'], s['attack'], s['defense'], s['speed'], s['special-attack'], s['special-defense'])
            guardado = json.loads(self._cache_base.read_text()) if self._cache_base.exists() else {}
            guardado[str(especie)] = self.base[especie]
            self.tools.mkdir(exist_ok=True)
            self._cache_base.write_text(json.dumps(guardado))
        return self.base[especie]

    def _especie(self, especie):
        """Movimientos por nivel en X/Y, sexo y habilidades, de PokéAPI (caché en tools/pkx_especies.json)."""
        f = self.tools / 'pkx_especies.json'
        todo = json.loads(f.read_text()) if f.exists() else {}
        if str(especie) not in todo:
            p = _json(f'https://pokeapi.co/api/v2/pokemon/{especie}')
            sp = _json(f'https://pokeapi.co/api/v2/pokemon-species/{especie}')
            movs = []
            for m in p['moves']:
                for v in m['version_group_details']:
                    if v['version_group']['name'] == 'x-y' and v['move_learn_method']['name'] == 'level-up':
                        movs.append((v['level_learned_at'], int(m['move']['url'].rstrip('/').rsplit('/', 1)[1])))
            hab = [0, 0, 0]
            for a in p['abilities']:
                if a['slot'] <= 3:
                    hab[a['slot'] - 1] = int(a['ability']['url'].rstrip('/').rsplit('/', 1)[1])
            todo[str(especie)] = {'movs': sorted(movs), 'sexo': sp['gender_rate'], 'hab': hab}
            self.tools.mkdir(exist_ok=True)
            f.write_text(json.dumps(todo))
        return todo[str(especie)]

    def movimientos(self, especie, nivel):
        """Los 4 últimos que aprende por nivel hasta ese nivel (como un Pokémon salvaje)."""
        vistos = []
        for n, m in self._especie(especie)['movs']:
            if n <= nivel and m <= MAX_MOVIMIENTO and m not in vistos:
                vistos.append(m)
        return (vistos[-4:] + [0, 0, 0, 0])[:4]

    def sexo(self, especie, azar):
        r = self._especie(especie)['sexo']               # -1 sin sexo; si no, octavos de hembras
        return 2 if r < 0 else 1 if azar.random() * 8 < r else 0

    def habilidades(self, especie):
        return self.habilidad.get(especie) or self._especie(especie)['hab']

    def tabla_exp(self, especie):
        """Experiencia mínima de cada nivel (índice = nivel, 1..100)."""
        if self._exp is None:
            f = self.tools / 'pkx_exp.json'
            if not f.exists():
                tablas, de_especie = {}, {}
                for i in range(1, 7):
                    g = _json(f'https://pokeapi.co/api/v2/growth-rate/{i}')
                    t = [0] * 101
                    for n in g['levels']:
                        t[n['level']] = n['experience']
                    tablas[i] = t
                    for s in g['pokemon_species']:
                        de_especie[int(s['url'].rstrip('/').rsplit('/', 1)[1])] = i
                self.tools.mkdir(exist_ok=True)
                f.write_text(json.dumps({'tablas': tablas, 'especies': de_especie}))
            d = json.loads(f.read_text())
            self._exp = ({int(k): v for k, v in d['tablas'].items()}, {int(k): v for k, v in d['especies'].items()})
        tablas, de_especie = self._exp
        return tablas[de_especie.get(especie, 2)]


def nivel_de_exp(tabla, exp):
    n = 1
    while n < 100 and tabla[n + 1] <= exp:
        n += 1
    return n


def calcular_stats(base, ivs, evs, nivel, naturaleza, especie):
    sube, baja = naturaleza // 5, naturaleza % 5            # 0 ataque, 1 defensa, 2 velocidad, 3 at. esp., 4 def. esp.
    out = []
    for k in range(6):
        v = (2 * base[k] + ivs[k] + evs[k] // 4) * nivel // 100
        if k == 0:
            out.append(1 if especie == 292 else v + nivel + 10)   # Shedinja siempre tiene 1 PS
        else:
            m = 1.1 if sube == k - 1 and sube != baja else 0.9 if baja == k - 1 and sube != baja else 1.0
            out.append(int((v + 5) * m))
    return out


# ---------- un Pokémon del equipo ----------

def _nombre(lista, i):
    l = NOMBRES[lista]
    return l[i] if 0 <= i < len(l) else f'#{i}'


def detalle(claro):
    """Todo lo que se puede ver y cambiar de un PK6 descifrado (254 bytes). None si el hueco está vacío."""
    p = juego.pokemon(claro)
    if not p:
        return None
    u16 = lambda o: struct.unpack_from('<H', claro, o)[0]
    u32 = lambda o: struct.unpack_from('<I', claro, o)[0]
    iv32 = u32(0x74)
    pid, tid, sid = u32(0x18), u16(0x0C), u16(0x0E)
    return {
        **p,
        'especie_nombre': _nombre('especies', p['especie']),
        'objeto': u16(0x0A), 'exp': u32(0x10), 'habilidad': claro[0x14],
        'naturaleza': claro[0x1C], 'sexo': (claro[0x1D] >> 1) & 3, 'forma': claro[0x1D] >> 3,
        'evs': list(claro[0x1E:0x24]),
        'movimientos': [u16(0x5A + 2 * k) for k in range(4)],
        'pp': list(claro[0x62:0x66]), 'pp_up': list(claro[0x66:0x6A]),
        'ivs': [(iv32 >> (5 * k)) & 31 for k in range(6)],
        'amistad': claro[0xA2], 'ball': claro[0xDC],
        'shiny': (tid ^ sid ^ (pid >> 16) ^ (pid & 0xFFFF)) < 16,
        'estado': u32(0xE8),
        'stats': [u16(0xF2)] + [u16(0xF4 + 2 * k) for k in range(5)],
    }


def aplicar(claro, c, datos):
    """Copia del PK6 con los cambios de c (las claves de detalle que vengan). Recalcula nivel/experiencia,
    estadísticas, PP y la suma de comprobación."""
    d = bytearray(claro)
    act = detalle(claro)
    put16 = lambda o, v: struct.pack_into('<H', d, o, int(v) & 0xFFFF)
    put32 = lambda o, v: struct.pack_into('<I', d, o, int(v) & 0xFFFFFFFF)
    especie = int(c.get('especie', act['especie']))
    if not 1 <= especie <= MAX_ESPECIE:
        raise ValueError('Especie no válida')
    put16(0x08, especie)
    if 'objeto' in c:
        if not 0 <= int(c['objeto']) <= MAX_OBJETO:
            raise ValueError('Objeto no válido')
        put16(0x0A, c['objeto'])
    if 'habilidad' in c:
        d[0x14] = int(c['habilidad']) & 0xFF
    if 'naturaleza' in c:
        d[0x1C] = int(c['naturaleza']) % 25
    if 'sexo' in c:
        d[0x1D] = (d[0x1D] & ~0x06) | ((int(c['sexo']) & 3) << 1)
    if 'evs' in c:
        evs = [max(0, min(252, int(v))) for v in c['evs']]
        while sum(evs) > 510:                             # el máximo del juego: se recorta del más alto
            evs[evs.index(max(evs))] -= 1
        d[0x1E:0x24] = bytes(evs)
    if 'ivs' in c:
        iv32 = struct.unpack_from('<I', d, 0x74)[0] & 0xC0000000
        for k, v in enumerate(c['ivs']):
            iv32 |= (max(0, min(31, int(v))) & 31) << (5 * k)
        put32(0x74, iv32)
    if 'mote' in c:
        mote = str(c['mote'])[:12] or _nombre('especies', especie)
        d[0x40:0x5A] = mote.encode('utf-16-le').ljust(26, b'\0')[:26]
        apodo = mote != _nombre('especies', especie)
        iv32 = struct.unpack_from('<I', d, 0x74)[0]
        put32(0x74, (iv32 | 0x80000000) if apodo else (iv32 & 0x7FFFFFFF))
    if 'movimientos' in c:
        for k, m in enumerate(c['movimientos'][:4]):
            m = int(m)
            if not 0 <= m <= MAX_MOVIMIENTO:
                raise ValueError('Movimiento no válido')
            if m != struct.unpack_from('<H', d, 0x5A + 2 * k)[0]:
                put16(0x5A + 2 * k, m)
                d[0x66 + k] = 0                           # PP Up de ese hueco
            base = juego.PP_BASE[m] if m < len(juego.PP_BASE) else 0
            d[0x62 + k] = base + base * d[0x66 + k] // 5 if m else 0
    if 'amistad' in c:
        d[0xA2] = max(0, min(255, int(c['amistad'])))
    if 'ball' in c:
        d[0xDC] = int(c['ball']) & 0xFF
    if 'shiny' in c:
        pid = struct.unpack_from('<I', d, 0x18)[0]
        tid, sid = struct.unpack_from('<HH', d, 0x0C)
        bajo = pid & 0xFFFF
        if c['shiny']:
            pid = ((tid ^ sid ^ bajo) << 16) | bajo
        elif act['shiny']:
            pid = (((tid ^ sid ^ bajo) ^ 0x8000) << 16) | bajo
        put32(0x18, pid)
    tabla = datos.tabla_exp(especie)
    if 'nivel' in c:
        nivel = max(1, min(100, int(c['nivel'])))
        put32(0x10, tabla[nivel])
    else:
        nivel = nivel_de_exp(tabla, struct.unpack_from('<I', d, 0x10)[0])
    d[0xEC] = nivel
    ivs = [(struct.unpack_from('<I', d, 0x74)[0] >> (5 * k)) & 31 for k in range(6)]
    stats = calcular_stats(datos.stats_base(especie), ivs, list(d[0x1E:0x24]), nivel, d[0x1C], especie)
    ps_antes, max_antes = struct.unpack_from('<HH', d, 0xF0)
    put16(0xF2, stats[0])
    for k in range(5):
        put16(0xF4 + 2 * k, stats[k + 1])
    if c.get('curar'):
        ps = stats[0]
        put32(0xE8, 0)
    elif 'ps' in c:
        ps = max(0, min(stats[0], int(c['ps'])))
    else:                                                 # mismos PS que faltaban
        ps = 0 if ps_antes == 0 else max(1, min(stats[0], stats[0] - (max_antes - ps_antes)))
    put16(0xF0, ps)
    put16(0x06, sum(struct.unpack_from('<112H', d, 0x08)) & 0xFFFF)
    return bytes(d)


# ---------- la mochila ----------
# Bolsillos de X/Y (MyItem): nombre, desplazamiento dentro del bloque y número de huecos de 4 bytes
# (u16 objeto, u16 cantidad). Los objetos que admite cada uno, de PKHeX (ItemStorage6XY).
BOLSILLOS = (('objetos', 0x000, 400, 999), ('clave', 0x640, 96, 1), ('mt', 0x7C0, 106, 1),
             ('medicinas', 0x968, 64, 999), ('bayas', 0xA68, 72, 999))
TAM_MOCHILA = 0xB88


def _admitidos():
    texto = (DATOS / 'ItemStorage6XY.cs').read_text(encoding='utf-8')
    out = {}
    for nombre, clave in (('objetos', 'General'), ('clave', 'Key'), ('mt', 'Machine'), ('medicinas', 'Medicine'), ('bayas', 'Berry')):
        m = re.search(r'ReadOnlySpan<ushort>\s+' + clave + r'\s*=>\s*\[(.*?)\];', texto, re.S)
        out[nombre] = [int(x, 16) if x.lower().startswith("0x") else int(x) for x in re.findall(r'\b(?:0x[0-9A-Fa-f]+|\d+)\b', re.sub(r'//[^\n]*', '', m[1]))] if m else []
    return out


ADMITIDOS = _admitidos()


def leer_mochila(rpc, inicio):
    crudo = rpc.leer(inicio, TAM_MOCHILA)
    out = {}
    for nombre, despl, huecos, _ in BOLSILLOS:
        lista = []
        for k in range(huecos):
            obj, n = struct.unpack_from('<HH', crudo, despl + 4 * k)
            if obj:
                lista.append({'objeto': obj, 'nombre': _nombre('objetos', obj), 'cantidad': n})
        out[nombre] = lista
    return out


def escribir_bolsillo(rpc, inicio, nombre, objetos):
    despl, huecos, maximo = next((b[1], b[2], b[3]) for b in BOLSILLOS if b[0] == nombre)
    validos = set(ADMITIDOS[nombre])
    datos = bytearray(4 * huecos)
    k = 0
    for o in objetos:
        obj, n = int(o['objeto']), int(o['cantidad'])
        if n <= 0:
            continue
        if obj not in validos:
            raise ValueError(f'{_nombre("objetos", obj)} no va en este bolsillo')
        if k >= huecos:
            raise ValueError('No caben más objetos en este bolsillo')
        struct.pack_into('<HH', datos, 4 * k, obj, min(n, maximo))
        k += 1
    rpc.escribir(inicio + despl, bytes(datos))



def nuevo_pokemon(plantilla, especie, nivel, datos):
    """Un Pokémon nuevo a partir de otro de la partida (así lleva tu nombre de entrenador, tu ID, la versión
    y el idioma): esa especie y nivel, IV al azar, sin EV, sus movimientos por nivel y en Poké Ball."""
    import random
    import time
    azar = random.SystemRandom()
    nivel = max(1, min(100, int(nivel)))
    d = bytearray(plantilla[:232]) + bytearray(28)
    struct.pack_into('<I', d, 0x00, azar.getrandbits(32))                   # EC
    struct.pack_into('<H', d, 0x08, especie)
    struct.pack_into('<H', d, 0x0A, 0)                                       # sin objeto
    struct.pack_into('<I', d, 0x10, datos.tabla_exp(especie)[nivel])
    hab = datos.habilidades(especie)
    k = azar.choice([i for i in (0, 1) if hab[i]] or [0])
    d[0x14], d[0x15] = hab[k] & 0xFF, 1 << k
    struct.pack_into('<I', d, 0x18, azar.getrandbits(32))                   # PID
    d[0x1C] = azar.randrange(25)
    d[0x1D] = datos.sexo(especie, azar) << 1
    d[0x1E:0x40] = bytes(0x22)                                               # EV, concursos, marcas, Pokérus, cintas
    d[0x40:0x5A] = _nombre('especies', especie).encode('utf-16-le').ljust(26, b'\0')[:26]
    for i, m in enumerate(datos.movimientos(especie, nivel)):
        struct.pack_into('<H', d, 0x5A + 2 * i, m)
        d[0x62 + i] = juego.PP_BASE[m] if m < len(juego.PP_BASE) else 0
        d[0x66 + i] = 0
    d[0x6A:0x72] = bytes(8)                                                  # movimientos recordados
    iv32 = 0
    for i in range(6):
        iv32 |= azar.randrange(32) << (5 * i)
    struct.pack_into('<I', d, 0x74, iv32)                                    # ni huevo ni mote
    d[0x78:0xB0] = bytes(0x38)                                               # ningún otro entrenador
    d[0xA2] = 70
    d[0xCA:0xD1] = bytes([70, 0, 0, 0, 0, 0, 0])                             # amistad y recuerdos
    t = time.localtime()
    d[0xD1:0xD8] = bytes([0, 0, 0, t.tm_year - 2000, t.tm_mon, t.tm_mday, 0])
    struct.pack_into('<HH', d, 0xD8, 0, 30001)                               # «un intercambio» como sitio
    d[0xDC] = 4                                                              # Poké Ball
    d[0xDD] = (d[0xDD] & 0x80) | nivel
    d[0xDE] = 0
    struct.pack_into('<H', d, 0x06, sum(struct.unpack_from('<112H', d, 0x08)) & 0xFFFF)
    return aplicar(bytes(d), {'curar': True}, datos)


LUGAR_GUARDERIA = 60002          # «una pareja de la guardería», de donde salen los huevos en X/Y
CICLOS_HUEVO = 10                # pasos para abrirse, en ciclos de 256 pasos (en los huevos, la amistad)


def nuevo_huevo(plantilla, especie, shiny, datos):
    """Un huevo de esa especie a nivel 1, de tu partida (tu ID: así el shiny sigue siéndolo al abrirse)."""
    import time
    d = bytearray(nuevo_pokemon(plantilla, especie, 1, datos))
    iv32 = struct.unpack_from('<I', d, 0x74)[0]
    struct.pack_into('<I', d, 0x74, iv32 | 0xC0000000)                     # huevo y con mote
    d[0x40:0x5A] = 'Huevo'.encode('utf-16-le').ljust(26, b'\0')[:26]
    d[0xA2], d[0xCA] = 0, CICLOS_HUEVO
    t = time.localtime()
    d[0xD1:0xD8] = bytes([t.tm_year - 2000, t.tm_mon, t.tm_mday, 0, 0, 0, 0])   # fecha del huevo, sin encuentro aún
    struct.pack_into('<HH', d, 0xD8, LUGAR_GUARDERIA, 0)
    struct.pack_into('<H', d, 0x06, sum(struct.unpack_from('<112H', d, 0x08)) & 0xFFFF)
    return aplicar(bytes(d), {'shiny': bool(shiny), 'curar': True}, datos)


# ---------- la partida guardada (con el juego cerrado) ----------
# Archivo "main" de la partida de X/Y (0x65600 bytes, igual que lo lee PKHeX): bloques con su CRC16-CCITT
# en la tabla del final. El equipo va en el bloque 18 (6 huecos de 0x104 bytes cifrados) y la mochila en el 1.
TAM_PARTIDA = 0x65600
BLOQUE_MOCHILA, MOCHILA, TAM_BLOQUE_MOCHILA = 1, 0x400, 0xB88
BLOQUE_EQUIPO, EQUIPO, TAM_BLOQUE_EQUIPO, PASO = 18, 0x14200, 0x61C, 0x104
CUENTA_EQUIPO = EQUIPO + 6 * PASO
BLOQUE_CAJAS, CAJAS, TAM_BLOQUE_CAJAS, PASO_CAJA, NUM_CAJAS = 53, 0x22600, 0x34AD0, 232, 31
NOMBRES_CAJAS, CAJAS_ABIERTAS = 0x4400, 0x4400 + 0x43E
VACIO_EQUIPO = b''.join(juego.cifrar(bytes(PASO)))          # un hueco vacío, como lo deja PKHeX
VACIO_CAJA = juego.cifrar(bytes(PASO_CAJA))[0]


def crc16(datos):
    arriba = abajo = 0xFF
    for b in datos:
        x = b ^ arriba
        x ^= x >> 4
        arriba = (abajo ^ (x >> 3) ^ (x << 4)) & 0xFF
        abajo = (x ^ (x << 5)) & 0xFF
    return (arriba << 8) | abajo


class Partida:
    def __init__(self, ruta):
        self.ruta = Path(ruta)
        self.d = bytearray(self.ruta.read_bytes())
        if len(self.d) != TAM_PARTIDA or not self._crc_bien(BLOQUE_EQUIPO, EQUIPO, TAM_BLOQUE_EQUIPO)                 or not self._crc_bien(BLOQUE_MOCHILA, MOCHILA, TAM_BLOQUE_MOCHILA)                 or not self._crc_bien(BLOQUE_CAJAS, CAJAS, TAM_BLOQUE_CAJAS):
            raise ValueError('Este archivo no parece una partida de Pokémon X/Y')

    def _crc_pos(self, bloque):
        return TAM_PARTIDA - 0x200 + 0x14 + bloque * 8 + 6

    def _crc_bien(self, bloque, ofs, tam):
        return crc16(self.d[ofs:ofs + tam]) == struct.unpack_from('<H', self.d, self._crc_pos(bloque))[0]

    def claro(self, i):
        b = EQUIPO + i * PASO
        return juego.descifrar(bytes(self.d[b:b + 232]), bytes(self.d[b + 232:b + PASO]))

    def poner(self, i, claro):
        b = EQUIPO + i * PASO
        bloque, resto = juego.cifrar(claro)
        self.d[b:b + PASO] = bloque + resto

    def equipo(self):
        return [detalle(self.claro(i)) for i in range(6)]

    # --- cajas ---
    def cuantas_cajas(self):
        return max(1, min(NUM_CAJAS, self.d[CAJAS_ABIERTAS] or NUM_CAJAS))

    def nombre_caja(self, c):
        o = NOMBRES_CAJAS + c * 0x22
        return bytes(self.d[o:o + 0x22]).decode('utf-16-le', 'ignore').split('\0')[0] or f'Caja {c + 1}'

    def claro_caja(self, c, k):
        b = CAJAS + (c * 30 + k) * PASO_CAJA
        return juego.descifrar(bytes(self.d[b:b + PASO_CAJA]), b'') + bytes(PASO - PASO_CAJA)

    def poner_caja(self, c, k, claro):
        b = CAJAS + (c * 30 + k) * PASO_CAJA
        self.d[b:b + PASO_CAJA] = juego.cifrar(claro[:PASO_CAJA])[0] if claro else VACIO_CAJA

    def de_caja(self, c, k, datos):
        """El de la caja con nivel y estadísticas calculados (en la caja no se guardan), o None."""
        cl = self.claro_caja(c, k)
        return aplicar(cl, {'curar': True}, datos) if juego.pokemon(cl) else None

    def cajas(self, datos):
        out = []
        for c in range(self.cuantas_cajas()):
            pokes = []
            for k in range(30):
                x = self.de_caja(c, k, datos)
                pokes.append(detalle(x) if x else None)
            out.append({'nombre': self.nombre_caja(c), 'pokemon': pokes})
        return out

    # --- cualquier sitio: ('equipo', 0, i) o ('caja', c, k) ---
    def en(self, lugar, datos):
        tipo, c, k = lugar
        if tipo == 'equipo':
            cl = self.claro(k)
            return cl if juego.pokemon(cl) else None
        return self.de_caja(c, k, datos)

    def poner_en(self, lugar, claro):
        tipo, c, k = lugar
        if tipo == 'caja':
            self.poner_caja(c, k, claro)
        else:
            self.poner(k, claro)

    def mover(self, desde, hasta, datos):
        """Intercambia lo que hay en los dos sitios. El equipo queda sin huecos y nunca vacío; lo que entra
        al equipo desde la caja llega curado (como al sacarlo del PC)."""
        a, b = self.en(desde, datos), self.en(hasta, datos)
        if not a:
            raise ValueError('Ahí no hay ningún Pokémon')
        if desde[0] == 'caja' and hasta[0] == 'caja':
            self.poner_caja(*hasta[1:], a)
            self.poner_caja(*desde[1:], b)
            return
        equipo = [self.claro(i) for i in range(6) if juego.pokemon(self.claro(i))]
        if desde[0] == 'equipo' and hasta[0] == 'equipo':
            i, j = desde[2], hasta[2]
            if j >= len(equipo):
                equipo.append(equipo.pop(i))
            else:
                equipo[i], equipo[j] = equipo[j], equipo[i]
        else:
            (eq, en_eq), (caja, en_caja) = ((desde, a), (hasta, b)) if desde[0] == 'equipo' else ((hasta, b), (desde, a))
            i = eq[2]
            if en_eq and en_caja:                                    # se cambian
                equipo[i] = aplicar(en_caja, {'curar': True}, datos)
            elif en_eq:                                              # del equipo a un hueco vacío de la caja
                if len(equipo) <= 1:
                    raise ValueError('No puedes dejar el equipo vacío')
                equipo.pop(i)
            else:                                                    # de la caja al equipo: al final
                if len(equipo) >= 6:
                    raise ValueError('El equipo ya tiene 6 Pokémon')
                equipo.append(aplicar(en_caja, {'curar': True}, datos))
            self.poner_caja(caja[1], caja[2], en_eq)
        for i in range(6):
            if i < len(equipo):
                self.poner(i, equipo[i])
            else:
                self.d[EQUIPO + i * PASO:EQUIPO + (i + 1) * PASO] = VACIO_EQUIPO
        self.d[CUENTA_EQUIPO] = len(equipo)

    def nuevo(self, lugar, especie, nivel, datos):
        if self.en(lugar, datos):
            raise ValueError('Ese hueco ya está ocupado')
        if lugar[0] == 'equipo' and lugar[2] != self.d[CUENTA_EQUIPO]:
            lugar = ('equipo', 0, self.d[CUENTA_EQUIPO])
        if lugar[0] == 'equipo' and lugar[2] >= 6:
            raise ValueError('El equipo ya tiene 6 Pokémon')
        nuevo = nuevo_pokemon(self.claro(0), int(especie), nivel, datos)
        self.poner_en(lugar, nuevo)
        if lugar[0] == 'equipo':
            self.d[CUENTA_EQUIPO] += 1
        return lugar

    def meter(self, claro, datos):
        """Al equipo si cabe y, si no, al primer hueco libre de las cajas. Devuelve dónde ha ido."""
        if self.d[CUENTA_EQUIPO] < 6:
            lugar = ('equipo', 0, self.d[CUENTA_EQUIPO])
            self.poner_en(lugar, claro)
            self.d[CUENTA_EQUIPO] += 1
            return lugar
        for c in range(self.cuantas_cajas()):
            for k in range(30):
                if not juego.pokemon(self.claro_caja(c, k)):
                    self.poner_en(('caja', c, k), claro)
                    return 'caja', c, k
        raise ValueError('No queda sitio ni en el equipo ni en las cajas')

    def mochila(self):
        leer = type('Lector', (), {'leer': lambda _, a, n: bytes(self.d[a:a + n])})()
        return leer_mochila(leer, MOCHILA)

    def bolsillo(self, nombre, objetos):
        escr = type('Escritor', (), {'escribir': lambda _, a, datos: self.d.__setitem__(slice(a, a + len(datos)), datos)})()
        escribir_bolsillo(escr, MOCHILA, nombre, objetos)

    def guardar(self, copias):
        """Rehace las sumas de los bloques tocados, guarda una copia del archivo de antes y escribe."""
        for bloque, ofs, tam in ((BLOQUE_EQUIPO, EQUIPO, TAM_BLOQUE_EQUIPO), (BLOQUE_MOCHILA, MOCHILA, TAM_BLOQUE_MOCHILA),
                                 (BLOQUE_CAJAS, CAJAS, TAM_BLOQUE_CAJAS)):
            struct.pack_into('<H', self.d, self._crc_pos(bloque), crc16(self.d[ofs:ofs + tam]))
        copias = Path(copias)
        copias.mkdir(parents=True, exist_ok=True)
        import time
        (copias / time.strftime('main_%Y%m%d_%H%M%S')).write_bytes(self.ruta.read_bytes())
        for vieja in sorted(copias.glob('main_*'))[:-20]:           # se quedan las 20 últimas
            vieja.unlink()
        self.ruta.write_bytes(bytes(self.d))
