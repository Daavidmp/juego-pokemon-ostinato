"""Vídeo de normas con la voz de Arce (voz/01.mp3 … 35.mp3, uno por plano) y la música de fondo (musica.mp3).
Cada plano dura lo que su audio más una pausa; la música se repite encadenada con fundidos, va bajita y se
aparta un poco más cuando habla Arce.
    tools\\build-venv\\Scripts\\python video\\montar_con_voz.py   ->  video/normas.mp4 (y video/normas_audio.m4a)
"""
import re
import subprocess
import tempfile
from pathlib import Path

import montar_previa as previa

AQUI = Path(__file__).resolve().parent
VOZ, MUSICA = AQUI / 'voz', AQUI / 'musica.mp3'
ENTRADA, PAUSA, CAMBIO, COLA = 1.5, 0.6, 1.1, 3.0   # s: música sola al empezar, entre frases, entre láminas, al acabar
VOZ_LUFS, MUSICA_LUFS = -16, -31                     # la música unos 15 dB por debajo de la voz
FUNDIDO_BUCLE = 4.0


def duracion(f):
    r = subprocess.run([previa.ffmpeg(), '-hide_banner', '-i', str(f)], capture_output=True, text=True)
    h, m, s = re.search(r'Duration: (\d+):(\d+):([\d.]+)', r.stderr).groups()
    return int(h) * 3600 + int(m) * 60 + float(s)


def ff(*args):
    subprocess.run([previa.ffmpeg(), '-y', '-hide_banner', '-loglevel', 'error', *map(str, args)], check=True)


def montar():
    voces = [VOZ / f'{i + 1:02d}.mp3' for i in range(len(previa.PLANOS))]
    faltan = [v.name for v in voces if not v.exists()]
    if faltan:
        raise SystemExit(f'faltan audios: {faltan}')
    dur = [duracion(v) for v in voces]
    # pausa tras cada frase: más larga si el plano siguiente cambia de lámina
    pausas = [PAUSA if i + 1 < len(dur) and previa.PLANOS[i + 1][0] == previa.PLANOS[i][0] else CAMBIO
              for i in range(len(dur))]
    pausas[-1] = COLA
    planos = [d + p for d, p in zip(dur, pausas)]
    planos[0] += ENTRADA
    total = sum(planos)
    tmp = Path(tempfile.mkdtemp())

    # voz: los 35 audios seguidos con sus pausas, igualados de volumen
    entradas, cadena = [], ''
    for i, (v, p) in enumerate(zip(voces, pausas)):
        entradas += ['-i', v]
        cadena += f'[{i}:a]aresample=44100,aformat=channel_layouts=stereo,apad=pad_dur={p}[v{i}];'
    cadena += ''.join(f'[v{i}]' for i in range(len(voces))) + f'concat=n={len(voces)}:v=0:a=1,'
    cadena += f'adelay={int(ENTRADA * 1000)}|{int(ENTRADA * 1000)},loudnorm=I={VOZ_LUFS}:TP=-1.5:LRA=11[voz]'
    ff(*entradas, '-filter_complex', cadena, '-map', '[voz]', '-ar', 44100, tmp / 'voz.wav')

    # música: vueltas encadenadas con fundido hasta cubrir el vídeo, entrada y salida suaves
    m = duracion(MUSICA)
    vueltas = 1
    while vueltas * m - (vueltas - 1) * FUNDIDO_BUCLE < total:
        vueltas += 1
    entradas, cadena, ant = [], '', '0:a'
    for i in range(vueltas):
        entradas += ['-i', MUSICA]
    for i in range(1, vueltas):
        cadena += f'[{ant}][{i}:a]acrossfade=d={FUNDIDO_BUCLE}[m{i}];'
        ant = f'm{i}'
    cadena += (f'[{ant}]aresample=44100,aformat=channel_layouts=stereo,atrim=0:{total:.3f},'
               f'loudnorm=I={MUSICA_LUFS}:TP=-6,afade=t=in:d=1.5,afade=t=out:st={total - COLA:.3f}:d={COLA}[mus]')
    ff(*entradas, '-filter_complex', cadena, '-map', '[mus]', '-ar', 44100, tmp / 'musica.wav')

    # mezcla: la música se aparta unos dB cuando habla Arce y vuelve en las pausas
    audio = AQUI / 'normas_audio.m4a'
    ff('-i', tmp / 'voz.wav', '-i', tmp / 'musica.wav', '-filter_complex',
       '[0:a]asplit=2[voz][llave];[1:a][llave]sidechaincompress=threshold=0.03:ratio=4:attack=30:release=500[fondo];'
       '[voz][fondo]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.95[a]',
       '-map', '[a]', '-c:a', 'aac', '-b:a', '192k', audio)

    video = previa.montar(planos, tmp / 'imagen.mp4')
    salida = AQUI / 'normas.mp4'
    ff('-i', video, '-i', audio, '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'copy', '-shortest', salida)
    print(f'{salida} · {total / 60:.1f} min · música en {vueltas} vueltas')


if __name__ == '__main__':
    montar()
