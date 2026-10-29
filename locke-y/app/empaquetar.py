"""Crea el Pokelocke.exe para repartir: un solo archivo con todo dentro (menos la ROM y Java).

  tools\\build-venv\\Scripts\\python app\\empaquetar.py      ->  tools\\dist-unico\\Pokelocke.exe

1. PyInstaller con la app, la web, los assets y las listas de PKHeX.
2. Un zip pegado al final del .exe con Citra (sin user/, que son las partidas), el randomizador, las
   cachés de PokéAPI y los fan arts. La app lo saca a %LOCALAPPDATA%\\Pokelocke al abrirse (main.instalar).
"""
import subprocess
import sys
import time
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TOOLS = RAIZ / 'tools'
SALIDA = TOOLS / 'dist-unico'
EXE = SALIDA / 'Pokelocke.exe'
CITRA = TOOLS / 'azahar' / 'citra-1920'
FUERA_CITRA = {'user', 'azahar_viejo.exe', 'lanzador.cs', 'citra.exe'}   # citra.exe: la versión sin ventana, no se usa


def pyinstaller():
    datos = [('app/web', 'app/web'), ('app/datos_pkx', 'app/datos_pkx'), ('app/LockeSettings.java', 'app'), ('app/MegaFases.java', 'app'),
             ('app/online.json', 'app'), ('assets', 'assets'),
             # opciones de la biblioteca: vídeo de normas, guía y contrato (se rellena con la firma)
             ('video/normas.mp4', 'video'), ('guia/Guia-Mega-Pokelocke-Y.pdf', 'guia'),
             ('normas/normas.html', 'normas'), ('normas/img', 'normas/img')]
    args = [str(Path(sys.executable).parent / 'pyinstaller'), '--noconfirm', '--onefile', '--noconsole',
            '--name', 'Pokelocke', '--icon', str(RAIZ / 'assets' / 'icono.ico'),
            '--distpath', str(SALIDA), '--workpath', str(TOOLS / 'build-unico'), '--specpath', str(TOOLS / 'build-unico')]
    for origen, destino in datos:
        args += ['--add-data', f'{RAIZ / origen};{destino}']
    subprocess.run(args + [str(RAIZ / 'app' / 'main.py')], check=True, cwd=RAIZ)


def archivos():
    """(ruta en disco, ruta dentro de RAIZ al instalar)"""
    for f in sorted(CITRA.rglob('*')):
        if f.is_file() and f.relative_to(CITRA).parts[0] not in FUERA_CITRA:
            yield f, f.relative_to(TOOLS)
    for f in sorted((TOOLS / 'upr').rglob('*')):
        if f.is_file() and not f.relative_to(TOOLS / 'upr').parts[0].startswith('tmp_'):   # restos de una randomización
            yield f, f.relative_to(TOOLS)
    for f in sorted(TOOLS.glob('pkx_*.json')):
        yield f, f.relative_to(TOOLS)
    for f in sorted((RAIZ / 'fanart').rglob('*')):
        if f.is_file():
            yield f, f.relative_to(RAIZ)


def pegar_zip():
    lista = list(archivos())
    with zipfile.ZipFile(EXE, 'a', zipfile.ZIP_DEFLATED, compresslevel=6) as z:   # 'a' sobre un .exe: lo pone al final
        for f, dentro in lista:
            z.write(f, ('tools' / dentro) if dentro.parts[0] != 'fanart' else dentro)
        z.comment = time.strftime('%Y%m%d-%H%M%S').encode()
    print(f'{len(lista)} archivos dentro · {EXE.stat().st_size / 2**20:.0f} MB · versión {z.comment.decode()}')


if __name__ == '__main__':
    pyinstaller()
    pegar_zip()
