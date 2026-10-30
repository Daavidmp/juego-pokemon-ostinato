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
import online
import pokehex

# Adoptium (la descarga de Java) responde 403 a «Python-urllib», el nombre que urllib pone por defecto
_opener = urllib.request.build_opener()
_opener.addheaders = [('User-Agent', 'Pokelocke')]
urllib.request.install_opener(_opener)

# El .exe (instalado con PokelockeSetup.exe en %LOCALAPPDATA%\Pokelocke, o el de desarrollo dentro de locke-y/)
# usa las carpetas de al lado: tools/ con Citra y el randomizador, datos/ con las partidas y fanart/.
# Lo que va dentro de PyInstaller (web, assets, vídeo, guía) está en su carpeta _internal.
if getattr(sys, 'frozen', False):
    RECURSOS = Path(sys._MEIPASS)
    RAIZ = Path(sys.executable).resolve().parent
else:
    RAIZ = RECURSOS = Path(__file__).resolve().parent.parent
APP, WEB, ASSETS = RECURSOS / 'app', RECURSOS / 'app' / 'web', RECURSOS / 'assets'
NORMAS, GUIA_PDF, VIDEO = RECURSOS / 'normas', RECURSOS / 'guia' / 'Guia-Mega-Pokelocke-Y.pdf', RECURSOS / 'video' / 'normas.mp4'
TOOLS, DATOS, FANART = RAIZ / 'tools', RAIZ / 'datos', RAIZ / 'fanart'
CACHE_ARTE = TOOLS / 'arte'
CAPA_PNG = TOOLS / 'capa.png'
BIBLIOTECA = DATOS / 'biblioteca.json'
PUERTO = int(os.environ.get('POKELOCKE_PUERTO') or 8765)
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
        'proceso': None, 'capa': 0, 'aviso': None}           # no se guarda en disco


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
    if jugando():
        raise RuntimeError('Cierra el juego para coger el huevo: si no, el juego lo borraría al guardar')
    h = j['huevos'][i]
    if h['cogido']:
        raise RuntimeError('Ese huevo ya lo has cogido')
    if not huevos_disponibles(j):
        raise RuntimeError(f'Puedes coger un huevo cada {MEDALLAS_POR_HUEVO} medallas')
    try:
        partida = pokehex.Partida(pokehex_partida(j))
    except ValueError as e:
        raise RuntimeError(str(e))
    if j['id'] not in hex_vivo['datos']:
        hex_vivo['datos'][j['id']] = pokehex.Datos(TOOLS, DATOS / 'juegos' / j['id'] / 'randomizacion.log')
    try:
        lugar = partida.meter(pokehex.nuevo_huevo(partida.claro(0), h['especie'], h['shiny'], hex_vivo['datos'][j['id']]),
                              hex_vivo['datos'][j['id']])
    except ValueError as e:
        raise RuntimeError(str(e))
    partida.guardar(DATOS / 'juegos' / j['id'] / 'copias_partida')
    h['cogido'] = True
    guardar()
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
    log = DATOS / 'juegos' / j['id'] / 'randomizacion.log'
    if not j.get('random') or not log.exists():
        return TOPES_ORIGINALES
    clave = (str(log), log.stat().st_mtime)
    if vivo.get('topes_de') != clave:
        topes = dict.fromkeys(LIDERES_Y)
        en_entrenadores = False
        for linea in log.read_text(encoding='utf-8', errors='ignore').splitlines():
            if linea.startswith('--'):
                en_entrenadores = linea.startswith('--Trainers Pokemon')
            m = en_entrenadores and re.match(r'#(\d+) \(', linea)
            if m and int(m[1]) in topes:
                topes[int(m[1])] = max(map(int, re.findall(r'Lv(\d+)', linea)), default=None)
        vivo['topes_de'], vivo['topes'] = clave, [topes[i] or TOPES_ORIGINALES[k] for k, i in enumerate(LIDERES_Y)]
    return vivo['topes']


def medallas_partida(j):
    try:
        datos = pokehex_partida(j).read_bytes()
    except (RuntimeError, OSError):
        return 0
    return bin(datos[MEDALLAS_EN_PARTIDA]).count('1') if len(datos) == pokehex.TAM_PARTIDA else 0


def abrir_fase_completa(j):
    """Con el juego cerrado: la randomización completa pasa a ser el mod del juego."""
    carpeta = DATOS / 'juegos' / j['id']
    if not (carpeta / MOD_COMPLETO).exists():
        return False
    shutil.rmtree(carpeta / 'mod', ignore_errors=True)
    (carpeta / MOD_COMPLETO).rename(carpeta / 'mod')
    j['fase'] = 2
    guardar()
    return True


def dar_caramelos(j):
    """Con el juego cerrado: rellena los Caramelos Raros de la mochila hasta 999, mientras no se hayan dado
    los 10000. Sin partida guardada todavía no hace nada (se dan la siguiente vez que se abra el juego)."""
    if j.get('reglas') != 'mega' or j.get('caramelos_dados', 0) >= CARAMELOS_MEGA:
        return
    try:
        partida = pokehex.Partida(pokehex_partida(j))
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
    partida.guardar(DATOS / 'juegos' / j['id'] / 'copias_partida')
    j['caramelos_dados'] = j.get('caramelos_dados', 0) + dar
    guardar()


def vidas(j):
    return max(0, j['vidas_iniciales'] + j['ajuste_vidas'] - len(j['muertos']))


def jugando():
    p = vivo['proceso']
    return p is not None and p.poll() is None


# este Citra se cae (0xc0000005 en citra-qt.exe+0x165ae7) si le llega una petición RPC mientras aún está
# cargando el juego. Un tiempo fijo no vale: en un PC lento (o con el antivirus mirando cada archivo) la carga
# dura más y se caía igual. Se espera a que salga la ventana del juego (la misma señal que usa el lanzador para
# quitarle los bordes) y luego MARGEN_RPC más. Si esa ventana no se ve nunca, se pregunta a los ESPERA_MAX segundos.
# Con Azahar (la copia de desarrollo, una sola ventana) se sigue esperando ESPERA_AZAHAR.
# Mientras tanto la capa enseña un cartel de «Abriendo el juego» en vez del layout (ver capa()), hasta que sale la
# ventana del juego o pasan CAPA_MAX segundos.
MARGEN_RPC, ESPERA_MAX, ESPERA_AZAHAR, CAPA_MAX = 8, 60, 15, 120


def ventanas_citra():
    """Cuántas ventanas visibles y con título tiene citra-qt.exe. Con el juego cargado son dos: la lista de
    juegos y la del juego."""
    import ctypes.wintypes as wt
    u, k32, pid, n = ctypes.windll.user32, ctypes.windll.kernel32, wt.DWORD(), [0]

    def mirar(h, _):
        if u.IsWindowVisible(h) and u.GetWindowTextLengthW(h) > 0:
            u.GetWindowThreadProcessId(h, ctypes.byref(pid))
            p = k32.OpenProcess(0x1000, False, pid.value)          # PROCESS_QUERY_LIMITED_INFORMATION
            if p:
                ruta, largo = ctypes.create_unicode_buffer(1024), wt.DWORD(1024)
                if k32.QueryFullProcessImageNameW(p, 0, ruta, ctypes.byref(largo)) and ruta.value.lower().endswith('citra-qt.exe'):
                    n[0] += 1
                k32.CloseHandle(p)
        return True
    u.EnumWindows(ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)(mirar), 0)
    return n[0]


def citra_listo():
    if not jugando():
        return False
    ahora = time.time()
    if not vivo.get('citra'):
        return ahora - vivo.get('lanzado', 0) > ESPERA_AZAHAR
    if not vivo.get('juego_visto'):
        if ahora - vivo.get('lanzado', 0) > ESPERA_MAX:
            vivo['juego_visto'] = ahora - MARGEN_RPC
        elif os.name == 'nt' and ahora - vivo.get('mirado', 0) >= 1:       # se mira como mucho una vez por segundo
            vivo['mirado'] = ahora
            if ventanas_citra() >= 2:
                vivo['juego_visto'], vivo['ventana_juego'] = ahora, True
                print(time.strftime('%H:%M:%S'), f'ventana del juego a los {ahora - vivo["lanzado"]:.0f} s', flush=True)
    return bool(vivo.get('juego_visto')) and ahora - vivo['juego_visto'] > MARGEN_RPC


# ---------- herramientas portables ----------

# lo que trae el instalador (app/empaquetar.py): un Java mínimo hecho con jlink y LockeSettings y MegaFases ya
# compilados en un .jar, así que no hace falta instalar ni descargar Java
JAVA_INCLUIDO = TOOLS / 'java' / 'runtime' / 'bin' / 'java.exe'
CLASES_POKELOCKE = TOOLS / 'upr' / 'pokelocke-upr.jar'


def java():
    if JAVA_INCLUIDO.exists() and CLASES_POKELOCKE.exists():
        return str(JAVA_INCLUIDO)
    candidatos = []
    if os.environ.get('JAVA_HOME'):
        candidatos.append(Path(os.environ['JAVA_HOME']) / 'bin' / 'java.exe')
    candidatos += sorted((Path.home() / '.jdks').glob('*/bin/java.exe'), reverse=True)
    candidatos += sorted((TOOLS / 'java').glob('*/bin/java.exe'), reverse=True)   # el que descarga la app
    en_path = shutil.which('java')
    if en_path:
        candidatos.append(Path(en_path))
    # sin el .jar compilado (la copia de desarrollo) solo vale un JDK, con javac al lado: un JRE no puede
    # ejecutar LockeSettings.java como fuente
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


def firefox():
    for base in (os.environ.get('ProgramFiles'), os.environ.get('ProgramFiles(x86)'), os.environ.get('LOCALAPPDATA')):
        if base and (Path(base) / 'Mozilla Firefox' / 'firefox.exe').exists():
            return str(Path(base) / 'Mozilla Firefox' / 'firefox.exe')
    return None


def perfil_firefox(nombre, prefs, css=''):
    """Perfil propio de Firefox para Pokelocke (no toca el del usuario). Las preferencias se reescriben siempre."""
    p = TOOLS / nombre
    (p / 'chrome').mkdir(parents=True, exist_ok=True)
    prefs = {'browser.shell.checkDefaultBrowser': False, 'browser.aboutwelcome.enabled': False,
             'datareporting.policy.dataSubmissionPolicyBypassNotification': True,
             'browser.startup.homepage_override.mstone': 'ignore', 'browser.tabs.warnOnClose': False, **prefs}
    (p / 'user.js').write_text(''.join(f'user_pref({json.dumps(k)}, {json.dumps(v)});\n' for k, v in prefs.items()),
                               encoding='utf-8')
    (p / 'chrome' / 'userChrome.css').write_text(css, encoding='utf-8')
    return str(p)


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
    # online: «Multijugador > Conectar directamente a una sala» ya relleno con el servidor y tu usuario
    if red['sesion'] and online_direccion():
        poner('Multiplayer', 'nickname', red['sesion']['usuario'])
        poner('Multiplayer', 'ip', online_direccion())          # el anfitrión, a sí mismo
        poner('Multiplayer', 'port', online.PUERTO_SALA)
    poner('Layout', 'layout_option', 6)                  # LayoutOption::CustomLayout
    # Citra 1920 no tiene la opción 6 (el lanzador la pasa a 0): usa custom_layout con izquierda/arriba/derecha/abajo
    poner('Layout', 'custom_layout', 'true')
    s, ox, oy = encaje()
    for nombre, (x, y, w, h) in (('top', HUECO_ARRIBA), ('bottom', HUECO_ABAJO)):
        poner('Layout', f'custom_{nombre}_x', ox + round(x * s))
        poner('Layout', f'custom_{nombre}_y', oy + round(y * s))
        poner('Layout', f'custom_{nombre}_width', round(w * s))
        poner('Layout', f'custom_{nombre}_height', round(h * s))
        poner('Layout', f'custom_{nombre}_left', ox + round(x * s))
        poner('Layout', f'custom_{nombre}_top', oy + round(y * s))
        poner('Layout', f'custom_{nombre}_right', ox + round((x + w) * s))
        poner('Layout', f'custom_{nombre}_bottom', oy + round((y + h) * s))
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


def clase_pokelocke(jar, nombre):
    """Los argumentos de java para LockeSettings o MegaFases: la clase compilada del instalador o, en la copia de
    desarrollo, el .java como fuente (con un JDK)."""
    if CLASES_POKELOCKE.exists():
        return ['-cp', f'{jar}{os.pathsep}{CLASES_POKELOCKE}', nombre]
    return ['-cp', str(jar), str(APP / f'{nombre}.java')]


def randomizar(j, opciones, avanzado, reglas=None):
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
        correr([jv, *clase_pokelocke(jar, 'LockeSettings'), str(ajustes)]
               + [f'{k}={v}' for k, v in opciones.items()], jar.parent)
    salida = TOOLS / 'salida'
    shutil.rmtree(salida, ignore_errors=True)
    salida.mkdir(parents=True)
    tarea('Randomizando el juego… (puede tardar un par de minutos)', paso=2)
    if reglas == 'mega':
        # una randomización y dos juegos: la fase fácil (hasta la segunda medalla) va de mod y la completa se
        # guarda aparte para cuando se gane la segunda medalla
        correr([jv, '-Xmx4096M', *clase_pokelocke(jar, 'MegaFases'), rom_jugable(j), str(ajustes),
                str(salida / 'completa'), str(salida / 'facil'), str(salida / 'y.log')], jar.parent)
        versiones = {'mod': salida / 'facil', MOD_COMPLETO: salida / 'completa'}
    else:
        correr([jv, '-jar', str(jar), 'cli', '-i', rom_jugable(j), '-o', str(salida / 'y'),
                '-s', str(ajustes), '-d', '-l'], jar.parent)
        versiones = {'mod': salida}
    shutil.rmtree(carpeta / MOD_COMPLETO, ignore_errors=True)
    for nombre, origen in versiones.items():
        romfs = next(origen.rglob('romfs'))
        titulo = romfs.parent.name if re.fullmatch(r'[0-9A-Fa-f]{16}', romfs.parent.name) else TITLE_Y
        mod = carpeta / nombre
        shutil.rmtree(mod, ignore_errors=True)
        shutil.copytree(romfs.parent, mod / titulo)
    for log in salida.rglob('*.log'):
        shutil.copy(log, carpeta / 'randomizacion.log')
    shutil.rmtree(salida, ignore_errors=True)
    j['random'] = {'avanzado': avanzado, 'opciones': opciones, 'fecha': time.strftime('%Y-%m-%d %H:%M')}


def citra_responde():
    """Hay una ventana visible de citra-qt que no está colgada («No responde»)."""
    import ctypes.wintypes as wt
    u, k32, pid, vista = ctypes.windll.user32, ctypes.windll.kernel32, wt.DWORD(), []

    def mirar(h, _):
        if u.IsWindowVisible(h) and not u.IsHungAppWindow(h):
            u.GetWindowThreadProcessId(h, ctypes.byref(pid))
            p = k32.OpenProcess(0x1000, False, pid.value)          # PROCESS_QUERY_LIMITED_INFORMATION
            if p:
                ruta, n = ctypes.create_unicode_buffer(1024), wt.DWORD(1024)
                if k32.QueryFullProcessImageNameW(p, 0, ruta, ctypes.byref(n)) and ruta.value.lower().endswith('citra-qt.exe'):
                    vista.append(h)
                k32.CloseHandle(p)
        return True
    u.EnumWindows(ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)(mirar), 0)
    return bool(vista)


def cerrar_citra_colgado():
    """Un Citra que se quedó de antes (colgado, o de un Pokelocke que se cerró) no deja abrir otro: se cierra.
    Si el juego está abierto y responde, no se toca."""
    if jugando() and citra_responde():
        raise RuntimeError('Ya hay un juego abierto')
    if os.name == 'nt':
        subprocess.run(['taskkill', '/F', '/T', '/IM', 'citra-qt.exe', '/IM', 'azahar.exe'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000)
    vivo['proceso'] = None


def lanzar(j):
    """Pone el mod del juego (o ninguno), abre Azahar a pantalla completa y la capa del layout encima."""
    print(time.strftime('%H:%M:%S'), 'abrir el juego', j['id'], flush=True)
    cerrar_citra_colgado()
    if not Path(j['ruta']).exists():
        raise RuntimeError(f'No encuentro la ROM: {j["ruta"]}')
    exe = configurar_azahar()
    with lock:
        dar_caramelos(j)
        completa = j.get('fase') == 1 and medallas_partida(j) >= MEDALLAS_PARA_COMPLETA and abrir_fase_completa(j)
    mods = carpeta_mods()
    shutil.rmtree(mods, ignore_errors=True)
    mods.mkdir(parents=True)
    mod = DATOS / 'juegos' / j['id'] / 'mod'
    if j.get('random') and mod.exists():
        shutil.copytree(mod, mods, dirs_exist_ok=True)
    vivo.update(activo=j['id'], equipo=[None] * 6, conectado=False, combate_visto_desde=None)
    vivo.update(lanzado=time.time(), juego_visto=None, mirado=0, ventana_juego=False,
                citra=(Path(exe).parent / 'citra-qt.exe').exists())
    vivo['proceso'] = subprocess.Popen([str(exe), '-f', rom_jugable(j)])
    if completa:
        avisar('¡Randomización completa! · Ahora los rivales sacan cualquier evolución y cualquier ataque', 25)
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


def preparar(j, opciones, vidas_ini, randomizar_juego, avanzado, reglas=None):
    if reglas == 'mega':
        vidas_ini = VIDAS_MEGA
    vivo['tarea']['random'] = randomizar_juego
    tarea('Preparando el emulador y el randomizador…', paso=1)
    herramientas()
    if randomizar_juego:
        randomizar(j, opciones, avanzado, reglas)
    else:
        j['random'] = None
    with lock:
        nuevo_locke(j, vidas_ini, reglas)
        j['preparado'] = True
        guardar()
    espera = vivo['tarea']['minimo'] - (time.time() - vivo['tarea']['inicio'])
    if espera > 0:                                    # el modal de carga dura como poco su minuto
        time.sleep(espera)
    tarea('Abriendo el juego con el layout…', paso=3)
    lanzar(j)


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
        if citra_listo():
            try:
                equipo = juego.leer_equipo(rpc)
                with lock:
                    if not vivo['conectado']:
                        vivo['conectado_desde'], vivo['a_cero'], vivo['curas_centro'] = time.time(), {}, None
                    vivo['conectado'] = True
                    # al entrar o salir de un combate el juego reescribe el equipo, y una lectura en ese momento
                    # no cuadra con su suma de comprobación: un hueco solo se da por vacío tras 3 lecturas seguidas
                    vacios = vivo.setdefault('vacios', [0] * 6)
                    for i, p in enumerate(equipo):
                        if p is None and vivo['equipo'][i] is not None and vacios[i] < 2:
                            vacios[i] += 1
                            equipo[i] = vivo['equipo'][i]
                        elif p is not None:
                            vacios[i] = 0
                    antes, vivo['equipo'] = vivo['equipo'], equipo
                    j = buscar(vivo['activo'])
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
                            avisar('¡Has llegado al fin de la primera parte del Mega Pokelocke! · '
                                   'Prepara tu equipo para el gran torneo', 20)
                        guardar()
                    # el vial se recarga cada vez que la enfermera de un Centro cura al equipo: sube su
                    # contador en los récords del juego. Si no se puede leer, se adivina por PS y PP
                    try:
                        curas = juego.curas_en_centro(rpc)
                    except (OSError, TimeoutError):
                        curas = None
                    previas, vivo['curas_centro'] = vivo.get('curas_centro'), curas
                    if curas is not None:
                        en_centro = previas is not None and curas > previas
                    else:
                        en_centro = time.time() - vivo.get('vial_usado', 0) > 5 and curado_en_centro(antes, equipo)
                    if not j.get('vial', True) and en_centro:
                        j['vial'] = True
                        avisar('Vial recargado en el Centro Pokémon')
                        guardar()
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
                        if combates and not vivo.get('combate_visto_desde'):
                            vivo['combate_visto_desde'] = time.time()
                        if combates and time.time() - vivo['combate_visto_desde'] > 3 \
                                and not vivo.get('en_combate') and not juego.en_combate(rpc):
                            j['muertes_activas'] = True
                            # unos segundos de margen: el contador sube al acabar el combate, a la vez que
                            # el equipo recibe los PS de la copia del combate
                            vivo['gracia_hasta'] = time.time() + 10
                            avisar('Primer combate superado · A partir de ahora cada muerte cuenta')
                            guardar()
                        cuentan = False
                    elif time.time() < vivo.get('gracia_hasta', 0):
                        cuentan = False
                    perdonados = j.setdefault('perdonados', [])
                    a_cero = vivo.setdefault('a_cero', {})
                    for p in equipo:
                        if not p or p['huevo'] or not p['psmax'] or p['ps'] != 0:
                            if p:
                                a_cero.pop(p['id'], None)
                                if p['ps'] and p['id'] in perdonados:
                                    perdonados.remove(p['id'])
                                    guardar()
                            continue
                        a_cero[p['id']] = a_cero.get(p['id'], 0) + 1
                        if a_cero[p['id']] >= 3 and time.time() - vivo.get('conectado_desde', 0) > 15 \
                                and p['id'] not in j['muertos'] and p['id'] not in perdonados:
                            (j['muertos'] if cuentan else perdonados).append(p['id'])
                            guardar()
            except (OSError, TimeoutError, RuntimeError):
                vivo['conectado'] = False
        else:
            vivo['conectado'] = False
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
        time.sleep(0.25)
        with lock:
            j = next((x for x in biblio['juegos'] if x['id'] == vivo['activo']), None) if citra_listo() else None
            if j and j.get('reglas') != 'mega':
                j = None
            if not j:
                # juego cerrado: si las Balls estaban escondidas, la partida guardada aún las tiene (en
                # combate no se puede guardar), así que no hay nada que devolver
                for x in biblio['juegos']:
                    if x.get('balls_escondidas'):
                        x['balls_escondidas'] = None
                        guardar()
                capturas = zona = combate_desde = fuera_desde = None
                rpc.equipo = None
                vivo['en_combate'] = False
                continue
        try:
            combate = vivo['en_combate'] = juego.en_combate(rpc)
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
                    and time.time() - vivo.get('aviso_fase', 0) > 120:
                vivo['aviso_fase'] = time.time()
                avisar('¡Segunda medalla! · Guarda y reinicia el juego para abrir la randomización completa', 15)
            with lock:
                usadas = j.setdefault('rutas_usadas', [])
                if capturas is not None and ahora is not None and ahora > capturas and zona is not None:
                    if juego.salvaje_shiny(rpc):
                        avisar('¡Shiny! No cuenta como la captura de esta ruta')
                    elif zona not in usadas:
                        usadas.append(zona)
                        avisar('Captura de esta ruta hecha · Aquí ya no puedes capturar más', 3)
                    guardar()
                if ahora is not None:
                    capturas = ahora
                if combate and not decidido and time.time() - combate_desde >= 1.5:
                    decidido = True
                    if zona in usadas and not j.get('balls_escondidas') and not juego.salvaje_shiny(rpc):
                        j['balls_escondidas'] = juego.esconder_balls(rpc)
                        avisadas = j.setdefault('rutas_avisadas', [])     # el aviso, solo la primera vez en cada ruta
                        if j['balls_escondidas'] and zona not in avisadas:
                            avisadas.append(zona)
                            avisar('Ya has capturado en esta ruta · Poké Balls bloqueadas', 3)
                        guardar()
                elif not combate and j.get('balls_escondidas') and time.time() - fuera_desde >= 3:
                    juego.devolver_balls(rpc, j['balls_escondidas'])
                    j['balls_escondidas'] = None
                    guardar()
        except (OSError, TimeoutError):
            rpc.equipo = None


def corregir(atajo):
    """F7 −1 vida, F8 +1 vida. Las medallas ya no van con F9: se leen del juego."""
    with lock:
        j = buscar(vivo['activo'])
        if atajo == 'menos':
            j['ajuste_vidas'] -= 1
        elif atajo == 'mas':
            j['ajuste_vidas'] += 1
        guardar()


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
        p = vivo['proceso']
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
            exe = azahar_exe()
            return exe is not None and Path(ruta.value).parent == exe.parent
        finally:
            k32.CloseHandle(h)

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


def avisar(texto, segundos=4):
    """Un aviso para el jugador en el layout (sobre la pantalla de arriba) durante unos segundos."""
    vivo['aviso'] = {'texto': texto, 'hasta': time.time() + segundos}


def usar_vial():
    """E: si el vial está cargado, cura a todo el equipo vivo y se gasta hasta el próximo Centro Pokémon."""
    if not citra_listo():
        return
    with lock:
        j = buscar(vivo['activo'])
        if not j.get('vial', True):
            avisar('El vial está vacío · Vuelve al Centro Pokémon para recargarlo')
            return
        mega = j.get('reglas') == 'mega'
    rpc = juego.RPC(espera=1.0)
    if mega and (vivo.get('en_combate') or juego.en_combate(rpc)):
        return                     # bloqueado: la E no hace nada (el layout ya enseña el vial tachado)
    if juego.curar_equipo(rpc):
        with lock:
            j['vial'] = False
            vivo['vial_usado'] = time.time()
            avisar('¡Has usado el vial! · Vuelve al Centro Pokémon para recargarlo')
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
    return json.dumps([a and [a['vidas'], a['vidas_iniciales'], a['medallas'], a['vial'], a['vial_bloqueado'], a['topes']], e['equipo'], artes, e['aviso']],
                      sort_keys=True)


def renderizar_capa():
    """Pinta /overlay?capa=1 a la resolución del monitor con el navegador sin ventana."""
    nav, ff = navegador(), None
    if not nav:
        ff = firefox()
        if not ff:
            return
    s, _, _ = encaje()
    CAPA_PNG.parent.mkdir(exist_ok=True)
    tmp = TOOLS / 'capa-nueva.png'
    tmp.unlink(missing_ok=True)
    if ff:
        # Firefox sin ventana: el zoom va en el perfil y la foto se hace al cargar (el estado viene ya en la página)
        perfil = perfil_firefox('firefox-capa', {'layout.css.devPixelsPerPx': str(s)})
        subprocess.run([ff, '-headless', '-no-remote', '-profile', perfil, '--window-size=1920,1080',
                        '--screenshot', str(tmp), f'{URL}/overlay?capa=1'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000, timeout=60)
    else:
        # sin capturar la salida: Edge deja procesos hijos con la tubería abierta y esperar a que la cierren
        # podía dejar colgado el pintor para siempre (la capa se quedaba con el equipo de ese momento). Pero el
        # msedge.exe que se lanza le pasa el trabajo a un hijo y sale enseguida: hay que esperar a que la captura
        # aparezca y deje de crecer, con un límite
        subprocess.run([nav, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                        f'--user-data-dir={TOOLS / "edge-capa"}', f'--force-device-scale-factor={s}',
                        f'--window-size={round(1920 * s)},{round(1080 * s)}', '--virtual-time-budget=4000',
                        f'--screenshot={tmp}', f'{URL}/overlay?capa=1'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000, timeout=60)
    tam, limite = -1, time.time() + 20
    while time.time() < limite:
        ahora = tmp.stat().st_size if tmp.exists() else 0
        if ahora and ahora == tam:
            break
        tam = ahora
        time.sleep(0.4)
    else:
        return False
    try:
        tmp.replace(CAPA_PNG)
    except OSError:                       # la capa la está leyendo justo ahora: el siguiente intento
        return False
    vivo['capa'] += 1
    return True


def pintor_capa():
    """Repinta la capa cuando cambia lo que se ve. Nunca se para: si algo falla, lo vuelve a intentar."""
    ultima = None
    while True:
        try:
            if jugando():
                huella = huella_capa()
                if huella != ultima and renderizar_capa():
                    ultima = huella                       # si no se pudo pintar, se reintenta en el siguiente
            else:
                ultima = None
        except Exception:
            traceback.print_exc()
            ultima = None
        time.sleep(1)


def cargando():
    """Segundos que lleva abriéndose el juego, o None si ya ha salido su ventana (o no hay juego)."""
    if not (jugando() and vivo.get('citra')):
        return None
    if not vivo.get('ventana_juego'):
        citra_listo()                                   # mira la ventana también aquí, no solo en seguimiento()
    s = time.time() - vivo.get('lanzado', 0)
    return None if vivo.get('ventana_juego') or s > CAPA_MAX else round(s)


def foto_estado():
    with lock:
        activo = None
        if vivo['activo'] and any(j['id'] == vivo['activo'] for j in biblio['juegos']):
            j = buscar(vivo['activo'])
            activo = {'id': j['id'], 'nombre': j['nombre'], 'vidas': vidas(j),
                      'vidas_iniciales': j['vidas_iniciales'] + j['ajuste_vidas'], 'medallas': j['medallas'],
                      'vial': j.get('vial', True),
                      'vial_bloqueado': j.get('reglas') == 'mega' and bool(vivo.get('en_combate')),
                      'topes': niveles_tope(j)}
            muertos = j['muertos']
        else:
            muertos = []
        return {
            'juegos': [{'id': j['id'], 'nombre': j['nombre'], 'ruta': j['ruta'], 'preparado': j.get('preparado', False),
                        'random': j.get('random'), 'vidas': vidas(j) if j.get('preparado') else None,
                        'reglas': j.get('reglas'), 'huevos': huevos_disponibles(j) if j.get('huevos') else None,
                        'vidas_iniciales': j.get('vidas_iniciales'), 'medallas': sum(j.get('medallas', [])),
                        'registro': (DATOS / 'juegos' / j['id'] / 'randomizacion.log').exists()}
                       for j in biblio['juegos']],
            'activo': activo, 'jugando': jugando(), 'conectado': vivo['conectado'], 'cargando': cargando(), 'tarea': vivo['tarea'] and {**vivo['tarea'], 'transcurrido': time.time() - vivo['tarea']['inicio']},
            'equipo': [p and {**p, 'muerto': p['id'] in muertos} for p in vivo['equipo']],
            'aviso': vivo['aviso']['texto'] if vivo['aviso'] and time.time() < vivo['aviso']['hasta'] else None,
            'capa': vivo['capa'], 'encaje': encaje() if os.name == 'nt' else (1, 0, 0),
            'avanzado': (DATOS / 'avanzado.rnqs').exists(),
            'online': online_estado(),
            'firma': biblio.get('firma'),
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


MESES = ('enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
         'noviembre', 'diciembre')


def firmar():
    """La primera vez que se juega, el contrato queda firmado con el usuario (el de la sesión online o, sin
    conexión, el de Windows) y la fecha de ese momento. Después ya no cambia."""
    with lock:
        if not biblio.get('firma'):
            nombre = (red['sesion'] or {}).get('usuario') or os.environ.get('USERNAME') or 'Entrenador'
            biblio['firma'] = {'nombre': nombre, 'fecha': time.strftime('%Y-%m-%d')}
            guardar()
        return biblio['firma']


# normas.html está hecho para imprimir en A4 (los márgenes van en @page, que en pantalla no existe): en la app
# se ve como una hoja con márgenes, la portada más baja y, en el hueco estrecho de Opciones, sin justificar
CONTRATO_PANTALLA = '''<style>
@media screen {
  html { background: #ece6e2; }
  body { max-width: 210mm; margin: 0 auto; padding: 14mm 16mm 18mm; background: #fff; box-shadow: 0 2mm 8mm rgba(0,0,0,.12); }
  .portada { height: auto; padding: 16mm 8mm; margin: -14mm -16mm 12mm; gap: 6mm; }
  .portada img { width: min(110mm, 80%); }
  .portada h1 { font-size: 26pt; }
  .anexo { margin-top: 12mm; padding-top: 8mm; border-top: 1px dashed var(--linea); }
}
@media screen and (max-width: 640px) {
  body { padding: 7mm 6mm 10mm; font-size: 10.5pt; }
  .portada { margin: -7mm -6mm 8mm; }
  p, .clausula li { text-align: left; hyphens: manual; }
  .lugar { text-align: left; }
  .hueco { min-width: 24mm; } .hueco.largo { min-width: 40mm; }
  .firmas { gap: 6mm; } .sello { width: 22mm; height: 22mm; }
  .tabla td:first-child { white-space: normal; }
}
</style>'''


def contrato_html():
    """normas/normas.html con sus imágenes servidas por la app y, si ya se ha firmado, los huecos rellenos."""
    html = (NORMAS / 'normas.html').read_text(encoding='utf-8')
    html = html.replace('src="../assets/', 'src="/assets/').replace('src="img/', 'src="/docs/img/')
    html = html.replace('</head>', CONTRATO_PANTALLA + '</head>', 1)
    f = biblio.get('firma')
    if not f:
        return html
    nombre = f['nombre'].replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    a, m, d = (int(x) for x in f['fecha'].split('-'))
    html = html.replace(
        '<span class="hueco corto"></span> de <span class="hueco"></span> de 20<span class="hueco corto"></span>',
        f'<b class="relleno">{d}</b> de <b class="relleno">{MESES[m - 1]}</b> de <b class="relleno">{a}</b>', 1)
    html = html.replace('el entrenador o entrenadora <span class="hueco largo"></span>',
                        f'el entrenador o entrenadora <b class="relleno">{nombre}</b>', 1)
    html = html.replace('<div class="firma"><div class="linea"></div><b>El Entrenador</b><small>Nombre y firma</small></div>',
                        f'<div class="firma"><div class="linea"><span class="rubrica">{nombre}</span></div>'
                        f'<b>El Entrenador</b><small>{nombre}</small></div>', 1)
    estilo = ('<link href="https://fonts.googleapis.com/css2?family=Caveat:wght@600&family=Great+Vibes&display=swap" rel="stylesheet">'
              '<style>.relleno { font: 600 15pt Caveat, cursive; color: #1d3a8a; padding: 0 1.5mm; }'
              '.firma .linea { display: flex; align-items: flex-end; justify-content: center; }'
              '.rubrica { font: 32pt "Great Vibes", cursive; color: #1d3a8a; line-height: 1; transform: rotate(-4deg); }</style>')
    return html.replace('</head>', estilo + '</head>', 1)


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
         '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.js': 'text/javascript', '.css': 'text/css',
         '.pdf': 'application/pdf', '.mp4': 'video/mp4'}


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

    def por_trozos(self, f):
        """Un archivo grande (el vídeo) con Range: así el reproductor puede adelantar y no se lee entero."""
        if not f.is_file():
            return self.enviar({'error': 'no existe'}, codigo=404)
        tam = f.stat().st_size
        m = re.fullmatch(r'bytes=(\d*)-(\d*)', self.headers.get('Range') or '')
        ini, fin = 0, tam - 1
        if m and (m[1] or m[2]):
            ini, fin = (int(m[1]), int(m[2] or tam - 1)) if m[1] else (tam - int(m[2]), tam - 1)
            fin = min(fin, tam - 1)
        self.send_response(206 if m else 200)
        self.send_header('Content-Type', TIPOS.get(f.suffix.lower(), 'application/octet-stream'))
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Content-Length', str(fin - ini + 1))
        if m:
            self.send_header('Content-Range', f'bytes {ini}-{fin}/{tam}')
        self.end_headers()
        with open(f, 'rb') as a:
            a.seek(ini)
            quedan = fin - ini + 1
            try:
                while quedan > 0:
                    trozo = a.read(min(quedan, 1 << 20))
                    if not trozo:
                        break
                    self.wfile.write(trozo)
                    quedan -= len(trozo)
            except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
                pass                                  # el reproductor corta la petición al adelantar

    def do_GET(self):
        # un error al contestar no puede dejar la petición sin respuesta: la ventana lo tomaba por Pokelocke cerrado
        try:
            self.responder_get()
        except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
            pass
        except Exception:
            traceback.print_exc()
            try:
                self.enviar({'error': 'error interno'}, codigo=500)
            except OSError:
                pass

    def responder_get(self):
        if not self.local():
            return self.enviar({'error': 'Petición no permitida'}, codigo=403)
        ruta = self.path.split('?')[0]
        if ruta == '/':
            return self.archivo(WEB / 'app.html')
        if ruta == '/overlay':
            if 'capa=' not in self.path:
                return self.archivo(WEB / 'overlay.html')
            # la capa: el estado va ya dentro, porque Firefox sin ventana hace la foto en cuanto carga
            estado = json.dumps(foto_estado(), ensure_ascii=False).replace('</', '<\\/')
            html = (WEB / 'overlay.html').read_text(encoding='utf-8')
            return self.enviar(html.replace('</head>', f'<script>window.ESTADO = {estado};</script></head>', 1).encode(),
                               'text/html; charset=utf-8')
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
        # opciones: vídeo de normas, guía y contrato (firmado si ya se ha jugado)
        if ruta == '/docs/video':
            return self.por_trozos(VIDEO)
        if ruta == '/docs/guia':
            return self.archivo(GUIA_PDF)
        if ruta == '/docs/contrato':
            return self.enviar(contrato_html().encode(), 'text/html; charset=utf-8')
        if m := re.fullmatch(r'/docs/img/([\w.-]+)', ruta):
            return self.archivo(NORMAS / 'img' / m[1])
        self.enviar({'error': 'no existe'}, codigo=404)

    def local(self):
        """La petición va a este Pokelocke por 127.0.0.1 o localhost. Una web con un dominio que apunte a 127.0.0.1
        (DNS rebinding) llega con su propio Host y se rechaza: no puede leer el estado ni mandar acciones."""
        return self.headers.get('Host', '') in (f'127.0.0.1:{PUERTO}', f'localhost:{PUERTO}')

    def do_POST(self):
        # cualquier web abierta en el PC puede mandar un POST a 127.0.0.1, pero no con Content-Type JSON sin
        # pedir permiso antes (CORS), y este servidor no se lo da: así solo la ventana de Pokelocke manda acciones
        if not self.local() or not (self.headers.get('Content-Type') or '').startswith('application/json'):
            return self.enviar({'error': 'Petición no permitida'}, codigo=403)
        try:
            largo = min(int(self.headers.get('Content-Length') or 0), 20_000_000)
            datos = json.loads(self.rfile.read(largo) or b'{}')
            if not isinstance(datos, dict):
                raise ValueError('Petición no válida')
            respuesta = self.accion(self.path, datos)
            self.enviar(respuesta or {'ok': True})
        except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
            pass
        except Exception as e:
            if not isinstance(e, (RuntimeError, ValueError, KeyError, TypeError, PermissionError)):
                traceback.print_exc()
            self.enviar({'error': str(e)}, codigo=400)

    def accion(self, ruta, d):
        if ruta == '/api/firmar':
            return {'firma': firmar()}
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
                j = buscar(d.get('id'))                  # solo ids de la biblioteca: nunca una ruta que llegue de fuera
                biblio['juegos'].remove(j)
                shutil.rmtree(DATOS / 'juegos' / j['id'], ignore_errors=True)
                guardar()
        elif ruta == '/api/reiniciar':          # vuelve a pedir vidas y randomización al jugar
            with lock:
                buscar(d['id'])['preparado'] = False
                guardar()
        elif ruta == '/api/borrar_partida':
            with lock:
                borrar_partida(buscar(d['id']))
        elif ruta == '/api/registro':
            log = DATOS / 'juegos' / buscar(d.get('id'))['id'] / 'randomizacion.log'
            if not log.exists():
                raise RuntimeError('Este juego no tiene registro: no se ha randomizado')
            os.startfile(log)
        elif ruta == '/api/preparar':
            j = buscar(d['id'])
            en_segundo_plano('Preparar el juego', preparar, j, d.get('opciones', {}), d.get('vidas', 25),
                             bool(d.get('randomizar')), bool(d.get('avanzado')),
                             'mega' if d.get('reglas') == 'mega' else None, minimo=60)
        elif ruta in ('/api/huevos', '/api/huevos/coger'):
            with lock:
                j = buscar(d['id'])
                if not j.get('huevos'):
                    raise RuntimeError('La caja de huevos es de las normas Mega Pokelocke')
                if ruta.endswith('coger'):
                    i = int(d['i'])
                    if not 0 <= i < len(j['huevos']):
                        raise RuntimeError('Ese huevo no existe')
                    return coger_huevo(j, i)
                return huevos_estado(j)
        elif ruta == '/api/jugar':
            j = buscar(d['id'])
            en_segundo_plano('Abrir el juego', lambda: (herramientas(), lanzar(j)))
        elif ruta == '/api/upr_completo':
            en_segundo_plano('Abrir el randomizador completo', lambda: (
                herramientas(), DATOS.mkdir(exist_ok=True),
                subprocess.Popen([java(), '-jar', str(upr_jar())], cwd=upr_jar().parent)))
        elif ruta == '/api/medalla':
            with lock:
                i = int(d['i'])
                if not 0 <= i < 8:
                    raise RuntimeError('Esa medalla no existe')
                buscar(vivo['activo'])['medallas'][i] = bool(d['valor'])
                guardar()
        elif ruta == '/api/vidas':
            with lock:
                buscar(vivo['activo'])['ajuste_vidas'] += int(d['delta'])
                guardar()
        elif ruta.startswith('/api/online/'):
            return online_accion(ruta.rsplit('/', 1)[1], d)
        elif ruta.startswith('/api/pokehex/'):
            return pokehex_accion(ruta.rsplit('/', 1)[1], d)
        else:
            raise RuntimeError('Acción desconocida')


# ---------- PokéHex: ver y cambiar el equipo y la mochila de la partida guardada ----------
# Con el juego cerrado: se edita el archivo de la partida del emulador (como PKHeX), con copia antes de cada cambio.

CLAVE_POKEHEX = 'Admin123!'
hex_vivo = {'tokens': set(), 'datos': {}, 'interno': hashlib.sha1(os.urandom(16)).hexdigest()}  # interno: encargos del servidor


def pokehex_partida(j):
    """El archivo de la partida del juego en el emulador: sdmc/Nintendo 3DS/*/*/title/00040000/<título>/data/00000001/main."""
    exe = azahar_exe()
    if not exe:
        raise RuntimeError('No encuentro el emulador en tools/')
    mod = DATOS / 'juegos' / j['id'] / 'mod'
    titulo = next((p.name for p in mod.iterdir() if re.fullmatch(r'[0-9A-Fa-f]{16}', p.name)), TITLE_Y) if mod.exists() else TITLE_Y
    sdmc = exe.parent / 'user' / 'sdmc' / 'Nintendo 3DS'
    for f in sdmc.glob(f'*/*/title/{titulo[:8].lower()}/{titulo[8:].lower()}/data/00000001/main'):
        return f
    raise RuntimeError('Este juego aún no tiene partida guardada en el emulador')


def borrar_partida(j):
    """Borra la partida guardada del juego en el emulador (la carpeta data/ de su título: el juego empieza de cero
    y crea una nueva) y pone a cero su locke. Antes se guarda una copia en datos/juegos/<id>/partidas_borradas/."""
    if jugando():
        raise RuntimeError('Cierra el juego antes de borrar la partida')
    datos = pokehex_partida(j).parent.parent                     # .../title/00040000/<título>/data
    copia = DATOS / 'juegos' / j['id'] / 'partidas_borradas' / time.strftime('%Y%m%d_%H%M%S')
    shutil.copytree(datos, copia)
    shutil.rmtree(datos)
    fase = j.get('fase')
    nuevo_locke(j, j['vidas_iniciales'], j.get('reglas'))
    if fase == 2:                       # la versión fácil ya no está: se sigue con la completa
        j['fase'] = 2
    guardar()


def pokehex_accion(que, d):
    if que == 'entrar':
        if d.get('clave') != CLAVE_POKEHEX:
            raise RuntimeError('Contraseña incorrecta')
        token = hashlib.sha1(os.urandom(16)).hexdigest()
        hex_vivo['tokens'].add(token)
        return {'token': token, 'nombres': pokehex.NOMBRES, 'admitidos': pokehex.ADMITIDOS, 'balls': pokehex.BALLS}
    if d.get('token') not in hex_vivo['tokens'] and d.get('token') != hex_vivo['interno']:
        raise RuntimeError('Vuelve a entrar en el PokéHex')
    if jugando():
        raise RuntimeError('Cierra el juego para usar el PokéHex: si no, el juego pisaría los cambios al guardar')
    with lock:
        j = buscar(d['id'])
    try:
        partida = pokehex.Partida(pokehex_partida(j))
    except ValueError as e:
        raise RuntimeError(str(e))
    copias = DATOS / 'juegos' / j['id'] / 'copias_partida'
    if j['id'] not in hex_vivo['datos']:
        hex_vivo['datos'][j['id']] = pokehex.Datos(TOOLS, DATOS / 'juegos' / j['id'] / 'randomizacion.log')
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


# ---------- online: cuentas, conectados, servidor y PokéHex a distancia ----------
# app/online.json: {"direccion": "..."}, adónde se conectan todos. Va dentro del .exe repartido, así que los
# demás no tienen que configurar nada. Lo que cambie cada uno (el anfitrión al activar el servidor) se guarda
# en datos/online.json, que manda sobre el de dentro.

F_ONLINE, F_SESION = DATOS / 'online.json', DATOS / 'sesion.json'
red = {'sesion': None, 'conectados': [], 'error': None, 'servidor': None, 'upnp': None, 'ip': None}


def online_config():
    for f in (F_ONLINE, APP / 'online.json'):
        try:
            return json.loads(f.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            pass
    return {}


def online_direccion():
    if red['servidor']:                     # este PC es el servidor: se habla con él directamente
        return '127.0.0.1'
    return online_config().get('direccion')


def online_estado():
    s = red['sesion']
    return {'sesion': s and {'usuario': s['usuario'], 'admin': s['admin']}, 'conectados': red['conectados'],
            'error': red['error'], 'servidor': bool(red['servidor']), 'upnp': red['upnp'], 'ip': red['ip'],
            'direccion': online_config().get('direccion')}


def online_guardar_sesion():
    if red['sesion']:
        F_SESION.write_text(json.dumps(red['sesion']), encoding='utf-8')
    else:
        F_SESION.unlink(missing_ok=True)


def online_latidos():
    """Cada pocos segundos: «sigo aquí» al servidor, la lista de conectados y los encargos del PokéHex."""
    try:
        red['sesion'] = json.loads(F_SESION.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        pass
    while True:
        s, direccion = red['sesion'], online_direccion()
        if s and direccion:
            with lock:
                j = buscar(vivo['activo']) if vivo['activo'] and jugando() else None
            estado = {'jugando': bool(j), 'juego': j and j['nombre']}
            try:
                r = online.peticion(direccion, '/latido', {'token': s['token'], 'estado': estado}, espera=8)
                if r.get('sesion') is False:
                    red['sesion'], red['conectados'] = None, []
                    online_guardar_sesion()
                elif 'error' in r:
                    red['error'] = r['error']
                else:
                    red['error'], red['conectados'] = None, r['conectados']
                    for t in r['tareas']:
                        threading.Thread(target=online_tarea, args=(direccion, s['token'], t), daemon=True).start()
            except OSError:
                red['error'], red['conectados'] = 'No se puede conectar con el servidor', []
        time.sleep(online.LATIDO)


def online_tarea(direccion, token, t):
    """Un encargo del administrador: el PokéHex de este jugador, en su partida (con el juego cerrado)."""
    try:
        with lock:
            juegos = [j for j in biblio['juegos'] if j.get('preparado')]
        if not juegos:
            raise RuntimeError('Este jugador no tiene ninguna partida')
        datos = dict(t.get('datos') or {})
        datos.setdefault('id', juegos[0]['id'])
        res = pokehex_accion(t['que'], {**datos, 'token': hex_vivo['interno']})
        if t['que'] == 'leer':
            res['juegos'] = [{'id': j['id'], 'nombre': j['nombre']} for j in juegos]
    except Exception as e:
        res = {'error': str(e)}
    online.peticion(direccion, '/resultado', {'token': token, 'id': t['id'], 'resultado': res})


def online_servidor(activar):
    if activar and not red['servidor']:
        exe = azahar_exe()
        sala = next((exe.parent / n for n in ('citra-room.exe', 'azahar-room.exe') if exe and (exe.parent / n).exists()), None)
        srv = online.Servidor(DATOS / 'servidor', sala)
        srv.arrancar(CLAVE_POKEHEX)
        red['servidor'] = srv
        red['upnp'], red['ip'] = online.abrir_puertos()
        if not red['upnp']:
            # la primera vez en un PC, el cortafuegos pregunta y mientras tanto el router no contesta: se reintenta
            def reintentar():
                for _ in range(6):
                    time.sleep(10)
                    if not red['servidor']:
                        return
                    red['upnp'], ip = online.abrir_puertos()
                    red['ip'] = ip or red['ip']
                    if red['upnp']:
                        return
            threading.Thread(target=reintentar, daemon=True).start()
        # la dirección que se reparte con la app: el nombre fijo de DuckDNS si lo hay (datos/servidor/duckdns.json,
        # {"dominio": "...", "token": "..."}, solo en el PC del anfitrión) y si no, la IP pública de ahora
        try:
            dd = json.loads((DATOS / 'servidor' / 'duckdns.json').read_text(encoding='utf-8'))
        except (OSError, ValueError):
            dd = None
        cfg = online_config()
        if dd and dd.get('dominio') and dd.get('token'):
            red['duckdns'] = online.duckdns(dd['dominio'], dd['token'])
            cfg['direccion'] = dd['dominio'].strip() if dd['dominio'].endswith('.duckdns.org') else dd['dominio'].strip() + '.duckdns.org'
        elif red['ip']:
            cfg['direccion'] = red['ip']
        F_ONLINE.write_text(json.dumps(cfg, indent=1), encoding='utf-8')
    elif not activar and red['servidor']:
        red['servidor'].parar()
        red['servidor'] = None
        threading.Thread(target=online.cerrar_puertos, daemon=True).start()
        red['conectados'] = []


def online_accion(que, d):
    if que == 'servidor':
        online_servidor(bool(d.get('activar')))
        return online_estado()
    if que == 'direccion':
        cfg = online_config()
        cfg['direccion'] = str(d.get('direccion', '')).strip()
        F_ONLINE.write_text(json.dumps(cfg, indent=1), encoding='utf-8')
        return online_estado()
    direccion = online_direccion()
    if que in ('entrar', 'registro'):
        if not direccion:
            raise RuntimeError('Falta la dirección del servidor')
        try:
            datos = {'usuario': d.get('usuario'), 'clave': d.get('clave')}
            if que == 'registro' and red['servidor']:      # registrarse desde el anfitrión: cuenta de administrador
                datos['anfitrion'] = red['servidor'].clave_anfitrion
            r = online.peticion(direccion, '/' + que, datos)
        except OSError:
            raise RuntimeError('No se puede conectar con el servidor. ¿Está encendido?')
        if 'error' in r:
            raise RuntimeError(r['error'])
        red['sesion'], red['error'] = {k: r[k] for k in ('token', 'usuario', 'admin', 'sala')}, None
        online_guardar_sesion()
        return online_estado()
    if que == 'salir':
        if red['sesion'] and direccion:
            try:
                online.peticion(direccion, '/salir', {'token': red['sesion']['token']}, espera=4)
            except OSError:
                pass
        red['sesion'], red['conectados'] = None, []
        online_guardar_sesion()
        return online_estado()
    if que in ('torneo', 'torneo_editar', 'foto'):    # el torneo lo ven todos; lo cambia el administrador
        if not red['sesion']:
            raise RuntimeError('Entra con tu usuario para ver el torneo')
        ruta = {'torneo': '/torneo', 'torneo_editar': '/torneo/editar', 'foto': '/foto'}[que]
        try:
            r = online.peticion(direccion, ruta, {**d, 'token': red['sesion']['token']}, espera=15)
        except OSError:
            raise RuntimeError('No se puede conectar con el servidor')
        if 'error' in r:
            raise RuntimeError(r['error'])
        return r
    if que == 'pokehex':                     # el PokéHex de otro jugador (solo el administrador)
        if not red['sesion']:
            raise RuntimeError('Entra con tu usuario')
        try:
            r = online.peticion(direccion, '/pokehex', {'token': red['sesion']['token'], 'clave_hex': d.get('clave_hex'),
                                                         'usuario': d.get('usuario'), 'que': d.get('que'),
                                                         'datos': d.get('datos') or {}}, espera=40)
        except OSError:
            raise RuntimeError('No se puede conectar con el servidor')
        if 'error' in r:
            raise RuntimeError(r['error'])
        return r
    raise RuntimeError('Acción desconocida')


# ---------- capa del layout encima de Azahar ----------

def capa():
    """Ventana sin bordes, siempre delante, con los huecos (color clave) transparentes y sin coger
    el foco: se ve y se toca el juego a través de ella y el teclado sigue en Azahar.
    Mientras el juego se abre es solo un cartel pequeño en el centro («Abriendo el juego…», con los segundos),
    para que se vea que no se ha colgado y para no tapar Citra (ni sus avisos) antes de tiempo: Alt+Q del
    lanzador solo funciona cuando ya está la ventana del juego, así que antes el layout no se podía quitar."""
    import tkinter as tk
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
    w, h = pantalla()
    s, ox, oy = encaje()
    raiz = tk.Tk()
    raiz.overrideredirect(True)
    raiz.attributes('-topmost', True)
    raiz.attributes('-transparentcolor', CLAVE)
    etiqueta = tk.Label(raiz, bd=0, bg=CLAVE)
    # el cartel de carga
    FONDO, TINTA, ACENTO = '#1b1820', '#ffffff', '#c8102e'
    cartel = tk.Frame(raiz, bg=FONDO, highlightthickness=3, highlightbackground=ACENTO)
    titulo = tk.Label(cartel, text='Abriendo el juego…', bg=FONDO, fg=TINTA, font=('Segoe UI Semibold', 20))
    detalle = tk.Label(cartel, bg=FONDO, fg='#f2b8c2', font=('Segoe UI', 12), justify='center')
    barra = tk.Canvas(cartel, width=380, height=10, bg='#3a2f3d', highlightthickness=0)
    bloque = barra.create_rectangle(0, 0, 90, 10, fill=ACENTO, width=0)
    for wdg, pad in ((titulo, (26, 6)), (detalle, (0, 14)), (barra, (0, 26))):
        wdg.pack(padx=34, pady=pad)
    raiz.update_idletasks()
    hwnd = ctypes.windll.user32.GetParent(raiz.winfo_id())
    GWL_EXSTYLE, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW = -20, 0x08000000, 0x00000080
    estilo = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, estilo | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW)
    vista = {'version': -1, 'imagen': None, 'arrancado': time.time(), 'modo': None, 'x': 0, 'fallos': 0}

    def modo_cartel(segundos):
        if vista['modo'] != 'cartel':
            vista['modo'] = 'cartel'
            etiqueta.place_forget()
            raiz.configure(bg=FONDO)
            cartel.pack()
            raiz.update_idletasks()
            cw, ch = cartel.winfo_reqwidth(), cartel.winfo_reqheight()
            raiz.geometry(f'{cw}x{ch}+{(w - cw) // 2}+{(h - ch) // 2}')
        texto = f'Lleva {segundos} s · En un PC lento puede tardar hasta un minuto.\nNo cierres nada: el juego saldrá aquí solo.'
        if segundos > 90:
            texto = (f'Lleva {segundos} s: está tardando más de lo normal.\n'
                     'Si Citra enseña un error, ciérralo y vuelve a darle a Jugar.')
        detalle.configure(text=texto)

    def modo_layout():
        if vista['modo'] != 'layout':
            vista['modo'] = 'layout'
            cartel.pack_forget()
            raiz.configure(bg=CLAVE)
            raiz.geometry(f'{w}x{h}+0+0')
            etiqueta.place(x=ox, y=oy)

    def animar():
        if vista['modo'] == 'cartel':                    # la barra va y viene: se ve que sigue vivo
            vista['x'] = (vista['x'] + 6) % 470
            barra.coords(bloque, vista['x'] - 90, 0, vista['x'], 10)
        raiz.after(40, animar)

    def refrescar():
        try:
            with urllib.request.urlopen(f'{URL}/api/estado', timeout=2) as r:
                e = json.load(r)
            vista['fallos'] = 0
        except (OSError, ValueError):
            # un fallo suelto no cierra el layout en mitad de la partida: solo si Pokelocke no contesta en 10 s
            vista['fallos'] += 1
            if vista['fallos'] >= 10:
                return raiz.destroy()
            return raiz.after(1000, refrescar)
        if not e['jugando'] and time.time() - vista['arrancado'] > 15:
            return raiz.destroy()
        if e.get('cargando') is not None:
            modo_cartel(e['cargando'])
        else:
            modo_layout()
            if e['capa'] != vista['version'] and CAPA_PNG.exists():
                vista['version'] = e['capa']
                vista['imagen'] = tk.PhotoImage(file=str(CAPA_PNG))
                etiqueta.configure(image=vista['imagen'])
        raiz.attributes('-topmost', True)
        raiz.after(1000, refrescar)

    refrescar()
    animar()
    raiz.mainloop()


def abrir_ventana_app():
    nav = navegador()
    url = f'{URL}/'
    if nav:
        subprocess.Popen([nav, f'--app={url}', f'--user-data-dir={TOOLS / "edge-perfil"}',
                          '--window-size=1280,820', '--no-first-run'])
    elif ff := firefox():
        # Firefox no tiene modo app: perfil propio con la barra de título de Windows y sin pestañas ni barra de direcciones
        perfil = perfil_firefox('firefox-perfil', {'toolkit.legacyUserProfileCustomizations.stylesheets': True,
                                                   'browser.tabs.inTitlebar': 0},
                                '#TabsToolbar, #nav-bar, #PersonalToolbar { visibility: collapse !important; }\n')
        subprocess.Popen([ff, '-profile', perfil, '-width', '1280', '-height', '820', url])
    else:
        import webbrowser
        webbrowser.open(url)


def main():
    if os.name == 'nt':
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
        # que la barra de tareas agrupe las ventanas de Pokelocke con su propio icono
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID('Pokelocke')
    if '--capa' in sys.argv:
        return capa()
    RAIZ.mkdir(parents=True, exist_ok=True)
    if getattr(sys, 'frozen', False):
        # el .exe no tiene consola: los errores van a pokelocke.log (y el de la vez anterior a pokelocke.old.log)
        log = RAIZ / 'pokelocke.log'
        try:
            log.replace(RAIZ / 'pokelocke.old.log')
        except OSError:
            pass
        sys.stdout = sys.stderr = open(log, 'a', encoding='utf-8', buffering=1)
        import faulthandler
        faulthandler.enable(sys.stderr)                    # también si Python se cae de golpe
        print(time.strftime('%Y-%m-%d %H:%M:%S'), 'Pokelocke abierto', flush=True)
    for carpeta in (TOOLS, DATOS, FANART):
        carpeta.mkdir(exist_ok=True)
    cargar()
    # sin SO_REUSEADDR: en Windows deja que dos Pokelocke escuchen a la vez en el mismo puerto (y los dos
    # contaban muertes); así el segundo falla al abrir el puerto y solo enseña la ventana del primero
    ThreadingHTTPServer.allow_reuse_address = False
    try:
        servidor = ThreadingHTTPServer(('127.0.0.1', PUERTO), Servidor)
    except OSError:                       # ya está abierto: solo enseña la ventana
        return abrir_ventana_app()
    threading.Thread(target=seguimiento, daemon=True).start()
    threading.Thread(target=normas_mega, daemon=True).start()
    threading.Thread(target=pintor_capa, daemon=True).start()
    threading.Thread(target=online_latidos, daemon=True).start()
    if os.name == 'nt':
        threading.Thread(target=atajos, daemon=True).start()
    print(f'Pokelocke en {URL}  ·  overlay para OBS: {URL}/overlay')
    if '--sin-ventana' not in sys.argv:       # --sin-ventana: solo el servidor (pruebas u OBS)
        abrir_ventana_app()
    servidor.serve_forever()


if __name__ == '__main__':
    main()
