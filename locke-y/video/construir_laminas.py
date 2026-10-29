"""Láminas del vídeo de normas: una imagen de 1920×1080 por cada «En pantalla» del GUION.md.
El tercio izquierdo queda libre para Arce. Salen en imagenes/NN_nombre.png.
    python3 construir_laminas.py
"""
import re
import subprocess
import sys
from pathlib import Path

import fitz
from PIL import Image

AQUI = Path(__file__).resolve().parent
LOCKE = AQUI.parent
sys.path.insert(0, str(LOCKE / 'guia'))
from construir_guia import tabla_tipos  # noqa: E402

R = AQUI / 'recursos'
for f in ('rarecandy.png', 'pokeball.png'):                     # los de Serebii traen mucho margen
    im = Image.open(R / f).convert('RGBA')
    im.crop(im.getbbox()).save(R / f)
for pdf, png in ((LOCKE / 'guia/Guia-Mega-Pokelocke-Y.pdf', 'portada_guia.png'),
                 (LOCKE / 'normas/Normas-Mega-Pokelocke-Y.pdf', 'portada_normas.png')):
    fitz.open(pdf)[0].get_pixmap(dpi=60).save(R / png)

OVERLAY = (LOCKE / 'app/web/overlay.html').read_text(encoding='utf-8')
CORAZON, ROTO = (re.search(rf'const {n} = "(.*?)";', OVERLAY)[1].replace('\\"', '"') for n in ('CORAZON', 'CORAZON_ROTO'))
HUEVO = ('<svg viewBox="0 0 40 48" class="huevo"><path d="M20 3C11 3 4 18 4 29a16 16 0 0 0 32 0C36 18 29 3 20 3Z" '
         'fill="#f6f0dc" stroke="#2f2f35" stroke-width="2.4"/><ellipse cx="13" cy="24" rx="4.5" ry="5.5" fill="#7fbf5a"/>'
         '<ellipse cx="26" cy="15" rx="3.5" ry="4" fill="#7fbf5a"/><ellipse cx="27" cy="33" rx="5" ry="4.5" fill="#7fbf5a"/>'
         '<ellipse cx="15" cy="38" rx="3" ry="2.5" fill="#7fbf5a"/></svg>')
HUEVO_SHINY = HUEVO.replace('#f6f0dc', '#ffe48a').replace('#7fbf5a', '#e8a21c')
TROFEO = ('<svg viewBox="0 0 64 64" class="trofeo"><path d="M18 6h28v14a14 14 0 0 1-28 0Z" fill="#f2c94c" stroke="#7a5a00" '
          'stroke-width="2.5"/><path d="M18 10H8v4a10 10 0 0 0 10 10M46 10h10v4a10 10 0 0 1-10 10" fill="none" '
          'stroke="#7a5a00" stroke-width="2.5"/><path d="M28 34h8v10h-8z" fill="#d8a92c" stroke="#7a5a00" stroke-width="2.5"/>'
          '<path d="M18 44h28v8H18z" fill="#9b6b2c" stroke="#5a3a10" stroke-width="2.5"/><path d="M14 52h36v6H14z" '
          'fill="#7a5222" stroke="#5a3a10" stroke-width="2.5"/></svg>')


def corazones(n, rotos=0):
    return '<div class="vidas">' + CORAZON * (n - rotos) + ROTO * rotos + '</div>'


def tecla(t):
    return f'<span class="tecla">{t}</span>'


def poke(n, cls=''):
    return f'<img class="poke {cls}" src="recursos/p{n}.png" alt="">'


# (nombre, título, subtítulo, contenido)
LAMINAS = [
    ('01_presentacion', None, None, '<img class="logo-grande" src="../assets/logo.png" alt="">'),
    ('02a_salvajes', 'Salvajes al azar', 'Cualquier Pokémon, en cualquier sitio',
     '<div class="fila">' + ''.join(f'<div class="interroga">{poke(n, "sombra")}<b>?</b></div>' for n in (658, 6, 94)) + '</div>'),
    ('02b_iniciales', 'Inicial al azar', 'Siempre uno con dos evoluciones',
     '<div class="fila">' + '<img class="ball" src="recursos/pokeball.png" alt="">' * 3 + '<div class="dado">⚄</div></div>'),
    ('02c_entrenadores', 'Entrenadores más fuertes', 'Equipos al azar y un 15 % más de nivel',
     '<div class="fila"><img class="sprite" src="../guia/sprites/youngster-gen6xy.png" alt="">'
     '<div class="nivel">Nv. 20 <span>→</span> <b>23</b></div><div class="grande rojo">+15 %</div></div>'),
    ('02d_tipos', 'La tabla de tipos de siempre', 'Tipos, estadísticas y evoluciones no cambian', tabla_tipos()),
    ('03a_vidas', '25 vidas', 'Ni una más', '<div class="contador">25</div>' + corazones(25)),
    ('03b_vida_menos', 'Pokémon a 0 PS = una vida menos', 'Aunque luego lo revivas',
     '<div class="contador">24</div>' + corazones(25, 1)),
    ('03c_ps_cero', 'Cuenta una sola vez', 'Si llegas a cero vidas, se acabó',
     '<div class="fila"><div class="barra"><span>PS</span><div><i></i></div><b>0 / 52</b></div>'
     f'<div class="enorme">{ROTO}</div></div>'),
    ('03d_shauna', 'Hasta aquí, gratis', 'Las muertes cuentan después del primer combate contra Shauna',
     '<img class="sprite grande-sprite" src="../guia/sprites/shauna.png" alt="">'),
    ('04a_una_por_ruta', 'Un Pokémon por ruta', 'La primera captura gasta la zona',
     '<div class="aviso ok">✔ Captura de esta ruta hecha · Aquí ya no puedes capturar más</div>'
     '<div class="fila"><div class="ruta">Ruta 4</div><img class="ball" src="recursos/pokeball.png" alt=""></div>'),
    ('04b_balls_escondidas', 'Zona gastada = sin Poké Balls', 'La app las esconde en el combate y las devuelve al acabar',
     '<div class="fila"><div class="tachado"><img class="ball" src="recursos/pokeball.png" alt=""></div>'
     '<div class="flecha">→</div><div class="ruta">Combate en zona gastada</div></div>'),
    ('04c_shiny', 'Shiny = libre', 'Se captura siempre y no gasta la zona',
     '<div class="brillo">' + poke('shiny130', 'shiny') + '<span>✦</span><span>✦</span><span>✦</span></div>'),
    ('04d_legendarios', 'Ni legendarios ni singulares', 'Si sale uno, se derrota o se huye',
     '<div class="rejilla3">' + ''.join(f'<div class="tachado">{poke(n, "sombra")}</div>' for n in (150, 151, 716, 717, 718, 719)) + '</div>'),
    ('04e_snorlax', 'El Pokémon de la Ruta 7 no se captura', 'Avisa al administrador y te pone un huevo en el PC',
     f'<div class="fila"><div class="zzz">{poke(143, "sombra")}<b>Zzz</b></div><div class="flecha">→</div>'
     f'<div class="caja-pc"><span>PC · Caja 1</span>{HUEVO}</div></div>'),
    ('05a_fase_facil', 'Hasta la 2.ª medalla, fase fácil', 'Pokémon que aún evolucionan y ataques de 70 o menos',
     '<div class="fila"><img class="medalla" src="../assets/medalla-1.png" alt=""><img class="medalla" '
     'src="../assets/medalla-2.png" alt=""><svg viewBox="0 0 48 48" class="svgico"><path d="M15 22V14a9 9 0 0 1 18 0" fill="none" stroke="#ffd84d" stroke-width="5" stroke-linecap="round"/><rect x="9" y="22" width="30" height="22" rx="4" fill="#ffd84d" stroke="#7a5a00" stroke-width="2.5"/><circle cx="24" cy="32" r="3.5" fill="#7a5a00"/></svg></div>'),
    ('05b_reiniciar', 'Con la 2.ª medalla: guarda y reinicia', 'Se abre la randomización completa',
     '<div class="fila"><div class="icono"><svg viewBox="0 0 48 48" class="svgico"><path d="M6 6h30l6 6v30H6z" fill="#4f86c6" stroke="#fff" stroke-width="3"/><path d="M13 6h20v12H13z" fill="#cde3ff"/><path d="M27 9h4v6h-4z" fill="#4f86c6"/><path d="M12 26h24v16H12z" fill="#fff"/></svg><span>Guardar</span></div><div class="flecha">→</div>'
     '<div class="icono"><b class="recarga">⟳</b><span>Reiniciar</span></div></div>'),
    ('05c_seis', 'Combates importantes: equipo de 6', 'Rivales, líderes, Alto Mando, Campeona y Team Flare con nombre',
     '<img class="lider" src="../assets/lider-3.png" alt=""><div class="fila">'
     + '<img class="ball pequena" src="recursos/pokeball.png" alt="">' * 6 + '</div>'),
    ('06a_caramelos', '10 000 Caramelos Raros', 'Se rellenan solos hasta 999 en la mochila',
     '<div class="fila"><img class="objeto" src="recursos/rarecandy.png" alt=""><div class="grande">× 999</div></div>'),
    ('06b_nivel_tope', 'Nunca por encima del nivel tope', 'El del Pokémon más fuerte del próximo líder',
     '<div class="fila"><img class="medalla" src="../assets/medalla-2.png" alt=""><div class="tope"><span>Nivel tope</span>'
     '<b>29</b><small>25 + 15 %</small></div></div>'),
    ('07a_vial', 'El vial', 'Cura PS, estado y PP del equipo vivo · no revive',
     f'<div class="fila"><img class="vial" src="../assets/vial.png" alt="">{tecla("E")}</div>'
     '<p class="nota">Una carga · solo fuera de combate</p>'),
    ('07b_vial_recarga', 'Se recarga en el Centro Pokémon', 'Guárdalo para cuando haga falta de verdad',
     '<div class="fila"><img class="vial" src="../assets/vial-gastado.png" alt=""><div class="flecha">→</div>'
     '<div class="centro">✚<span>Centro Pokémon</span></div><div class="flecha">→</div>'
     '<img class="vial" src="../assets/vial.png" alt=""></div>'),
    ('08_huevos', 'La caja de 30 huevos', 'Uno cada 2 medallas · si sale shiny, otro más',
     '<div class="huevos">' + ''.join(HUEVO_SHINY if i in (7, 22) else HUEVO for i in range(30)) + '</div>'
     '<div class="fila">' + ''.join(f'<img class="medalla pequena" src="../assets/medalla-{m}.png" alt="">' for m in (2, 4, 6, 8)) + '</div>'),
    ('09a_calendario', 'Un mes de Mega Pokelocke', 'Salvo imprevistos',
     '<div class="calendario"><div><b>Semanas 1 y 2</b>Hasta la 4.ª medalla</div><div class="sab"><b>Sábado</b>Torneo intermedio</div>'
     '<div><b>Semanas 3 y 4</b>Hasta la Liga, con vidas</div><div class="sab final"><b>Sábado</b>Torneo final</div></div>'),
    ('09b_parada', 'Con la 4.ª medalla, paráis', 'Ni historia ni zonas nuevas: solo preparar el equipo',
     '<div class="fila"><img class="medalla" src="../assets/medalla-4.png" alt=""><div class="stop">STOP</div></div>'),
    ('09c_torneo', 'Cruces por sorteo, al mejor de 3', 'Si sois impares, los que pierden en la 1.ª ronda juegan a una partida',
     '<div class="cuadro"><div class="col"><i>Jugador A</i><i>Jugador B</i><i>Jugador C</i><i>Jugador D</i></div>'
     '<div class="col"><i>Ganador A-B</i><i>Ganador C-D</i></div><div class="col"><i class="oro">Campeón</i></div></div>'
     '<p class="nota">Mejor de 3 en cada cruce · sorteo en cada ronda</p>'),
    ('10_premios', 'Premios del torneo intermedio', None,
     '<div class="podio"><div><span class="puesto plata">2.º</span>' + HUEVO + '<img src="../normas/img/menta.png" alt=""></div>'
     '<div class="primero"><span class="puesto oro">1.º</span><img src="../normas/img/capsula-habilidad.png" alt="">'
     '<img src="../normas/img/menta.png" alt="">' + HUEVO + '</div>'
     '<div><span class="puesto bronce">3.º</span><img src="../normas/img/menta.png" alt=""></div></div>'),
    ('11_ganar', 'Cómo se gana el Mega Pokelocke', 'Las dos cosas',
     '<div class="fila"><img class="sprite" src="../guia/sprites/diantha.png" alt=""><div class="grande">+</div>' + TROFEO + '</div>'
     '<div class="fila etiquetas"><span>Liga con vidas</span><span>Torneo final</span></div>'),
    ('12a_teclas', 'Si la app se equivoca', 'Corrígelo delante del directo',
     f'<div class="fila">{tecla("F7")}<span class="txt">quita una vida</span></div>'
     f'<div class="fila">{tecla("F8")}<span class="txt">añade una vida</span></div>'),
    ('12b_documentos', 'Todo está en la guía y en el contrato', 'Leedlo, firmadlo y a jugar',
     '<div class="fila"><img class="portada" src="recursos/portada_guia.png" alt="">'
     '<img class="portada" src="recursos/portada_normas.png" alt=""></div>'),
    ('12c_final', None, None, '<img class="logo-grande" src="../assets/logo.png" alt=""><div class="jugar">Jugar</div>'),
]

CSS = (LOCKE / 'guia/plantilla.html').read_text(encoding='utf-8')
CSS_TIPOS = '\n'.join(re.findall(r'\.tipos[^{}]*\{[^}]*\}', CSS))


def construir():
    paginas = ''
    for nombre, titulo, sub, contenido in LAMINAS:
        cabeza = (f'<h1>{titulo}</h1>' if titulo else '') + (f'<h2>{sub}</h2>' if sub else '')
        clase = 'portada-lam' if not titulo else ''
        paginas += f'<section class="lam {clase}" data-n="{nombre}"><div class="panel">{cabeza}<div class="cont">{contenido}</div></div></section>'
    html = f'''<!doctype html><html lang="es"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@500;600;700&family=Nunito:wght@600;700;800&display=swap" rel="stylesheet">
<style>
@page {{ size: 1920px 1080px; margin: 0; }}
* {{ box-sizing: border-box; }}
html {{ -webkit-print-color-adjust: exact; print-color-adjust: exact; }}
body {{ margin: 0; font: 700 28px Nunito, sans-serif; color: #fff; }}
.lam {{ width: 1920px; height: 1080px; position: relative; overflow: hidden; page-break-after: always;
  background: linear-gradient(90deg, rgba(20,12,18,.15), rgba(20,12,18,.75) 45%), url(../assets/fondo-xy.jpg) center/cover; }}
.panel {{ position: absolute; left: 760px; top: 90px; width: 1080px; height: 900px; border-radius: 40px; padding: 60px 70px;
  background: rgba(24,18,26,.86); border: 3px solid rgba(200,16,46,.75); box-shadow: 0 30px 80px rgba(0,0,0,.5);
  display: flex; flex-direction: column; }}
.portada-lam .panel {{ background: none; border: none; box-shadow: none; left: 700px; width: 1180px; justify-content: center; align-items: center; }}
h1 {{ margin: 0; font: 600 64px/1.1 Fredoka, sans-serif; }}
h2 {{ margin: 14px 0 0; font: 700 32px/1.3 Nunito, sans-serif; color: #f2b8c2; }}
.cont {{ flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 40px; }}
.fila {{ display: flex; align-items: center; justify-content: center; gap: 48px; }}
.logo-grande {{ width: 1000px; filter: drop-shadow(0 20px 40px rgba(0,0,0,.6)); }}
.jugar {{ font: 600 56px Fredoka; background: #c8102e; border-radius: 60px; padding: 18px 90px; box-shadow: 0 10px 0 #7a0a1c; }}
.poke {{ width: 230px; height: 230px; object-fit: contain; }}
.sombra {{ filter: brightness(0) drop-shadow(0 0 2px rgba(255,255,255,.6)); }}
.interroga {{ position: relative; }}
.interroga b {{ position: absolute; inset: 0; display: grid; place-items: center; font: 700 120px Fredoka; color: #ffd84d; }}
.ball {{ width: 150px; }} .ball.pequena {{ width: 90px; }}
.dado {{ font-size: 170px; line-height: 1; color: #ffd84d; }}
.sprite {{ width: 300px; image-rendering: pixelated; }} .grande-sprite {{ width: 460px; }}
.nivel {{ font: 600 72px Fredoka; white-space: nowrap; }} .svgico {{ width: 170px; height: 170px; }} .recarga {{ font: 700 170px/1 Fredoka; color: #9fd2ff; }} .nivel span {{ color: #f2b8c2; }} .nivel b {{ color: #ff4d64; }}
.grande {{ font: 700 110px Fredoka; white-space: nowrap; }} .rojo {{ color: #ff4d64; }}
.enorme svg {{ width: 260px; height: 260px; }}
.tipos {{ transform: scale(1.05); transform-origin: center; color: #222; }}
{CSS_TIPOS}
.tipos th.esq {{ color: #ddd; }}
.contador {{ font: 700 150px/1 Fredoka; text-shadow: 0 8px 0 #7a0a1c; }}
.vidas {{ display: grid; grid-template-columns: repeat(9, 80px); gap: 12px; }} .vidas svg {{ width: 80px; height: 80px; }}
.barra {{ display: flex; align-items: center; gap: 20px; background: #2a2f3a; border: 4px solid #fff; border-radius: 20px; padding: 20px 30px; }}
.barra div {{ width: 300px; height: 26px; border-radius: 13px; background: #555; }} .barra b {{ font: 600 44px Fredoka; }}
.aviso {{ font: 800 32px Nunito; background: #1d6b34; border-radius: 18px; padding: 22px 34px; }}
.ruta {{ font: 600 54px Fredoka; background: #3a6b2a; border-radius: 20px; padding: 26px 46px; border: 4px solid #8fd06f; }}
.tachado {{ position: relative; }} .tachado::after {{ content: ''; position: absolute; left: -8%; right: -8%; top: 50%; height: 16px;
  background: #ff2b47; border-radius: 8px; transform: rotate(-35deg); box-shadow: 0 0 0 4px #24121a; }}
.flecha {{ font: 700 110px Fredoka; color: #f2b8c2; }}
.brillo {{ position: relative; }} .brillo .poke {{ width: 420px; height: 420px; }}
.brillo span {{ position: absolute; color: #ffe066; font-size: 90px; }}
.brillo span:nth-of-type(1) {{ top: 0; left: -40px; }} .brillo span:nth-of-type(2) {{ top: 60px; right: -50px; font-size: 60px; }}
.brillo span:nth-of-type(3) {{ bottom: 10px; left: 20px; font-size: 70px; }}
.rejilla3 {{ display: grid; grid-template-columns: repeat(3, 230px); gap: 30px 60px; }} .rejilla3 .poke {{ width: 200px; height: 200px; }}
.zzz {{ position: relative; }} .zzz b {{ position: absolute; top: -20px; right: -30px; font: 700 70px Fredoka; color: #9fd2ff; }}
.caja-pc {{ width: 300px; height: 300px; border-radius: 24px; background: #4f86c6; border: 6px solid #cde3ff; display: flex;
  flex-direction: column; align-items: center; justify-content: center; gap: 20px; }} .caja-pc span {{ font: 600 34px Fredoka; }}
.huevo {{ width: 120px; }}
.medalla {{ width: 200px; }} .medalla.pequena {{ width: 110px; }}
.candado {{ font-size: 150px; }}
.icono {{ font-size: 150px; line-height: 1; display: flex; flex-direction: column; align-items: center; gap: 16px; }}
.icono span {{ font: 600 40px Fredoka; }}
.lider {{ height: 380px; }}
.objeto {{ width: 260px; }}
.tope {{ text-align: center; background: #c8102e; border-radius: 30px; padding: 30px 60px; }}
.tope span {{ display: block; font: 800 30px Nunito; letter-spacing: 3px; text-transform: uppercase; }}
.tope b {{ display: block; font: 700 170px/1 Fredoka; }} .tope small {{ font: 700 28px Nunito; opacity: .85; }}
.vial {{ width: 190px; image-rendering: pixelated; }}
.tecla {{ font: 800 90px Nunito; color: #222; background: #f4efe9; border-radius: 22px; padding: 10px 44px;
  box-shadow: 0 12px 0 #9c938a; border: 3px solid #fff; }}
.txt {{ font: 600 56px Fredoka; }}
.nota {{ margin: 0; font: 700 34px Nunito; color: #f2b8c2; }}
.centro {{ font-size: 140px; color: #ff4d64; background: #fff; border-radius: 30px; padding: 10px 40px; display: flex;
  flex-direction: column; align-items: center; line-height: 1.1; }} .centro span {{ font: 600 30px Fredoka; color: #c8102e; }}
.huevos {{ display: grid; grid-template-columns: repeat(10, 72px); gap: 18px; }} .huevos .huevo {{ width: 72px; }}
.calendario {{ display: grid; grid-template-columns: 1fr 1fr; gap: 24px; width: 100%; }}
.calendario div {{ background: #2e2533; border-radius: 24px; padding: 30px 34px; font: 700 36px Nunito; }}
.calendario b {{ display: block; font: 600 46px Fredoka; color: #f2b8c2; margin-bottom: 6px; }}
.calendario .sab {{ background: #c8102e; }} .calendario .sab b {{ color: #fff; }} .calendario .final {{ background: #b8860b; }}
.stop {{ font: 700 120px Fredoka; background: #c8102e; border: 10px solid #fff; padding: 20px 50px; border-radius: 40px; }}
.cuadro {{ display: flex; gap: 60px; align-items: center; }} .cuadro .col {{ display: flex; flex-direction: column; justify-content: space-around; gap: 60px; }}
.cuadro i {{ font: 600 36px Fredoka; font-style: normal; background: #2e2533; border: 3px solid #f2b8c2; border-radius: 16px; padding: 16px 30px; }}
.cuadro i.oro {{ background: #b8860b; border-color: #ffe066; }}
.podio {{ display: flex; align-items: flex-end; gap: 30px; }}
.podio > div {{ background: #2e2533; border-radius: 30px 30px 0 0; width: 300px; display: flex; flex-direction: column; align-items: center;
  gap: 18px; padding: 30px 20px; }}
.podio > div:nth-child(1) {{ height: 420px; }} .podio .primero {{ height: 600px; width: 340px; background: #3d2a33; }} .podio > div:nth-child(3) {{ height: 300px; }}
.podio img, .podio .huevo {{ width: 110px; height: 110px; object-fit: contain; }}
.puesto {{ font: 700 54px Fredoka; width: 120px; height: 120px; border-radius: 50%; display: grid; place-items: center; color: #222; }}
.oro {{ background: linear-gradient(135deg, #f7d774, #c9962b); }} .plata {{ background: linear-gradient(135deg, #eef0f3, #a9aeb6); }}
.bronce {{ background: linear-gradient(135deg, #f0b98a, #a8622e); }}
.trofeo {{ width: 300px; }}
.etiquetas {{ gap: 200px; font: 600 40px Fredoka; color: #f2b8c2; }}
.portada {{ height: 470px; border-radius: 16px; box-shadow: 0 20px 50px rgba(0,0,0,.6); }}
</style></head><body>{paginas}</body></html>'''
    (AQUI / 'laminas.html').write_text(html, encoding='utf-8')
    pdf = AQUI / 'laminas.pdf'
    subprocess.run(['google-chrome', '--headless=new', '--disable-gpu', '--no-pdf-header-footer', '--virtual-time-budget=15000',
                    f'--print-to-pdf={pdf}', (AQUI / 'laminas.html').as_uri()], check=True, capture_output=True)
    salida = AQUI / 'imagenes'
    salida.mkdir(exist_ok=True)
    doc = fitz.open(pdf)
    assert len(doc) == len(LAMINAS), (len(doc), len(LAMINAS))
    for pagina, (nombre, *_) in zip(doc, LAMINAS):
        pix = pagina.get_pixmap(matrix=fitz.Matrix(1920 / pagina.rect.width, 1080 / pagina.rect.height))
        pix.save(salida / f'{nombre}.png')
    pdf.unlink()
    print(len(LAMINAS), 'láminas en', salida)


if __name__ == '__main__':
    construir()
