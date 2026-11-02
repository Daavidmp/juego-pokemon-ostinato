"""La actividad de cada jugador, para que el administrador pueda pillar trampas.

Cada cosa que pasa se apunta en datos/eventos.jsonl, numerada y encadenada con su huella, y se manda al servidor con
los latidos: lo que ya ha llegado no se puede borrar desde el PC del jugador, y si borra o cambia su archivo el servidor
lo nota. Niveles: info (lo normal), aviso (raro, hay que mirarlo) y sospecha (lo que suele ser trampa).
Lo que se comprueba y por qué está en CONTEXTO_CLAUDE.txt (4e).
"""
import hashlib
import json
import threading
import time

import comun
import online

cerrojo = threading.Lock()
cuenta = {'n': None, 'h': ''}                    # el último evento apuntado (se lee del archivo la primera vez)
NIVELES = ('info', 'aviso', 'sospecha')
# legendarios y singulares hasta la 6.ª generación: el contrato no deja capturarlos
LEGENDARIOS = frozenset([144, 145, 146, 150, 151, 243, 244, 245, 249, 250, 251, *range(377, 387), *range(480, 495),
                         *range(638, 650), *range(716, 722)])
LECTURAS_RETROCESO = 3                           # un contador tiene que bajar en 3 lecturas seguidas para ser de verdad


def archivo():
    return comun.DATOS / 'eventos.jsonl'


def _leer():
    try:
        with open(archivo(), encoding='utf-8') as f:
            return [json.loads(l) for l in f if l.strip()]
    except (OSError, ValueError):
        return []


def evento(tipo, texto, nivel='info', **extra):
    with cerrojo:
        if cuenta['n'] is None:
            lineas = _leer()
            cuenta.update(n=lineas[-1]['n'] if lineas else 0, h=lineas[-1]['h'] if lineas else '')
        e = {'n': cuenta['n'] + 1, 't': time.strftime('%Y-%m-%d %H:%M:%S'), 'tipo': tipo, 'nivel': nivel, 'texto': str(texto)[:300], **extra}
        e['h'] = online.huella_evento(cuenta['h'], e)
        comun.DATOS.mkdir(parents=True, exist_ok=True)
        with open(archivo(), 'a', encoding='utf-8') as f:
            f.write(json.dumps(e, ensure_ascii=False) + '\n')
        cuenta.update(n=e['n'], h=e['h'])
    print(e['t'][11:], 'evento', nivel, texto, flush=True)
    return e


def para_mandar(hasta, maximo=100):
    """Los eventos que aún no tiene el servidor, y cuántos hay en total."""
    with cerrojo:
        lineas = _leer()
    return [e for e in lineas if e['n'] > hasta][:maximo], lineas[-1]['n'] if lineas else 0


def ultimas_vidas():
    for e in reversed(_leer()):
        if 'vidas' in e:
            return e['vidas']
    return None


# ---------- la partida y lo que rodea al juego ----------

def huella_partida(j):
    import guardado
    try:
        return hashlib.sha1(guardado.pokehex_partida(j).read_bytes()).hexdigest()
    except (RuntimeError, OSError):
        return None


def anotar_partida(j):
    """La partida está como debe: si cambia antes de la próxima vez que se abra el juego, ha sido por fuera de Pokelocke."""
    j['huella_partida'] = huella_partida(j)


def carpeta_citra():
    import emulador
    exe = emulador.azahar_exe()
    return exe.parent / 'user' if exe else None


def estados_guardados():
    """Los save states de Citra: guardar y cargar con ellos permite repetir cualquier combate."""
    u = carpeta_citra()
    if not u or not (u / 'states').exists():
        return set()
    return {f'{f.name} {f.stat().st_mtime_ns}' for f in (u / 'states').rglob('*') if f.is_file()}


def trucos_citra():
    u = carpeta_citra()
    if not u or not (u / 'cheats').exists():
        return []
    return [f.name for f in (u / 'cheats').rglob('*') if f.is_file() and f.stat().st_size > 0]


def abrir(j):
    """Al darle a Jugar: lo que ha cambiado desde que se cerró el juego la última vez."""
    import emulador
    import locke
    vidas = locke.vidas(j)
    anterior = j.get('huella_partida')
    if anterior and huella_partida(j) not in (None, anterior):
        evento('partida', 'La partida ha cambiado con el juego cerrado: editada con otro programa (PKHeX), o jugada abriendo '
                          'Citra sin Pokelocke', 'sospecha')
    firma = j.get('firma_mod')
    if firma and j.get('random') and firma != emulador.firma_mod(j):
        evento('rom', 'Los archivos de la randomización no son los que se prepararon', 'sospecha')
    registradas = ultimas_vidas()
    if registradas is not None and registradas != vidas:
        evento('vidas', f'Las vidas no coinciden: iba con {registradas} y ahora tiene {vidas}, sin que Pokelocke lo haya apuntado', 'sospecha')
    trucos = trucos_citra()
    if trucos:
        evento('trucos', f'Hay códigos de trucos en Citra: {", ".join(trucos[:5])}', 'sospecha')
    if not comun.red['sesion'] or comun.red.get('error'):
        evento('conexion', 'Juega sin conexión con el servidor', 'aviso')
    comun.vivo.update(sin_guardar=[], estados_al_abrir=estados_guardados(), contadores={}, retroceso={}, tope_avisado=set(), legendario_avisado=set())
    evento('abrir', f'Abre el juego · {vidas} vidas · {sum(j.get("medallas", []))} medallas · versión {comun.VERSION_APP}', vidas=vidas)


def apuntar_sin_guardar(texto):
    comun.vivo.setdefault('sin_guardar', []).append((time.time(), texto))


def cerrar(j):
    """Al cerrarse el juego: si pasó algo importante después de la última vez que guardó, salió sin guardar."""
    import guardado
    import locke
    vidas = locke.vidas(j)
    try:
        guardado_en = guardado.pokehex_partida(j).stat().st_mtime
    except (RuntimeError, OSError):
        guardado_en = 0
    perdido = [t for h, t in comun.vivo.get('sin_guardar', []) if h > guardado_en]
    if perdido:
        evento('sin_guardar', 'Ha cerrado el juego sin guardar después de: ' + ' · '.join(perdido[:6]), 'sospecha')
    nuevos = estados_guardados() - comun.vivo.get('estados_al_abrir', set())
    if nuevos:
        evento('estados', f'Ha creado {len(nuevos)} estado(s) guardado(s) de Citra mientras jugaba', 'sospecha')
    anotar_partida(j)
    evento('cerrar', f'Cierra el juego · {vidas} vidas · {sum(j.get("medallas", []))} medallas', vidas=vidas)
    comun.guardar()


def muerte(j, p, cuenta_vida):
    import locke
    nombre = p.get('mote') or f'Pokémon {p["especie"]}'
    if cuenta_vida:
        apuntar_sin_guardar(f'muerte de {nombre}')
        evento('muerte', f'Muere {nombre} (nivel {p["nivel"]}) · quedan {locke.vidas(j)} vidas', vidas=locke.vidas(j))
    else:
        evento('perdonado', f'{nombre} se debilita antes del primer combate: no cuenta')


def captura(j, zona, gastada):
    apuntar_sin_guardar(f'captura en la zona {zona}')
    if gastada:
        evento('captura', f'Captura en la zona {zona}, que ya estaba gastada', 'sospecha')
    else:
        evento('captura', f'Captura en la zona {zona}')


def contador(nombre, valor):
    """Un contador del juego (capturas, combates) nunca baja: si baja, la partida ha vuelto atrás."""
    contadores, baja = comun.vivo.setdefault('contadores', {}), comun.vivo.setdefault('retroceso', {})
    antes = contadores.get(nombre)
    if not valor:                                # en la pantalla de título se lee 0
        return
    if antes is None or valor >= antes:
        contadores[nombre], baja[nombre] = valor, 0
        return
    baja[nombre] = baja.get(nombre, 0) + 1
    if baja[nombre] >= LECTURAS_RETROCESO:
        evento('retroceso', f'La partida ha vuelto atrás ({nombre}: de {antes} a {valor}): ha reiniciado sin guardar o ha cargado un estado', 'sospecha')
        contadores[nombre], baja[nombre] = valor, 0


def ronda(j, equipo, rpc):
    """Cada lectura del juego: que no haya vuelto atrás, nivel tope y legendarios."""
    import juego
    import locke
    contador('capturas', juego.record(rpc, juego.RECORD_CAPTURAS))
    contador('combates', juego.record(rpc, juego.RECORD_ENTRENADORES))
    comun.vivo.setdefault('tope_avisado', set())
    comun.vivo.setdefault('legendario_avisado', set())
    topes = locke.niveles_tope(j) if j.get('reglas') == 'mega' else None
    medallas = sum(j.get('medallas', []))
    for p in equipo:
        if not p or p.get('huevo'):
            continue
        if topes and medallas < len(topes) and p['nivel'] > topes[medallas] and (medallas, p['id']) not in comun.vivo['tope_avisado']:
            comun.vivo['tope_avisado'].add((medallas, p['id']))
            evento('nivel', f'{p.get("mote")} está al nivel {p["nivel"]}, por encima del tope ({topes[medallas]}) con {medallas} medallas', 'sospecha')
        if p['especie'] in LEGENDARIOS and p['id'] not in comun.vivo['legendario_avisado']:
            comun.vivo['legendario_avisado'].add(p['id'])
            evento('legendario', f'Lleva un legendario o singular en el equipo: {p.get("mote")} (n.º {p["especie"]})', 'sospecha')
