"""El locke: vidas, huevos, caramelos, fases, seguimiento del juego, normas Mega, atajos y vial."""
import ctypes
import re
import shutil
import time
import traceback
from pathlib import Path

import juego
import pokehex
import comun
import emulador
import guardado


def nuevo_locke(j, vidas, reglas=None):
    j.update(vidas_iniciales=int(vidas), ajuste_vidas=0, muertos=[], medallas=[False] * 8, vial=True,
             reglas=reglas, perdonados=[], caramelos_dados=0, muertes_activas=False,
             fase=1 if reglas == 'mega' else None, rutas_usadas=[], rutas_avisadas=[], balls_escondidas=None,
             aviso_torneo=False,
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
    return max(0, sum(j.get('medallas', [])) // MEDALLAS_POR_HUEVO - gastados)


def huevos_estado(j):
    """Lo que ve la página: los cogidos con su especie; los demás, sin desvelar."""
    return {'disponibles': huevos_disponibles(j), 'medallas': sum(j.get('medallas', [])),
            'huevos': [{'cogido': True, 'especie': h['especie'], 'shiny': h['shiny'],
                        'nombre': pokehex.NOMBRES['especies'][h['especie']]} if h['cogido'] else {'cogido': False}
                       for h in j['huevos']]}


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
    h['cogido'] = True
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


def vidas(j):
    return max(0, j['vidas_iniciales'] + j['ajuste_vidas'] - len(j['muertos']))


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
                    # las medallas se marcan solas: las lee del juego en cuanto vences al líder
                    try:
                        medallas = juego.medallas_bits(rpc)
                    except (OSError, TimeoutError):
                        medallas = None
                    if medallas is not None and medallas != j.get('medallas'):
                        j['medallas'] = medallas
                        # Mega Pokelocke: la 4.ª medalla (Amaro) es la mitad del juego y toca el torneo. Una vez
                        if j.get('reglas') == 'mega' and sum(medallas) >= 4 and not j.get('aviso_torneo'):
                            j['aviso_torneo'] = True
                            comun.avisar('¡Has llegado al fin de la primera parte del Mega Pokelocke! · '
                                   'Prepara tu equipo para el gran torneo', 20)
                        comun.guardar()
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
                            comun.guardar()
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
                    elif zona not in usadas:
                        usadas.append(zona)
                        comun.avisar('Captura de esta ruta hecha · Aquí ya no puedes capturar más', 3)
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
                            comun.avisar('Ya has capturado en esta ruta · Poké Balls bloqueadas', 3)
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
            comun.guardar()
