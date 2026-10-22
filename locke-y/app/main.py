"""Pokelocke: lanzador del juego, seguimiento del locke y overlay para OBS.

Todo vive dentro de locke-y/ y no se instala nada en el sistema:
  tools/   Azahar portable, Universal Pokemon Randomizer ZX y caché de arte (no se sube a git)
  rom/     tu ROM descifrada de Pokémon Y (no se sube a git)
  datos/   partida del locke, ajustes y log de la randomización (no se sube a git)
  fanart/  arte propio por especie: 658.png, 658.jpg... (no se sube a git)
Arranque: Pokelocke.bat  →  lanzador en http://localhost:8765, overlay en /overlay
"""
import configparser
import json
import os
import re
import shutil
import subprocess
import threading
import time
import traceback
import urllib.request
import webbrowser
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import juego

RAIZ = Path(__file__).resolve().parent.parent
APP, WEB, ASSETS = RAIZ / 'app', RAIZ / 'app' / 'web', RAIZ / 'assets'
TOOLS, ROMS, DATOS, FANART = RAIZ / 'tools', RAIZ / 'rom', RAIZ / 'datos', RAIZ / 'fanart'
CACHE_ARTE = TOOLS / 'arte'
ESTADO = DATOS / 'estado.json'
PUERTO = 8765
TITLE_Y = '0004000000055E00'
ARTE_URL = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{}.png'

# campos de Settings que el menú puede tocar (el resto queda como en el UPR por defecto)
OPCIONES = {
    'wildPokemonMod', 'wildPokemonRestrictionMod', 'blockWildLegendaries', 'useMinimumCatchRate',
    'minimumCatchRateLevel', 'wildLevelsModified', 'wildLevelModifier', 'startersMod',
    'limitMainGameLegendaries', 'trainersMod', 'trainersUsePokemonOfSimilarStrength',
    'trainersLevelModified', 'trainersLevelModifier', 'trainersForceFullyEvolved', 'staticPokemonMod',
    'abilitiesMod', 'typesMod', 'baseStatisticsMod', 'evolutionsMod', 'evosSimilarStrength',
    'movesetsMod', 'fieldItemsMod', 'inGameTradesMod',
}

lock = threading.Lock()
estado = {'vidas_iniciales': 25, 'ajuste_vidas': 0, 'muertos': [], 'medallas': [False] * 8,
          'random': None}
vivo = {'equipo': [None] * 6, 'conectado': False, 'tarea': None}   # no se guarda en disco


def guardar():
    DATOS.mkdir(exist_ok=True)
    ESTADO.write_text(json.dumps(estado, indent=2, ensure_ascii=False), encoding='utf-8')


def cargar():
    if ESTADO.exists():
        estado.update(json.loads(ESTADO.read_text(encoding='utf-8')))


def vidas():
    return max(0, estado['vidas_iniciales'] + estado['ajuste_vidas'] - len(estado['muertos']))


# ---------- herramientas portables ----------

def java():
    candidatos = []
    if os.environ.get('JAVA_HOME'):
        candidatos.append(Path(os.environ['JAVA_HOME']) / 'bin' / 'java.exe')
    candidatos += sorted((Path.home() / '.jdks').glob('*/bin/java.exe'), reverse=True)
    for c in candidatos:
        if c.exists():
            return str(c)
    return shutil.which('java')


def azahar_exe():
    return next((TOOLS / 'azahar').rglob('azahar.exe'), None) if (TOOLS / 'azahar').exists() else None


def upr_jar():
    return next((TOOLS / 'upr').rglob('PokeRandoZX.jar'), None) if (TOOLS / 'upr').exists() else None


def roms():
    return sorted(p.name for p in ROMS.glob('*') if p.suffix.lower() in ('.3ds', '.cci', '.cxi', '.cia'))


def tarea(mensaje, error=False, fin=False):
    vivo['tarea'] = {'mensaje': mensaje, 'error': error, 'fin': fin}


def descargar(repo, patron, destino, nombre):
    tarea(f'Buscando la última versión de {nombre}…')
    with urllib.request.urlopen(f'https://api.github.com/repos/{repo}/releases/latest') as r:
        rel = json.load(r)
    asset = next(a for a in rel['assets'] if re.fullmatch(patron, a['name']))
    zip_tmp = TOOLS / 'descarga.zip'
    TOOLS.mkdir(exist_ok=True)

    def progreso(bloques, tam, total):
        if total > 0:
            tarea(f'Descargando {nombre} {rel["tag_name"]}… {min(100, bloques * tam * 100 // total)} %')
    try:
        urllib.request.urlretrieve(asset['browser_download_url'], zip_tmp, progreso)
        tarea(f'Descomprimiendo {nombre}…')
        shutil.rmtree(destino, ignore_errors=True)
        with zipfile.ZipFile(zip_tmp) as z:
            entradas = z.infolist()
            for m in entradas:
                m.filename = m.filename.replace('\\', '/')   # el zip de Azahar usa barras de Windows
            z.extractall(destino, members=entradas)
    finally:
        zip_tmp.unlink(missing_ok=True)


def preparar_azahar():
    """Modo portable (carpeta user/ junto al exe) y servidor RPC activado."""
    exe = azahar_exe()
    cfg = exe.parent / 'user' / 'config' / 'qt-config.ini'
    cfg.parent.mkdir(parents=True, exist_ok=True)
    ini = configparser.RawConfigParser()
    ini.optionxform = str
    if cfg.exists():
        ini.read(cfg, encoding='utf-8')
    if not ini.has_section('Debugging'):
        ini.add_section('Debugging')
    ini.set('Debugging', 'enable_rpc_server\\default', 'false')
    ini.set('Debugging', 'enable_rpc_server', 'true')
    with open(cfg, 'w', encoding='utf-8') as f:
        ini.write(f, space_around_delimiters=False)
    return exe


def carpeta_mods():
    return azahar_exe().parent / 'user' / 'load' / 'mods'


def correr(args, cwd):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip()[-1500:])
    return r.stdout


def randomizar(rom, opciones, avanzado):
    jar, jv = upr_jar(), java()
    ajustes = DATOS / ('avanzado.rnqs' if avanzado else 'ajustes.rnqs')
    DATOS.mkdir(exist_ok=True)
    if avanzado:
        if not ajustes.exists():
            raise RuntimeError('Guarda antes los ajustes del UPR completo en datos/avanzado.rnqs')
    else:
        malas = set(opciones) - OPCIONES
        if malas:
            raise RuntimeError(f'Opciones desconocidas: {malas}')
        tarea('Preparando los ajustes…')
        correr([jv, '-cp', str(jar), str(APP / 'LockeSettings.java'), str(ajustes)]
               + [f'{k}={v}' for k, v in opciones.items()], jar.parent)
    salida = TOOLS / 'salida'
    shutil.rmtree(salida, ignore_errors=True)
    salida.mkdir(parents=True)
    tarea('Randomizando el juego… (puede tardar un par de minutos)')
    correr([jv, '-jar', str(jar), 'cli', '-i', str(ROMS / rom), '-o', str(salida / 'y'),
            '-s', str(ajustes), '-d', '-l'], jar.parent)
    romfs = next(salida.rglob('romfs'))
    titulo = romfs.parent.name if re.fullmatch(r'[0-9A-Fa-f]{16}', romfs.parent.name) else TITLE_Y
    destino = carpeta_mods() / titulo
    shutil.rmtree(destino, ignore_errors=True)
    shutil.copytree(romfs.parent, destino)
    for log in salida.rglob('*.log'):
        shutil.copy(log, DATOS / 'randomizacion.log')
    with lock:
        estado['random'] = {'rom': rom, 'avanzado': avanzado, 'opciones': opciones,
                            'fecha': time.strftime('%Y-%m-%d %H:%M')}
        guardar()


def en_segundo_plano(nombre, fn, *args):
    if vivo['tarea'] and not vivo['tarea']['fin']:
        raise RuntimeError('Ya hay una tarea en marcha')

    def envoltura():
        try:
            fn(*args)
            tarea(f'{nombre}: hecho.', fin=True)
        except Exception as e:
            traceback.print_exc()
            tarea(f'{nombre}: {e}', error=True, fin=True)
    tarea(f'{nombre}…')
    threading.Thread(target=envoltura, daemon=True).start()


# ---------- seguimiento del locke ----------

def seguimiento():
    rpc = juego.RPC()
    while True:
        try:
            equipo = juego.leer_equipo(rpc)
            with lock:
                vivo['conectado'] = True
                vivo['equipo'] = equipo
                for p in equipo:
                    # un Pokémon a 0 PS cuenta como muerto una sola vez, aunque luego lo revivan
                    if p and not p['huevo'] and p['psmax'] and p['ps'] == 0 and p['id'] not in estado['muertos']:
                        estado['muertos'].append(p['id'])
                        guardar()
        except (OSError, TimeoutError):
            vivo['conectado'] = False
        time.sleep(1)


def foto_estado():
    with lock:
        return {
            'vidas': vidas(), 'vidas_iniciales': estado['vidas_iniciales'] + estado['ajuste_vidas'],
            'medallas': estado['medallas'], 'random': estado['random'],
            'equipo': [p and {**p, 'muerto': p['id'] in estado['muertos']} for p in vivo['equipo']],
            'conectado': vivo['conectado'], 'tarea': vivo['tarea'],
            'herramientas': {'azahar': bool(azahar_exe()), 'upr': bool(upr_jar()), 'java': java(),
                             'roms': roms(), 'avanzado': (DATOS / 'avanzado.rnqs').exists()},
        }


def arte(especie):
    """Fanart propio si existe (fanart/658.png|jpg|webp); si no, el arte oficial, guardado en caché."""
    for ext in ('png', 'jpg', 'jpeg', 'webp'):
        f = FANART / f'{especie}.{ext}'
        if f.exists():
            return f
    f = CACHE_ARTE / f'{especie}.png'
    if not f.exists():
        CACHE_ARTE.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(ARTE_URL.format(especie), f)
    return f


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
            return self.archivo(WEB / 'lanzador.html')
        if ruta == '/overlay':
            return self.archivo(WEB / 'overlay.html')
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
        if ruta == '/api/descargar':
            if d['que'] == 'azahar':
                en_segundo_plano('Descargar Azahar', descargar, 'azahar-emu/azahar',
                                 r'azahar-windows-msvc-[\d.]+\.zip', TOOLS / 'azahar', 'Azahar')
            else:
                en_segundo_plano('Descargar el randomizador', descargar,
                                 'Ajarmar/universal-pokemon-randomizer-zx', r'PokeRandoZX-.*\.zip',
                                 TOOLS / 'upr', 'Universal Pokemon Randomizer ZX')
        elif ruta == '/api/randomizar':
            if d['rom'] not in roms():
                raise RuntimeError('Elige una ROM de la carpeta rom/')
            en_segundo_plano('Randomizar', randomizar, d['rom'], d.get('opciones', {}), bool(d.get('avanzado')))
        elif ruta == '/api/quitar_random':
            for carpeta in carpeta_mods().glob('*'):
                shutil.rmtree(carpeta)
            with lock:
                estado['random'] = None
                guardar()
        elif ruta == '/api/upr_completo':
            DATOS.mkdir(exist_ok=True)
            subprocess.Popen([java(), '-jar', str(upr_jar())], cwd=upr_jar().parent)
        elif ruta == '/api/nuevo':
            with lock:
                estado.update(vidas_iniciales=int(d['vidas']), ajuste_vidas=0, muertos=[],
                              medallas=[False] * 8)
                guardar()
        elif ruta == '/api/jugar':
            if d['rom'] not in roms():
                raise RuntimeError('Elige una ROM de la carpeta rom/')
            subprocess.Popen([str(preparar_azahar()), str(ROMS / d['rom'])])
        elif ruta == '/api/medalla':
            with lock:
                estado['medallas'][int(d['i'])] = bool(d['valor'])
                guardar()
        elif ruta == '/api/vidas':
            with lock:
                estado['ajuste_vidas'] += int(d['delta'])
                guardar()
        else:
            raise RuntimeError('Acción desconocida')


def main():
    for carpeta in (TOOLS, ROMS, DATOS, FANART):
        carpeta.mkdir(exist_ok=True)
    cargar()
    threading.Thread(target=seguimiento, daemon=True).start()
    servidor = ThreadingHTTPServer(('127.0.0.1', PUERTO), Servidor)
    print(f'Pokelocke en http://localhost:{PUERTO}  ·  overlay para OBS: http://localhost:{PUERTO}/overlay')
    print('Cierra esta ventana para apagarlo.')
    webbrowser.open(f'http://localhost:{PUERTO}')
    servidor.serve_forever()


if __name__ == '__main__':
    main()
