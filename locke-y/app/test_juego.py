"""Comprueba el descifrado PK6: cifra un Pokémon de ejemplo y lo vuelve a leer.  python test_juego.py"""
import struct

import juego


def cifrar(claro):
    ec = struct.unpack_from('<I', claro, 0)[0]
    orden = juego.ORDEN[(ec >> 13) % 24]
    bloques = [None] * 4
    for k in range(4):
        bloques[orden[k]] = claro[8 + 56 * k:8 + 56 * k + 56]
    return claro[:8] + juego._xor(b''.join(bloques), ec), juego._xor(claro[232:254], ec)


claro = bytearray(254)
struct.pack_into('<I', claro, 0x00, 0x9ABC1357)          # EC
struct.pack_into('<H', claro, 0x08, 658)                 # Greninja
claro[0x40:0x40 + 10] = 'NINJA'.encode('utf-16-le')
claro[0xEC] = 36
struct.pack_into('<HH', claro, 0xF0, 0, 101)             # debilitado
struct.pack_into('<H', claro, 0x06, sum(struct.unpack_from('<112H', claro, 0x08)) & 0xFFFF)

bloque, stats = cifrar(bytes(claro))
assert bloque != bytes(claro[:232])
p = juego.pokemon(juego.descifrar(bloque, stats))
assert p == {'id': '9ABC1357', 'especie': 658, 'mote': 'NINJA', 'huevo': False,
             'nivel': 36, 'ps': 0, 'psmax': 101}, p
assert juego.pokemon(bytes(254)) is None                 # hueco vacío
basura = bytearray(claro); basura[0x50] ^= 1             # checksum roto
assert juego.pokemon(bytes(basura)) is None
# vial: cura PS, estado y PP (con PP Up); a los debilitados no los toca
herido = bytearray(claro)
struct.pack_into('<HHHH', herido, 0x5A, 33, 0, 57, 0)            # Placaje (35 PP) y Surf (15 PP)
herido[0x64] = 0; herido[0x68] = 2                               # Surf sin PP y con 2 PP Up
struct.pack_into('<I', herido, 0xE8, 8)                          # envenenado
struct.pack_into('<H', herido, 0xF0, 12)
struct.pack_into('<H', herido, 0x06, sum(struct.unpack_from('<112H', herido, 0x08)) & 0xFFFF)
assert juego.descifrar(*juego.cifrar(bytes(herido))) == bytes(herido)
c = juego.curado(bytes(herido))
assert juego.pokemon(c)['ps'] == 101 and c[0x62] == 35 and c[0x64] == 21
assert struct.unpack_from('<I', c, 0xE8)[0] == 0
assert juego.curado(bytes(claro)) is None                        # el de 0 PS sigue muerto
print('ok')
