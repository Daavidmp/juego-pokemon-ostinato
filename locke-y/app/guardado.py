"""La partida guardada del emulador: PokéHex, copias automáticas y borrar."""
import hashlib
import hmac
import json
import os
import re
import shutil
import time

import online
import pokehex
import comun
import emulador
import locke


# ---------- PokéHex: ver y cambiar el equipo y la mochila de la partida guardada ----------
# Con el juego cerrado: se edita el archivo de la partida del emulador (como PKHeX), con copia antes de cada cambio.

# la contraseña del PokéHex de este PC: la crea cada uno la primera vez y se guarda cifrada (antes era una sola, escrita
# en el código de un repositorio público)
F_POKEHEX = comun.DATOS / 'pokehex.json'


def comprobar_clave_pokehex(clave):
    clave = str(clave or '')
    try:
        guardada = json.loads(F_POKEHEX.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        guardada = None
    if not guardada:
        if len(clave) < 4:
            raise RuntimeError('Elige una contraseña para tu PokéHex (al menos 4 caracteres): la primera vez, la que '
                               'escribas se queda como la tuya')
        sal = os.urandom(16).hex()
        F_POKEHEX.write_text(json.dumps({'sal': sal, 'hash': online._hash(clave, sal)}), encoding='utf-8')
    elif not hmac.compare_digest(online._hash(clave, guardada['sal']), guardada['hash']):
        raise RuntimeError('Contraseña incorrecta')
hex_vivo = {'tokens': set(), 'datos': {}, 'interno': hashlib.sha1(os.urandom(16)).hexdigest()}  # interno: encargos del servidor


def pokehex_partida(j):
    """El archivo de la partida del juego en el emulador: sdmc/Nintendo 3DS/*/*/title/00040000/<título>/data/00000001/main."""
    exe = emulador.azahar_exe()
    if not exe:
        raise RuntimeError('No encuentro el emulador en tools/')
    mod = comun.DATOS / 'juegos' / j['id'] / 'mod'
    titulo = next((p.name for p in mod.iterdir() if re.fullmatch(r'[0-9A-Fa-f]{16}', p.name)), comun.TITLE_Y) if mod.exists() else comun.TITLE_Y
    sdmc = exe.parent / 'user' / 'sdmc' / 'Nintendo 3DS'
    for f in sdmc.glob(f'*/*/title/{titulo[:8].lower()}/{titulo[8:].lower()}/data/00000001/main'):
        return f
    raise RuntimeError('Este juego aún no tiene partida guardada en el emulador')


def tablero(j):
    """Lo que enseña el tablero, leído de la partida guardada: avanza cada vez que se guarda en el juego. Solo se
    vuelve a leer cuando cambia el archivo; si se lee justo mientras el juego guarda, se queda lo de antes."""
    try:
        f = pokehex_partida(j)
        clave = (str(f), f.stat().st_mtime)
    except (RuntimeError, OSError):
        return {'guardada': False, 'medallas': [False] * 8, 'equipo': []}
    if comun.vivo.get('tablero_de') != clave:
        try:
            p = pokehex.Partida(f)
        except (OSError, ValueError):
            return comun.vivo.get('tablero') or {'guardada': False, 'medallas': [False] * 8, 'equipo': []}
        b = p.d[locke.MEDALLAS_EN_PARTIDA]
        equipo = [{k: x[k] for k in ('id', 'especie', 'especie_nombre', 'mote', 'nivel', 'huevo', 'shiny')}
                  for x in p.equipo() if x]
        comun.vivo['tablero_de'] = clave
        comun.vivo['tablero'] = {'guardada': True, 'medallas': [bool(b >> i & 1) for i in range(8)], 'equipo': equipo}
    return comun.vivo['tablero']


# copias de la partida del emulador al abrir y al cerrar el juego: si el archivo se estropea (o Citra se cae al
# guardar) no se pierde el locke. Se quedan las últimas MAX_COPIAS en datos/juegos/<id>/copias_auto/
MAX_COPIAS = 10
MOTIVOS_COPIA = {'al-abrir': 'Al abrir el juego', 'al-cerrar': 'Al cerrar el juego', 'antes-de-restaurar': 'Antes de restaurar otra'}


def carpeta_copias(j):
    return comun.DATOS / 'juegos' / j['id'] / 'copias_auto'


def copiar_partida(j, motivo):
    """Copia la carpeta de la partida (data/00000001). Sin partida todavía, no hace nada."""
    try:
        origen = pokehex_partida(j).parent
    except RuntimeError:
        return None
    carpeta = carpeta_copias(j)
    nombre = f'{time.strftime("%Y%m%d_%H%M%S")}_{motivo}'
    shutil.copytree(origen, carpeta / nombre, dirs_exist_ok=True)
    for vieja in sorted(carpeta.iterdir())[:-MAX_COPIAS]:
        shutil.rmtree(vieja, ignore_errors=True)
    print(time.strftime('%H:%M:%S'), 'copia de la partida', j['id'], nombre, flush=True)
    return nombre


def copias_partida(j):
    carpeta = carpeta_copias(j)
    if not carpeta.exists():
        return []
    out = []
    for c in sorted(carpeta.iterdir(), reverse=True):
        m = re.fullmatch(r'(\d{8})_(\d{6})_([a-z-]+)', c.name)
        if m and c.is_dir():
            f, h = m[1], m[2]
            out.append({'nombre': c.name, 'fecha': f'{f[6:]}/{f[4:6]}/{f[:4]} {h[:2]}:{h[2:4]}',
                        'motivo': MOTIVOS_COPIA.get(m[3], m[3])})
    return out


def restaurar_partida(j, nombre):
    """Pone una copia en lugar de la partida actual (que antes se copia también)."""
    if emulador.jugando():
        raise RuntimeError('Cierra el juego antes de restaurar una copia')
    if nombre not in {c['nombre'] for c in copias_partida(j)}:      # solo nombres de la lista: nunca una ruta
        raise RuntimeError('Esa copia ya no existe')
    destino = pokehex_partida(j).parent
    temporal = comun.DATOS / 'juegos' / j['id'] / 'restaurando'
    shutil.rmtree(temporal, ignore_errors=True)
    shutil.copytree(carpeta_copias(j) / nombre, temporal)     # primero aparte: la copia de seguridad de ahora
    copiar_partida(j, 'antes-de-restaurar')                    # podría hacer sitio borrando la más vieja
    shutil.rmtree(destino)
    temporal.replace(destino)


def borrar_partida(j):
    """Borra la partida guardada del juego en el emulador (la carpeta data/ de su título: el juego empieza de cero
    y crea una nueva) y pone a cero su locke. Antes se guarda una copia en datos/juegos/<id>/partidas_borradas/."""
    if emulador.jugando():
        raise RuntimeError('Cierra el juego antes de borrar la partida')
    datos = pokehex_partida(j).parent.parent                     # .../title/00040000/<título>/data
    copia = comun.DATOS / 'juegos' / j['id'] / 'partidas_borradas' / time.strftime('%Y%m%d_%H%M%S')
    shutil.copytree(datos, copia)
    shutil.rmtree(datos)
    fase = j.get('fase')
    locke.nuevo_locke(j, j['vidas_iniciales'], j.get('reglas'))
    if fase == 2:                       # la versión fácil ya no está: se sigue con la completa
        j['fase'] = 2
    comun.guardar()


def pokehex_accion(que, d):
    if que == 'entrar':
        comprobar_clave_pokehex(d.get('clave'))
        token = hashlib.sha1(os.urandom(16)).hexdigest()
        hex_vivo['tokens'].add(token)
        return {'token': token, 'nombres': pokehex.NOMBRES, 'admitidos': pokehex.ADMITIDOS, 'balls': pokehex.BALLS}
    if d.get('token') not in hex_vivo['tokens'] and d.get('token') != hex_vivo['interno']:
        raise RuntimeError('Vuelve a entrar en el PokéHex')
    if emulador.jugando():
        raise RuntimeError('Cierra el juego para usar el PokéHex: si no, el juego pisaría los cambios al guardar')
    with comun.lock:
        j = comun.buscar(d['id'])
    try:
        partida = pokehex.Partida(pokehex_partida(j))
    except ValueError as e:
        raise RuntimeError(str(e))
    copias = comun.DATOS / 'juegos' / j['id'] / 'copias_partida'
    if j['id'] not in hex_vivo['datos']:
        hex_vivo['datos'][j['id']] = pokehex.Datos(comun.TOOLS, comun.DATOS / 'juegos' / j['id'] / 'randomizacion.log')
    datos = hex_vivo['datos'][j['id']]

    def lugar(x):                     # {"tipo": "equipo"|"caja", "caja": c, "hueco": k}
        tipo = x.get('tipo', 'equipo')
        if tipo not in ('equipo', 'caja'):
            raise RuntimeError('Sitio no válido')
        c, k = int(x.get('caja', 0)), int(x['hueco'])
        if not (0 <= k < (6 if tipo == 'equipo' else 30)) or not 0 <= c < partida.cuantas_cajas():
            raise RuntimeError('Sitio no válido')
        return tipo, c, k

    try:
        if que == 'leer':
            return {'equipo': partida.equipo(), 'mochila': partida.mochila(), 'cajas': partida.cajas(datos)}
        if que == 'pokemon':
            sitio = lugar(d.get('lugar') or {'tipo': 'equipo', 'hueco': d['hueco']})
            claro = partida.en(sitio, datos)
            if not claro:
                raise RuntimeError('Ahí no hay ningún Pokémon')
            nuevo = pokehex.aplicar(claro, d.get('cambios', {}), datos)
            partida.poner_en(sitio, nuevo)
            partida.guardar(copias)
            return {'pokemon': pokehex.detalle(nuevo)}
        if que == 'mover':
            partida.mover(lugar(d['desde']), lugar(d['hasta']), datos)
            partida.guardar(copias)
            return {'equipo': partida.equipo(), 'cajas': partida.cajas(datos)}
        if que == 'nuevo':
            if not 1 <= int(d['especie']) <= pokehex.MAX_ESPECIE:
                raise RuntimeError('Especie no válida')
            partida.nuevo(lugar(d['lugar']), int(d['especie']), int(d.get('nivel', 5)), datos)
            partida.guardar(copias)
            return {'equipo': partida.equipo(), 'cajas': partida.cajas(datos)}
        if que == 'bolsillo':
            partida.bolsillo(d['bolsillo'], d.get('objetos', []))
            partida.guardar(copias)
            return {'mochila': partida.mochila()}
    except ValueError as e:
        raise RuntimeError(str(e))
    raise RuntimeError('Acción desconocida')
