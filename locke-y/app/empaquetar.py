"""Crea el instalador de Pokelocke para repartir.

  tools\\build-venv\\Scripts\\python app\\empaquetar.py      ->  tools\\instalador\\PokelockeSetup.exe

1. PyInstaller en modo carpeta (--onedir): Pokelocke.exe y su _internal con la app, la web, los assets, el vídeo,
   la guía y el contrato. Nada se descomprime al abrirlo (el modo de un solo archivo lo sacaba todo a %TEMP% en
   cada arranque, y dos veces al jugar por la capa: lento y lo que más marcan los antivirus).
2. Al lado, lo que antes iba en un zip pegado al .exe: Citra (sin user/, que son las partidas), el randomizador,
   las cachés de PokéAPI y los fan arts. Y lo que la app descargaba al usarla, para no instalar nada aparte:
   - un Java mínimo (jlink, solo los módulos que usa el randomizador) en tools/java/runtime
   - LockeSettings y MegaFases compilados en tools/upr/pokelocke-upr.jar (así basta ese Java, sin JDK)
   - makerom, para los .cia (se descarga aquí una vez si no está en tools/makerom)
   Hace falta un JDK 17 o superior en el PC que construye (JAVA_HOME, %USERPROFILE%\\.jdks o tools\\java).
3. Si está POKELOCKE_FIRMA (p. ej. «signtool sign /fd sha256 /tr http://timestamp.acs.microsoft.com /td sha256
   /a "{archivo}"»), se firman los .exe y el instalador.
4. Inno Setup (app/instalador.iss) hace PokelockeSetup.exe: instala en %LOCALAPPDATA%\\Pokelocke sin pedir
   administrador, con accesos directos y desinstalador. Las partidas no van en él, así que nunca se pisan.
   ISCC.exe se busca en tools\\inno, en scoop (inno-setup) y en Archivos de programa.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TOOLS = RAIZ / 'tools'
DIST = TOOLS / 'dist' / 'Pokelocke'
SALIDA = TOOLS / 'instalador'
CITRA = TOOLS / 'azahar' / 'citra-1920'
FUERA_CITRA = {'user', 'azahar_viejo.exe', 'lanzador.cs', 'citra.exe'}   # citra.exe: la versión sin ventana, no se usa
EDITOR = 'David Martínez Palacios'
VERSION = time.strftime('%Y.%m.%d.%H%M')


def version_pyinstaller():
    """Datos de versión del .exe (Propiedades > Detalles): un .exe sin ellos es de lo que más desconfían los antivirus."""
    n = tuple(int(x) for x in VERSION.split('.'))
    f = TOOLS / 'build' / 'version.txt'
    f.parent.mkdir(parents=True, exist_ok=True)
    campos = {'CompanyName': EDITOR, 'FileDescription': 'Pokelocke', 'FileVersion': VERSION,
              'InternalName': 'Pokelocke', 'LegalCopyright': f'© {time.strftime("%Y")} {EDITOR}',
              'OriginalFilename': 'Pokelocke.exe', 'ProductName': 'Pokelocke', 'ProductVersion': VERSION}
    f.write_text(f"""VSVersionInfo(
  ffi=FixedFileInfo(filevers={n}, prodvers={n}, mask=0x3f, flags=0x0, OS=0x40004, fileType=0x1, subtype=0x0, date=(0, 0)),
  kids=[StringFileInfo([StringTable('0C0A04B0', [{', '.join(f'StringStruct({k!r}, {v!r})' for k, v in campos.items())}])]),
        VarFileInfo([VarStruct('Translation', [0x0C0A, 1200])])])
""", encoding='utf-8')
    return f


def version_app():
    f = TOOLS / 'build' / 'version_app' / 'version.txt'
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(VERSION, encoding='utf-8')
    return f


def pyinstaller():
    datos = [('app/web', 'app/web'), ('app/datos_pkx', 'app/datos_pkx'), ('app/LockeSettings.java', 'app'), ('app/MegaFases.java', 'app'),
             ('app/online.json', 'app'), ('assets', 'assets'),
             # opciones de la biblioteca: vídeo de normas, guía y contrato (se rellena con la firma)
             ('video/normas.mp4', 'video'), ('guia/Guia-Mega-Pokelocke-Y.pdf', 'guia'),
             ('normas/normas.html', 'normas'), ('normas/img', 'normas/img'),
             (version_app(), 'app')]          # la versión, para comparar con la del servidor al buscar actualizaciones
    args = [str(Path(sys.executable).parent / 'pyinstaller'), '--noconfirm', '--clean', '--onedir', '--noconsole', '--noupx',
            '--name', 'Pokelocke', '--icon', str(RAIZ / 'assets' / 'icono.ico'), '--version-file', str(version_pyinstaller()),
            '--distpath', str(DIST.parent), '--workpath', str(TOOLS / 'build'), '--specpath', str(TOOLS / 'build')]
    for origen, destino in datos:
        args += ['--add-data', f'{RAIZ / origen};{destino}']
    subprocess.run(args + [str(RAIZ / 'app' / 'main.py')], check=True, cwd=RAIZ)


def archivos():
    """(ruta en disco, ruta dentro de la carpeta instalada)"""
    if not (CITRA / 'citra-qt.exe').exists() or not (CITRA / 'azahar.exe').exists():
        raise SystemExit(f'Falta Citra con su lanzador en {CITRA} (citra-qt.exe y azahar.exe; ver README)')
    for f in sorted(CITRA.rglob('*')):
        if f.is_file() and f.relative_to(CITRA).parts[0] not in FUERA_CITRA:
            yield f, f.relative_to(RAIZ)
    for f in sorted((TOOLS / 'upr').rglob('*')):
        if f.is_file() and not f.relative_to(TOOLS / 'upr').parts[0].startswith('tmp_'):   # restos de una randomización
            yield f, f.relative_to(RAIZ)
    for f in sorted(TOOLS.glob('pkx_*.json')):
        yield f, f.relative_to(RAIZ)
    for f in sorted((RAIZ / 'fanart').rglob('*')):
        if f.is_file():
            yield f, f.relative_to(RAIZ)


def copiar_herramientas():
    lista = list(archivos())
    for f, dentro in lista:
        destino = DIST / dentro
        destino.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, destino)
    print(f'{len(lista)} archivos de Citra, randomizador y fan arts')


def jdk():
    """Un JDK con jlink y javac para construir."""
    candidatos = [Path(os.environ['JAVA_HOME'])] if os.environ.get('JAVA_HOME') else []
    candidatos += sorted((Path.home() / '.jdks').glob('*'), reverse=True) + sorted((TOOLS / 'java').glob('*'), reverse=True)
    for c in candidatos:
        if (c / 'bin' / 'jlink.exe').exists() and (c / 'bin' / 'javac.exe').exists():
            return c / 'bin'
    raise SystemExit('Hace falta un JDK 17 o superior (JAVA_HOME, %USERPROFILE%\\.jdks o tools\\java) para construir')


def clases_y_java():
    """LockeSettings y MegaFases compilados en un .jar y un Java mínimo que los ejecuta con el randomizador."""
    bin_ = jdk()
    upr = next((TOOLS / 'upr').rglob('PokeRandoZX.jar'))
    clases = TOOLS / 'build' / 'clases'
    shutil.rmtree(clases, ignore_errors=True)
    subprocess.run([str(bin_ / 'javac'), '-encoding', 'UTF-8', '-nowarn', '-cp', str(upr), '-d', str(clases),
                    str(RAIZ / 'app' / 'LockeSettings.java'), str(RAIZ / 'app' / 'MegaFases.java')], check=True)
    jar = DIST / upr.parent.relative_to(RAIZ) / 'pokelocke-upr.jar'
    jar.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(bin_ / 'jar'), 'cf', str(jar), '-C', str(clases), '.'], check=True)
    modulos = subprocess.run([str(bin_ / 'jdeps'), '--ignore-missing-deps', '--print-module-deps', '--multi-release', 'base',
                              str(upr), str(jar)], check=True, capture_output=True, text=True).stdout.strip()
    modulos += ',jdk.charsets,jdk.crypto.ec'        # textos y descargas del randomizador
    runtime = DIST / 'tools' / 'java' / 'runtime'
    shutil.rmtree(runtime, ignore_errors=True)
    subprocess.run([str(bin_ / 'jlink'), '--add-modules', modulos, '--strip-debug', '--no-header-files',
                    '--no-man-pages', '--output', str(runtime)], check=True)
    print(f'Java mínimo ({modulos}) y {jar.name}')


def makerom():
    """makerom en tools/makerom (lo descarga de GitHub la primera vez que se construye)."""
    destino = TOOLS / 'makerom'
    if not (destino.exists() and next(destino.rglob('makerom.exe'), None)):
        rel = json.load(urllib.request.urlopen('https://api.github.com/repos/3DSGuy/Project_CTR/releases/latest', timeout=30))
        url = next(a['browser_download_url'] for a in rel['assets'] if re.fullmatch(r'makerom-v[\d.]+-win_x86_64\.zip', a['name']))
        zip_tmp = TOOLS / 'makerom.zip'
        urllib.request.urlretrieve(url, zip_tmp)
        with zipfile.ZipFile(zip_tmp) as z:
            z.extractall(destino)
        zip_tmp.unlink()
    for f in destino.rglob('*'):
        if f.is_file():
            (DIST / f.relative_to(RAIZ)).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, DIST / f.relative_to(RAIZ))


def firmar(archivo):
    orden = os.environ.get('POKELOCKE_FIRMA')
    if orden:
        subprocess.run(orden.replace('{archivo}', str(archivo)), check=True, shell=True)


def iscc():
    for c in (TOOLS / 'inno' / 'ISCC.exe', Path.home() / 'scoop' / 'apps' / 'inno-setup' / 'current' / 'ISCC.exe',
              Path(os.environ.get('ProgramFiles(x86)', '')) / 'Inno Setup 6' / 'ISCC.exe',
              Path(os.environ.get('ProgramFiles', '')) / 'Inno Setup 6' / 'ISCC.exe'):
        if c.exists():
            return c
    raise SystemExit('No encuentro Inno Setup 6 (ISCC.exe). Ponlo en tools\\inno o «scoop install inno-setup».')


def instalador():
    for exe in (DIST / 'Pokelocke.exe', DIST / 'tools' / 'azahar' / 'citra-1920' / 'azahar.exe'):
        firmar(exe)
    SALIDA.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(iscc()), '/Q', f'/DVersion={VERSION}', f'/DOrigen={DIST}', f'/DSalida={SALIDA}',
                    f'/DIcono={RAIZ / "assets" / "icono.ico"}', str(RAIZ / 'app' / 'instalador.iss')], check=True)
    setup = SALIDA / 'PokelockeSetup.exe'
    firmar(setup)
    (SALIDA / 'PokelockeSetup.version').write_text(VERSION, encoding='utf-8')
    # el anfitrión lo reparte con /descargar y anuncia su versión en /version: van junto a su Pokelocke instalado
    instalado = Path(os.environ.get('LOCALAPPDATA', '')) / 'Pokelocke'
    if instalado.is_dir():
        shutil.copy2(setup, instalado / 'PokelockeSetup.exe')
        shutil.copy2(SALIDA / 'PokelockeSetup.version', instalado / 'PokelockeSetup.version')
    print(f'{setup} · {setup.stat().st_size / 2**20:.0f} MB · versión {VERSION}')


if __name__ == '__main__':
    shutil.rmtree(DIST, ignore_errors=True)
    pyinstaller()
    copiar_herramientas()
    clases_y_java()
    makerom()
    instalador()
