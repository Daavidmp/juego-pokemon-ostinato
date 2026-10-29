"""Montaje de prueba del vídeo de normas, sin voz: láminas + Arce recortada + subtítulos con el guion.
Cada plano dura lo que se tarda en decir su frase (unas 2,6 palabras por segundo).
    PYTHONPATH=<carpeta con imageio_ffmpeg> python3 montar_previa.py   ->  previa.mp4
"""
import os
import subprocess
import tempfile
import textwrap
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


def ffmpeg():
    """El de imageio_ffmpeg si está; si no, el de Krita (en Windows es el único que hay)."""
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return os.environ.get('FFMPEG') or r'C:\Program Files\Krita (x64)\bin\ffmpeg.exe'


def codec_video():
    """libx264 si el ffmpeg lo trae; el de Krita no, y ahí h264_qsv (Intel) da más calidad que libopenh264."""
    r = subprocess.run([ffmpeg(), '-hide_banner', '-encoders'], capture_output=True, text=True).stdout
    if ' libx264 ' in r:
        return ['-c:v', 'libx264', '-crf', '20']
    return ['-c:v', 'h264_qsv', '-global_quality', '20']

AQUI = Path(__file__).resolve().parent
ARCE = AQUI.parent.parent / 'CREDITOS' / 'firefly'
LAM = AQUI / 'imagenes'
PALABRAS_POR_SEGUNDO = 2.6
PARPADEO_CADA, PARPADEO_DURA = 3.5, 0.15
PARPADEOS = {'base': 'base_parpadeo', 'explica': 'explica_parpadeo', 'senala': 'senala_parpadeo'}

# (lámina, pose de Arce, frase)
PLANOS = [
    ('01_presentacion', 'saluda', 'Hola. Soy la profesora Arce. No soy de Kalos, pero me han pedido que os explique esto, y como nadie más se lo ha leído entero, aquí estoy.'),
    ('01_presentacion', 'base_guino', 'Esto es el Mega Pokelocke Y. Pokémon Y, randomizado, con normas. Un mes de partida y dos torneos entre vosotros. Vamos por partes, que hay bastante.'),
    ('02a_salvajes', 'senala', 'El juego no es el que conocéis. Los Pokémon salvajes salen al azar, cualquiera en cualquier sitio.'),
    ('02b_iniciales', 'explica', 'Vuestro inicial también es al azar, pero siempre uno con dos evoluciones: eso no os lo voy a quitar.'),
    ('02c_entrenadores', 'explica', 'Los entrenadores llevan equipos al azar y un quince por ciento más de nivel. Movimientos, habilidades y lo que encontréis por el suelo, también al azar.'),
    ('02d_tipos', 'explica', 'Lo que no cambia: los tipos, las estadísticas y las evoluciones. La tabla de tipos de siempre os sigue valiendo. Aprendéosla, que os va a salvar más que yo.'),
    ('03a_vidas', 'alto_seria', 'Tenéis veinticinco vidas. Ni una más.'),
    ('03b_vida_menos', 'brazos_cruzados_seria', 'Cada vez que un Pokémon vuestro se queda a cero PS, perdéis una. Da igual que luego lo reviváis: esa vida ya no vuelve.'),
    ('03c_ps_cero', 'brazos_cruzados_seria', 'Si llegáis a cero vidas, se acabó vuestro Mega Pokelocke.'),
    ('03d_shauna', 'base', 'Os doy un margen. Hasta que no acabéis el primer combate contra Shauna, en Pueblo Acuarela, no cuenta nada. Después, todo.'),
    ('04a_una_por_ruta', 'explica', 'Un Pokémon por ruta. El primero que capturéis en una zona, esa zona queda gastada.'),
    ('04b_balls_escondidas', 'explica', 'No hace falta que os fieis de vosotros mismos: si volvéis a combatir en una zona gastada, la app os esconde las Poké Balls y os las devuelve al acabar.'),
    ('04c_shiny', 'pulgar_guino', 'Salvo que el Pokémon sea shiny. Un shiny no cuenta: se puede capturar siempre y no gasta nada.'),
    ('04d_legendarios', 'brazos_cruzados_seria', 'Legendarios y singulares, ninguno. Os pueden salir, que esto es al azar. Se derrotan o se huye.'),
    ('04e_snorlax', 'ensena', 'Y una cosa concreta: en la Ruta 7 hay un Pokémon dormido, el Snorlax de toda la vida. Ese no se captura, porque la app no sabe distinguirlo de los de la ruta. Cuando lleguéis, avisáis al administrador y os pone un huevo en el PC. Sales ganando.'),
    ('05a_fase_facil', 'dos_dedos', 'Al principio os lo pongo fácil. Hasta la segunda medalla, los Pokémon que os encontréis todavía pueden evolucionar y los rivales no pegan con ataques de más de setenta de potencia.'),
    ('05b_reiniciar', 'alto_seria', 'Cuando ganéis la segunda medalla, a Lino, guardáis y reiniciáis el juego. Ahí se abre todo. La app os lo va a recordar hasta que lo hagáis, así que no os hagáis los despistados.'),
    ('05c_seis', 'senala', 'Y los combates importantes —rivales, líderes, el Alto Mando, la Campeona y los del Team Flare con nombre— llevan seis Pokémon. Seis. Id preparados.'),
    ('06a_caramelos', 'ensena', 'Tenéis diez mil Caramelos Raros. Se os rellenan solos en la mochila.'),
    ('06b_nivel_tope', 'brazos_cruzados_seria', 'Pero ningún Pokémon puede pasar del nivel tope: el del Pokémon más fuerte del próximo líder. La app y la guía os lo dicen en cada tramo. Subir hasta ahí es fácil. Pasarse es trampa.'),
    ('07a_vial', 'ensena', 'Esto es el vial. Cura a todo el equipo que siga vivo: vida, estados y PP. A los debilitados no los levanta, no os hagáis ilusiones.'),
    ('07b_vial_recarga', 'base_guino', 'Una carga. Se usa con la tecla E y solo fuera de combate. Se recarga cuando os curáis en un Centro Pokémon. Guardadlo para cuando haga falta de verdad, que siempre hace falta antes de lo que creéis.'),
    ('08_huevos', 'explica', 'Al empezar se sortea una caja de treinta huevos. Dos son shiny, y no se sabe cuáles. Cogéis uno cada dos medallas, desde la biblioteca de la app y con el juego cerrado.'),
    ('08_huevos', 'mano_pecho_rie', 'Si os toca un shiny, cogéis otro. Ya me contaréis la cara que se os queda.'),
    ('09a_calendario', 'dos_dedos', 'Esto dura un mes. Dos semanas para llegar a la cuarta medalla, la de Amaro.'),
    ('09b_parada', 'alto_seria', 'Y ahí paráis: no avanzáis más, ni historia ni zonas nuevas. Podéis entrenar y preparar el equipo en lo que ya habéis recorrido, nada más.'),
    ('09a_calendario', 'explica', 'Entonces viene el primer torneo, entre vosotros. Otras dos semanas para pasaros la Liga, y el torneo final. A poder ser, los sábados, cada dos semanas.'),
    ('09c_torneo', 'explica', 'Los cruces se sortean y todo va al mejor de tres. Si sois impares, los que pierdan en la primera ronda juegan entre ellos a una sola partida, y el que gane se enfrenta al que se quedó sin combatir.'),
    ('09c_torneo', 'pulgar_guino', 'El primer torneo sirve para ver cómo vais y aprender a montar equipos. El que de verdad decide quién gana es el último.'),
    ('10_premios', 'mano_pecho_rie', 'Y como no todo van a ser normas, el primer torneo tiene premio.'),
    ('10_premios', 'ensena', 'El primero se lleva una Cápsula Habilidad, una menta a su elección y un huevo. El segundo, un huevo y una menta. El tercero, una menta. El resto, la experiencia, que tampoco está mal.'),
    ('11_ganar', 'brazos_cruzados_seria', 'Para ganar el Mega Pokelocke hacen falta dos cosas: pasaros la Liga Pokémon con vidas y ganar el torneo final. Las dos.'),
    ('12a_teclas', 'explica', 'Si la app se equivoca con las vidas, lo corregís con F7 y F8, y delante del directo. Corregir a vuestro favor sin motivo es trampa, y se nota.'),
    ('12b_documentos', 'senala', 'Todo esto lo tenéis en la guía y en el contrato. Leedlo, firmadlo, y luego a jugar.'),
    ('12c_final', 'despedida_guino', 'Y cuando se os ponga malo un Pokémon por el camino, que se os va a poner, no le deis hierbas raras. Le habláis.'),
]

_arces = {}


def arce(pose):
    """Arce sin el fondo blanco: se rellena el blanco conectado con los bordes (el contorno negro la cierra)."""
    if pose not in _arces:
        im = Image.open(ARCE / f'arce_{pose}.png').convert('RGB')
        marca = (255, 0, 255)
        relleno = im.copy()
        for esquina in ((0, 0), (im.width - 1, 0)):
            ImageDraw.floodfill(relleno, esquina, marca, thresh=60)
        fondo = ImageChops.difference(relleno, Image.new('RGB', im.size, marca)).convert('L').point(lambda v: 255 if v else 0)
        sola = im.convert('RGBA')
        sola.putalpha(fondo)
        sola = sola.crop(sola.getbbox())
        alto = 920
        _arces[pose] = sola.resize((round(sola.width * alto / sola.height), alto), Image.LANCZOS)
    return _arces[pose]


FUENTE = ImageFont.truetype(next(f for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
                                            r'C:\Windows\Fonts\DejaVuSans-Bold.ttf', r'C:\Windows\Fonts\arialbd.ttf')
                                   if Path(f).exists()), 34)


def plano(lamina, pose, texto):
    lienzo = Image.open(LAM / f'{lamina}.png').convert('RGBA')
    a = arce(pose)
    lienzo.alpha_composite(a, (max(-160, 320 - a.width // 2), 1080 - a.height))
    lineas = textwrap.wrap(texto, 80)
    alto = 20 + 44 * len(lineas)
    banda = Image.new('RGBA', (1920, alto), (10, 8, 12, 200))
    d = ImageDraw.Draw(banda)
    for i, l in enumerate(lineas):
        w = d.textlength(l, font=FUENTE)
        d.text(((1920 - w) / 2, 10 + i * 44), l, font=FUENTE, fill=(255, 255, 255))
    lienzo.alpha_composite(banda, (0, 1080 - alto))
    return lienzo.convert('RGB')


def montar(duraciones=None, salida=None):
    """duraciones: segundos de cada plano (montar_con_voz.py los saca de los audios); sin ellas, por palabras."""
    tmp = Path(tempfile.mkdtemp())
    lista, n, total = [], 0, 0.0
    for i, (lamina, pose, texto) in enumerate(PLANOS):
        dura = duraciones[i] if duraciones else max(2.5, len(texto.split()) / PALABRAS_POR_SEGUNDO)
        tramos = [(pose, dura)]
        if pose in PARPADEOS:                       # parpadeo cada 3,5 s dentro del plano
            tramos, t = [], 0.0
            while dura - t > PARPADEO_CADA + PARPADEO_DURA:
                tramos += [(pose, PARPADEO_CADA), (PARPADEOS[pose], PARPADEO_DURA)]
                t += PARPADEO_CADA + PARPADEO_DURA
            tramos.append((pose, dura - t))
        for p, s in tramos:
            f = tmp / f'{n:04d}.png'
            plano(lamina, p, texto).save(f)
            lista.append(f"file '{f.as_posix()}'\nduration {s:.3f}")
            n += 1
        total += dura
    lista.append(f"file '{(tmp / f'{n - 1:04d}.png').as_posix()}'")    # el concat necesita repetir el último
    (tmp / 'lista.txt').write_text('\n'.join(lista))
    salida = salida or AQUI / 'previa.mp4'
    subprocess.run([ffmpeg(), '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0',
                    '-i', str(tmp / 'lista.txt'), '-vf', 'fps=25,format=nv12' if 'h264_qsv' in codec_video() else 'fps=25,format=yuv420p', *codec_video(),
                    str(salida)], check=True)
    print(f'{salida} · {len(PLANOS)} planos · {total / 60:.1f} min')
    return salida


if __name__ == '__main__':
    montar()
