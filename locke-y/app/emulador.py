"""El emulador: Citra/Azahar, Java y el randomizador, la ROM, los mods y abrir el juego."""
import configparser
import ctypes
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import traceback
import urllib.request
import zipfile
from pathlib import Path

import online
import comun
import conexion
import guardado
import locke
import vigia


def jugando():
    p = comun.vivo['proceso']
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
    if not comun.vivo.get('citra'):
        return ahora - comun.vivo.get('lanzado', 0) > ESPERA_AZAHAR
    if not comun.vivo.get('juego_visto'):
        if ahora - comun.vivo.get('lanzado', 0) > ESPERA_MAX:
            comun.vivo['juego_visto'] = ahora - MARGEN_RPC
        elif os.name == 'nt' and ahora - comun.vivo.get('mirado', 0) >= 1:       # se mira como mucho una vez por segundo
            comun.vivo['mirado'] = ahora
            if ventanas_citra() >= 2:
                comun.vivo['juego_visto'], comun.vivo['ventana_juego'] = ahora, True
                print(time.strftime('%H:%M:%S'), f'ventana del juego a los {ahora - comun.vivo["lanzado"]:.0f} s', flush=True)
    return bool(comun.vivo.get('juego_visto')) and ahora - comun.vivo['juego_visto'] > MARGEN_RPC


# ---------- herramientas portables ----------

# lo que trae el instalador (app/empaquetar.py): un Java mínimo hecho con jlink y LockeSettings y MegaFases ya
# compilados en un .jar, así que no hace falta instalar ni descargar Java
JAVA_INCLUIDO = comun.TOOLS / 'java' / 'runtime' / 'bin' / 'java.exe'
CLASES_POKELOCKE = comun.TOOLS / 'upr' / 'pokelocke-upr.jar'


def java():
    if JAVA_INCLUIDO.exists() and CLASES_POKELOCKE.exists():
        return str(JAVA_INCLUIDO)
    candidatos = []
    if os.environ.get('JAVA_HOME'):
        candidatos.append(Path(os.environ['JAVA_HOME']) / 'bin' / 'java.exe')
    candidatos += sorted((Path.home() / '.jdks').glob('*/bin/java.exe'), reverse=True)
    candidatos += sorted((comun.TOOLS / 'java').glob('*/bin/java.exe'), reverse=True)   # el que descarga la app
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


def _ventana_titulada(inicio):
    """La ventana visible cuyo título empieza así, o None."""
    u, hallada = ctypes.windll.user32, []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def mira(h, _):
        b = ctypes.create_unicode_buffer(128)
        u.GetWindowTextW(ctypes.c_void_p(h), b, 128)
        if b.value.startswith(inicio):
            hallada.append(h)
        return True

    u.EnumWindows(mira, None)
    return hallada[0] if hallada else None


def volumen_citra():
    """El volumen que tiene puesto el emulador (0-1), de su configuración; 1 si no se puede leer."""
    try:
        t = (azahar_exe().parent / 'user' / 'config' / 'qt-config.ini').read_text(encoding='utf-8', errors='ignore')
        audio = t.split('[Audio]', 1)[1].split('\n[', 1)[0]
        if re.search(r'(?m)^volume\\default=true', audio):
            return 1.0
        return max(0.0, min(1.0, float(re.search(r'(?m)^volume=([0-9.]+)', audio)[1])))
    except (OSError, IndexError, TypeError, ValueError, AttributeError):
        return 1.0


def _al_frente(hwnd):
    """Delante y con el teclado: Windows solo lo deja si compartes entrada con quien está delante (como en el lanzador)."""
    u, h = ctypes.windll.user32, ctypes.c_void_p(hwnd)
    yo, suyo = ctypes.windll.kernel32.GetCurrentThreadId(), u.GetWindowThreadProcessId(ctypes.c_void_p(u.GetForegroundWindow()), None)
    unido = suyo and suyo != yo and u.AttachThreadInput(yo, suyo, True)
    u.BringWindowToTop(h)
    u.SetForegroundWindow(h)
    if unido:
        u.AttachThreadInput(yo, suyo, False)
    if u.GetForegroundWindow() != hwnd:
        u.SwitchToThisWindow(h, True)


def _cerrar_titulada(inicio):
    """Cierra el navegador de la ventana con ese título: es su proceso quien manda, no el que se lanzó (ese sale enseguida)."""
    u = ctypes.windll.user32
    while (hwnd := _ventana_titulada(inicio)):
        pid = ctypes.c_ulong()
        u.GetWindowThreadProcessId(ctypes.c_void_p(hwnd), ctypes.byref(pid))
        subprocess.run(['taskkill', '/F', '/T', '/PID', str(pid.value)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000)
        time.sleep(0.2)
        if _ventana_titulada(inicio) == hwnd:
            break


MARGEN, MARGEN_ARRIBA = 12, 46        # lo que la ventana se sale del hueco: la barra de título mide 31 y hay 8 de borde invisible
MAX_APERTURA = 150                    # la página se rompe sola al minuto sin pulsar y dura medio más: esto es por si se cuelga


def apertura(especie, shiny):
    """La animación de un huevo: un navegador sin marco justo encima de la pantalla grande del juego. Se queda
    con el teclado (el huevo se rompe a golpes de Enter) y al acabar se lo devuelve al juego."""
    nav = navegador()
    if not nav or os.name != 'nt' or comun.vivo.get('apertura'):
        return
    u = ctypes.windll.user32
    s, ox, oy = comun.encaje()
    x, y, w, h = (round(v * s) for v in comun.HUECO_ARRIBA)
    x, y = x + ox, y + oy
    delante = u.GetForegroundWindow()
    comun.vivo['apertura'] = True
    for t in ('Pokelocke apertura', 'Pokelocke fin'):                  # lo que dejara una vez anterior
        _cerrar_titulada(t)
    # un perfil por vez: con uno fijo, un navegador que se hubiera quedado vivo se lleva la ventana y el lanzado sale
    base = comun.TOOLS / 'apertura-edge'
    shutil.rmtree(base, ignore_errors=True)
    perfil = base / str(int(time.time()))
    proc = subprocess.Popen([nav, f'--app={comun.URL}/apertura?especie={especie}&shiny={int(shiny)}&vol={volumen_citra():.3f}', f'--user-data-dir={perfil}', '--no-first-run', '--no-default-browser-check',
                             '--autoplay-policy=no-user-gesture-required', '--disable-features=Translate', '--window-position=-6000,0', f'--window-size={w},{h}'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000)
    try:
        limite = time.time() + 20
        hwnd = None
        while time.time() < limite and not hwnd:
            hwnd = _ventana_titulada('Pokelocke apertura') or _ventana_titulada('Pokelocke fin')
            time.sleep(0.05)
        if not hwnd:
            return
        h_ = ctypes.c_void_p(hwnd)
        # como la ventana del juego: debajo de la capa y algo más grande que el hueco, para que el layout tape la barra
        # de título y los bordes del navegador (Edge los vuelve a pintar aunque se le quiten o se le recorten)
        u.SetWindowPos(h_, None, x - MARGEN, y - MARGEN_ARRIBA, w + 2 * MARGEN, h + MARGEN_ARRIBA + MARGEN, 0x40)
        _al_frente(hwnd)
        limite = time.time() + MAX_APERTURA
        while time.time() < limite and not _ventana_titulada('Pokelocke fin') and u.IsWindow(h_):
            if u.GetForegroundWindow() != hwnd:
                _al_frente(hwnd)
            time.sleep(0.25)
    finally:
        comun.vivo['apertura'] = False
        for t in ('Pokelocke apertura', 'Pokelocke fin'):
            _cerrar_titulada(t)
        subprocess.run(['taskkill', '/F', '/T', '/PID', str(proc.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000)
        if delante:
            _al_frente(delante)


def firefox():
    for base in (os.environ.get('ProgramFiles'), os.environ.get('ProgramFiles(x86)'), os.environ.get('LOCALAPPDATA')):
        if base and (Path(base) / 'Mozilla Firefox' / 'firefox.exe').exists():
            return str(Path(base) / 'Mozilla Firefox' / 'firefox.exe')
    return None


def perfil_firefox(nombre, prefs, css=''):
    """Perfil propio de Firefox para Pokelocke (no toca el del usuario). Las preferencias se reescriben siempre."""
    p = comun.TOOLS / nombre
    (p / 'chrome').mkdir(parents=True, exist_ok=True)
    prefs = {'browser.shell.checkDefaultBrowser': False, 'browser.aboutwelcome.enabled': False,
             'datareporting.policy.dataSubmissionPolicyBypassNotification': True,
             'browser.startup.homepage_override.mstone': 'ignore', 'browser.tabs.warnOnClose': False, **prefs}
    (p / 'user.js').write_text(''.join(f'user_pref({json.dumps(k)}, {json.dumps(v)});\n' for k, v in prefs.items()),
                               encoding='utf-8')
    (p / 'chrome' / 'userChrome.css').write_text(css, encoding='utf-8')
    return str(p)


def azahar_exe():
    """El lanzador de Citra 1920. Un Pokelocke antiguo pudo descargar un Azahar de verdad en tools/azahar: las
    actualizaciones no lo borran y ese rechaza nuestra ROM («las aplicaciones cifradas no son compatibles»)."""
    raiz = comun.TOOLS / 'azahar'
    if not raiz.exists():
        return None
    citra = raiz / 'citra-1920' / 'azahar.exe'
    return citra if citra.exists() else next(raiz.rglob('azahar.exe'), None)


def upr_jar():
    return next((comun.TOOLS / 'upr').rglob('PokeRandoZX.jar'), None) if (comun.TOOLS / 'upr').exists() else None


def descargar(repo, patron, destino, nombre):
    comun.tarea(f'Buscando la última versión de {nombre}…')
    with urllib.request.urlopen(f'https://api.github.com/repos/{repo}/releases/latest') as r:
        rel = json.load(r)
    asset = next(a for a in rel['assets'] if re.fullmatch(patron, a['name']))
    descargar_zip(asset['browser_download_url'], destino, f'{nombre} {rel["tag_name"]}')


def descargar_java():
    """Java 17 portable (Temurin, de Adoptium) dentro de tools/java: el randomizador lo necesita.
    Tiene que ser el JDK y no el JRE: LockeSettings.java se ejecuta como fuente y eso pide jdk.compiler."""
    descargar_zip('https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse',
                  comun.TOOLS / 'java', 'Java 17')


def descargar_zip(url, destino, nombre):
    zip_tmp = comun.TOOLS / 'descarga.zip'
    comun.TOOLS.mkdir(exist_ok=True)

    def progreso(bloques, tam, total):
        if total > 0:
            pct = min(100, bloques * tam * 100 // total)
            comun.tarea(f'Descargando {nombre}…', paso=1, pct=pct)
    try:
        urllib.request.urlretrieve(url, zip_tmp, progreso)
        comun.tarea(f'Descomprimiendo {nombre}…', paso=1)
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
        descargar('azahar-emu/azahar', r'azahar-windows-msvc-[\d.]+\.zip', comun.TOOLS / 'azahar', 'Azahar')
    if not upr_jar():
        descargar('Ajarmar/universal-pokemon-randomizer-zx', r'PokeRandoZX-.*\.zip', comun.TOOLS / 'upr',
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
    if comun.red['sesion'] and conexion.online_direccion():
        poner('Multiplayer', 'nickname', comun.red['sesion']['usuario'])
        poner('Multiplayer', 'ip', conexion.online_direccion())          # el anfitrión, a sí mismo
        poner('Multiplayer', 'port', online.PUERTO_SALA)
    # modo ligero (Opciones): resolución interna nativa, lo que más pesa en una gráfica integrada. Al quitarlo vuelve
    # la que hubiera antes
    ajustes = comun.biblio.setdefault('ajustes', {})
    if ajustes.get('ligero'):
        if 'resolucion_antes' not in ajustes:
            ajustes['resolucion_antes'] = ini.get('Renderer', 'resolution_factor', fallback=None)
        poner('Renderer', 'resolution_factor', 1)
    elif 'resolucion_antes' in ajustes:
        antes = ajustes.pop('resolucion_antes')
        if antes is None:
            for clave in ('resolution_factor', 'resolution_factor\\default'):
                if ini.has_option('Renderer', clave):
                    ini.remove_option('Renderer', clave)
        else:
            poner('Renderer', 'resolution_factor', antes)
    comun.guardar()
    poner('Layout', 'layout_option', 6)                  # LayoutOption::CustomLayout
    # Citra 1920 no tiene la opción 6 (el lanzador la pasa a 0): usa custom_layout con izquierda/arriba/derecha/abajo
    poner('Layout', 'custom_layout', 'true')
    s, ox, oy = comun.encaje()
    for nombre, (x, y, w, h) in (('top', comun.HUECO_ARRIBA), ('bottom', comun.HUECO_ABAJO)):
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
    return next((comun.TOOLS / 'makerom').rglob('makerom.exe'), None) if (comun.TOOLS / 'makerom').exists() else None


def rom_jugable(j):
    """La ROM que abren el randomizador y Azahar. Un .cia se convierte una vez a .cci (makerom) dentro de
    datos/juegos/<id>/; el .cia original no se toca. Solo vale si el .cia está descifrado."""
    if not j['ruta'].lower().endswith('.cia'):
        return j['ruta']
    cci = comun.DATOS / 'juegos' / j['id'] / 'rom.cci'
    if cci.exists() and cci.stat().st_mtime >= Path(j['ruta']).stat().st_mtime:
        return str(cci)
    if not makerom_exe():
        descargar('3DSGuy/Project_CTR', r'makerom-v[\d.]+-win_x86_64\.zip', comun.TOOLS / 'makerom', 'makerom')
    comun.tarea('Convirtiendo el .cia a .cci…', paso=1)
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
    return ['-cp', str(jar), str(comun.APP / f'{nombre}.java')]


def randomizar(j, opciones, avanzado, reglas=None):
    jar, jv = upr_jar(), java()
    carpeta = comun.DATOS / 'juegos' / j['id']
    carpeta.mkdir(parents=True, exist_ok=True)
    ajustes = comun.DATOS / 'avanzado.rnqs' if avanzado else carpeta / 'ajustes.rnqs'
    if avanzado:
        if not ajustes.exists():
            raise RuntimeError('Guarda antes los ajustes del UPR completo en datos/avanzado.rnqs')
    else:
        malas = set(opciones) - comun.OPCIONES
        if malas:
            raise RuntimeError(f'Opciones desconocidas: {malas}')
        comun.tarea('Preparando los ajustes…', paso=2)
        correr([jv, *clase_pokelocke(jar, 'LockeSettings'), str(ajustes)]
               + [f'{k}={v}' for k, v in opciones.items()], jar.parent)
    salida = comun.TOOLS / 'salida'
    shutil.rmtree(salida, ignore_errors=True)
    salida.mkdir(parents=True)
    comun.tarea('Randomizando el juego… (puede tardar un par de minutos)', paso=2)
    if reglas == 'mega':
        # una randomización y dos juegos: la fase fácil (hasta la segunda medalla) va de mod y la completa se
        # guarda aparte para cuando se gane la segunda medalla
        correr([jv, '-Xmx4096M', *clase_pokelocke(jar, 'MegaFases'), rom_jugable(j), str(ajustes),
                str(salida / 'completa'), str(salida / 'facil'), str(salida / 'y.log')], jar.parent)
        versiones = {'mod': salida / 'facil', locke.MOD_COMPLETO: salida / 'completa'}
    else:
        correr([jv, '-jar', str(jar), 'cli', '-i', rom_jugable(j), '-o', str(salida / 'y'),
                '-s', str(ajustes), '-d', '-l'], jar.parent)
        versiones = {'mod': salida}
    shutil.rmtree(carpeta / locke.MOD_COMPLETO, ignore_errors=True)
    for nombre, origen in versiones.items():
        romfs = next(origen.rglob('romfs'))
        titulo = romfs.parent.name if re.fullmatch(r'[0-9A-Fa-f]{16}', romfs.parent.name) else comun.TITLE_Y
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
    comun.vivo['proceso'] = None


def firma_mod(j):
    """Huella de los archivos de la randomización del juego."""
    origen = comun.DATOS / 'juegos' / j['id'] / 'mod'
    if not (j.get('random') and origen.exists()):
        return 'ninguno'
    return hashlib.sha1(json.dumps(sorted(
        (str(f.relative_to(origen)), f.stat().st_size, f.stat().st_mtime_ns) for f in origen.rglob('*') if f.is_file()
    )).encode()).hexdigest()


def poner_mod(j):
    """Copia la randomización del juego a la carpeta de mods del emulador, solo si no es ya la que hay: antes se
    borraba y se copiaba entera cada vez que se abría el juego (segundos en un disco lento)."""
    mods = carpeta_mods()
    marca = mods.parent / 'pokelocke-mod.txt'
    origen = comun.DATOS / 'juegos' / j['id'] / 'mod'
    origen = origen if j.get('random') and origen.exists() else None
    firma = f'{j["id"]} {firma_mod(j)}'
    try:
        if mods.exists() and marca.read_text(encoding='utf-8') == firma:
            return
    except OSError:
        pass
    shutil.rmtree(mods, ignore_errors=True)
    mods.mkdir(parents=True)
    if origen:
        shutil.copytree(origen, mods, dirs_exist_ok=True)
    marca.write_text(firma, encoding='utf-8')


TIENDAS_VERSION = 3       # 2: también las de MT (con objetos) · 3: las de MT venden MT al azar


def tiendas_al_azar(j, mensaje='Poniendo tiendas aleatorias en tu partida… (solo esta vez)', reglas=None):
    """Las tiendas del segundo dependiente de los Centros, aleatorias (normas Mega). El randomizador solo cambia las
    tiendas «especiales» y se salta las de MT (las de Luminalia), que salían iguales en todas las partidas; y las
    partidas randomizadas antes de la 1.2.0 no tienen ni las especiales. Las tiendas de Pokémon Y están en el code.bin
    del mod: TiendasAzar.java las cambia ahí, con las mismas reglas que las partidas nuevas y sin volver a randomizar
    nada más. Se hace al randomizar y, en las partidas que ya había, una vez al abrir el juego; si falla se juega igual
    y se vuelve a intentar la próxima vez."""
    r = j.get('random') or {}
    if (reglas or j.get('reglas')) != 'mega' or r.get('avanzado') \
            or (j.get('tiendas_parche') or {}).get('version') == TIENDAS_VERSION:
        return
    carpeta = comun.DATOS / 'juegos' / j['id']
    codigos = [c for v in ('mod', locke.MOD_COMPLETO) for c in (carpeta / v).glob('*/code.bin')]
    if not codigos:
        return
    registro = carpeta / 'tiendas_parche.log'
    # la huella de los archivos (vigia) cambia con el parche: se renueva, pero solo si cuadraba antes (si no, que
    # siga saltando el aviso de archivos tocados)
    huella_buena = j.get('firma_mod') == firma_mod(j)
    comun.tarea(mensaje)
    try:
        jar, jv = upr_jar(), java()
        salida = correr([jv, '-Xmx2048M', *clase_pokelocke(jar, 'TiendasAzar'), rom_jugable(j),
                         *map(str, codigos), str(registro)], jar.parent)
    except Exception:
        traceback.print_exc()
        return
    estado = 'hecho' if 'Hecho' in salida else 'sin tiendas' if 'SIN TIENDAS' in salida else 'ya estaban'
    print(time.strftime('%H:%M:%S'), 'tiendas al azar:', estado, flush=True)
    if estado == 'hecho' and registro.exists():
        with open(carpeta / 'randomizacion.log', 'a', encoding='utf-8') as f:
            f.write('\n' + registro.read_text(encoding='utf-8'))
    with comun.lock:
        j['tiendas_parche'] = {'estado': estado, 'version': TIENDAS_VERSION, 'fecha': time.strftime('%Y-%m-%d %H:%M')}
        if estado == 'hecho' and huella_buena:
            j['firma_mod'] = firma_mod(j)
        comun.guardar()


PERSONAL_VERSION = 1      # 1: MT al azar (si eran las del juego original) y sin Superguarda (1.2.4)


def personal_al_azar(j, mensaje='Poniendo MT al azar y quitando Superguarda en tu partida… (solo esta vez)', reglas=None):
    """Los datos de cada Pokémon del mod (romfs/a/2/1/8), normas Mega: hasta la 1.2.4 la app no pedía al randomizador
    que cambiara qué MT aprende cada uno (se quedaban las del juego, casi siempre las de su tipo) y dejaba salir
    Superguarda. PersonalAzar.java sortea las MT con el randomizador (totalmente al azar, con todas las MO) y cambia
    Superguarda por otra habilidad, sin tocar nada más. Como tiendas_al_azar: al randomizar y, en las partidas que ya
    había, una vez al abrir el juego; si falla se juega igual y se vuelve a intentar la próxima vez."""
    r = j.get('random') or {}
    if (reglas or j.get('reglas')) != 'mega' or r.get('avanzado')             or (j.get('personal_parche') or {}).get('version') == PERSONAL_VERSION:
        return
    carpeta = comun.DATOS / 'juegos' / j['id']
    personales = [t / 'romfs' / 'a' / '2' / '1' / '8' for v in ('mod', locke.MOD_COMPLETO) for t in (carpeta / v).glob('*')
                  if (t / 'code.bin').exists()]
    if not personales:
        return
    registro = carpeta / 'personal_parche.log'
    huella_buena = j.get('firma_mod') == firma_mod(j)
    comun.tarea(mensaje)
    try:
        jar, jv = upr_jar(), java()
        salida = correr([jv, '-Xmx2048M', *clase_pokelocke(jar, 'PersonalAzar'), rom_jugable(j),
                         *map(str, personales), str(registro)], jar.parent)
    except Exception:
        traceback.print_exc()
        return
    estado = 'hecho' if 'Hecho' in salida else 'ya estaban'
    print(time.strftime('%H:%M:%S'), 'MT y habilidades:', estado, flush=True)
    if estado == 'hecho' and registro.exists():
        with open(carpeta / 'randomizacion.log', 'a', encoding='utf-8') as f:
            f.write('\n' + registro.read_text(encoding='utf-8'))
    with comun.lock:
        j['personal_parche'] = {'estado': estado, 'version': PERSONAL_VERSION, 'fecha': time.strftime('%Y-%m-%d %H:%M')}
        if estado == 'hecho':
            import guardado                     # los datos de los huevos se vuelven a leer del registro nuevo
            guardado.hex_vivo['datos'].pop(j['id'], None)
            if huella_buena:
                j['firma_mod'] = firma_mod(j)
        comun.guardar()


def mt_fijas(j):
    """Las MT de la fase fácil, también en la completa (normas Mega, 1.2.4). Hasta la 1.2.4 la fase fácil cambiaba las
    MT de 70 o más por otras más flojas solo en su mod, y al abrir la randomización completa (2.ª medalla) las MT
    enseñaban otros ataques. MTFijas.java copia los ataques de cada MT al code.bin de la completa, y aquí se copia el
    texto con sus descripciones (romfs/a/0/7/4). Solo con la partida aún en la fase 1: la fase fácil se borra al pasar
    a la completa y ya no se sabe qué MT tenía. Una vez por partida; si falla se juega igual."""
    r = j.get('random') or {}
    carpeta = comun.DATOS / 'juegos' / j['id']
    if j.get('reglas') != 'mega' or r.get('avanzado') or j.get('fase') != 1 or j.get('mt_fijas')             or not (carpeta / locke.MOD_COMPLETO).exists():
        return
    pares = [(t, carpeta / locke.MOD_COMPLETO / t.name) for t in (carpeta / 'mod').glob('*')
             if (t / 'code.bin').exists() and (carpeta / locke.MOD_COMPLETO / t.name / 'code.bin').exists()]
    if not pares:
        return
    huella_buena = j.get('firma_mod') == firma_mod(j)
    comun.tarea('Dejando las MT iguales para toda la partida… (solo esta vez)')
    estado = 'ya estaban'
    try:
        jar, jv = upr_jar(), java()
        for facil, completa in pares:
            salida = correr([jv, '-Xmx2048M', *clase_pokelocke(jar, 'MTFijas'), rom_jugable(j),
                             str(facil / 'code.bin'), str(completa / 'code.bin')], jar.parent)
            if 'Hecho' in salida:
                estado = 'hecho'
                texto = facil / 'romfs' / 'a' / '0' / '7' / '4'
                if texto.exists():
                    (completa / 'romfs' / 'a' / '0' / '7').mkdir(parents=True, exist_ok=True)
                    shutil.copy2(texto, completa / 'romfs' / 'a' / '0' / '7' / '4')
    except Exception:
        traceback.print_exc()
        return
    print(time.strftime('%H:%M:%S'), 'MT fijas:', estado, flush=True)
    with comun.lock:
        j['mt_fijas'] = {'estado': estado, 'fecha': time.strftime('%Y-%m-%d %H:%M')}
        if estado == 'hecho' and huella_buena:
            j['firma_mod'] = firma_mod(j)
        comun.guardar()


def _sortear_mt(j, maximo, mensaje):
    """Lee las MT de la mochila de la partida guardada y sortea el ataque de todas las demas con MTAzar.java (de menos
    de maximo + 1 de potencia), en mod y mod_completo. Devuelve las MT respetadas, o None si no se ha podido (no se
    toca nada y se vuelve a intentar la proxima vez)."""
    carpeta = comun.DATOS / 'juegos' / j['id']
    codigos = [c for v in ('mod', locke.MOD_COMPLETO) for c in (carpeta / v).glob('*/code.bin')]
    if not codigos:
        return None
    try:
        import guardado, pokehex
        bolsa = pokehex.Partida(guardado.pokehex_partida(j)).mochila()['mt']
        guardar = sorted({pokehex.OBJETOS_MT.index(x['objeto']) + 1 for x in bolsa if x['objeto'] in pokehex.OBJETOS_MT})
    except Exception:
        traceback.print_exc()
        return None
    registro = carpeta / 'mt_azar.log'
    huella_buena = j.get('firma_mod') == firma_mod(j)
    comun.tarea(mensaje)
    try:
        jar, jv = upr_jar(), java()
        salida = correr([jv, '-Xmx2048M', *clase_pokelocke(jar, 'MTAzar'), rom_jugable(j), f'max={maximo}',
                         ','.join(map(str, guardar)), *map(str, codigos), str(registro)], jar.parent)
    except Exception:
        traceback.print_exc()
        return None
    hecho = 'Hecho' in salida
    print(time.strftime('%H:%M:%S'), f'MT al azar (max {maximo}):', 'hecho' if hecho else 'fallo', flush=True)
    if not hecho:
        return None
    if registro.exists():
        with open(carpeta / 'randomizacion.log', 'a', encoding='utf-8') as f:
            f.write('\n' + registro.read_text(encoding='utf-8'))
    if huella_buena:
        with comun.lock:
            j['firma_mod'] = firma_mod(j)
    return guardar


def mt_azar(j):
    """El ataque de cada MT, al azar en cada partida (normas Mega, 1.2.6): hasta la 1.2.6 cada MT ensenaba el mismo
    ataque en todas las rooms (las partidas nuevas ya salen al azar del randomizador). Las MT que el jugador ya tiene
    en la mochila no cambian, ni las de uso fuera de combate; las demas, de menos de 70 de potencia (la norma de la fase
    facil). Va despues de mt_fijas. Una vez por partida."""
    r = j.get('random') or {}
    if j.get('reglas') != 'mega' or not j.get('random') or r.get('avanzado') or j.get('mt_azar'):
        return
    guardar = _sortear_mt(j, 69, 'Sorteando el ataque de cada MT (las de tu mochila no cambian)… (solo esta vez)')
    if guardar is not None:
        with comun.lock:
            j['mt_azar'] = {'estado': 'hecho', 'guardadas': guardar, 'fecha': time.strftime('%Y-%m-%d %H:%M')}
            comun.guardar()


def mt_fuertes(j):
    """Las MT que no estan en la mochila se sortean otra vez SIN limite de potencia, en cualquier fase (David,
    2026-11-11: «a partir de ahora las MT salen random sin limitaciones»; la MT25 deja de ser Trueno). Las de la
    mochila no cambian, ni las MO (MTAzar solo toca las MT) ni las de uso fuera de combate. Una vez por partida, en la
    primera apertura con la 1.3.0; las partidas nuevas ya salen asi del randomizador (preparar lo marca)."""
    r = j.get('random') or {}
    if j.get('reglas') != 'mega' or not j.get('random') or r.get('avanzado') or j.get('mt_fuertes'):
        return
    guardar = _sortear_mt(j, 999, 'Sorteando MT nuevas (las de tu mochila no cambian)… (solo esta vez)')
    if guardar is not None:
        with comun.lock:
            j['mt_fuertes'] = {'estado': 'hecho', 'guardadas': guardar, 'fecha': time.strftime('%Y-%m-%d %H:%M')}
            comun.guardar()


def mega_torre(j):
    """La mega de la Torre Maestra (normas Mega, 1.3.1): el regalo de Corelia tras la 3.a medalla pasa a ser un Pokemon
    al azar NO legendario que pueda megaevolucionar, con su megapiedra equipada (MegaTorre.java, sobre el DllField.cro
    del mod). Distinto en cada partida, el mismo en sus dos fases. Las partidas nuevas ya salen asi de MegaFases
    (preparar lo marca). Una vez por partida; si falla se juega igual y se reintenta. Quien ya lo recogio se queda el
    suyo (esta en su partida)."""
    r = j.get('random') or {}
    if j.get('reglas') != 'mega' or not j.get('random') or r.get('avanzado') or j.get('mega_torre'):
        return
    carpeta = comun.DATOS / 'juegos' / j['id']
    campos = [c for v in ('mod', locke.MOD_COMPLETO) for c in (carpeta / v).glob('*/romfs/DllField.cro')]
    if not campos:
        return
    huella_buena = j.get('firma_mod') == firma_mod(j)
    comun.tarea('Preparando la mega de la Torre Maestra… (solo esta vez)')
    try:
        jar, jv = upr_jar(), java()
        salida = correr([jv, '-Xmx2048M', *clase_pokelocke(jar, 'MegaTorre'), rom_jugable(j), *map(str, campos)], jar.parent)
    except Exception:
        traceback.print_exc()
        return
    linea = next((l for l in salida.splitlines() if l.startswith(('Hecho', 'YA', 'SIN REGALO'))), '')
    print(time.strftime('%H:%M:%S'), 'mega de la Torre Maestra:', linea, flush=True)
    if not linea:
        return
    if linea.startswith('Hecho'):
        with open(carpeta / 'randomizacion.log', 'a', encoding='utf-8') as f:
            f.write('\n--Pokelocke: la mega de la Torre Maestra--\nTorre Maestra: ' + linea[6:] + ' equipada\n')
    with comun.lock:
        j['mega_torre'] = {'estado': linea.split()[0].lower(), 'regalo': linea[6:] if linea.startswith('Hecho') else '',
                           'fecha': time.strftime('%Y-%m-%d %H:%M')}
        if linea.startswith('Hecho') and huella_buena:
            j['firma_mod'] = firma_mod(j)
        comun.guardar()


# Cambios de MT a mano en partidas concretas (MTVolver.java): id -> (version, "mt:nuevo:actual ..."). Cada MT pasa al
# ataque «nuevo» solo si sigue con «actual» (números de ataque de datos_pkx/Moves.txt: línea - 1). La version se apunta
# en j['mt_vuelta']: subirla vuelve a aplicar.
# Historial: e911dd18d8 (Cesbay), version 1 (1.2.8, 2026-11-11): se deshizo su sorteo de la 1.2.7 con los pares de su
# mt_azar.log -> volvieron las MT del juego original y las flojas de la fase 1. Ya aplicado; luego, mt_fuertes (1.2.9).
MT_VOLVER = {}

def mt_volver(j):
    """Aplica los cambios de MT a mano de MT_VOLVER a su partida (MTVolver.java): una vez por version, despues de
    mt_azar; solo las MT que siguen con el ataque de partida. Si falla se juega igual y se reintenta."""
    version, cambios = MT_VOLVER.get(j['id'], (None, None))
    hecha = j.get('mt_vuelta')                  # la de la 1.2.8 se apunto sin version: era la 1
    if not cambios or (hecha.get('version', 1) if hecha else 0) >= version             or not (j.get('mt_azar') or {}).get('estado') == 'hecho':
        return
    carpeta = comun.DATOS / 'juegos' / j['id']
    codigos = [c for v in ('mod', locke.MOD_COMPLETO) for c in (carpeta / v).glob('*/code.bin')]
    if not codigos:
        return
    huella_buena = j.get('firma_mod') == firma_mod(j)
    comun.tarea('Poniendo tus MT al dia… (solo esta vez)')
    try:
        jar, jv = upr_jar(), java()
        salida = correr([jv, '-Xmx2048M', *clase_pokelocke(jar, 'MTVolver'), rom_jugable(j), cambios,
                         *map(str, codigos)], jar.parent)
    except Exception:
        traceback.print_exc()
        return
    estado = 'hecho' if 'Hecho' in salida else 'ya estaban' if 'YA' in salida else 'fallo'
    print(time.strftime('%H:%M:%S'), 'MT a mano:', estado, salida.strip()[-40:], flush=True)
    if estado == 'fallo':
        return
    with open(carpeta / 'randomizacion.log', 'a', encoding='utf-8') as f:
        f.write(f'\n--Pokelocke: cambios de MT a mano, version {version} ({estado})--\n')
    with comun.lock:
        j['mt_vuelta'] = {'estado': estado, 'version': version, 'fecha': time.strftime('%Y-%m-%d %H:%M')}
        if estado == 'hecho' and huella_buena:
            j['firma_mod'] = firma_mod(j)
        comun.guardar()


def _garc(b):
    """Dónde está cada archivo de un GARC del romfs: [(inicio, largo)] del primer subarchivo de cada uno."""
    if b[:4] != b'CRAG':
        raise ValueError('no es un GARC')
    datos = struct.unpack_from('<I', b, 0x10)[0]
    o = struct.unpack_from('<I', b, 4)[0]
    o += struct.unpack_from('<I', b, o + 4)[0]                     # FATO, y detrás FATB
    if b[o:o + 4] != b'BTAF':
        raise ValueError('GARC sin FATB')
    p, sitios = o + 12, []
    for _ in range(struct.unpack_from('<I', b, o + 8)[0]):
        bits = struct.unpack_from('<I', b, p)[0]
        p += 4
        primero = None
        for k in range(32):
            if bits >> k & 1:
                ini, _fin, largo = struct.unpack_from('<III', b, p)
                p += 12
                primero = primero or (datos + ini, largo)
        sitios.append(primero)
    return sitios


ENTRENADORES, EQUIPOS = 'a/0/3/8', 'a/0/4/0'      # trdata y trpoke de Pokémon X/Y en el romfs
LEM, ALIANA_CENTRAL = 23, 175                    # índices de entrenador de la ROM


def niveles_entrenador(trdata, trpoke, i):
    """[(posición del nivel en trpoke, nivel)] de cada Pokémon del entrenador i."""
    sd, sp = _garc(trdata), _garc(trpoke)
    d = trdata[sd[i][0]:sd[i][0] + sd[i][1]]
    ancho = 8 + (2 if d[0] & 2 else 0) + (8 if d[0] & 1 else 0)  # con objeto y/o con ataques propios
    ini = sp[i][0]
    return [(ini + k * ancho + 2, struct.unpack_from('<H', trpoke, ini + k * ancho + 2)[0]) for k in range(d[3])]


def aliana_bajo_tope(j):
    """Normas Mega: Aliana en la Central Eléctrica va antes que Lem y salía por encima de su nivel tope (el de Lem):
    ningún Pokémon suyo pasa de un nivel menos que el tope. Se arregla en el mod de la partida, en el sitio (mismo
    tamaño), cada vez que se abre el juego; si ya está bien no toca nada. Si falla, se juega igual."""
    if j.get('reglas') != 'mega' or not j.get('random'):
        return
    romfs = next((comun.DATOS / 'juegos' / j['id'] / 'mod').glob('*/romfs'), None)
    if not romfs or not (romfs / ENTRENADORES).exists() or not (romfs / EQUIPOS).exists():
        return
    try:
        trdata, trpoke = (romfs / ENTRENADORES).read_bytes(), bytearray((romfs / EQUIPOS).read_bytes())
        maximo = max(n for _, n in niveles_entrenador(trdata, trpoke, LEM)) - 1
        altos = [(sitio, n) for sitio, n in niveles_entrenador(trdata, trpoke, ALIANA_CENTRAL) if n > maximo]
        if not altos or maximo < 1:
            return
        for sitio, _ in altos:
            struct.pack_into('<H', trpoke, sitio, maximo)
        nuevo = romfs / (EQUIPOS + '.nuevo')
        nuevo.write_bytes(trpoke)
        os.replace(nuevo, romfs / EQUIPOS)
    except (ValueError, struct.error, IndexError, OSError):
        traceback.print_exc()
        return
    with open(comun.DATOS / 'juegos' / j['id'] / 'randomizacion.log', 'a', encoding='utf-8') as f:
        f.write(f'\n--Pokelocke: Aliana (Central Eléctrica) {", ".join(f"Lv{n}" for _, n in altos)} -> Lv{maximo}, '
                f'uno menos que el tope de Lem--\n')
    print(time.strftime('%H:%M:%S'), 'Aliana bajada a', maximo, flush=True)


def lanzar(j):
    """Pone el mod del juego (o ninguno), abre Azahar a pantalla completa y la capa del layout encima."""
    print(time.strftime('%H:%M:%S'), 'abrir el juego', j['id'], flush=True)
    cerrar_citra_colgado()
    if not Path(j['ruta']).exists():
        raise RuntimeError(f'No encuentro la ROM: {j["ruta"]}')
    exe = configurar_azahar()
    tiendas_al_azar(j)
    personal_al_azar(j)
    mt_fijas(j)                               # antes de abrir la fase completa
    mt_azar(j)
    mt_volver(j)
    mega_torre(j)
    with comun.lock:
        vigia.abrir(j)
        for dar in (locke.dar_caramelos, locke.dar_escamas):
            try:
                dar(j)
            except (ValueError, OSError):           # si no se pueden dar, se juega igual y se prueba la próxima vez
                traceback.print_exc()
        completa = j.get('fase') == 1 and locke.medallas_partida(j) >= locke.MEDALLAS_PARA_COMPLETA and locke.abrir_fase_completa(j)
        aliana_bajo_tope(j)                   # en el mod que se va a jugar (ya con la fase completa si toca)
        j['firma_mod'] = firma_mod(j)
    mt_fuertes(j)                             # despues de abrir la fase completa: antes de poner el mod
    poner_mod(j)
    guardado.fijo_por_defecto(j)
    try:
        guardado.copiar_partida(j, 'al-abrir')
    except OSError:
        traceback.print_exc()                              # sin copia, pero se juega igual
    comun.vivo.update(activo=j['id'], equipo=[None] * 6, conectado=False, combate_visto_desde=None, jugaba=True)
    comun.vivo.update(lanzado=time.time(), juego_visto=None, mirado=0, ventana_juego=False,
                citra=(Path(exe).parent / 'citra-qt.exe').exists())
    comun.vivo['proceso'] = subprocess.Popen([str(exe), '-f', rom_jugable(j)])
    if completa:
        comun.avisar('¡Randomización completa! · Ahora los rivales sacan cualquier evolución y cualquier ataque', 25)
    yo = [sys.executable] if getattr(sys, 'frozen', False) else [sys.executable, str(Path(__file__))]
    subprocess.Popen(yo + ['--capa'])                     # la capa la pinta pintor_capa cuando el juego ya ha cargado


def preparar(j, opciones, vidas_ini, randomizar_juego, avanzado, reglas=None):
    if reglas == 'mega':
        vidas_ini = locke.VIDAS_MEGA
    comun.vivo['tarea']['random'] = randomizar_juego
    comun.tarea('Preparando el emulador y el randomizador…', paso=1)
    herramientas()
    if randomizar_juego:
        randomizar(j, opciones, avanzado, reglas)
        j.pop('tiendas_parche', None)
        tiendas_al_azar(j, 'Poniendo tiendas aleatorias…', reglas)
        j.pop('personal_parche', None)
        personal_al_azar(j, 'Revisando las MT y las habilidades…', reglas)
        j['mt_fijas'] = {'estado': 'de serie', 'fecha': time.strftime('%Y-%m-%d %H:%M')}   # MegaFases ya las deja iguales
        j['mt_azar'] = {'estado': 'de serie', 'fecha': time.strftime('%Y-%m-%d %H:%M')}    # el randomizador ya las sortea
        j['mt_fuertes'] = {'estado': 'de serie', 'fecha': time.strftime('%Y-%m-%d %H:%M')}  # sin limite de potencia
        j['mega_torre'] = {'estado': 'de serie', 'fecha': time.strftime('%Y-%m-%d %H:%M')}   # MegaFases ya la pone
    else:
        j['random'] = None
    with comun.lock:
        locke.nuevo_locke(j, vidas_ini, reglas)
        j['preparado'] = True
        j['firma_mod'] = firma_mod(j)
        vigia.anotar_partida(j)
        vigia.evento('preparar', f'Prepara el juego · {"normas Mega" if reglas == "mega" else "sin las normas Mega"} · {vidas_ini} vidas'
                     + (' · ajustes avanzados' if avanzado else ''), 'info' if reglas == 'mega' and not avanzado else 'sospecha',
                     vidas=locke.vidas(j))
        comun.guardar()
    espera = comun.vivo['tarea']['minimo'] - (time.time() - comun.vivo['tarea']['inicio'])
    if espera > 0:                                    # el modal de carga dura como poco su minuto
        time.sleep(espera)
    comun.tarea('¡Todo listo!', paso=3)               # se vuelve a la biblioteca: el juego se abre al darle a Jugar


def cargando():
    """Segundos que lleva abriéndose el juego, o None si ya ha salido su ventana (o no hay juego)."""
    if not (jugando() and comun.vivo.get('citra')):
        return None
    if not comun.vivo.get('ventana_juego'):
        citra_listo()                                   # mira la ventana también aquí, no solo en seguimiento()
    s = time.time() - comun.vivo.get('lanzado', 0)
    return None if comun.vivo.get('ventana_juego') or s > CAPA_MAX else round(s)
