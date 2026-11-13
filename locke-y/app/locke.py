"""El locke: vidas, huevos, caramelos, fases, seguimiento del juego, normas Mega, atajos y vial."""
import ctypes
import re
import shutil
import threading
import time
import traceback
from pathlib import Path

import juego
import pokehex
import comun
import emulador
import guardado
import vigia


def nuevo_locke(j, vidas, reglas=None):
    j.update(vidas_iniciales=int(vidas), ajuste_vidas=0, muertos=[], medallas=[False] * 8, vial=True,
             reglas=reglas, perdonados=[], caramelos_dados=0, muertes_activas=False,
             fase=1 if reglas == 'mega' else None, rutas_usadas=[], rutas_avisadas=[], balls_escondidas=None,
             aviso_torneo=False, reto=None, retos=[], huevos_extra=0, vidas_retos=0, reto_avisado=None,
             mision=None, misiones_ofertas=[], misiones=[], misiones_vistas=[], escamas_pendientes=0, duelos_vistos=None, fijo_puesto=None,
             huevos=caja_de_huevos() if reglas == 'mega' else None)


# la caja de huevos de Mega Pokelocke: 30 huevos de especies al azar y 2 de ellos shiny, sorteados al empezar
# el locke. Cada 2 medallas se puede coger uno; si sale shiny no gasta el turno
HUEVOS_CAJA, HUEVOS_SHINY, MEDALLAS_POR_HUEVO = 30, 2, 2


def caja_de_huevos():
    import random
    azar = random.SystemRandom()
    shiny = set(azar.sample(range(HUEVOS_CAJA), HUEVOS_SHINY))
    return [{'especie': azar.randint(1, pokehex.MAX_ESPECIE), 'shiny': i in shiny, 'cogido': False}
            for i in range(HUEVOS_CAJA)]


def huevos_disponibles(j):
    gastados = sum(1 for h in j.get('huevos') or [] if h['cogido'] and not h['shiny'])
    return max(0, sum(j.get('medallas', [])) // MEDALLAS_POR_HUEVO + j.get('huevos_extra', 0) - gastados)


def huevos_estado(j):
    """Lo que ve la página: los cogidos con su especie; los demás, sin desvelar."""
    cerrados = _huevos_en_partida(j)
    return {'disponibles': huevos_disponibles(j), 'medallas': sum(j.get('medallas', [])),
            'huevos': [_huevo_visible(h, h['especie'] in cerrados) for h in j['huevos']]}


def _huevos_en_partida(j):
    """Las especies de los huevos que siguen sin abrir en la partida guardada."""
    try:
        p = pokehex.Partida(guardado.pokehex_partida(j))
        datos = guardado.hex_vivo['datos'].get(j['id']) or pokehex.Datos(comun.TOOLS, comun.DATOS / 'juegos' / j['id'] / 'randomizacion.log')
        todos = [*p.equipo(), *(x for c in p.cajas(datos) for x in c['pokemon'])]
    except (ValueError, RuntimeError, OSError, KeyError):
        return set()
    return {x['especie'] for x in todos if x and x['huevo']}


def _huevo_visible(h, sigue_cerrado=False):
    """Hasta que se abre en el juego no se sabe qué lleva dentro."""
    if not h['cogido']:
        return {'cogido': False}
    if sigue_cerrado or not h.get('abierto', True):
        return {'cogido': True, 'abierto': False, 'shiny': h['shiny']}
    return {'cogido': True, 'abierto': True, 'especie': h['especie'], 'shiny': h['shiny'], 'nombre': pokehex.NOMBRES['especies'][h['especie']]}


PASOS_HUEVO = 5


def nacer(j, p):
    """La animación, y solo al acabar se abre en el juego: hasta entonces, ni el layout ni el juego saben qué es."""
    nombre = pokehex.NOMBRES['especies'][p['especie']]
    with comun.lock:
        mio = next((h for h in j.get('huevos') or [] if h['cogido'] and h.get('abierto') is False and h['especie'] == p['especie']), None)
    emulador.apertura(p['especie'], bool(mio and mio['shiny']))
    try:
        rpc = juego.RPC()
        if not juego.abrir_huevo(rpc, p['id'], nombre):
            return
    except (OSError, TimeoutError):
        traceback.print_exc()
        comun.vivo['ya_nacidos'].discard(p['id'])
        comun.vivo['pasos_huevo'].pop(p['id'], None)
        return
    with comun.lock:
        if mio:
            mio['abierto'] = True
        vigia.evento('huevo', f'Se abre un huevo: {nombre}')
        comun.guardar()


def vigilar_huevos(rpc, j, equipo):
    """Lleva la cuenta de los pasos dados desde que cada huevo va en el equipo y, al llegar, abre uno."""
    pasos_de = comun.vivo.setdefault('pasos_huevo', {})
    nacidos = comun.vivo.setdefault('ya_nacidos', set())
    huevos = [p for p in equipo if p and p['huevo'] and p['id'] not in nacidos]
    if not huevos or comun.vivo.get('apertura') or comun.vivo.get('en_combate'):
        return
    juego.retrasar_huevos(rpc)
    pasos = juego.record(rpc, juego.RECORD_PASOS)
    if pasos is None:
        return
    listos = [p for p in huevos if pasos - pasos_de.setdefault(p['id'], pasos) >= PASOS_HUEVO]
    if listos and not juego.en_combate(rpc):
        nacidos.add(listos[0]['id'])
        pasos_de.clear()                               # los demás, 5 pasos más cada uno
        threading.Thread(target=nacer, args=(j, listos[0]), daemon=True).start()


def huevos_abiertos(antes, ahora):
    """Los del equipo que eran huevo en la lectura anterior y ya no lo son."""
    previos = {p['id']: p for p in antes if p}
    return [p for p in ahora if p and not p['huevo'] and p['id'] in previos and previos[p['id']]['huevo']]


def rol(base):
    """Atacante si su mejor ataque supera a su mejor defensa; físico o especial según cuál de los dos sea mayor."""
    _, at, de, _, ate, dee = base
    if max(at, ate) >= max(de, dee):
        return ('Atacante físico', 'rol-fisico') if at >= ate else ('Atacante especial', 'rol-especial')
    return ('Tanque físico', 'tanque-fisico') if de >= dee else ('Tanque especial', 'tanque-especial')


def ficha_huevo(especie, shiny):
    """Lo que enseña la animación: los datos reales de esta partida, que pueden estar aleatorizados."""
    if not 0 < especie <= pokehex.MAX_ESPECIE:
        raise RuntimeError('Esa especie no existe')
    with comun.lock:
        ids = [comun.vivo['activo']] + [x['id'] for x in comun.biblio['juegos']]
        jid = next((i for i in ids if i), None)
    datos = guardado.hex_vivo['datos'].get(jid)
    if not datos:
        datos = pokehex.Datos(comun.TOOLS, comun.DATOS / 'juegos' / str(jid) / 'randomizacion.log')
        if jid:
            guardado.hex_vivo['datos'][jid] = datos
    b = datos.stats_base(especie)
    texto, icono = rol(b)
    return {'especie': especie, 'nombre': pokehex.NOMBRES['especies'][especie], 'shiny': bool(shiny), 'tipos': datos.tipos_de(especie), 'total': sum(b),
            'base': dict(zip(('ps', 'ataque', 'defensa', 'velocidad', 'ataque_esp', 'defensa_esp'), b)), 'rol': texto, 'icono': icono}


def coger_huevo(j, i):
    if emulador.jugando():
        raise RuntimeError('Cierra el juego para coger el huevo: si no, el juego lo borraría al guardar')
    h = j['huevos'][i]
    if h['cogido']:
        raise RuntimeError('Ese huevo ya lo has cogido')
    if not huevos_disponibles(j):
        raise RuntimeError(f'Puedes coger un huevo cada {MEDALLAS_POR_HUEVO} medallas')
    try:
        partida = pokehex.Partida(guardado.pokehex_partida(j))
    except ValueError as e:
        raise RuntimeError(str(e))
    if j['id'] not in guardado.hex_vivo['datos']:
        guardado.hex_vivo['datos'][j['id']] = pokehex.Datos(comun.TOOLS, comun.DATOS / 'juegos' / j['id'] / 'randomizacion.log')
    try:
        lugar = partida.meter(pokehex.nuevo_huevo(partida.claro(0), h['especie'], h['shiny'], guardado.hex_vivo['datos'][j['id']]),
                              guardado.hex_vivo['datos'][j['id']])
    except ValueError as e:
        raise RuntimeError(str(e))
    partida.guardar(comun.DATOS / 'juegos' / j['id'] / 'copias_partida')
    h['cogido'], h['abierto'] = True, False
    vigia.anotar_partida(j)
    vigia.evento('huevo', f'Coge un huevo de la caja{" (shiny)" if h["shiny"] else ""}')
    comun.guardar()
    return {**huevos_estado(j), 'donde': 'tu equipo' if lugar[0] == 'equipo' else partida.nombre_caja(lugar[1])}


# Normas Mega Pokelocke: 25 vidas, las muertes cuentan desde el primer combate contra un entrenador y
# 10000 Caramelos Raros, que se dan de 999 en 999 (el máximo de un hueco de la mochila)
VIDAS_MEGA = 25
CARAMELO_RARO, CARAMELOS_MEGA, MAX_HUECO = 50, 10000, 999

# dificultad exponencial: hasta la segunda medalla se juega la fase fácil (mod/, hecha por MegaFases.java) y
# luego la randomización completa (mod_completo/). El emulador solo lee el mod al arrancar: el cambio se hace al
# abrir el juego, mirando las medallas de la partida guardada (bloque de PKHeX Misc6XY, en 0x4200: dinero en +8
# y medallas en +0xC, un bit por medalla)
MOD_COMPLETO = 'mod_completo'
MEDALLAS_PARA_COMPLETA = 2
MEDALLAS_EN_PARTIDA = 0x420C


# nivel tope de cada líder (el de su Pokémon más alto): sale del registro de la randomización, que ya lleva el
# +15 % de las normas Mega. Índices de entrenador de los 8 líderes en Pokémon Y; sin randomizar, los originales
LIDERES_Y = (6, 76, 21, 22, 23, 24, 25, 26)
TOPES_ORIGINALES = [12, 25, 32, 34, 37, 42, 48, 59]


def niveles_tope(j):
    log = comun.DATOS / 'juegos' / j['id'] / 'randomizacion.log'
    if not j.get('random') or not log.exists():
        return TOPES_ORIGINALES
    clave = (str(log), log.stat().st_mtime)
    if comun.vivo.get('topes_de') != clave:
        topes = dict.fromkeys(LIDERES_Y)
        en_entrenadores = False
        for linea in log.read_text(encoding='utf-8', errors='ignore').splitlines():
            if linea.startswith('--'):
                en_entrenadores = linea.startswith('--Trainers Pokemon')
            m = en_entrenadores and re.match(r'#(\d+) \(', linea)
            if m and int(m[1]) in topes:
                topes[int(m[1])] = max(map(int, re.findall(r'Lv(\d+)', linea)), default=None)
        comun.vivo['topes_de'], comun.vivo['topes'] = clave, [topes[i] or TOPES_ORIGINALES[k] for k, i in enumerate(LIDERES_Y)]
    return comun.vivo['topes']


def medallas_partida(j):
    try:
        datos = guardado.pokehex_partida(j).read_bytes()
    except (RuntimeError, OSError):
        return 0
    return bin(datos[MEDALLAS_EN_PARTIDA]).count('1') if len(datos) == pokehex.TAM_PARTIDA else 0


def medallas_de_la_partida(j):
    """Con el juego cerrado: si la partida guardada tiene más medallas de las que sabe la app (las de la app solo se
    leen con el juego abierto), se ponen al día, para que tablero, retos y caja de huevos digan lo mismo. Con un reto
    en marcha no: ese se resuelve al ver la medalla jugando, con el equipo de ese momento."""
    if not j.get('preparado') or j.get('reto'):
        return
    try:
        t = guardado.tablero(j)
    except Exception:
        return
    nuevas = [bool(m) for m in (t or {}).get('medallas', [])]
    if len(nuevas) == 8 and sum(nuevas) > sum(j.get('medallas', [])):
        j['medallas'] = nuevas
        vigia.evento('medallas', f'La partida guardada tiene {sum(nuevas)} medallas: se ponen al día')
        comun.guardar()


def abrir_fase_completa(j):
    """Con el juego cerrado: la randomización completa pasa a ser el mod del juego."""
    carpeta = comun.DATOS / 'juegos' / j['id']
    if not (carpeta / MOD_COMPLETO).exists():
        return False
    shutil.rmtree(carpeta / 'mod', ignore_errors=True)
    (carpeta / MOD_COMPLETO).rename(carpeta / 'mod')
    j['fase'] = 2
    comun.guardar()
    return True


def dar_caramelos(j):
    """Con el juego cerrado: rellena los Caramelos Raros de la mochila hasta 999, mientras no se hayan dado
    los 10000. Sin partida guardada todavía no hace nada (se dan la siguiente vez que se abra el juego)."""
    if j.get('reglas') != 'mega' or j.get('caramelos_dados', 0) >= CARAMELOS_MEGA:
        return
    try:
        partida = pokehex.Partida(guardado.pokehex_partida(j))
    except (RuntimeError, ValueError, OSError):
        return
    medicinas = partida.mochila()['medicinas']
    hueco = next((o for o in medicinas if o['objeto'] == CARAMELO_RARO), None)
    tiene = hueco['cantidad'] if hueco else 0
    dar = min(MAX_HUECO - tiene, CARAMELOS_MEGA - j.get('caramelos_dados', 0))
    if dar <= 0:
        return
    if hueco:
        hueco['cantidad'] += dar
    else:
        medicinas.append({'objeto': CARAMELO_RARO, 'cantidad': dar})
    partida.bolsillo('medicinas', medicinas)
    partida.guardar(comun.DATOS / 'juegos' / j['id'] / 'copias_partida')
    j['caramelos_dados'] = j.get('caramelos_dados', 0) + dar
    comun.guardar()


def dar_escamas(j):
    """Con el juego cerrado: mete en la mochila las Escamas Corazón ganadas en misiones. Sin partida guardada todavía,
    esperan a la siguiente vez."""
    if not j.get('escamas_pendientes'):
        return
    try:
        partida = pokehex.Partida(guardado.pokehex_partida(j))
    except (RuntimeError, ValueError, OSError):
        return
    objetos = partida.mochila()['objetos']
    hueco = next((o for o in objetos if o['objeto'] == ESCAMA_CORAZON), None)
    if hueco:
        hueco['cantidad'] = min(MAX_HUECO, hueco['cantidad'] + j['escamas_pendientes'])
    else:
        objetos.append({'objeto': ESCAMA_CORAZON, 'cantidad': j['escamas_pendientes']})
    partida.bolsillo('objetos', objetos)
    partida.guardar(comun.DATOS / 'juegos' / j['id'] / 'copias_partida')
    vigia.evento('mision', f'{j["escamas_pendientes"]} Escama(s) Corazón a la mochila')
    j['escamas_pendientes'] = 0
    comun.guardar()


def vidas(j):
    return max(0, j['vidas_iniciales'] + j['ajuste_vidas'] - len(j['muertos']) - j.get('vidas_retos', 0))


# ---------- retos (Mega Pokelocke) ----------
# Desde el 2.º gimnasio, antes de cada líder se puede aceptar un reto, con el juego cerrado y sin vuelta atrás. Se
# resuelve solo en cuanto se consigue esa medalla: superado, un huevo extra en la caja; fallado, una vida menos.
RETOS = {
    'sin_vidas': ('Sin perder ninguna vida', 'Consigue la medalla sin perder ninguna vida desde que aceptas el reto.'),
    'nivel_bajo': ('Por debajo del tope', 'Gana al líder con todo el equipo 3 niveles o más por debajo del nivel tope.'),
    'tres': ('Solo tres', 'Gana al líder con 3 Pokémon como mucho en el equipo.'),
}
NIVELES_MENOS = 3
LIDERES = ('Violeta', 'Lino', 'Corelia', 'Amaro', 'Lem', 'Valeria', 'Ástrid', 'Édel')
AVISO_RETO = 2                  # segundos que dura en el juego el aviso de un reto nuevo


def retos_estado(j):
    m = sum(j.get('medallas', []))
    return {'puede': j.get('reglas') == 'mega' and 1 <= m < 8 and not j.get('reto'), 'medalla': m + 1,
            'activo': j.get('reto'), 'historial': j.get('retos', []), 'misiones': misiones_estado(j),
            'lista': [{'id': k, 'nombre': n, 'texto': t} for k, (n, t) in RETOS.items()]}


def aceptar_reto(j, tipo):
    if j.get('reglas') != 'mega':
        raise RuntimeError('Los retos son de las normas Mega Pokelocke')
    if tipo not in RETOS:
        raise RuntimeError('Ese reto no existe')
    if j.get('reto'):
        raise RuntimeError('Ya tienes un reto en marcha: se resuelve al conseguir la medalla')
    if not retos_estado(j)['puede']:
        raise RuntimeError('Los retos se pueden aceptar a partir del segundo gimnasio y hasta el octavo')
    if emulador.jugando():
        raise RuntimeError('Los retos se aceptan con el juego cerrado')
    medalla = sum(j.get('medallas', [])) + 1
    j['reto'] = {'tipo': tipo, 'medalla': medalla, 'vidas': vidas(j), 'fecha': time.strftime('%Y-%m-%d %H:%M')}
    vigia.evento('reto', f'Acepta el reto «{RETOS[tipo][0]}» para la medalla {medalla}')
    comun.guardar()


def resolver_reto(j):
    """En cuanto el juego da la medalla del reto (se llama con comun.lock): se mira el equipo de ese momento."""
    r = j.get('reto')
    if not r or sum(j.get('medallas', [])) < r['medalla']:
        return False
    equipo = [p for p in comun.vivo['equipo'] if p and not p.get('huevo')]
    tope = niveles_tope(j)[r['medalla'] - 1]
    superado = {'sin_vidas': vidas(j) >= r['vidas'],
                'nivel_bajo': bool(equipo) and all(p['nivel'] <= tope - NIVELES_MENOS for p in equipo),
                'tres': 0 < len(equipo) <= 3}[r['tipo']]
    nombre = RETOS[r['tipo']][0]
    if superado:
        j['huevos_extra'] = j.get('huevos_extra', 0) + 1
        celebrar(True, '¡Reto superado!', nombre, 'Ganas un huevo extra', 'huevo')
    else:
        j['vidas_retos'] = j.get('vidas_retos', 0) + 1
        celebrar(False, 'Reto fallado', nombre, 'Pierdes una vida', 'corazon')
    j.setdefault('retos', []).append({**r, 'superado': superado})
    j['reto'] = None
    vigia.evento('reto', f'Reto «{nombre}» de la medalla {r["medalla"]}: {"superado" if superado else "fallado"}')
    comun.guardar()
    return True


def avisar_en_cola(texto, segundos):
    """Un aviso en el juego detrás del que esté en pantalla (y de los que ya esperan), para que no se pisen."""
    ahora = time.time()
    libre = max(ahora, (comun.vivo.get('aviso') or {}).get('hasta', 0), comun.vivo.get('cola_avisos', 0))
    comun.vivo['cola_avisos'] = libre + segundos
    if libre <= ahora:
        comun.avisar(texto, segundos)
    else:
        threading.Timer(libre - ahora + .2, comun.avisar, (texto, segundos)).start()


def celebrar(gana, titulo, nombre, efecto, icono):
    """El final de un reto, una misión o un duelo con el juego abierto: una animación sobre la pantalla de arriba
    (la pinta y la enseña la capa, ver capa.pintor_capa). Si no se puede pintar, sale como aviso de texto."""
    if emulador.jugando():
        comun.vivo.setdefault('fiestas', []).append({'gana': gana, 'titulo': titulo, 'nombre': nombre, 'efecto': efecto,
                                                     'icono': icono, 'texto': f'{titulo} {nombre} · {efecto}'})


def avisar_reto_nuevo(j):
    """Desde el 2.º gimnasio, al conseguir cada medalla aparece el reto del líder siguiente: si se está jugando, un
    aviso de AVISO_RETO segundos en el juego (detrás del resultado del reto anterior, si lo hay)."""
    est = retos_estado(j)
    if not est['puede'] or j.get('reto_avisado') == est['medalla']:
        return
    j['reto_avisado'] = est['medalla']
    avisar_en_cola(f'¡Nuevo reto! · {LIDERES[est["medalla"] - 1]} te ofrece sus cartas en Retos', AVISO_RETO)


# ---------- misiones (Mega Pokelocke) ----------
# Además de las cartas de los líderes, desde la 1.ª medalla aparecen misiones en distintos momentos: al llegar a un
# número de combates contra entrenadores o al conseguir ciertas medallas, siempre en este orden. Las que dependen de
# una medalla (capturas, sin Centro) se ofrecen hasta la medalla siguiente y luego desaparecen; las rachas de combates
# no tienen límite de gimnasio: ni caduca la oferta ni hay plazo para cumplirlas. Aceptada (con el juego cerrado), se
# comprueba sola mientras se juega con los contadores del juego. Superada: las fáciles dan una Escama Corazón (va a la
# mochila la próxima vez que se abra el juego) y las difíciles un huevo extra. Fallada: las fáciles no quitan nada (te
# quedas sin la escama); las difíciles, una vida. Una en marcha como mucho; ofertas puede haber varias.
MISIONES = [   # id, cuándo aparece, nombre, texto, tipo, cantidad, difícil
    ('racha10', ('combates', 30), 'Racha de diez', 'Gana 10 combates contra entrenadores sin perder ninguna vida.', 'racha', 10, False),
    ('explorador', ('medallas', 3), 'Explorador', 'Camina 20.000 pasos sin perder ninguna vida.', 'pasos', 20000, False),
    ('racha15', ('medallas', 5), 'Racha de quince', 'Gana 15 combates contra entrenadores sin perder ninguna vida.', 'racha', 15, True),
    ('racha20', ('medallas', 7), 'Imparable', 'Gana 20 combates contra entrenadores sin perder ninguna vida.', 'racha', 20, True),
]
ESCAMA_CORAZON = 93


def _ficha_mision(mid):
    x = next(m for m in MISIONES if m[0] == mid)
    return {'id': x[0], 'nombre': x[2], 'texto': x[3], 'tipo': x[4], 'n': x[5], 'premio': 'huevo' if x[6] else 'escama'}


def _ofertas(j):
    """Las ofertas de misión (las partidas de antes guardaban una sola, en 'mision_oferta')."""
    if j.get('mision_oferta'):
        j.setdefault('misiones_ofertas', []).append(j.pop('mision_oferta'))
    return j.setdefault('misiones_ofertas', [])


def misiones_estado(j):
    act = j.get('mision')
    return {'ofertas': [{**_ficha_mision(o['id']), 'hasta': o['hasta']} for o in _ofertas(j)],
            'activa': act and {**_ficha_mision(act['id']), 'hasta': act['hasta'], 'progreso': act.get('progreso', 0)},
            'historial': [{**_ficha_mision(h['id']), 'superada': h['superada']} for h in j.get('misiones', [])]}


def aceptar_mision(j, mid=None):
    ofertas = _ofertas(j)
    of = next((o for o in ofertas if mid in (None, o['id'])), None)
    if j.get('reglas') != 'mega':
        raise RuntimeError('Las misiones son de las normas Mega Pokelocke')
    if not of:
        raise RuntimeError('Esa misión ya no está disponible')
    if j.get('mision'):
        raise RuntimeError('Ya tienes una misión en marcha')
    if emulador.jugando():
        raise RuntimeError('Las misiones se aceptan con el juego cerrado')
    # los contadores de partida (combates, capturas, curas) se toman al volver a jugar: con el juego cerrado no cambian
    j['mision'] = {'id': of['id'], 'hasta': of['hasta'], 'base': None, 'progreso': 0, 'fecha': time.strftime('%Y-%m-%d %H:%M')}
    ofertas.remove(of)
    vigia.evento('mision', f'Acepta la misión «{_ficha_mision(of["id"])["nombre"]}»')
    comun.guardar()


def _cerrar_mision(j, superada):
    m = _ficha_mision(j['mision']['id'])
    if superada and m['premio'] == 'huevo':
        j['huevos_extra'] = j.get('huevos_extra', 0) + 1
        celebrar(True, '¡Misión superada!', m['nombre'], 'Ganas un huevo extra', 'huevo')
    elif superada:
        j['escamas_pendientes'] = j.get('escamas_pendientes', 0) + 1
        celebrar(True, '¡Misión superada!', m['nombre'], 'Ganas una Escama Corazón (al volver a abrir el juego)', 'escama')
    elif m['premio'] == 'escama':
        celebrar(False, 'Misión fallada', m['nombre'], 'Te quedas sin la Escama Corazón', 'escama')
    else:
        j['vidas_retos'] = j.get('vidas_retos', 0) + 1
        celebrar(False, 'Misión fallada', m['nombre'], 'Pierdes una vida', 'corazon')
    j.setdefault('misiones', []).append({'id': m['id'], 'superada': superada})
    j['mision'] = None
    vigia.evento('mision', f'Misión «{m["nombre"]}»: {"superada" if superada else "fallada"}')
    comun.guardar()


def misiones_tick(j, rpc):
    """Mientras se juega (con comun.lock): caducan las ofertas, aparecen misiones nuevas y se mira la que está en marcha."""
    if j.get('reglas') != 'mega':
        return
    try:
        cont = {'combates': juego.record(rpc, juego.RECORD_ENTRENADORES), 'pasos': juego.record(rpc, juego.RECORD_PASOS)}
    except (OSError, TimeoutError):
        return
    if None in cont.values():
        return
    med = sum(j.get('medallas', []))
    ofertas = _ofertas(j)
    pasadas = [o for o in ofertas if o['hasta'] is not None and med >= o['hasta']]
    for o in pasadas:                                   # ya ha pasado esa parte de la historia
        ofertas.remove(o)
    if pasadas:
        comun.guardar()
    vistas = j.setdefault('misiones_vistas', [])
    siguiente = next((m for m in MISIONES if m[0] not in vistas), None)
    if siguiente and 1 <= med < 8:
        que, cuanto = siguiente[1]
        if (cont['combates'] if que == 'combates' else med) >= cuanto:
            vistas.append(siguiente[0])
            # las rachas de combates y de pasos no tienen límite de gimnasio (las de otro tipo, hasta la medalla siguiente)
            ofertas.append({'id': siguiente[0], 'hasta': None if siguiente[4] in ('racha', 'pasos') else med + 1})
            avisar_en_cola(f'¡Nueva misión! · {siguiente[2]}: la tienes en Retos', AVISO_RETO)
            comun.guardar()
    act = j.get('mision')
    if not act:
        return
    if act.get('base') is None:
        act['base'] = {**cont, 'vidas': vidas(j)}
        comun.guardar()
        return
    m, b, superada = _ficha_mision(act['id']), act['base'], None
    antes = act.get('progreso', 0)
    if m['tipo'] == 'pasos':
        act['progreso'] = max(0, min(m['n'], cont['pasos'] - b['pasos']))
        if vidas(j) < b['vidas']:
            superada = False
        elif act['progreso'] >= m['n']:
            superada = True
    elif m['tipo'] == 'racha':
        act['progreso'] = max(0, min(m['n'], cont['combates'] - b['combates']))
        if vidas(j) < b['vidas']:
            superada = False
        elif act['progreso'] >= m['n'] and not comun.vivo.get('en_combate'):
            superada = True                              # el contador sube al empezar: cuenta al acabar el combate
    if superada is not None:
        _cerrar_mision(j, superada)
    elif act.get('progreso', 0) != antes:
        comun.guardar()


# ---------- seguimiento del locke ----------

def curado_en_centro(antes, ahora):
    """En un Centro Pokémon se cura todo el equipo de golpe, PS y PP. Cuenta como Centro cuando, de una lectura
    a la siguiente, todos los vivos quedan con PS y PP al máximo y además: algún Pokémon recupera PP (las
    pociones no los dan), o dos o más recuperan PS a la vez, o revive alguno (los debilitados no se tocan)."""
    previos = {p['id']: p for p in antes if p}
    vivos = [p for p in ahora if p and not p['huevo'] and p['ps'] > 0]
    if not vivos or not all(p['ps'] == p['psmax'] and p.get('pp_llenos', True) for p in vivos):
        return False
    antes_de = [previos[p['id']] for p in vivos if p['id'] in previos]
    pp = any(not a.get('pp_llenos', True) for a in antes_de)
    ps = sum(1 for a in antes_de if 0 < a['ps'] < a['psmax'])
    revive = any(a['ps'] == 0 for a in antes_de)
    return pp or ps >= 2 or revive or (ps == 1 and len(vivos) == 1)


def seguimiento():
    rpc = juego.RPC()
    while True:
        if comun.vivo.get('jugaba') and not emulador.jugando():           # se acaba de cerrar el juego: copia de la partida
            comun.vivo['jugaba'] = False
            try:
                with comun.lock:
                    j = comun.buscar(comun.vivo['activo'])
                guardado.copiar_partida(j, 'al-cerrar')
                with comun.lock:
                    vigia.cerrar(j)
            except (RuntimeError, OSError):
                traceback.print_exc()
        if emulador.citra_listo():
            try:
                equipo = juego.leer_equipo(rpc)
                with comun.lock:
                    if not comun.vivo['conectado']:
                        comun.vivo['conectado_desde'], comun.vivo['a_cero'], comun.vivo['curas_centro'] = time.time(), {}, None
                    comun.vivo['conectado'] = True
                    # al entrar o salir de un combate el juego reescribe el equipo, y una lectura en ese momento
                    # no cuadra con su suma de comprobación: un hueco solo se da por vacío tras 3 lecturas seguidas
                    vacios = comun.vivo.setdefault('vacios', [0] * 6)
                    for i, p in enumerate(equipo):
                        if p is None and comun.vivo['equipo'][i] is not None and vacios[i] < 2:
                            vacios[i] += 1
                            equipo[i] = comun.vivo['equipo'][i]
                        elif p is not None:
                            vacios[i] = 0
                    antes, comun.vivo['equipo'] = comun.vivo['equipo'], equipo
                    j = comun.buscar(comun.vivo['activo'])
                    vigilar_huevos(rpc, j, equipo)
                    # Mega: combate en Fijo desde el principio, una vez por partida (luego se respeta lo que elija el jugador)
                    if j.get('reglas') == 'mega' and any(equipo):
                        try:
                            quien = juego.entrenador_equipo(rpc)
                            if quien and j.get('fijo_puesto') != quien and juego.poner_fijo(rpc):
                                j['fijo_puesto'] = quien
                                comun.guardar()
                        except (OSError, TimeoutError):
                            pass
                    # por si el juego abre uno por su cuenta, sin haber pasado por aquí
                    for p in (x for x in huevos_abiertos(antes, equipo) if x['id'] not in comun.vivo.get('ya_nacidos', ())):
                        mio = next((h for h in j.get('huevos') or [] if h['cogido'] and h.get('abierto') is False and h['especie'] == p['especie']), None)
                        if mio:
                            mio['abierto'] = True
                            comun.guardar()
                        vigia.evento('huevo', f'Se abre un huevo: {pokehex.NOMBRES["especies"][p["especie"]]}')
                        threading.Thread(target=emulador.apertura, args=(p['especie'], bool(mio and mio['shiny'])), daemon=True).start()
                    # las medallas se marcan solas: las lee del juego en cuanto vences al líder
                    try:
                        medallas = juego.medallas_bits(rpc)
                    except (OSError, TimeoutError):
                        medallas = None
                    if medallas is not None and medallas != j.get('medallas'):
                        if sum(medallas) < sum(j.get('medallas', [])):
                            vigia.evento('retroceso', f'La partida ha perdido medallas: de {sum(j["medallas"])} a {sum(medallas)}', 'sospecha')
                        j['medallas'] = medallas
                        resolver_reto(j)
                        avisar_reto_nuevo(j)
                        # Mega Pokelocke: la 4.ª medalla (Amaro) es la mitad del juego y toca el torneo. Una vez
                        if j.get('reglas') == 'mega' and sum(medallas) >= 4 and not j.get('aviso_torneo'):
                            j['aviso_torneo'] = True
                            comun.avisar('¡Has llegado al fin de la primera parte del Mega Pokelocke! · '
                                   'Prepara tu equipo para el gran torneo', 20)
                        comun.guardar()
                    misiones_tick(j, rpc)
                    # el vial se recarga cada vez que la enfermera de un Centro cura al equipo: sube su
                    # contador en los récords del juego. Si no se puede leer, se adivina por PS y PP
                    try:
                        curas = juego.curas_en_centro(rpc)
                    except (OSError, TimeoutError):
                        curas = None
                    previas, comun.vivo['curas_centro'] = comun.vivo.get('curas_centro'), curas
                    if curas is not None:
                        en_centro = previas is not None and curas > previas
                    else:
                        en_centro = time.time() - comun.vivo.get('vial_usado', 0) > 5 and curado_en_centro(antes, equipo)
                    if not j.get('vial', True) and en_centro:
                        j['vial'] = True
                        comun.avisar('Vial recargado en el Centro Pokémon')
                        comun.guardar()
                    # un Pokémon a 0 PS cuenta como muerto una sola vez, aunque luego lo revivan. Para no contar
                    # lecturas a medias (al cargar la partida o al cambiar de mapa), tiene que seguir a 0 PS en
                    # 3 lecturas seguidas y no justo al conectar con el juego
                    # Mega Pokelocke: hasta acabar el primer combate contra un entrenador (el de Shauna) no cuenta
                    # ninguna muerte. Los que se debilitan antes quedan perdonados hasta que se curen
                    cuentan = True
                    if j.get('reglas') == 'mega' and not j.get('muertes_activas'):
                        try:
                            combates = juego.record(rpc, juego.RECORD_ENTRENADORES)
                        except (OSError, TimeoutError):
                            combates = None
                        # el contador del juego sube al EMPEZAR el combate: se espera a que haya acabado (fuera de
                        # combate y con el contador subido desde hace unos segundos, por si el combate aún no se ve)
                        if combates and not comun.vivo.get('combate_visto_desde'):
                            comun.vivo['combate_visto_desde'] = time.time()
                        if combates and time.time() - comun.vivo['combate_visto_desde'] > 3 \
                                and not comun.vivo.get('en_combate') and not juego.en_combate(rpc):
                            j['muertes_activas'] = True
                            # unos segundos de margen: el contador sube al acabar el combate, a la vez que
                            # el equipo recibe los PS de la copia del combate
                            comun.vivo['gracia_hasta'] = time.time() + 10
                            comun.avisar('Primer combate superado · A partir de ahora cada muerte cuenta')
                            comun.guardar()
                        cuentan = False
                    elif time.time() < comun.vivo.get('gracia_hasta', 0):
                        cuentan = False
                    perdonados = j.setdefault('perdonados', [])
                    a_cero = comun.vivo.setdefault('a_cero', {})
                    for p in equipo:
                        if not p or p['huevo'] or not p['psmax'] or p['ps'] != 0:
                            if p:
                                a_cero.pop(p['id'], None)
                                if p['ps'] and p['id'] in perdonados:
                                    perdonados.remove(p['id'])
                                    comun.guardar()
                            continue
                        a_cero[p['id']] = a_cero.get(p['id'], 0) + 1
                        if a_cero[p['id']] >= 3 and time.time() - comun.vivo.get('conectado_desde', 0) > 15 \
                                and p['id'] not in j['muertos'] and p['id'] not in perdonados:
                            (j['muertos'] if cuentan else perdonados).append(p['id'])
                            vigia.muerte(j, p, cuentan)
                            comun.guardar()
                    vigia.ronda(j, equipo, rpc)
            except (OSError, TimeoutError, RuntimeError):
                comun.vivo['conectado'] = False
        else:
            comun.vivo['conectado'] = False
        time.sleep(1)


def normas_mega():
    """Mega Pokelocke, una captura por ruta: cuando sube el contador de capturas del juego, la zona donde
    estás queda gastada (salvo si el capturado era shiny). En un combate en una zona gastada se esconden las
    Poké Balls de la mochila y se devuelven al acabar; si el salvaje es shiny se dejan.
    La mochila solo se toca en dos momentos: durante la animación de entrada del combate (se decide una vez,
    a los 1,5 s, cuando ya está el salvaje nuevo) y con el juego fuera de combate desde hace 3 s. Tocarla
    justo al capturar (el juego está guardando el Pokémon y la Ball gastada) cuelga el juego."""
    rpc = juego.RPC(espera=1.0)
    capturas = zona = None
    combate_desde = fuera_desde = None
    decidido = False
    while True:
        time.sleep(0.5)                       # de sobra: las Balls se deciden a los 1,5 s de empezar el combate
        with comun.lock:
            j = next((x for x in comun.biblio['juegos'] if x['id'] == comun.vivo['activo']), None) if emulador.citra_listo() else None
            if j and j.get('reglas') != 'mega':
                j = None
            if not j:
                # juego cerrado: si las Balls estaban escondidas, la partida guardada aún las tiene (en
                # combate no se puede guardar), así que no hay nada que devolver
                for x in comun.biblio['juegos']:
                    if x.get('balls_escondidas'):
                        x['balls_escondidas'] = None
                        comun.guardar()
                capturas = zona = combate_desde = fuera_desde = None
                rpc.equipo = None
                comun.vivo['en_combate'] = False
                continue
        try:
            combate = comun.vivo['en_combate'] = juego.en_combate(rpc)
            if combate:
                fuera_desde = None
                if combate_desde is None:
                    combate_desde, decidido = time.time(), False
            else:
                zona = juego.zona(rpc)
                combate_desde = None
                with comun.lock:
                    vistas = j.setdefault('zonas_vistas', [])     # en orden: de aquí salen las llegadas del tablero
                    if zona not in vistas:
                        vistas.append(zona)
                        vigia.evento('zona', f'Zona nueva: {zona}')
                        comun.guardar()
                fuera_desde = fuera_desde or time.time()
            ahora = juego.record(rpc, juego.RECORD_CAPTURAS)
            # segunda medalla en la fase fácil: el cambio se hace al volver a abrir el juego (con la partida
            # guardada); hasta entonces se recuerda cada 2 minutos
            if j.get('fase') == 1 and not combate and juego.medallas(rpc) >= MEDALLAS_PARA_COMPLETA \
                    and time.time() - comun.vivo.get('aviso_fase', 0) > 120:
                comun.vivo['aviso_fase'] = time.time()
                comun.avisar('¡Segunda medalla! · Guarda y reinicia el juego para abrir la randomización completa', 15)
            with comun.lock:
                usadas = j.setdefault('rutas_usadas', [])
                if capturas is not None and ahora is not None and ahora > capturas and zona is not None:
                    if juego.salvaje_shiny(rpc):
                        comun.avisar('¡Shiny! No cuenta como la captura de esta ruta')
                        vigia.evento('captura', f'Captura de un shiny en la zona {zona}: no gasta la ruta')
                    elif zona not in usadas:
                        usadas.append(zona)
                        comun.avisar('Captura de esta ruta hecha · Aquí ya no puedes capturar más', 3)
                        vigia.captura(j, zona, False)
                    else:
                        vigia.captura(j, zona, True)
                    comun.guardar()
                if ahora is not None:
                    capturas = ahora
                if combate and not decidido and time.time() - combate_desde >= 1.5:
                    decidido = True
                    if zona in usadas and not j.get('balls_escondidas') and not juego.salvaje_shiny(rpc):
                        j['balls_escondidas'] = juego.esconder_balls(rpc)
                        avisadas = j.setdefault('rutas_avisadas', [])     # el aviso, solo la primera vez en cada ruta
                        if j['balls_escondidas'] and zona not in avisadas:
                            avisadas.append(zona)
                            comun.avisar('Ya has capturado en esta ruta · Poké Balls bloqueadas', 1.5)
                        comun.guardar()
                elif not combate and j.get('balls_escondidas') and time.time() - fuera_desde >= 3:
                    juego.devolver_balls(rpc, j['balls_escondidas'])
                    j['balls_escondidas'] = None
                    comun.guardar()
        except (OSError, TimeoutError):
            rpc.equipo = None


def corregir(atajo):
    """F7 −1 vida, F8 +1 vida. Las medallas ya no van con F9: se leen del juego."""
    with comun.lock:
        j = comun.buscar(comun.vivo['activo'])
        if atajo == 'menos':
            j['ajuste_vidas'] -= 1
        elif atajo == 'mas':
            j['ajuste_vidas'] += 1
        vigia.evento('vidas', f'Se {"quita" if atajo == "menos" else "suma"} una vida con {"F7" if atajo == "menos" else "F8"}: ahora tiene {vidas(j)}',
                     'info' if atajo == 'menos' else 'sospecha', vidas=vidas(j))
        comun.guardar()


def atajos():
    """Atajos globales de Windows, registrados solo mientras hay un juego abierto."""
    import ctypes.wintypes as wt
    u = ctypes.windll.user32
    TECLAS = {1: (0, 0x76, 'menos'), 2: (0, 0x77, 'mas')}       # 0x76, 0x77 = F7, F8
    # el vial va con la E (Azahar no la usa; la V es su botón de encendido). Solo se captura con el
    # juego delante, para que en el resto de programas la E se siga escribiendo
    VIAL = {5: (0, 0x45, 'vial')}
    MOD_NOREPEAT, WM_HOTKEY, PM_REMOVE = 0x4000, 0x0312, 1
    registrados = vial_registrado = False
    msg = wt.MSG()
    pid = wt.DWORD()

    k32 = ctypes.windll.kernel32

    def juego_delante():
        """La ventana de delante es del emulador: del proceso lanzado o de otro programa de su carpeta
        (con Citra, Pokelocke lanza el lanzador azahar.exe y la ventana es de citra-qt.exe)."""
        u.GetWindowThreadProcessId(u.GetForegroundWindow(), ctypes.byref(pid))
        p = comun.vivo['proceso']
        if p is None:
            return False
        if pid.value == p.pid:
            return True
        h = k32.OpenProcess(0x1000, False, pid.value)              # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return False
        try:
            ruta, n = ctypes.create_unicode_buffer(1024), wt.DWORD(1024)
            if not k32.QueryFullProcessImageNameW(h, 0, ruta, ctypes.byref(n)):
                return False
            exe = emulador.azahar_exe()
            return exe is not None and Path(ruta.value).parent == exe.parent
        finally:
            k32.CloseHandle(h)

    while True:
        if emulador.jugando() and not registrados:
            for i, (mod, tecla, _) in TECLAS.items():
                u.RegisterHotKey(None, i, mod | MOD_NOREPEAT, tecla)
            registrados = True
        elif not emulador.jugando() and registrados:
            for i in TECLAS:
                u.UnregisterHotKey(None, i)
            registrados = False
        delante = emulador.jugando() and juego_delante()
        if delante and not vial_registrado:
            for i, (mod, tecla, _) in VIAL.items():
                u.RegisterHotKey(None, i, mod | MOD_NOREPEAT, tecla)
            vial_registrado = True
        elif not delante and vial_registrado:
            for i in VIAL:
                u.UnregisterHotKey(None, i)
            vial_registrado = False
        while u.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
            if msg.message != WM_HOTKEY:
                continue
            accion = (TECLAS.get(msg.wParam) or VIAL.get(msg.wParam) or (0, 0, None))[2]
            try:
                if accion == 'vial':
                    usar_vial()
                elif accion:
                    corregir(accion)
            except (RuntimeError, OSError, TimeoutError):
                traceback.print_exc()
        time.sleep(0.1)


def usar_vial():
    """E: si el vial está cargado, cura a todo el equipo vivo y se gasta hasta el próximo Centro Pokémon."""
    if not emulador.citra_listo():
        return
    with comun.lock:
        j = comun.buscar(comun.vivo['activo'])
        if not j.get('vial', True):
            comun.avisar('El vial está vacío · Vuelve al Centro Pokémon para recargarlo')
            return
        mega = j.get('reglas') == 'mega'
    rpc = juego.RPC(espera=1.0)
    if mega and (comun.vivo.get('en_combate') or juego.en_combate(rpc)):
        return                     # bloqueado: la E no hace nada (el layout ya enseña el vial tachado)
    if juego.curar_equipo(rpc):
        with comun.lock:
            j['vial'] = False
            comun.vivo['vial_usado'] = time.time()
            comun.avisar('¡Has usado el vial! · Vuelve al Centro Pokémon para recargarlo')
            vigia.evento('vial', 'Usa el vial')
            comun.guardar()


# ---------- duelos entre amigos (online) ----------
# Un jugador reta a otro desde Retos: gana quien pierda menos vidas hasta el 4.º gimnasio (el gran torneo). Lo lleva el
# servidor (online.Servidor, con las cuentas que manda cada latido); aquí se avisa de cada paso y, al cerrarse, se
# apunta el premio (un huevo extra) o el castigo (una vida). Con las mismas vidas perdidas, empate: nada.
def mi_locke():
    """El locke de este Pokelocke (solo hay una ROM): el que está preparado."""
    return next((j for j in comun.biblio['juegos'] if j.get('preparado')), None)


def perdidas(j):
    return len(j.get('muertos', [])) + j.get('vidas_retos', 0)


def _vidas_txt(n):
    return f'{n} {"vida" if n == 1 else "vidas"}'


def duelos_tick(duelos, yo):
    """Con cada latido (con comun.lock): lo nuevo de cada duelo desde la última vez."""
    j = mi_locke()
    if not j:
        return
    clave = lambda d: {'estado': d['estado'], 'fin': sorted(d['fin'])}
    if j.get('duelos_vistos') is None:            # locke nuevo: los duelos de antes no cuentan para este
        j['duelos_vistos'] = {d['id']: clave(d) for d in duelos}
        comun.guardar()
        return
    vistos, cambio = j['duelos_vistos'], False
    for d in duelos:
        antes, otro = vistos.get(d['id']), d['a'] if d['de'] == yo else d['de']
        if antes == clave(d):
            continue
        vistos[d['id']], cambio = clave(d), True
        if d['estado'] == 'pendiente' and d['a'] == yo:
            avisar_en_cola(f'¡{otro} te reta a un duelo! · Acéptalo o recházalo en Retos', 5)
        elif d['estado'] == 'rechazado' and d['de'] == yo:
            avisar_en_cola(f'{otro} rechaza tu duelo', 4)
        elif d['estado'] in ('en_marcha', 'cerrado') and (antes or {}).get('estado') == 'pendiente' and d['de'] == yo:
            avisar_en_cola(f'¡{otro} acepta tu duelo! · Gana quien pierda menos vidas hasta el 4.º gimnasio', 5)
        for p in d['fin']:
            if p not in (antes or {}).get('fin', []):
                quien = 'Llegas al 4.º gimnasio: has perdido' if p == yo else f'{p} llega al 4.º gimnasio: ha perdido'
                falta = '' if len(d['fin']) == 2 else f' · Falta {otro if p == yo else "que llegues tú"}'
                avisar_en_cola(f'Duelo · {quien} {_vidas_txt(d["fin"][p])}{falta}', 6)
        if d['estado'] == 'cerrado':
            mio, suyo = d['fin'][yo], d['fin'][otro]
            marcador = f'{yo} {_vidas_txt(mio)} · {otro} {_vidas_txt(suyo)} perdidas'
            if d['ganador'] == yo:
                j['huevos_extra'] = j.get('huevos_extra', 0) + 1
                celebrar(True, '¡Duelo ganado!', f'Contra {otro}: {mio} a {suyo}', 'Ganas un huevo extra', 'huevo')
            elif d['ganador'] == otro:
                j['vidas_retos'] = j.get('vidas_retos', 0) + 1
                celebrar(False, 'Duelo perdido', f'Contra {otro}: {mio} a {suyo}', 'Pierdes una vida', 'corazon')
            else:
                avisar_en_cola(f'Duelo empatado con {otro} · {_vidas_txt(mio)} cada uno: nadie gana ni pierde', 6)
            vigia.evento('duelo', f'Duelo con {otro}: {marcador} · ' + ('gana' if d['ganador'] == yo else 'empate' if d['ganador'] is None else 'pierde'))
    if cambio:
        comun.guardar()
