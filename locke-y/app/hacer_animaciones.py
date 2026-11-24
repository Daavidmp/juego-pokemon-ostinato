"""Deja en assets/combate/anim las animaciones de combate de Pokémon Ostinato para el combate en línea (2.4.0).

  tools/build-venv/Scripts/python app/hacer_animaciones.py <carpeta del juego>

1. exportar_animaciones.rb (con el Ruby de tools/ruby) saca cada animación a <n>.json, el índice de las comunes y la
   lista de gráficos (Graphics/Animations) y sonidos (Audio/SE) que usan.
2. Los gráficos se copian a g/ y los sonidos a s/ con un nombre sin espacios ni signos (el servidor de la app solo sirve
   [letras, números, - _ .]); los .wav y .mp3 se pasan a .ogg (ffmpeg de Krita) para que pesen menos.
3. nombres.json: {nombre en el juego: archivo} de gráficos y sonidos, para que el reproductor de la app los encuentre.
"""
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
JUEGO = Path(sys.argv[1])
SALIDA = RAIZ / 'assets' / 'combate' / 'anim'
FFMPEG = Path(r'C:\Program Files\Krita (x64)\bin\ffmpeg.exe')
shutil.rmtree(SALIDA, ignore_errors=True)
(SALIDA / 'g').mkdir(parents=True)
(SALIDA / 's').mkdir(parents=True)

tmp = Path(tempfile.mkdtemp())
subprocess.run([str(RAIZ / 'tools' / 'ruby' / 'bin' / 'ruby.exe'), str(RAIZ / 'app' / 'ostinato' / 'exportar_animaciones.rb'),
                str(JUEGO), str(tmp)], check=True, stderr=subprocess.DEVNULL)
for f in tmp.glob('*.json'):
    if f.name != 'usados.json':
        shutil.copy2(f, SALIDA / f.name)
usados = json.loads((tmp / 'usados.json').read_text(encoding='utf-8'))


def seguro(nombre):
    return re.sub(r'[^\w.-]', '_', Path(nombre).stem)


def busca(carpetas, nombre, exts):
    base = Path(nombre)
    for c in carpetas:
        for cand in [c / nombre] + [c / (str(base.with_suffix('')) + e) for e in exts]:
            if cand.is_file():
                return cand
    return None


nombres = {'graficos': {}, 'sonidos': {}}
for n in usados['graficos']:
    f = busca([JUEGO / 'Graphics' / 'Animations'], n, ['.png', '.gif'])
    if f:
        destino = f'{seguro(n)}{f.suffix.lower()}'
        shutil.copy2(f, SALIDA / 'g' / destino)
        nombres['graficos'][n] = destino
convertidos = 0
for n in usados['sonidos']:
    f = busca([JUEGO / 'Audio' / 'SE', JUEGO / 'Audio' / 'SE' / 'Anim'], n, ['.ogg', '.wav', '.mp3'])
    if not f:
        continue
    destino = f'{seguro(n)}.ogg'
    if f.suffix.lower() == '.ogg':
        shutil.copy2(f, SALIDA / 's' / destino)
    else:
        # el ffmpeg de Krita no abre rutas con tildes («Pokémon Ostinato»): se pasa por una copia en la carpeta temporal
        entrada, sale = tmp / f'entrada{f.suffix.lower()}', tmp / 'salida.ogg'
        shutil.copy2(f, entrada)
        subprocess.run([str(FFMPEG), '-v', 'error', '-y', '-i', str(entrada), '-ac', '2', '-c:a', 'vorbis', '-strict', '-2', '-q:a', '3',
                        str(sale)], check=True)
        shutil.copy2(sale, SALIDA / 's' / destino)
        convertidos += 1
    nombres['sonidos'][n] = destino
(SALIDA / 'nombres.json').write_text(json.dumps(nombres, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
peso = sum(f.stat().st_size for f in SALIDA.rglob('*') if f.is_file())
print(f"{len(list(SALIDA.glob('*.json'))) - 2} animaciones, {len(nombres['graficos'])} gráficos, {len(nombres['sonidos'])} sonidos "
      f"({convertidos} pasados a ogg), {peso / 2**20:.1f} MB")
