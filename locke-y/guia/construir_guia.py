"""Guía del Mega Pokelocke Y: genera guia.html y la imprime a Guia-Mega-Pokelocke-Y.pdf con Chrome headless.

Entrenadores y niveles originales: Serebii Pokéarth (entrenadores_serebii.json). Los niveles se muestran con el
+15 % de las normas Mega (redondeo del UPR). Sprites de entrenador: Pokémon Showdown, en caché en sprites/.
    python3 construir_guia.py
"""
import html
import json
import subprocess
import urllib.request
from pathlib import Path

AQUI = Path(__file__).resolve().parent
SPRITES = AQUI / 'sprites'
SD = 'https://play.pokemonshowdown.com/sprites/trainers/'
DATOS = json.loads((AQUI / 'entrenadores_serebii.json').read_text(encoding='utf-8'))


def mega(nivel):
    return min(100, int(nivel * 1.15 + 0.5))


# ---------- nombres ----------

PERSONAJES = {
    'Viola': 'Violeta', 'Grant': 'Lino', 'Korrina': 'Corelia', 'Ramos': 'Amaro', 'Clemont': 'Lem',
    'Valerie': 'Valeria', 'Olympia': 'Ástrid', 'Wulfric': 'Édel', 'Siebold': 'Narciso', 'Wikstrom': 'Tileo',
    'Drasna': 'Drácena', 'Dianthe': 'Dianta', 'Sycamore': 'Ciprés', 'Lysandre': 'Lysson', 'Trevor': 'Trovato',
}
# clase en inglés -> (masculino, femenino)
CLASES = {
    'Youngster': ('Joven',) * 2, 'Lass': ('Chica',) * 2, 'Preschooler': ('Parvulito', 'Parvulita'),
    'Schoolboy': ('Colegial',) * 2, 'Schoolgirl': ('Colegiala',) * 2, 'Roller Skater': ('Patinador', 'Patinadora'),
    'Rising Star': ('Promesa',) * 2, 'Poké Fan': ('Pokéfan',) * 2, 'Gardener': ('Jardinero',) * 2,
    'Tourist': ('Turista',) * 2, 'Backpacker': ('Mochilero', 'Mochilera'), 'Artist': ('Artista',) * 2,
    'Pokémon Breeder': ('Criador Pokémon', 'Criadora Pokémon'), 'Black Belt': ('Karateka',) * 2,
    'Battle Girl': ('Luchadora',) * 2, 'Sky Trainer': ('Entrenador aéreo', 'Entrenadora aérea'),
    'Hiker': ('Montañero',) * 2, 'Psychic': ('Médium',) * 2, 'Fisherman': ('Pescador',) * 2,
    'Swimmer M': ('Nadador',) * 2, 'Swimmer F': ('Nadadora',) * 2, 'Pokémon Ranger': ('Pokémon Ranger',) * 2,
    'Ace Trainer': ('Entrenador guay', 'Entrenadora guay'), 'Hex Maniac': ('Ocultista',) * 2,
    'Fairy Tale Girl': ('Chica de cuento',) * 2, 'Furisode Girl': ('Chica furisode',) * 2,
    'Punk Guy': ('Punk',) * 2, 'Punk Girl': ('Punk',) * 2, 'Veteran': ('Veterano', 'Veterana'),
    'Worker': ('Obrero',) * 2, 'Brains & Brawn': ('Cerebro y Músculo',) * 2, 'Twins': ('Gemelas',) * 2,
    'Rangers': ('Rangers',) * 2, 'Ace Duo': ('Dúo guay',) * 2, 'Punk Couple': ('Pareja punk',) * 2,
    'Honeymooners': ('Recién casados',) * 2, 'Mysterious Sisters': ('Hermanas misteriosas',) * 2,
    'PokéFan Family': ('Familia Pokéfan',) * 2, 'Owner': ('Dueño',) * 2, 'Waitress': ('Camarera',) * 2,
    'Garcon': ('Camarero',) * 2, 'Beauty': ('Bella',) * 2, 'Scientist': ('Científico', 'Científica'),
    'Butler': ('Mayordomo',) * 2, 'Team Flare Grunt': ('Recluta Flare',) * 2,
    'Team Flare Admin': ('Admin. Flare',) * 2, 'Team Flare': ('Team Flare',) * 2, 'Leader': ('Líder',) * 2,
    'Elite Four': ('Alto Mando',) * 2, 'Champion': ('Campeona',) * 2, 'Pokémon Trainer': ('Amiga', 'Amiga'),
    'Pokémon Professor': ('Profesor',) * 2, 'Successor': ('Heredera',) * 2,
}
# clase -> sprite de Showdown (masculino, femenino)
SPRITE_CLASE = {
    'Youngster': ('youngster-gen6xy',) * 2, 'Lass': ('lass-gen6',) * 2,
    'Preschooler': ('preschooler-gen6', 'preschoolerf-gen6'), 'Schoolboy': ('schoolkid-gen6',) * 2,
    'Schoolgirl': ('schoolkidf-gen6',) * 2, 'Roller Skater': ('rollerskater', 'rollerskaterf'),
    'Rising Star': ('risingstar-gen6', 'risingstarf-gen6'), 'Poké Fan': ('pokefan-gen6xy', 'pokefanf-gen6xy'),
    'Gardener': ('gardener',) * 2, 'Tourist': ('tourist', 'touristf'), 'Backpacker': ('backpacker-gen6', 'backpackerf'),
    'Artist': ('artist-gen6', 'artistf-gen6'), 'Pokémon Breeder': ('pokemonbreeder-gen6xy', 'pokemonbreederf-gen6xy'),
    'Black Belt': ('blackbelt-gen6',) * 2, 'Battle Girl': ('battlegirl-gen6xy',) * 2,
    'Sky Trainer': ('skytrainer', 'skytrainerf'), 'Hiker': ('hiker-gen6',) * 2, 'Psychic': ('psychic-gen6',) * 2,
    'Fisherman': ('fisherman-gen6xy',) * 2, 'Swimmer M': ('swimmer-gen6',) * 2, 'Swimmer F': ('swimmerf-gen6',) * 2,
    'Pokémon Ranger': ('pokemonranger-gen6xy', 'pokemonrangerf-gen6xy'), 'Rangers': ('pokemonranger-gen6xy',) * 2,
    'Ace Trainer': ('acetrainer-gen6xy', 'acetrainerf-gen6xy'), 'Ace Duo': ('acetrainer-gen6xy',) * 2,
    'Hex Maniac': ('hexmaniac-gen6',) * 2, 'Fairy Tale Girl': ('fairytalegirl',) * 2,
    'Furisode Girl': ('furisodegirl-pink',) * 2, 'Punk Guy': ('punkguy',) * 2, 'Punk Girl': ('punkgirl',) * 2,
    'Punk Couple': ('punkguy',) * 2, 'Veteran': ('veteran-gen6', 'veteranf-gen6'), 'Worker': ('worker-gen6',) * 2,
    'Brains & Brawn': ('psychic-gen6',) * 2, 'Twins': ('twins-gen6',) * 2, 'Honeymooners': ('youngcouple-gen6',) * 2,
    'Mysterious Sisters': ('hexmaniac-gen6',) * 2, 'PokéFan Family': ('pokefan-gen6xy',) * 2,
    'Owner': ('owner',) * 2, 'Waitress': ('waitress-gen6',) * 2, 'Garcon': ('garcon',) * 2,
    'Beauty': ('beauty-gen6xy',) * 2, 'Scientist': ('scientist-gen6', 'scientistf-gen6'), 'Butler': ('butler',) * 2,
    'Team Flare Grunt': ('flaregrunt',) * 2, 'Team Flare Admin': ('flaregruntf',) * 2,
}
SPRITE_PERSONAJE = {
    'Viola': 'viola', 'Grant': 'grant', 'Korrina': 'korrina', 'Ramos': 'ramos', 'Clemont': 'clemont',
    'Valerie': 'valerie', 'Olympia': 'olympia', 'Wulfric': 'wulfric', 'Malva': 'malva', 'Siebold': 'siebold',
    'Wikstrom': 'wikstrom', 'Drasna': 'drasna', 'Dianthe': 'diantha', 'Sycamore': 'sycamore', 'Lysandre': 'lysandre',
    'Shauna': 'shauna', 'Tierno': 'tierno', 'Trevor': 'trevor', 'Bryony': 'bryony', 'Mable': 'mable',
    'Xerosic': 'xerosic', 'Aliana': 'flaregruntf', 'Celosia': 'flaregruntf',
}
MUJERES = set('Alanza Cordelia Hilde Imelda Mireille Monique Shannon Ambre Brooke Clementine Melina Petra Twiggy Amala '
              'Mercy Estel Helene Louise Manon Nelly Paulette Abigail Agnes Lydie Roisin Tara Georgia Ella Lily Mia '
              'Natalie Eriko Fumiko Hiroko Mari Monami Tomoko Catrina Inga Trisha Calida Kate Rinka Rolanda Winnie '
              'Anila Aveza Clara Elata Era Indra Sera Yvette Heike Sonia Michele Mona'.split())
IMPORTANTES = {'Shauna', 'Tierno', 'Trevor', 'Lysandre', 'Aliana', 'Celosia', 'Bryony', 'Mable', 'Xerosic'}
COMBATE = {'Single Battle': 'Individual', 'Double Battle': 'Doble', 'Triple Battle': 'Triple',
           'Rotation Battle': 'Rotatoria', 'Sky Battle': 'Aérea', 'Inverse Battle': 'Inversa', 'Horde Battle': 'Horda'}


def separar(nombre):
    """'Pokémon Ranger Silas' -> ('Pokémon Ranger', 'Silas')."""
    for clase in sorted(CLASES, key=len, reverse=True):
        if nombre.startswith(clase + ' ') or nombre == clase:
            return clase, nombre[len(clase):].strip()
    raise KeyError(nombre)


def ficha(t, primera_shauna=False):
    clase, nombre = separar(t['name'])
    rival = nombre in ('Serena', 'Calem')
    mujer = nombre in MUJERES or nombre.split(' & ')[0] in MUJERES
    if rival:
        etiqueta, nombre, sprites = 'Rival', 'Kalm / Serena', ['calem', 'serena']
    else:
        etiqueta = CLASES[clase][mujer]
        if clase == 'Pokémon Trainer':
            etiqueta = 'Amigo' if nombre in ('Tierno', 'Trevor') else 'Amiga'
        if clase == 'Team Flare' and nombre != 'Lysandre':
            etiqueta = 'Científico Flare' if nombre == 'Xerosic' else 'Científica Flare'
        sprites = [SPRITE_PERSONAJE.get(nombre) or SPRITE_CLASE[clase][mujer]]
        nombre = PERSONAJES.get(nombre, nombre)
    niveles = [mega(n) for n in t['lv']]
    jefe = clase in ('Leader', 'Elite Four', 'Champion') or rival or (separar(t['name'])[1] in IMPORTANTES)
    seis = jefe and not primera_shauna and len(niveles) < 6 and t['bt'] == 'Single Battle'
    if seis:                                  # MegaFases: relleno al nivel del más bajo, el as sigue el último
        niveles = niveles[:-1] + [min(niveles)] * (6 - len(niveles)) + niveles[-1:]
    return dict(etiqueta=etiqueta, nombre=nombre, sprites=sprites, niveles=niveles, jefe=jefe, seis=seis,
                combate=COMBATE.get(t['bt'], t['bt']))


def entrenadores(pagina, filtro=lambda t: True):
    vistos, out = set(), []
    for t in DATOS[pagina]:
        if not filtro(t):
            continue
        clave = (t['name'].replace('Calem', 'Serena'), tuple(t['lv']))
        if clave in vistos:
            continue
        vistos.add(clave)
        out.append(ficha(t, primera_shauna=(pagina == 'aquacordetown')))
    return out


# ---------- recorrido ----------
# (título, página de Serebii o None, qué hacer, filtro)
NO_POSTGAME_LUMINALIA = lambda t: min(t['lv']) < 50
BLOQUES = [
    dict(medalla=1, lider='Violeta', tipo='Bicho', tope=12, titulo='Primeros pasos', zonas=[
        ('Pueblo Boceto', None, 'Empieza la aventura. Tu inicial es aleatorio, pero siempre con dos evoluciones. '
         'Habla con tu madre y sal hacia Pueblo Acuarela.'),
        ('Pueblo Acuarela', 'aquacordetown', 'Conoces a Shauna, Tierno y Trovato. El primer combate contra Shauna '
         'lleva un solo Pokémon. <b>Las muertes no cuentan hasta que termina este combate.</b>'),
        ('Ruta 2', 'route2', 'Primera hierba alta: tu primera captura de verdad. Recuerda, una por ruta.'),
        ('Bosque Novarte', 'santaluneforest', 'Bosque con varias zonas de hierba; cuenta como una sola ruta. '
         'Shauna te acompaña y te cura tras cada combate.'),
        ('Ruta 3', 'route3', 'Ruta corta con entrenadores de nivel bajo. Buena para subir un poco antes del gimnasio.'),
        ('Ciudad Novarte', 'santalunecity', 'Rinka te da los Patines. Tras ganar a Violeta, Alexa te entrega el '
         '<b>Repartir Experiencia</b>. Ruta 22 (Camino Desvío) queda al oeste: entrenadores opcionales.'),
        ('Ruta 22 · Camino Desvío', 'route22', 'Opcional. Combates fáciles de nivel bajo y una ruta más para capturar.'),
    ]),
    dict(medalla=2, lider='Lino', tipo='Roca', tope=25, titulo='Rumbo a Relieve', zonas=[
        ('Ruta 4', 'route4', 'Jardines de flores camino de Luminalia. Ojo con los patinadores.'),
        ('Ciudad Luminalia (1.ª visita)', 'lumiosecity', 'Visita el laboratorio del profesor Ciprés: te reta y te da un '
         'Pokémon de regalo (aleatorio). Muchas calles están cerradas hasta tener electricidad.',
         lambda t: max(t['lv']) <= 10),
        ('Ruta 5', 'route5', 'Tierno te reta en la ruta. Hay patinadores y combates dobles.'),
        ('Pueblo Vánitas', 'camphriertown', 'Un Snorlax (aleatorio) bloquea la Ruta 7: necesitas la Poké Flauta del '
         'Palacio Cénit.'),
        ('Ruta 6 y Palacio Cénit', 'route6', 'Avenida de los turistas. En el palacio, ayuda a encontrar el Poké '
         'Flauta y vuelve para despertar al Pokémon de la Ruta 7.'),
        ('Ruta 7', 'route7', 'Tierno y Trovato te esperan. El Pokémon dormido es un estático aleatorio: puedes '
         'capturarlo, pero cuenta como la captura de la ruta. El Castillo Batalla queda aquí.'),
        ('Cueva Desenlace', 'connectingcave', 'Cueva corta y oscura. Un criador con cuatro Pokémon.'),
        ('Ruta 8', 'route8', 'Acantilados junto al mar. Muchos entrenadores: prepárate antes de cruzar.'),
        ('Ruta 9 y Cueva Brillante', 'glitteringcave', 'Primer encuentro con el Team Flare. Al fondo te dan a '
         'elegir un fósil.'),
        ('Ruta 9 · Cañón Espinoso', 'route9', 'Se cruza a lomos de Rhyhorn. Un entrenador aéreo.'),
        ('Ciudad Relieve', 'cyllagecity', 'Gimnasio de escalada de Lino. <b>Segunda medalla: guarda y reinicia el '
         'juego</b> para abrir la randomización completa. Toca coger huevo.'),
    ]),
    dict(medalla=3, lider='Corelia', tipo='Lucha', tope=32, titulo='La Mega Evolución', zonas=[
        ('Ruta 10', 'route10', 'Camino de menhires. Desde aquí los rivales ya no llevan límite de potencia.'),
        ('Pueblo Geosenge', 'geosengetown', 'Pueblo de las piedras. El Team Flare ronda por aquí.',
         lambda t: 'Korrina' not in t['name'] and max(t['lv']) < 40),
        ('Ruta 11', 'route11', 'Ruta con médiums, luchadoras y un combate de Cerebro y Músculo.'),
        ('Cueva Reflejos', 'reflectioncave', 'Cueva de espejos con varios pisos y entrenadores de nivel alto.'),
        ('Torre Maestra', 'towerofmastery', 'Combate contra tu rival y, tras el gimnasio, el duelo de Mega '
         'Evolución con Corelia. Te dan el Mega Aro.'),
        ('Ciudad Yantra', 'shalourcity', 'Gimnasio de patinaje de Corelia.'),
    ]),
    dict(medalla=4, lider='Amaro', tipo='Planta', tope=34, titulo='El gran torneo', zonas=[
        ('Ruta 12', 'route12', 'Costa con Lapras de alquiler. Nadadores y pescadores.'),
        ('Bahía Azul', 'azurebay', 'Bahía con entrenadores sobre el agua.'),
        ('Ciudad Témpera', 'coumarinecity', 'Tu rival te espera en el acantilado. <b>Cuarta medalla: termina la '
         'primera parte y toca el gran torneo.</b> Coge otro huevo.'),
    ]),
    dict(medalla=5, lider='Lem', tipo='Eléctrico', tope=37, titulo='Luz para Luminalia', zonas=[
        ('Ruta 13 · Desierto Hondonada', 'route13', 'Tormenta de arena. Un recluta Flare camino de la central.'),
        ('Central Eléctrica de Kalos', 'kalospowerplant', 'El Team Flare corta la luz de Luminalia. Aliana espera '
         'al final.'),
        ('Ciudad Luminalia', 'lumiosecity', 'Con la luz de vuelta se abren las plazas y la Torre Prisma. Gimnasio de '
         'Lem: trivial de preguntas antes de llegar a él.', lambda t: 10 < max(t['lv']) and NO_POSTGAME_LUMINALIA(t)),
    ]),
    dict(medalla=6, lider='Valeria', tipo='Hada', tope=42, titulo='La ciudad de las hadas', zonas=[
        ('Ruta 14 · Senda Inhóspita', 'route14', 'Pantanos y tu rival. Hay una casa de terror opcional.'),
        ('Ciudad Romantis', 'laverrecity', 'Gimnasio de Valeria.'),
        ('Fábrica de Poké Balls', 'pokeballfactory', 'El Team Flare ocupa la fábrica. Celosia y Bryony al '
         'fondo. <b>Sexta medalla: otro huevo.</b>'),
    ]),
    dict(medalla=7, lider='Ástrid', tipo='Psíquico', tope=48, titulo='Hacia el reloj de sol', zonas=[
        ('Ruta 15', 'route15', 'Bosque otoñal con rangers y ocultistas.'),
        ('Hotel Desolación', 'losthotel', 'Opcional. Un hotel en ruinas lleno de punks.'),
        ('Ruta 16', 'route16', 'Camino a Pueblo Fresco con combates aéreos.'),
        ('Cueva Helada', 'frostcavern', 'Mable y el Team Flare. Necesitas cruzarla para seguir.'),
        ('Ruta 17 · Vía Mamoswine', 'route17', 'Nieve profunda: se cruza a lomos de Mamoswine.'),
        ('Ciudad Fluxus', 'anistarcity', 'Tu rival te reta junto al reloj de sol. Gimnasio de Ástrid.'),
    ]),
    dict(medalla=8, lider='Édel', tipo='Hielo', tope=59, titulo='El arma definitiva', zonas=[
        ('Laboratorio de Lysson', 'lysandrelabs', 'Bajo el Café Lysson. Lysson, los científicos y los '
         'admins del Team Flare.', lambda t: t['sec'] != 'Hidden Floor'),
        ('Base del Team Flare', 'teamflarehq', 'Bajo Pueblo Geosenge. Combates dobles con tus amigos y '
         'Lysson al final. El legendario es aleatorio.'),
        ('Pueblo Geosenge (de vuelta)', 'geosengetown', 'Un recluta guarda la entrada a la base.',
         lambda t: 'Korrina' not in t['name'] and max(t['lv']) >= 40),
        ('Ruta 18', 'route18', 'Camino de vuelta al sur. El médium Inver propone combates inversos: opcionales.',
         lambda t: 'Inver' not in t['name'] or t['lv'][0] == 55),
        ('Cueva Término', 'terminuscave', 'Opcional, al lado de la Ruta 18. Mineros y luchadores.'),
        ('Pueblo Mosaico', 'couriwaytown', 'El profesor Ciprés te reta con los iniciales de Kanto.'),
        ('Ruta 19 · Camino Pantanoso', 'route19', 'Shauna, Tierno y Trovato te esperan aquí, uno tras otro.'),
        ('Ruta 20 · Bosque Errante', 'route20', 'Bosque laberíntico hacia la Aldea Pokémon (opcional).'),
        ('Ciudad Fractal', 'snowbellecity', 'Gimnasio de Édel. <b>Octava medalla: último huevo.</b>'),
    ]),
    dict(medalla=None, lider='Dianta', tipo='Liga', tope=68, titulo='La Liga Pokémon', zonas=[
        ('Ruta 21 · Calle Derecha', 'route21', 'Entrenadores guay antes de la Calle Victoria.'),
        ('Calle Victoria', 'victoryroad', 'Larga y llena de veteranos. Tu rival te espera en la parte exterior.'),
        ('Liga Pokémon', 'pokemonleague', 'Alto Mando en el orden que quieras y, al final, la campeona Dianta.'),
    ]),
]
for b in BLOQUES:
    b['tope_mega'] = mega(b['tope'])

TIPOS = ['Normal', 'Fuego', 'Agua', 'Eléctrico', 'Planta', 'Hielo', 'Lucha', 'Veneno', 'Tierra', 'Volador',
         'Psíquico', 'Bicho', 'Roca', 'Fantasma', 'Dragón', 'Siniestro', 'Acero', 'Hada']
COLOR_TIPO = ['#9fa19f', '#e62829', '#2980ef', '#d6ad00', '#3fa129', '#3dcef3', '#ff8000', '#9141cb', '#915121',
              '#81b9ef', '#ef4179', '#91a119', '#afa981', '#704170', '#5060e1', '#624d4e', '#60a1b8', '#ef70ef']
# atacante: (súper eficaz, poco eficaz, inmune) — 6.ª generación
EF = {
    'Normal': ('', 'Roca Acero', 'Fantasma'),
    'Fuego': ('Planta Hielo Bicho Acero', 'Fuego Agua Roca Dragón', ''),
    'Agua': ('Fuego Tierra Roca', 'Agua Planta Dragón', ''),
    'Eléctrico': ('Agua Volador', 'Eléctrico Planta Dragón', 'Tierra'),
    'Planta': ('Agua Tierra Roca', 'Fuego Planta Veneno Volador Bicho Dragón Acero', ''),
    'Hielo': ('Planta Tierra Volador Dragón', 'Fuego Agua Hielo Acero', ''),
    'Lucha': ('Normal Hielo Roca Siniestro Acero', 'Veneno Volador Psíquico Bicho Hada', 'Fantasma'),
    'Veneno': ('Planta Hada', 'Veneno Tierra Roca Fantasma', 'Acero'),
    'Tierra': ('Fuego Eléctrico Veneno Roca Acero', 'Planta Bicho', 'Volador'),
    'Volador': ('Planta Lucha Bicho', 'Eléctrico Roca Acero', ''),
    'Psíquico': ('Lucha Veneno', 'Psíquico Acero', 'Siniestro'),
    'Bicho': ('Planta Psíquico Siniestro', 'Fuego Lucha Veneno Volador Fantasma Acero Hada', ''),
    'Roca': ('Fuego Hielo Volador Bicho', 'Lucha Tierra Acero', ''),
    'Fantasma': ('Psíquico Fantasma', 'Siniestro', 'Normal'),
    'Dragón': ('Dragón', 'Acero', 'Hada'),
    'Siniestro': ('Psíquico Fantasma', 'Lucha Siniestro Hada', ''),
    'Acero': ('Hielo Roca Hada', 'Fuego Agua Eléctrico Acero', ''),
    'Hada': ('Lucha Dragón Siniestro', 'Fuego Veneno Acero', ''),
}


def factor(a, d):
    s, p, i = (x.split() for x in EF[a])
    return 0 if d in i else 2 if d in s else 0.5 if d in p else 1


# ---------- HTML ----------

def sprite(nombre):
    f = SPRITES / f'{nombre}.png'
    if not f.exists():
        req = urllib.request.Request(SD + f.name, headers={'User-Agent': 'Mozilla/5.0'})
        f.write_bytes(urllib.request.urlopen(req, timeout=30).read())
    return f'sprites/{f.name}'


def carta(e, tope):
    imgs = ''.join(f'<img src="{sprite(s)}" alt="">' for s in e['sprites'])
    chips = ''.join(f'<span class="nv{" alto" if n > tope else ""}">{n}</span>' for n in e['niveles'])
    marcas = f'<span class="tag">{e["combate"]}</span>' if e['combate'] != 'Individual' else ''
    if e['seis']:
        marcas += '<span class="tag seis">Equipo de 6</span>'
    return (f'<div class="carta{" jefe" if e["jefe"] else ""}"><div class="foto{" doble" if len(e["sprites"]) > 1 else ""}">'
            f'{imgs}</div><div class="info"><div class="clase">{html.escape(e["etiqueta"])}</div>'
            f'<div class="nombre">{html.escape(e["nombre"])}</div><div class="niveles">{chips}</div>'
            f'<div class="marcas">{marcas}</div></div></div>')


def tabla_tipos():
    cab = ''.join(f'<th class="vert"><span style="background:{COLOR_TIPO[i]}">{t[:3].upper()}</span></th>'
                  for i, t in enumerate(TIPOS))
    filas = ''
    for i, a in enumerate(TIPOS):
        celdas = ''
        for d in TIPOS:
            f = factor(a, d)
            txt, cls = {2: ('2', 'x2'), 0.5: ('½', 'x05'), 0: ('0', 'x0'), 1: ('', '')}[f]
            celdas += f'<td class="{cls}">{txt}</td>'
        filas += f'<tr><th><span class="pill" style="background:{COLOR_TIPO[i]}">{a}</span></th>{celdas}</tr>'
    return f'<table class="tipos"><tr><th class="esq">ATACA ↓ · DEFIENDE →</th>{cab}</tr>{filas}</table>'


def construir():
    SPRITES.mkdir(exist_ok=True)
    indice, cuerpo = [], []
    for n, b in enumerate(BLOQUES, 1):
        ancla = f'bloque-{n}'
        med = f'<img class="medalla" src="../assets/medalla-{b["medalla"]}.png" alt="">' if b['medalla'] else '<div class="medalla liga">★</div>'
        subz = []
        zonas_html = ''
        for k, z in enumerate(b['zonas']):
            titulo, pagina, texto = z[:3]
            filtro = z[3] if len(z) > 3 else (lambda t: True)
            za = f'{ancla}-{k}'
            subz.append(f'<li><a href="#{za}">{titulo}</a></li>')
            lista = entrenadores(pagina, filtro) if pagina else []
            cartas = ''.join(carta(e, b['tope_mega']) for e in lista) or '<p class="vacio">Sin entrenadores.</p>'
            zonas_html += (f'<section class="zona" id="{za}"><h3>{titulo}</h3><div class="hacer"><b class="et">Qué hacer</b>'
                           f'<p>{texto}</p></div><div class="cartas">{cartas}</div></section>')
        rival = 'Campeona' if not b['medalla'] else f'Líder · tipo {b["tipo"]}'
        indice.append(f'<li class="ib"><a href="#{ancla}"><span class="num">{n}</span><span class="t">{b["titulo"]}'
                      f'</span><span class="cap">Tope {b["tope_mega"]}</span></a><ul>{"".join(subz)}</ul></li>')
        cuerpo.append(
            f'<section class="bloque" id="{ancla}"><header class="cabecera">{med}<div><div class="eta">Bloque {n} · '
            f'{rival}</div><h2>{b["titulo"]}</h2><div class="sub">Hasta {b["lider"]}</div></div><div class="tope">'
            f'<span>Nivel tope</span><b>{b["tope_mega"]}</b><small>{b["tope"]} + 15 %</small></div></header>'
            f'{zonas_html}</section>')
    plantilla = (AQUI / 'plantilla.html').read_text(encoding='utf-8')
    out = (plantilla.replace('{{INDICE}}', ''.join(indice)).replace('{{TIPOS}}', tabla_tipos())
           .replace('{{BLOQUES}}', ''.join(cuerpo)))
    (AQUI / 'guia.html').write_text(out, encoding='utf-8')
    subprocess.run(['google-chrome', '--headless=new', '--disable-gpu', '--no-pdf-header-footer',
                    '--virtual-time-budget=15000', f'--print-to-pdf={AQUI / "Guia-Mega-Pokelocke-Y.pdf"}',
                    (AQUI / 'guia.html').as_uri()], check=True, capture_output=True)
    print('Hecho:', AQUI / 'Guia-Mega-Pokelocke-Y.pdf')


if __name__ == '__main__':
    construir()
