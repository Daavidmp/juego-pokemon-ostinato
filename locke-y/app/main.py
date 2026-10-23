"""Pokelocke: biblioteca de juegos, randomizador, Azahar con el layout del stream y seguimiento del locke.

Todo vive dentro de locke-y/ y no se instala nada en el sistema:
  tools/   Azahar portable, Universal Pokemon Randomizer ZX, perfil de Edge, caché de arte (no se sube a git)
  datos/   biblioteca, lockes, ajustes y mods randomizados de cada juego (no se sube a git)
  fanart/  arte propio por especie: 658.png, 658.jpg... (no se sube a git)

Pokelocke.exe (o Pokelocke.bat) abre la biblioteca. Con --capa abre solo la capa del layout
que va encima de Azahar mientras se juega.
"""
import configparser
import ctypes
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import traceback
import urllib.request
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import juego

if getattr(sys, 'frozen', False):          # Pokelocke.exe, junto a app/ dentro de locke-y/
    RAIZ = Path(sys.executable).resolve().parent
else:
    RAIZ = Path(__file__).resolve().parent.parent
APP, WEB, ASSETS = RAIZ / 'app', RAIZ / 'app' / 'web', RAIZ / 'assets'
TOOLS, DATOS, FANART = RAIZ / 'tools', RAIZ / 'datos', RAIZ / 'fanart'
CACHE_ARTE = TOOLS / 'arte'
CAPA_PNG = TOOLS / 'capa.png'
BIBLIOTECA = DATOS / 'biblioteca.json'
PUERTO = 8765
URL = f'http://127.0.0.1:{PUERTO}'
TITLE_Y = '0004000000055E00'
ARTE_URL = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{}.png'
CLAVE = '#ff00ff'                      # color de los huecos de la capa: Windows lo vuelve transparente

# huecos del layout de 1920×1080 (x, y, ancho, alto)
HUECO_ARRIBA = (72, 244, 1000, 600)
HUECO_ABAJO = (1168, 530, 680, 510)

# campos de Settings del UPR que el menú puede tocar (el resto queda como en el UPR por defecto)
OPCIONES = {
    'wildPokemonMod', 'wildPokemonRestrictionMod', 'blockWildLegendaries', 'useMinimumCatchRate',
    'minimumCatchRateLevel', 'wildLevelsModified', 'wildLevelModifier', 'startersMod',
    'limitMainGameLegendaries', 'trainersMod', 'trainersUsePokemonOfSimilarStrength',
    'trainersLevelModified', 'trainersLevelModifier', 'trainersForceFullyEvolved', 'staticPokemonMod',
    'abilitiesMod', 'typesMod', 'baseStatisticsMod', 'evolutionsMod', 'evosSimilarStrength',
    'movesetsMod', 'fieldItemsMod', 'inGameTradesMod',
}

lock = threading.Lock()
biblio = {'juegos': []}
vivo = {'equipo': [None] * 6, 'conectado': False, 'tarea': None, 'activo': None,
        'proceso': None, 'capa': 0}                          # no se guarda en disco


# ---------- biblioteca y lockes ----------

def guardar():
    DATOS.mkdir(exist_ok=True)
    BIBLIOTECA.write_text(json.dumps(biblio, indent=2, ensure_ascii=False), encoding='utf-8')


def cargar():
    if BIBLIOTECA.exists():
        biblio.update(json.loads(BIBLIOTECA.read_text(encoding='utf-8')))


def buscar(id_juego):
    j = next((j for j in biblio['juegos'] if j['id'] == id_juego), None)
    if not j:
        raise RuntimeError('Ese juego ya no está en la biblioteca')
    return j


def nuevo_locke(j, vidas):
    j.update(vidas_iniciales=int(vidas), ajuste_vidas=0, muertos=[], medallas=[False] * 8, vial=True)


def vidas(j):
    return max(0, j['vidas_iniciales'] + j['ajuste_vidas'] - len(j['muertos']))


def jugando():
    p = vivo['proceso']
    return p is not None and p.poll() is None


# ---------- herramientas portables ----------

def java():
    candidatos = []
    if os.environ.get('JAVA_HOME'):
        candidatos.append(Path(os.environ['JAVA_HOME']) / 'bin' / 'java.exe')
    candidatos += sorted((Path.home() / '.jdks').glob('*/bin/java.exe'), reverse=True)
    candidatos += sorted((TOOLS / 'java').glob('*/bin/java.exe'), reverse=True)   # el que descarga la app
    en_path = shutil.which('java')
    if en_path:
        candidatos.append(Path(en_path))
    # solo un JDK vale (con javac al lado): un JRE no puede ejecutar LockeSettings.java
    for c in candidatos:
        if c.exists() and (c.parent / 'javac.exe').exists():
            return str(c)
    return None


def navegador():
    for base in (os.environ.get('ProgramFiles(x86)'), os.environ.get('ProgramFiles'), os.environ.get('LOCALAPPDATA')):
        for rel in (r'Microsoft\Edge\Application\msedge.exe', r'Google\Chrome\Application\chrome.exe'):
            if base and (Path(base) / rel).exists():
                return str(Path(base) / rel)
    return None


def azahar_exe():
    return next((TOOLS / 'azahar').rglob('azahar.exe'), None) if (TOOLS / 'azahar').exists() else None


def upr_jar():
    return next((TOOLS / 'upr').rglob('PokeRandoZX.jar'), None) if (TOOLS / 'upr').exists() else None


def pantalla():
    """Resolución física del monitor principal."""
    u = ctypes.windll.user32
    return u.GetSystemMetrics(0), u.GetSystemMetrics(1)


def encaje():
    """Escala y desplazamiento del layout 1920×1080 dentro del monitor."""
    w, h = pantalla()
    s = min(w / 1920, h / 1080)
    return s, round((w - 1920 * s) / 2), round((h - 1080 * s) / 2)


def tarea(mensaje, error=False, fin=False, paso=None, pct=None):
    """paso: 1 herramientas, 2 randomización, 3 abrir el juego (la pantalla de progreso los muestra)."""
    anterior = vivo['tarea'] or {}
    vivo['tarea'] = {'mensaje': mensaje, 'error': error, 'fin': fin, 'pct': pct,
                     'paso': paso or anterior.get('paso'), 'random': anterior.get('random', False),
                     'inicio': anterior.get('inicio', time.time()), 'minimo': anterior.get('minimo', 0)}


def descargar(repo, patron, destino, nombre):
    tarea(f'Buscando la última versión de {nombre}…')
    with urllib.request.urlopen(f'https://api.github.com/repos/{repo}/releases/latest') as r:
        rel = json.load(r)
    asset = next(a for a in rel['assets'] if re.fullmatch(patron, a['name']))
    descargar_zip(asset['browser_download_url'], destino, f'{nombre} {rel["tag_name"]}')


def descargar_java():
    """Java 17 portable (Temurin, de Adoptium) dentro de tools/java: el randomizador lo necesita.
    Tiene que ser el JDK y no el JRE: LockeSettings.java se ejecuta como fuente y eso pide jdk.compiler."""
    descargar_zip('https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse',
                  TOOLS / 'java', 'Java 17')


def descargar_zip(url, destino, nombre):
    zip_tmp = TOOLS / 'descarga.zip'
    TOOLS.mkdir(exist_ok=True)

    def progreso(bloques, tam, total):
        if total > 0:
            pct = min(100, bloques * tam * 100 // total)
            tarea(f'Descargando {nombre}…', paso=1, pct=pct)
    try:
        urllib.request.urlretrieve(url, zip_tmp, progreso)
        tarea(f'Descomprimiendo {nombre}…', paso=1)
        shutil.rmtree(destino, ignore_errors=True)
        with zipfile.ZipFile(zip_tmp) as z:
            entradas = z.infolist()
            for m in entradas:
                m.filename = m.filename.replace('\\', '/')   # el zip de Azahar usa barras de Windows
            z.extractall(destino, members=entradas)
    finally:
        zip_tmp.unlink(missing_ok=True)


def herramientas():
    if not java():
        descargar_java()
        if not java():
            raise RuntimeError('No he podido descargar Java. Instala Java 11 o superior y vuelve a intentarlo.')
    if not azahar_exe():
        descargar('azahar-emu/azahar', r'azahar-windows-msvc-[\d.]+\.zip', TOOLS / 'azahar', 'Azahar')
    if not upr_jar():
        descargar('Ajarmar/universal-pokemon-randomizer-zx', r'PokeRandoZX-.*\.zip', TOOLS / 'upr',
                  'el randomizador')


def configurar_azahar():
    """Modo portable, servidor RPC y pantallas colocadas en los huecos del layout."""
    exe = azahar_exe()
    cfg = exe.parent / 'user' / 'config' / 'qt-config.ini'
    cfg.parent.mkdir(parents=True, exist_ok=True)
    ini = configparser.RawConfigParser()
    ini.optionxform = str
    if cfg.exists():
        ini.read(cfg, encoding='utf-8')

    def poner(grupo, clave, valor):
        if not ini.has_section(grupo):
            ini.add_section(grupo)
        ini.set(grupo, clave + '\\default', 'false')
        ini.set(grupo, clave, str(valor))

    poner('Debugging', 'enable_rpc_server', 'true')
    poner('Layout', 'layout_option', 6)                  # LayoutOption::CustomLayout
    s, ox, oy = encaje()
    for nombre, (x, y, w, h) in (('top', HUECO_ARRIBA), ('bottom', HUECO_ABAJO)):
        poner('Layout', f'custom_{nombre}_x', ox + round(x * s))
        poner('Layout', f'custom_{nombre}_y', oy + round(y * s))
        poner('Layout', f'custom_{nombre}_width', round(w * s))
        poner('Layout', f'custom_{nombre}_height', round(h * s))
    with open(cfg, 'w', encoding='utf-8') as f:
        ini.write(f, space_around_delimiters=False)
    return exe


def carpeta_mods():
    return azahar_exe().parent / 'user' / 'load' / 'mods'


def correr(args, cwd):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, creationflags=0x08000000)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip()[-1500:])
    return r.stdout


def makerom_exe():
    return next((TOOLS / 'makerom').rglob('makerom.exe'), None) if (TOOLS / 'makerom').exists() else None


def rom_jugable(j):
    """La ROM que abren el randomizador y Azahar. Un .cia se convierte una vez a .cci (makerom) dentro de
    datos/juegos/<id>/; el .cia original no se toca. Solo vale si el .cia está descifrado."""
    if not j['ruta'].lower().endswith('.cia'):
        return j['ruta']
    cci = DATOS / 'juegos' / j['id'] / 'rom.cci'
    if cci.exists() and cci.stat().st_mtime >= Path(j['ruta']).stat().st_mtime:
        return str(cci)
    if not makerom_exe():
        descargar('3DSGuy/Project_CTR', r'makerom-v[\d.]+-win_x86_64\.zip', TOOLS / 'makerom', 'makerom')
    tarea('Convirtiendo el .cia a .cci…', paso=1)
    cci.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run([str(makerom_exe()), '-ciatocci', j['ruta'], '-o', str(cci)],
                       capture_output=True, text=True, creationflags=0x08000000)
    if r.returncode != 0 or not cci.exists():
        cci.unlink(missing_ok=True)
        if 'decrypt' in (r.stdout + r.stderr).lower():
            raise RuntimeError('Este .cia está cifrado y no se puede usar. Descífralo en tu 3DS con GodMode9 '
                               '(«Build decrypted .3ds» o «Decrypt file») y añade el archivo descifrado.')
        raise RuntimeError('No se ha podido convertir el .cia: ' + (r.stderr or r.stdout).strip()[-500:])
    return str(cci)


def randomizar(j, opciones, avanzado):
    jar, jv = upr_jar(), java()
    carpeta = DATOS / 'juegos' / j['id']
    carpeta.mkdir(parents=True, exist_ok=True)
    ajustes = DATOS / 'avanzado.rnqs' if avanzado else carpeta / 'ajustes.rnqs'
    if avanzado:
        if not ajustes.exists():
            raise RuntimeError('Guarda antes los ajustes del UPR completo en datos/avanzado.rnqs')
    else:
        malas = set(opciones) - OPCIONES
        if malas:
            raise RuntimeError(f'Opciones desconocidas: {malas}')
        tarea('Preparando los ajustes…', paso=2)
        correr([jv, '-cp', str(jar), str(APP / 'LockeSettings.java'), str(ajustes)]
               + [f'{k}={v}' for k, v in opciones.items()], jar.parent)
    salida = TOOLS / 'salida'
    shutil.rmtree(salida, ignore_errors=True)
    salida.mkdir(parents=True)
    tarea('Randomizando el juego… (puede tardar un par de minutos)', paso=2)
    correr([jv, '-jar', str(jar), 'cli', '-i', rom_jugable(j), '-o', str(salida / 'y'),
            '-s', str(ajustes), '-d', '-l'], jar.parent)
    romfs = next(salida.rglob('romfs'))
    titulo = romfs.parent.name if re.fullmatch(r'[0-9A-Fa-f]{16}', romfs.parent.name) else TITLE_Y
    mod = carpeta / 'mod'
    shutil.rmtree(mod, ignore_errors=True)
    shutil.copytree(romfs.parent, mod / titulo)
    for log in salida.rglob('*.log'):
        shutil.copy(log, carpeta / 'randomizacion.log')
    shutil.rmtree(salida, ignore_errors=True)
    j['random'] = {'avanzado': avanzado, 'opciones': opciones, 'fecha': time.strftime('%Y-%m-%d %H:%M')}


def lanzar(j):
    """Pone el mod del juego (o ninguno), abre Azahar a pantalla completa y la capa del layout encima."""
    if jugando():
        raise RuntimeError('Ya hay un juego abierto')
    if not Path(j['ruta']).exists():
        raise RuntimeError(f'No encuentro la ROM: {j["ruta"]}')
    exe = configurar_azahar()
    mods = carpeta_mods()
    shutil.rmtree(mods, ignore_errors=True)
    mods.mkdir(parents=True)
    mod = DATOS / 'juegos' / j['id'] / 'mod'
    if j.get('random') and mod.exists():
        shutil.copytree(mod, mods, dirs_exist_ok=True)
    vivo.update(activo=j['id'], equipo=[None] * 6, conectado=False)
    vivo['proceso'] = subprocess.Popen([str(exe), '-f', rom_jugable(j)])
    yo = [sys.executable] if getattr(sys, 'frozen', False) else [sys.executable, str(Path(__file__))]
    subprocess.Popen(yo + ['--capa'])
    renderizar_capa()


def en_segundo_plano(nombre, fn, *args, minimo=0):
    """minimo: segundos que como poco dura el modal de carga (la ventana anima la barra con ese tiempo)."""
    if vivo['tarea'] and not vivo['tarea']['fin']:
        raise RuntimeError('Ya hay una tarea en marcha')

    def envoltura():
        try:
            fn(*args)
            tarea(f'{nombre}: hecho.', fin=True)
        except Exception as e:
            traceback.print_exc()
            tarea(f'{nombre}: {e}', error=True, fin=True)
    vivo['tarea'] = {'inicio': time.time(), 'minimo': minimo}
    tarea(f'{nombre}…', paso=1)
    threading.Thread(target=envoltura, daemon=True).start()


def preparar(j, opciones, vidas_ini, randomizar_juego, avanzado):
    vivo['tarea']['random'] = randomizar_juego
    tarea('Preparando el emulador y el randomizador…', paso=1)
    herramientas()
    if randomizar_juego:
        randomizar(j, opciones, avanzado)
    else:
        j['random'] = None
    with lock:
        nuevo_locke(j, vidas_ini)
        j['preparado'] = True
        guardar()
    espera = vivo['tarea']['minimo'] - (time.time() - vivo['tarea']['inicio'])
    if espera > 0:                                    # el modal de carga dura como poco su minuto
        time.sleep(espera)
    tarea('Abriendo el juego con el layout…', paso=3)
    lanzar(j)


# ---------- seguimiento del locke ----------

def curado_en_centro(antes, ahora):
    """En un Centro Pokémon se cura todo el equipo de golpe: dos o más Pokémon vivos pasan a la vez de
    estar heridos a tener los PS al máximo (una poción cura de uno en uno). Con un solo Pokémon vivo basta él."""
    previos = {p['id']: p for p in antes if p}
    vivos = [p for p in ahora if p and not p['huevo'] and p['ps'] > 0]
    sanados = [p for p in vivos if p['id'] in previos and previos[p['id']]['ps'] < p['psmax'] == p['ps']]
    return len(sanados) >= min(2, len(vivos)) and len(sanados) > 0 and all(p['ps'] == p['psmax'] for p in vivos)


def seguimiento():
    rpc = juego.RPC()
    while True:
        if jugando():
            try:
                equipo = juego.leer_equipo(rpc)
                with lock:
                    vivo['conectado'] = True
                    antes, vivo['equipo'] = vivo['equipo'], equipo
                    j = buscar(vivo['activo'])
                    # el vial se recarga al curarse en un Centro (no cuenta la cura del propio vial)
                    if not j.get('vial', True) and time.time() - vivo.get('vial_usado', 0) > 5 \
                            and curado_en_centro(antes, equipo):
                        j['vial'] = True
                        guardar()
                    for p in equipo:
                        # un Pokémon a 0 PS cuenta como muerto una sola vez, aunque luego lo revivan
                        if p and not p['huevo'] and p['psmax'] and p['ps'] == 0 and p['id'] not in j['muertos']:
                            j['muertos'].append(p['id'])
                            guardar()
            except (OSError, TimeoutError, RuntimeError):
                vivo['conectado'] = False
        else:
            vivo['conectado'] = False
        time.sleep(1)


def corregir(atajo):
    """F7 −1 vida, F8 +1 vida, F9 marca la siguiente medalla, Mayús+F9 desmarca la última."""
    with lock:
        j = buscar(vivo['activo'])
        if atajo == 'menos':
            j['ajuste_vidas'] -= 1
        elif atajo == 'mas':
            j['ajuste_vidas'] += 1
        elif atajo == 'medalla' and False in j['medallas']:
            j['medallas'][j['medallas'].index(False)] = True
        elif atajo == 'recargar_vial':
            j['vial'] = True
        elif atajo == 'quitar_medalla' and True in j['medallas']:
            j['medallas'][len(j['medallas']) - 1 - j['medallas'][::-1].index(True)] = False
        guardar()


def atajos():
    """Atajos globales de Windows, registrados solo mientras hay un juego abierto."""
    import ctypes.wintypes as wt
    u = ctypes.windll.user32
    TECLAS = {1: (0, 0x76, 'menos'), 2: (0, 0x77, 'mas'), 3: (0, 0x78, 'medalla'),
              4: (0x0004, 0x78, 'quitar_medalla')}           # 0x76..0x78 = F7..F9, 0x0004 = Mayús
    # el vial va con la E (Azahar no la usa; la V es su botón de encendido). Solo se captura con el
    # juego delante, para que en el resto de programas la E se siga escribiendo
    VIAL = {5: (0, 0x45, 'vial'), 6: (0x0004, 0x45, 'recargar_vial')}
    MOD_NOREPEAT, WM_HOTKEY, PM_REMOVE = 0x4000, 0x0312, 1
    registrados = vial_registrado = False
    msg = wt.MSG()
    pid = wt.DWORD()

    def juego_delante():
        u.GetWindowThreadProcessId(u.GetForegroundWindow(), ctypes.byref(pid))
        p = vivo['proceso']
        return p is not None and pid.value == p.pid

    while True:
        if jugando() and not registrados:
            for i, (mod, tecla, _) in TECLAS.items():
                u.RegisterHotKey(None, i, mod | MOD_NOREPEAT, tecla)
            registrados = True
        elif not jugando() and registrados:
            for i in TECLAS:
                u.UnregisterHotKey(None, i)
            registrados = False
        delante = jugando() and juego_delante()
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
        time.sleep(0.05)


def usar_vial():
    """E: si el vial está cargado, cura a todo el equipo vivo y se gasta hasta el próximo Centro Pokémon."""
    with lock:
        j = buscar(vivo['activo'])
        if not j.get('vial', True):
            return
    if juego.curar_equipo(juego.RPC(espera=1.0)):
        with lock:
            j['vial'] = False
            vivo['vial_usado'] = time.time()
            guardar()


def huella_capa():
    """Lo que se ve en la capa: si cambia, hay que volver a pintarla."""
    e = foto_estado()
    a = e['activo']
    # también el fanart de cada carta (ruta y fecha): pegar o cambiar uno se ve al momento
    artes = []
    for p in e['equipo']:
        try:
            f = arte(p['especie']) if p and not p['huevo'] else None
            artes.append(f and [str(f), f.stat().st_mtime])
        except OSError:
            artes.append(None)
    return json.dumps([a and [a['vidas'], a['vidas_iniciales'], a['medallas'], a['vial']], e['equipo'], artes],
                      sort_keys=True)


def renderizar_capa():
    """Pinta /overlay?capa=1 a la resolución del monitor con el navegador sin ventana."""
    nav = navegador()
    if not nav:
        return
    s, _, _ = encaje()
    CAPA_PNG.parent.mkdir(exist_ok=True)
    tmp = TOOLS / 'capa-nueva.png'
    subprocess.run([nav, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                    f'--user-data-dir={TOOLS / "edge-capa"}', f'--force-device-scale-factor={s}',
                    f'--window-size={round(1920 * s)},{round(1080 * s)}', '--virtual-time-budget=4000',
                    f'--screenshot={tmp}', f'{URL}/overlay?capa=1'],
                   capture_output=True, creationflags=0x08000000, timeout=60)
    if tmp.exists():
        tmp.replace(CAPA_PNG)
        vivo['capa'] += 1


def pintor_capa():
    ultima = None
    while True:
        if jugando():
            huella = huella_capa()
            if huella != ultima:
                ultima = huella
                try:
                    renderizar_capa()
                except Exception:
                    traceback.print_exc()
        else:
            ultima = None
        time.sleep(1)


def foto_estado():
    with lock:
        activo = None
        if vivo['activo'] and any(j['id'] == vivo['activo'] for j in biblio['juegos']):
            j = buscar(vivo['activo'])
            activo = {'id': j['id'], 'nombre': j['nombre'], 'vidas': vidas(j),
                      'vidas_iniciales': j['vidas_iniciales'] + j['ajuste_vidas'], 'medallas': j['medallas'],
                      'vial': j.get('vial', True)}
            muertos = j['muertos']
        else:
            muertos = []
        return {
            'juegos': [{'id': j['id'], 'nombre': j['nombre'], 'ruta': j['ruta'], 'preparado': j.get('preparado', False),
                        'random': j.get('random'), 'vidas': vidas(j) if j.get('preparado') else None,
                        'vidas_iniciales': j.get('vidas_iniciales'), 'medallas': sum(j.get('medallas', [])),
                        'registro': (DATOS / 'juegos' / j['id'] / 'randomizacion.log').exists()}
                       for j in biblio['juegos']],
            'activo': activo, 'jugando': jugando(), 'conectado': vivo['conectado'], 'tarea': vivo['tarea'] and {**vivo['tarea'], 'transcurrido': time.time() - vivo['tarea']['inicio']},
            'equipo': [p and {**p, 'muerto': p['id'] in muertos} for p in vivo['equipo']],
            'capa': vivo['capa'], 'encaje': encaje() if os.name == 'nt' else (1, 0, 0),
            'avanzado': (DATOS / 'avanzado.rnqs').exists(),
        }


def arte(especie):
    """Fanart propio si existe (fanart/658.png|jpg|webp, o cualquier imagen dentro de la carpeta
    fanart/658 Greninja/); si no, el arte oficial, guardado en caché."""
    exts = ('png', 'jpg', 'jpeg', 'webp')
    for ext in exts:
        f = FANART / f'{especie}.{ext}'
        if f.exists():
            return f
    if FANART.exists():
        for carpeta in FANART.iterdir():
            n = carpeta.name.split(' ', 1)[0]
            if carpeta.is_dir() and n.isdigit() and int(n) == especie:
                fotos = sorted(f for f in carpeta.iterdir() if f.suffix.lower().lstrip('.') in exts)
                if fotos:
                    return fotos[0]
    f = CACHE_ARTE / f'{especie}.png'
    if not f.exists():
        CACHE_ARTE.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(ARTE_URL.format(especie), f)
    return f


def elegir_rom():
    """Explorador de archivos de Windows para elegir la ROM."""
    resultado = []

    def dialogo():
        import tkinter as tk
        from tkinter import filedialog
        raiz = tk.Tk()
        raiz.withdraw()
        raiz.attributes('-topmost', True)
        resultado.append(filedialog.askopenfilename(
            parent=raiz, title='Añadir juego: elige la ROM descifrada de Pokémon Y',
            filetypes=[('Juegos de 3DS', '*.3ds *.cci *.cxi *.cia'), ('Todos los archivos', '*.*')]))
        raiz.destroy()
    hilo = threading.Thread(target=dialogo)
    hilo.start()
    hilo.join()
    return resultado[0] if resultado else ''


# ---------- servidor ----------

TIPOS = {'.html': 'text/html; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg',
         '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.js': 'text/javascript', '.css': 'text/css'}


class Servidor(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def enviar(self, cuerpo, tipo='application/json', codigo=200):
        if isinstance(cuerpo, (dict, list)):
            cuerpo = json.dumps(cuerpo, ensure_ascii=False).encode()
        self.send_response(codigo)
        self.send_header('Content-Type', tipo)
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(cuerpo)

    def archivo(self, f):
        if not f.is_file():
            return self.enviar({'error': 'no existe'}, codigo=404)
        self.enviar(f.read_bytes(), TIPOS.get(f.suffix.lower(), 'application/octet-stream'))

    def do_GET(self):
        ruta = self.path.split('?')[0]
        if ruta == '/':
            return self.archivo(WEB / 'app.html')
        if ruta == '/overlay':
            return self.archivo(WEB / 'overlay.html')
        if ruta == '/capa.png':
            return self.archivo(CAPA_PNG)
        if ruta == '/api/estado':
            return self.enviar(foto_estado())
        if m := re.fullmatch(r'/arte/(\d{1,3})', ruta):
            try:
                return self.archivo(arte(int(m[1])))
            except OSError:
                return self.enviar({'error': 'sin arte'}, codigo=404)
        if m := re.fullmatch(r'/assets/([\w.-]+)', ruta):
            return self.archivo(ASSETS / m[1])
        self.enviar({'error': 'no existe'}, codigo=404)

    def do_POST(self):
        largo = int(self.headers.get('Content-Length') or 0)
        datos = json.loads(self.rfile.read(largo) or b'{}')
        try:
            respuesta = self.accion(self.path, datos)
            self.enviar(respuesta or {'ok': True})
        except Exception as e:
            self.enviar({'error': str(e)}, codigo=400)

    def accion(self, ruta, d):
        if ruta == '/api/anadir':
            rom = elegir_rom()
            if not rom:
                return {'ok': False}
            with lock:
                ruta_rom = str(Path(rom))
                if any(j['ruta'] == ruta_rom for j in biblio['juegos']):
                    raise RuntimeError('Ese juego ya está en la biblioteca')
                biblio['juegos'].append({'id': hashlib.sha1(ruta_rom.encode()).hexdigest()[:10],
                                         'nombre': Path(rom).stem, 'ruta': ruta_rom, 'preparado': False,
                                         'random': None, 'vidas_iniciales': 25, 'ajuste_vidas': 0,
                                         'muertos': [], 'medallas': [False] * 8})
                guardar()
        elif ruta == '/api/quitar':
            with lock:
                biblio['juegos'] = [j for j in biblio['juegos'] if j['id'] != d['id']]
                shutil.rmtree(DATOS / 'juegos' / d['id'], ignore_errors=True)
                guardar()
        elif ruta == '/api/reiniciar':          # vuelve a pedir vidas y randomización al jugar
            with lock:
                buscar(d['id'])['preparado'] = False
                guardar()
        elif ruta == '/api/registro':
            log = DATOS / 'juegos' / d['id'] / 'randomizacion.log'
            if not log.exists():
                raise RuntimeError('Este juego no tiene registro: no se ha randomizado')
            os.startfile(log)
        elif ruta == '/api/preparar':
            j = buscar(d['id'])
            en_segundo_plano('Preparar el juego', preparar, j, d.get('opciones', {}), d.get('vidas', 25),
                             bool(d.get('randomizar')), bool(d.get('avanzado')), minimo=60)
        elif ruta == '/api/jugar':
            j = buscar(d['id'])
            en_segundo_plano('Abrir el juego', lambda: (herramientas(), lanzar(j)))
        elif ruta == '/api/upr_completo':
            en_segundo_plano('Abrir el randomizador completo', lambda: (
                herramientas(), DATOS.mkdir(exist_ok=True),
                subprocess.Popen([java(), '-jar', str(upr_jar())], cwd=upr_jar().parent)))
        elif ruta == '/api/medalla':
            with lock:
                buscar(vivo['activo'])['medallas'][int(d['i'])] = bool(d['valor'])
                guardar()
        elif ruta == '/api/vidas':
            with lock:
                buscar(vivo['activo'])['ajuste_vidas'] += int(d['delta'])
                guardar()
        else:
            raise RuntimeError('Acción desconocida')


# ---------- capa del layout encima de Azahar ----------

def capa():
    """Ventana sin bordes, siempre delante, con los huecos (color clave) transparentes y sin coger
    el foco: se ve y se toca el juego a través de ella y el teclado sigue en Azahar."""
    import tkinter as tk
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
    w, h = pantalla()
    s, ox, oy = encaje()
    raiz = tk.Tk()
    raiz.overrideredirect(True)
    raiz.geometry(f'{w}x{h}+0+0')
    raiz.configure(bg=CLAVE)
    raiz.attributes('-topmost', True)
    raiz.attributes('-transparentcolor', CLAVE)
    etiqueta = tk.Label(raiz, bd=0, bg=CLAVE)
    etiqueta.place(x=ox, y=oy)
    raiz.update_idletasks()
    hwnd = ctypes.windll.user32.GetParent(raiz.winfo_id())
    GWL_EXSTYLE, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW = -20, 0x08000000, 0x00000080
    estilo = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, estilo | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW)
    vista = {'version': -1, 'imagen': None, 'arrancado': time.time()}

    def refrescar():
        try:
            with urllib.request.urlopen(f'{URL}/api/estado', timeout=2) as r:
                e = json.load(r)
        except OSError:
            return raiz.destroy()
        if not e['jugando'] and time.time() - vista['arrancado'] > 15:
            return raiz.destroy()
        if e['capa'] != vista['version'] and CAPA_PNG.exists():
            vista['version'] = e['capa']
            vista['imagen'] = tk.PhotoImage(file=str(CAPA_PNG))
            etiqueta.configure(image=vista['imagen'])
        raiz.attributes('-topmost', True)
        raiz.after(1000, refrescar)

    refrescar()
    raiz.mainloop()


def abrir_ventana_app():
    nav = navegador()
    url = f'{URL}/'
    if nav:
        subprocess.Popen([nav, f'--app={url}', f'--user-data-dir={TOOLS / "edge-perfil"}',
                          '--window-size=1280,820', '--no-first-run'])
    else:
        import webbrowser
        webbrowser.open(url)


def main():
    if os.name == 'nt':
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    if '--capa' in sys.argv:
        return capa()
    for carpeta in (TOOLS, DATOS, FANART):
        carpeta.mkdir(exist_ok=True)
    cargar()
    try:
        servidor = ThreadingHTTPServer(('127.0.0.1', PUERTO), Servidor)
    except OSError:                       # ya está abierto: solo enseña la ventana
        return abrir_ventana_app()
    threading.Thread(target=seguimiento, daemon=True).start()
    threading.Thread(target=pintor_capa, daemon=True).start()
    if os.name == 'nt':
        threading.Thread(target=atajos, daemon=True).start()
    print(f'Pokelocke en {URL}  ·  overlay para OBS: {URL}/overlay')
    if '--sin-ventana' not in sys.argv:       # --sin-ventana: solo el servidor (pruebas u OBS)
        abrir_ventana_app()
    servidor.serve_forever()


if __name__ == '__main__':
    main()
