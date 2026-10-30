"""El emulador: Citra/Azahar, Java y el randomizador, la ROM, los mods y abrir el juego."""
import configparser
import ctypes
import hashlib
import json
import os
import re
import shutil
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
    return next((comun.TOOLS / 'azahar').rglob('azahar.exe'), None) if (comun.TOOLS / 'azahar').exists() else None


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


def poner_mod(j):
    """Copia la randomización del juego a la carpeta de mods del emulador, solo si no es ya la que hay: antes se
    borraba y se copiaba entera cada vez que se abría el juego (segundos en un disco lento)."""
    mods = carpeta_mods()
    marca = mods.parent / 'pokelocke-mod.txt'
    mod = comun.DATOS / 'juegos' / j['id'] / 'mod'
    origen = mod if j.get('random') and mod.exists() else None
    firma = 'ninguno' if not origen else hashlib.sha1(json.dumps(sorted(
        (str(f.relative_to(origen)), f.stat().st_size, f.stat().st_mtime_ns) for f in origen.rglob('*') if f.is_file()
    )).encode()).hexdigest()
    firma = f'{j["id"]} {firma}'
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


def lanzar(j):
    """Pone el mod del juego (o ninguno), abre Azahar a pantalla completa y la capa del layout encima."""
    print(time.strftime('%H:%M:%S'), 'abrir el juego', j['id'], flush=True)
    cerrar_citra_colgado()
    if not Path(j['ruta']).exists():
        raise RuntimeError(f'No encuentro la ROM: {j["ruta"]}')
    exe = configurar_azahar()
    with comun.lock:
        locke.dar_caramelos(j)
        completa = j.get('fase') == 1 and locke.medallas_partida(j) >= locke.MEDALLAS_PARA_COMPLETA and locke.abrir_fase_completa(j)
    poner_mod(j)
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
    else:
        j['random'] = None
    with comun.lock:
        locke.nuevo_locke(j, vidas_ini, reglas)
        j['preparado'] = True
        comun.guardar()
    espera = comun.vivo['tarea']['minimo'] - (time.time() - comun.vivo['tarea']['inicio'])
    if espera > 0:                                    # el modal de carga dura como poco su minuto
        time.sleep(espera)
    comun.tarea('Abriendo el juego con el layout…', paso=3)
    lanzar(j)


def cargando():
    """Segundos que lleva abriéndose el juego, o None si ya ha salido su ventana (o no hay juego)."""
    if not (jugando() and comun.vivo.get('citra')):
        return None
    if not comun.vivo.get('ventana_juego'):
        citra_listo()                                   # mira la ventana también aquí, no solo en seguimiento()
    s = time.time() - comun.vivo.get('lanzado', 0)
    return None if comun.vivo.get('ventana_juego') or s > CAPA_MAX else round(s)
