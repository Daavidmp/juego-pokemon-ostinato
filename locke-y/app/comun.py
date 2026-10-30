"""Lo compartido: rutas, constantes, el estado en memoria, la biblioteca en disco, tareas y avisos."""
import ctypes
import json
import os
import sys
import threading
import time
import urllib.request
from pathlib import Path

import errores


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
# la pone app/empaquetar.py al construir el instalador (año.mes.día.horaminuto); la copia de desarrollo no tiene
try:
    VERSION_APP = (APP / 'version.txt').read_text(encoding='utf-8').strip()
except OSError:
    VERSION_APP = 'desarrollo'
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
    """Se escribe en un archivo aparte y se cambia de golpe: si el PC se apaga a mitad, biblioteca.json sigue entero
    (antes se quedaba a medias y se perdía el locke). El que había pasa a biblioteca.bak.json."""
    DATOS.mkdir(exist_ok=True)
    tmp = BIBLIOTECA.with_suffix('.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(biblio, f, indent=2, ensure_ascii=False)
        f.flush()
        os.fsync(f.fileno())
    if BIBLIOTECA.exists():
        try:
            BIBLIOTECA.replace(BIBLIOTECA.with_suffix('.bak.json'))
        except OSError:
            pass
    tmp.replace(BIBLIOTECA)


def cargar():
    """La biblioteca; si está rota, la copia anterior (y la rota se guarda aparte para mirarla)."""
    for f in (BIBLIOTECA, BIBLIOTECA.with_suffix('.bak.json')):
        if not f.exists():
            continue
        try:
            biblio.update(json.loads(f.read_text(encoding='utf-8')))
        except (OSError, ValueError):
            print(time.strftime('%Y-%m-%d %H:%M:%S'), f'{f.name} está roto: se prueba la copia anterior', flush=True)
            continue
        if f != BIBLIOTECA:
            BIBLIOTECA.replace(BIBLIOTECA.with_suffix(f'.rota-{time.strftime("%Y%m%d_%H%M%S")}.json'))
            guardar()
        return


def buscar(id_juego):
    j = next((j for j in biblio['juegos'] if j['id'] == id_juego), None)
    if not j:
        raise RuntimeError('Ese juego ya no está en la biblioteca')
    return j


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


def en_segundo_plano(nombre, fn, *args, minimo=0):
    """minimo: segundos que como poco dura el modal de carga (la ventana anima la barra con ese tiempo)."""
    if vivo['tarea'] and not vivo['tarea']['fin']:
        raise RuntimeError('Ya hay una tarea en marcha')

    def envoltura():
        try:
            fn(*args)
            tarea(f'{nombre}: hecho.', fin=True)
        except Exception as e:
            mensaje = errores.describir(e, nombre)
            tarea(f'{nombre}: {mensaje}' if type(e) is RuntimeError else mensaje, error=True, fin=True)
    vivo['tarea'] = {'inicio': time.time(), 'minimo': minimo}
    tarea(f'{nombre}…', paso=1)
    threading.Thread(target=envoltura, daemon=True).start()


def avisar(texto, segundos=4):
    """Un aviso para el jugador en el layout (sobre la pantalla de arriba) durante unos segundos."""
    vivo['aviso'] = {'texto': texto, 'hasta': time.time() + segundos}


# ---------- online: cuentas, conectados, servidor y PokéHex a distancia ----------
# app/online.json: {"direccion": "..."}, adónde se conectan todos. Va dentro del .exe repartido, así que los
# demás no tienen que configurar nada. Lo que cambie cada uno (el anfitrión al activar el servidor) se guarda
# en datos/online.json, que manda sobre el de dentro.

F_ONLINE, F_SESION = DATOS / 'online.json', DATOS / 'sesion.json'
red = {'sesion': None, 'conectados': [], 'error': None, 'servidor': None, 'upnp': None, 'ip': None}
