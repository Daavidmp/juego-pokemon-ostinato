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

# orden de los cuatro bloques de 56 bytes según (EC >> 13) % 24
ORDEN = [
    (0, 1, 2, 3), (0, 1, 3, 2), (0, 2, 1, 3), (0, 3, 1, 2), (0, 2, 3, 1), (0, 3, 2, 1),
    (1, 0, 2, 3), (1, 0, 3, 2), (2, 0, 1, 3), (3, 0, 1, 2), (2, 0, 3, 1), (3, 0, 2, 1),
    (1, 2, 0, 3), (1, 3, 0, 2), (2, 1, 0, 3), (3, 1, 0, 2), (2, 3, 0, 1), (3, 2, 0, 1),
    (1, 2, 3, 0), (1, 3, 2, 0), (2, 1, 3, 0), (3, 1, 2, 0), (2, 3, 1, 0), (3, 2, 1, 0),
]


class RPC:
    def __init__(self, espera=0.5):
        self.s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.s.settimeout(espera)

    def leer(self, direccion, n):
        """Lee n bytes de la memoria del juego. Lanza OSError/TimeoutError si Azahar no responde."""
        out = b''
        while n > 0:
            trozo = min(n, 32 * 1024)
            rid = random.getrandbits(32)
            self.s.sendto(struct.pack('<IIII', 2, rid, 1, 8) + struct.pack('<II', direccion, trozo),
                          ('127.0.0.1', PUERTO))
            while True:
                r = self.s.recv(32 * 1024 + 16)
                _, i, tipo, _ = struct.unpack('<IIII', r[:16])
                if i == rid and tipo == 1:
                    break
            datos = r[16:]
            if not datos:
                raise OSError('Azahar devolvió una lectura vacía')
            out += datos
            direccion += len(datos)
            n -= len(datos)
        return out


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
    orden = ORDEN[(ec >> 13) % 24]
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
    }


def leer_equipo(rpc):
    equipo = []
    for i in range(6):
        base = DIR_EQUIPO + i * PASO_HUECO
        equipo.append(pokemon(descifrar(rpc.leer(base, 232), rpc.leer(base + DESPL_STATS, 22))))
    return equipo
