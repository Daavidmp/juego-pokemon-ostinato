"""Lectura del equipo de Pokémon Y desde Azahar por su servidor RPC.

Protocolo: dist/scripting/AzaharRPC.py de Azahar. Direcciones y descifrado PK6:
CitraRNG (Admiral-Fish), manager_xy.py y crypto.py.
"""
import random
import socket
import struct

PUERTO = 45987
DIR_EQUIPO = 0x8CE1CF8      # primer hueco del equipo en X/Y
PASO_HUECO = 484            # bytes entre huecos
DESPL_STATS = 344           # PS y nivel del hueco, cifrados aparte

# orden de los cuatro bloques de 56 bytes según ((EC >> 13) & 31) % 24 (los valores 24-31 repiten las
# 8 primeras filas, como en PKHeX; con (EC >> 13) % 24 a secas salían mal muchos Pokémon)
ORDEN = [
    (0, 1, 2, 3), (0, 1, 3, 2), (0, 2, 1, 3), (0, 3, 1, 2), (0, 2, 3, 1), (0, 3, 2, 1),
    (1, 0, 2, 3), (1, 0, 3, 2), (2, 0, 1, 3), (3, 0, 1, 2), (2, 0, 3, 1), (3, 0, 2, 1),
    (1, 2, 0, 3), (1, 3, 0, 2), (2, 1, 0, 3), (3, 1, 0, 2), (2, 3, 0, 1), (3, 2, 0, 1),
    (1, 2, 3, 0), (1, 3, 2, 0), (2, 1, 3, 0), (3, 1, 2, 0), (2, 3, 1, 0), (3, 2, 1, 0),
]


# versión del protocolo y tamaño máximo de cada lectura: Azahar habla la 2 (32 KB); los Citra antiguos,
# como el Nightly 1920, la 1 (32 bytes) y a la 2 contestan vacío
PROTOCOLOS = ((2, 32 * 1024), (1, 32))


class RPC:
    def __init__(self, espera=0.5):
        self.s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.s.settimeout(espera)
        self.protocolo = 0

    def _pedir(self, version, direccion, trozo):
        rid = random.getrandbits(32)
        self.s.sendto(struct.pack('<IIII', version, rid, 1, 8) + struct.pack('<II', direccion, trozo),
                      ('127.0.0.1', PUERTO))
        while True:
            r = self.s.recv(32 * 1024 + 16)
            _, i, tipo, _ = struct.unpack('<IIII', r[:16])
            if i == rid and tipo == 1:
                return r[16:]

    def leer(self, direccion, n):
        """Lee n bytes de la memoria del juego. Lanza OSError/TimeoutError si el emulador no responde."""
        out = b''
        while n > 0:
            version, maximo = PROTOCOLOS[self.protocolo]
            datos = self._pedir(version, direccion, min(n, maximo))
            if not datos and not out:
                # respuesta vacía: se prueba con el otro protocolo y se queda el que funcione
                otro = 1 - self.protocolo
                datos = self._pedir(PROTOCOLOS[otro][0], direccion, min(n, PROTOCOLOS[otro][1]))
                if datos:
                    self.protocolo = otro
            if not datos:
                raise OSError('El emulador devolvió una lectura vacía')
            out += datos
            direccion += len(datos)
            n -= len(datos)
        return out

    def escribir(self, direccion, datos):
        """Escribe en la memoria del juego (petición 2 del RPC), en trozos que quepan en un paquete."""
        version, maximo = PROTOCOLOS[self.protocolo]
        while datos:
            trozo = datos[:maximo - 8]
            rid = random.getrandbits(32)
            self.s.sendto(struct.pack('<IIII', version, rid, 2, 8 + len(trozo)) +
                          struct.pack('<II', direccion, len(trozo)) + trozo, ('127.0.0.1', PUERTO))
            while True:
                r = self.s.recv(32 * 1024 + 16)
                _, i, tipo, _ = struct.unpack('<IIII', r[:16])
                if i == rid and tipo == 2:
                    break
            direccion += len(trozo)
            datos = datos[len(trozo):]


def bloque_orden(ec):
    return ((ec >> 13) & 31) % 24


def _xor(datos, semilla):
    out = bytearray(datos)
    s = semilla
    for i in range(0, len(out) - 1, 2):
        s = (s * 0x41C64E6D + 0x6073) & 0xFFFFFFFF
        out[i] ^= (s >> 16) & 0xFF
        out[i + 1] ^= s >> 24
    return bytes(out)


def descifrar(bloque, stats):
    """bloque: 232 bytes cifrados; stats: 22 bytes cifrados (desde 0xE8). Devuelve 254 bytes en claro."""
    ec = struct.unpack_from('<I', bloque, 0)[0]
    cuerpo = _xor(bloque[8:232], ec)
    orden = ORDEN[bloque_orden(ec)]
    cuerpo = b''.join(cuerpo[56 * orden[k]:56 * orden[k] + 56] for k in range(4))
    return bloque[:8] + cuerpo + _xor(stats, ec)


def pokemon(datos):
    """Interpreta un PK6 descifrado. None si el hueco está vacío o los datos no cuadran."""
    especie = struct.unpack_from('<H', datos, 0x08)[0]
    if not 0 < especie <= 721:
        return None
    suma = sum(struct.unpack_from('<112H', datos, 0x08)) & 0xFFFF
    if suma != struct.unpack_from('<H', datos, 0x06)[0]:
        return None
    ec = struct.unpack_from('<I', datos, 0x00)[0]
    return {
        'id': f'{ec:08X}',
        'especie': especie,
        'mote': datos[0x40:0x58].decode('utf-16-le', 'ignore').split('\0')[0],
        'huevo': bool(struct.unpack_from('<I', datos, 0x74)[0] >> 30 & 1),
        'nivel': datos[0xEC],
        'ps': struct.unpack_from('<H', datos, 0xF0)[0],
        'psmax': struct.unpack_from('<H', datos, 0xF2)[0],
        # PP llenos: el Centro Pokémon los recupera y las pociones no (sirve para saber si te has curado ahí)
        'pp_llenos': all(datos[0x62 + k] >= _pp_max(datos, k) for k in range(4)),
    }


def _pp_max(datos, k):
    mov = struct.unpack_from('<H', datos, 0x5A + 2 * k)[0]
    if not mov:
        return 0
    base = PP_BASE[mov] if mov < len(PP_BASE) else datos[0x62 + k]
    return base + base * datos[0x66 + k] // 5


# según la versión del juego el equipo empieza en un sitio u otro (en Pokémon Y en español sin
# actualizar, 16 bytes antes): se mira dónde hay un Pokémon válido en el primer hueco
DIRECCIONES = (DIR_EQUIPO, DIR_EQUIPO - 0x10)


# récords de la partida (los de PKHeX): el 11 es «Pokémon curados en Centros Pokémon» y sube cada vez que la
# enfermera cura al equipo, aunque no le falte nada. En memoria, el bloque de récords está a esta distancia
# del equipo (medido en Pokémon Y en español con Citra; se comprueba que lo leído tenga sentido)
RECORDS_DESDE_EQUIPO = -0x5F254
RECORD_ENTRENADORES = 6          # combates contra entrenadores
RECORD_CENTRO = 11


def record(rpc, indice):
    """Un contador de los récords de la partida, o None si no se puede leer o no parece el bloque de récords."""
    inicio = getattr(rpc, 'equipo', None)
    if inicio is None:
        return None
    base = inicio + RECORDS_DESDE_EQUIPO
    pasos, guardado = struct.unpack('<II', rpc.leer(base, 8))
    valor = struct.unpack('<I', rpc.leer(base + 4 * indice, 4))[0]
    # una partida recién empezada aún no se ha guardado nunca, pero ya ha andado
    if not (guardado < 100000 and valor < 10_000_000 and 0 < pasos < 1_000_000_000):
        return None
    return valor


def curas_en_centro(rpc):
    return record(rpc, RECORD_CENTRO)


RECORD_CAPTURAS = 7

# Medido en Pokémon Y en español con Citra 1920 (equipo en 0x8CE1CE8), comparando la memoria dentro y fuera de
# combates salvajes y contra entrenadores, con menús abiertos y con la enfermera del Centro:
# - seis valores que son 0 fuera de combate y otra cosa dentro. Los tres primeros están siempre en el mismo
#   sitio; los otros tres, junto a los datos de la partida, se cuentan desde el equipo. Se vota: 4 de 6
# - la zona en la que estás (cambia al andar; la de la partida guardada solo al guardar)
# - la mochila (el combate la lee en cada momento: lo que se quita no se puede usar)
# - el Pokémon salvaje del último combate (se queda ahí al acabar)
COMBATE_FIJAS = (0x8000144, 0x80009AC, 0x8000D9C)
COMBATE_DESDE_EQUIPO = (-0xA60CC, -0x800C0, 0x9D248)
ZONA_DESDE_EQUIPO = -0x7AB68
# el bloque del entrenador de la partida (el 0x4200 del archivo: dinero en +8, medallas en +0xC, un bit cada una)
MEDALLAS_DESDE_EQUIPO = -0x77654 + 0xC
MOCHILA_DESDE_EQUIPO = -0x7A794
DIR_SALVAJE = 0x8805614
HUECOS_OBJETOS = 400             # bolsillo de objetos: 400 huecos de (u16 objeto, u16 cantidad)
BALLS = set(range(1, 17)) | set(range(492, 501)) | {576}


def _inicio(rpc):
    if getattr(rpc, 'equipo', None) is None:
        leer_equipo(rpc)
    if getattr(rpc, 'equipo', None) is None:
        raise OSError('Aún no hay equipo en la memoria')
    return rpc.equipo


def en_combate(rpc):
    inicio = _inicio(rpc)
    dirs = list(COMBATE_FIJAS) + [inicio + d for d in COMBATE_DESDE_EQUIPO]
    return sum(1 for a in dirs if struct.unpack('<I', rpc.leer(a, 4))[0]) >= 4


def medallas_bits(rpc):
    """Las 8 medallas de Kalos, en orden de gimnasio (bit 0 = Violeta). Comprobado: pasa de 0 a 1 con la primera."""
    b = rpc.leer(_inicio(rpc) + MEDALLAS_DESDE_EQUIPO, 1)[0]
    return [bool(b >> i & 1) for i in range(8)]


def medallas(rpc):
    return sum(medallas_bits(rpc))


def zona(rpc):
    return struct.unpack('<H', rpc.leer(_inicio(rpc) + ZONA_DESDE_EQUIPO, 2))[0]


def _shiny(pid, tid, sid):
    return (tid ^ sid ^ (pid >> 16) ^ (pid & 0xFFFF)) < 16


def salvaje_shiny(rpc):
    """Si el Pokémon salvaje del combate es shiny para ti. Tu ID es la que más se repite en tu equipo."""
    from collections import Counter
    inicio = _inicio(rpc)
    ids = Counter()
    for i in range(6):
        base = inicio + i * PASO_HUECO
        claro = descifrar(rpc.leer(base, 232), rpc.leer(base + DESPL_STATS, 22))
        if pokemon(claro):
            ids[struct.unpack_from('<HH', claro, 0x0C)] += 1
    claro = descifrar(rpc.leer(DIR_SALVAJE, 232), rpc.leer(DIR_SALVAJE + 232, 22))
    if not ids or not pokemon(claro):
        return False
    tid, sid = ids.most_common(1)[0][0]
    return _shiny(struct.unpack_from('<I', claro, 0x18)[0], tid, sid)


def _bolsillo(rpc):
    crudo = rpc.leer(_inicio(rpc) + MOCHILA_DESDE_EQUIPO, 4 * HUECOS_OBJETOS)
    return [struct.unpack_from('<HH', crudo, 4 * k) for k in range(HUECOS_OBJETOS)]


def _poner_bolsillo(rpc, huecos):
    huecos = [h for h in huecos if h[0]][:HUECOS_OBJETOS]
    datos = b''.join(struct.pack('<HH', *h) for h in huecos).ljust(4 * HUECOS_OBJETOS, b'\0')
    rpc.escribir(_inicio(rpc) + MOCHILA_DESDE_EQUIPO, datos)


def esconder_balls(rpc):
    """Quita las Poké Balls del bolsillo de objetos y devuelve cuáles eran [(objeto, cantidad)]."""
    h = _bolsillo(rpc)
    fuera = [list(x) for x in h if x[0] in BALLS]
    if fuera:
        _poner_bolsillo(rpc, [x for x in h if x[0] not in BALLS])
    return fuera


def devolver_balls(rpc, balls):
    if not balls:
        return
    h = [list(x) for x in _bolsillo(rpc) if x[0]]
    for obj, n in balls:                           # si ya hay de esa Ball, se suman en el mismo hueco
        hueco = next((x for x in h if x[0] == obj), None)
        if hueco:
            hueco[1] = min(999, hueco[1] + n)
        else:
            h.append([obj, n])
    _poner_bolsillo(rpc, [tuple(x) for x in h])


def leer_hueco(rpc, inicio, i):
    base = inicio + i * PASO_HUECO
    return pokemon(descifrar(rpc.leer(base, 232), rpc.leer(base + DESPL_STATS, 22)))


def leer_equipo(rpc):
    inicio = getattr(rpc, 'equipo', None)
    if inicio is None:
        inicio = next((d for d in DIRECCIONES if leer_hueco(rpc, d, 0)), None)
        if inicio is None:
            return [None] * 6                 # aún sin Pokémon: se vuelve a buscar en la siguiente lectura
        rpc.equipo = inicio
    return [leer_hueco(rpc, inicio, i) for i in range(6)]


# PP base de cada movimiento (hasta el 621, el último de X/Y), de los datos de PokéAPI
PP_BASE = (0,35,25,10,15,20,20,15,15,15,35,30,5,10,20,30,35,35,20,15,20,20,25,20,30,5,10,15,15,15,25,20,5,35,15,20,20,10,15,30,35,20,20,30,25,40,20,15,20,20,20,30,25,15,30,25,5,15,10,5,20,20,20,5,35,20,20,20,20,20,15,25,15,10,20,25,10,35,30,15,10,40,10,15,30,15,20,10,15,10,5,10,10,25,10,20,40,30,30,20,20,15,10,40,15,5,30,10,20,10,40,40,20,30,30,20,30,10,10,20,5,10,30,20,20,20,5,15,15,20,10,15,35,20,15,5,10,30,15,40,20,10,10,5,10,30,10,15,20,15,40,20,10,5,15,10,5,10,15,30,30,10,10,20,10,1,1,10,25,10,5,15,25,15,10,15,30,5,40,15,10,25,10,30,10,20,10,10,10,10,10,20,5,40,5,5,15,5,10,5,10,10,10,10,20,20,40,15,5,20,20,25,5,15,10,5,20,15,20,25,20,5,30,5,10,20,40,5,20,40,20,15,35,10,5,5,5,15,5,20,5,5,15,20,10,5,5,15,10,15,15,10,10,10,20,10,10,10,10,15,15,15,10,20,20,10,20,20,20,20,20,10,10,10,20,20,5,15,10,10,15,10,20,5,5,10,10,20,5,10,20,10,20,20,20,5,5,15,20,10,15,20,15,5,10,15,10,5,5,10,15,10,5,20,25,5,40,15,5,40,15,20,20,5,15,20,20,15,15,5,10,30,20,30,15,5,40,15,5,20,5,15,25,25,15,20,15,20,15,20,10,20,20,5,5,5,5,40,10,10,5,10,10,15,10,20,15,30,10,20,5,10,10,15,10,10,5,15,5,10,10,30,20,20,10,10,5,5,10,5,20,10,20,10,15,10,20,20,20,15,15,10,15,15,15,10,10,10,20,10,30,5,10,15,10,10,5,20,30,10,30,15,15,15,15,30,10,20,15,10,10,20,15,5,5,15,15,5,10,5,20,5,15,20,5,20,20,20,20,10,20,10,15,20,15,10,10,5,10,5,5,10,5,5,10,5,5,5,15,10,10,10,10,10,10,15,20,15,10,15,10,15,10,20,10,10,10,20,20,20,20,20,15,15,15,15,15,15,20,15,10,15,15,15,15,10,10,10,10,10,15,15,15,15,5,5,15,5,10,10,10,20,20,20,10,10,30,15,15,10,15,25,10,15,10,10,10,20,10,10,10,10,10,15,15,5,5,10,10,10,5,5,10,5,5,15,10,5,5,5,10,10,10,10,20,25,10,20,30,25,20,20,15,20,15,20,20,10,10,10,10,10,20,10,30,15,10,10,10,20,20,5,5,5,20,10,10,20,15,20,20,10,20,30,10,10,40,40,30,20,40,20,20,10,10,10,10,5,10,10,5,5)


def cifrar(claro):
    """Inverso de descifrar: el PK6 en claro → (232 bytes del bloque, el resto: PS, estado y estadísticas)."""
    ec = struct.unpack_from('<I', claro, 0)[0]
    orden = ORDEN[bloque_orden(ec)]
    bloques = [None] * 4
    for k in range(4):
        bloques[orden[k]] = claro[8 + 56 * k:8 + 56 * k + 56]
    return claro[:8] + _xor(b''.join(bloques), ec), _xor(claro[232:], ec)   # PS y estado (22 o 28 bytes)


def curado(claro):
    """Copia del Pokémon con los PS al máximo, sin estado y con los PP llenos. Los debilitados (0 PS)
    y los huevos se quedan como están: en un locke no se reviven."""
    p = pokemon(claro)
    if not p or p['huevo'] or p['ps'] == 0:
        return None
    d = bytearray(claro)
    for k in range(4):
        mov = struct.unpack_from('<H', d, 0x5A + 2 * k)[0]
        if mov:
            base = PP_BASE[mov] if mov < len(PP_BASE) else d[0x62 + k]
            d[0x62 + k] = base + base * d[0x66 + k] // 5          # con los PP Up que tenga
    struct.pack_into('<H', d, 0x06, sum(struct.unpack_from('<112H', d, 0x08)) & 0xFFFF)
    struct.pack_into('<I', d, 0xE8, 0)                            # estado (veneno, quemado, sueño…)
    struct.pack_into('<H', d, 0xF0, p['psmax'])
    return bytes(d)


def curar_equipo(rpc):
    """El vial: cura a todo el equipo vivo escribiendo en la memoria. Devuelve cuántos ha curado."""
    inicio = getattr(rpc, 'equipo', None)
    if inicio is None:
        leer_equipo(rpc)
        inicio = getattr(rpc, 'equipo', None)
        if inicio is None:
            return 0
    curados = 0
    for i in range(6):
        base = inicio + i * PASO_HUECO
        nuevo = curado(descifrar(rpc.leer(base, 232), rpc.leer(base + DESPL_STATS, 22)))
        if nuevo:
            bloque, stats = cifrar(nuevo)
            rpc.escribir(base, bloque)
            rpc.escribir(base + DESPL_STATS, stats)
            curados += 1
    return curados
