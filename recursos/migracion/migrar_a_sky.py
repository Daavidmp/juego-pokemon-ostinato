"""Migra Pokémon Ostinato de Essentials BES (v16.2) a La Base de Sky (Essentials v21.1).

    python migrar_a_sky.py            # desde recursos/migracion/, con las dos carpetas del juego al lado

Parte de una copia limpia de La Base de Sky en «Pokémon Ostinato/» y trae lo del juego que hay en
«Pokémon Essentials BES/», sin tocar esta última. Lo que hace, en orden:
  1. Mapas: fuera los de la demo de Sky; dentro los de Ostinato, su MapInfos y su Tilesets.rxdata
     (los terrain tags 1-16 son iguales en las dos versiones; ningún tileset usa el 17).
  2. System.rxdata: el de Sky, con lo de Ostinato encima (música del título, nombres de los switches
     y variables propios, posición de inicio y mapa del editor).
  3. Gráficos: tilesets, autotiles, títulos, sprites de mapa que falten y sprites de entrenador
     (trainer001.png -> CLASE.png, trback001.png -> CLASE_back.png, como los nombra la v21).
  4. Audio: la música, los sonidos ambientales y los ME de BES que Sky no tenga.
  5. PBS: jugadores, música global y metadatos de los mapas de Ostinato en el formato de la v21;
     las 3 clases de entrenador de BES que Sky no tiene. Sin los restos de la demo de BES que quedaban
     pegados a los números de mapa reutilizados (ver NO_SE_PASA).
  6. mkxp.json (pantalla completa, escalado suave, ventana 1364x768) y Game.ini.
Los scripts de Ostinato van aparte, como plugin, en Plugins/Ostinato/.
"""
import os, re, shutil, sys, filecmp

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
BES = os.path.join(RAIZ, 'Pokémon Essentials BES')
SKY = os.path.join(RAIZ, 'Pokémon Ostinato')
sys.path.insert(0, os.environ.get('PKMN_DEVKIT', r'C:\Users\david.martinez\pkmn-devkit'))
sys.path.insert(0, '/mnt/c/Users/david.martinez/pkmn-devkit')
from devkit.rxdata import marshal
from devkit.rxdata.marshal import IvarWrapped

MAPAS = [1, 2, 3, 4, 5, 6, 7, 43]          # los que hay en el MapInfos de Ostinato
# Metadatos de BES que se pasan, por mapa. El resto eran de la demo de Essentials (en la demo el 5 era la
# Ruta 1 y el 7 Ciudad Milanesa), y aplicados a la casa y al laboratorio los volvían «exteriores».
METADATOS = {2: ('Outdoor', 'MapPosition', 'ShowArea'), 3: ('BattleBack', 'MapPosition', 'HealingSpot')}
NO_SE_PASA = ('conexiones de la demo (Preludio-norte y laboratorio-sur llevaban al piso de arriba de la casa '
              'genérica), encuentros de la demo en los mapas 2 y 5, y los metadatos de exterior del 5 y el 7')
SWITCHES_PROPIOS = [72, 73]                 # fuga del laboratorio (numeración del guion + 50)
txt = lambda v: v.value if isinstance(v, IvarWrapped) else v
informe = []


def copiar(src, dst, pisar=True):
    if os.path.exists(dst) and (not pisar or filecmp.cmp(src, dst, shallow=False)):
        return False
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    return True


def copiar_carpeta(sub, pisar=True, filtro=None, destino=None):
    s, d = os.path.join(BES, sub), os.path.join(SKY, destino or sub)
    n = 0
    for base, _, fs in os.walk(s):
        for f in fs:
            if filtro and not filtro(f): continue
            rel = os.path.relpath(os.path.join(base, f), s)
            n += copiar(os.path.join(base, f), os.path.join(d, rel), pisar)
    informe.append('%-28s %4d ficheros' % (sub + (' (sin pisar)' if not pisar else ''), n))


# 1. mapas -------------------------------------------------------------------------------------
data = os.path.join(SKY, 'Data')
for f in os.listdir(data):
    if re.fullmatch(r'Map\d{3}\.rxdata', f): os.remove(os.path.join(data, f))
for m in MAPAS:
    shutil.copy2(os.path.join(BES, 'Data', 'Map%03d.rxdata' % m), os.path.join(data, 'Map%03d.rxdata' % m))
for f in ('MapInfos.rxdata', 'Tilesets.rxdata'):
    shutil.copy2(os.path.join(BES, 'Data', f), os.path.join(data, f))
informe.append('mapas %s, MapInfos y Tilesets de Ostinato' % MAPAS)

# 2. System ------------------------------------------------------------------------------------
sb = marshal.load_file(os.path.join(BES, 'Data', 'System.rxdata'))
ss = marshal.load_file(os.path.join(data, 'System.rxdata'))
for i in SWITCHES_PROPIOS:
    if txt(ss['switches'][i]): raise SystemExit('El switch %d ya tiene nombre en Sky: %r' % (i, txt(ss['switches'][i])))
    ss['switches'][i] = sb['switches'][i]
for k in ('title_bgm', 'start_map_id', 'start_x', 'start_y', 'edit_map_id'):
    ss[k] = sb[k]
blob = marshal.dump(ss); marshal.load(blob)
open(os.path.join(data, 'System.rxdata'), 'wb').write(blob)
informe.append('System: título «%s», switches %s' % (txt(sb['title_bgm']['name']), SWITCHES_PROPIOS))

# 3. gráficos ----------------------------------------------------------------------------------
for sub in ('Graphics/Tilesets', 'Graphics/Autotiles', 'Graphics/Titles'):
    copiar_carpeta(sub)
copiar_carpeta('Graphics/Characters', pisar=False)
for f in ('trchar000.png', 'trchar001.png', 'boy_run.png', 'girl_run.png', 'MUDKIP.png', 'FENNEKIN.png', 'SPRIGATITO.png'):
    copiar(os.path.join(BES, 'Graphics/Characters', f), os.path.join(SKY, 'Graphics/Characters', f))
tipos = {}
for l in open(os.path.join(BES, 'PBS/trainertypes.txt'), encoding='utf-8-sig').read().splitlines():
    p = l.split(',')
    if len(p) > 2 and p[0].strip().isdigit(): tipos[int(p[0])] = p
n = 0
for f in os.listdir(os.path.join(BES, 'Graphics/Battlers/Trainers')):
    m = re.fullmatch(r'(trainer|trback)(\d{3}|[A-Z0-9_]+)\.png', f)
    if not m: continue
    clave = m[2]
    nombre = tipos[int(clave)][1] if clave.isdigit() and int(clave) in tipos else (None if clave.isdigit() else clave)
    if not nombre: continue
    n += copiar(os.path.join(BES, 'Graphics/Battlers/Trainers', f),
                os.path.join(SKY, 'Graphics/Trainers', nombre + ('_back' if m[1] == 'trback' else '') + '.png'))
informe.append('Graphics/Trainers            %4d sprites de entrenador' % n)

# 4. audio -------------------------------------------------------------------------------------
for sub in ('Audio/BGM', 'Audio/BGS', 'Audio/ME'):
    copiar_carpeta(sub, pisar=False)
# en BES la música de victoria era un ME; la v21 la reproduce como BGM
for f in ('Victory - Trainer.ogg', 'Victory - Wild Pokemon.ogg'):
    copiar(os.path.join(BES, 'Audio/ME', f), os.path.join(SKY, 'Audio/BGM', f), pisar=False)

# 5. PBS ---------------------------------------------------------------------------------------
pbs = os.path.join(SKY, 'PBS')
meta = open(os.path.join(pbs, 'metadata.txt'), encoding='utf-8-sig').read()
def poner(bloque, clave, valor):
    global meta
    patron = r'(?ms)(^\[%s\]\n.*?)(^%s = .*?$)' % (bloque, clave)
    if re.search(patron, meta): meta = re.sub(patron, lambda m: m[1] + '%s = %s' % (clave, valor), meta, count=1)
    else: meta = re.sub(r'(?m)^\[%s\]\n' % bloque, lambda m: m[0] + '%s = %s\n' % (clave, valor), meta, count=1)
for clave, valor in (('Home', '3,7,5,8'), ('TrainerBattleBGM', 'Battle! (Trainer)'), ('WildBattleBGM', 'Battle! (Wild Pokemon)'),
                     ('TrainerVictoryBGM', 'Victory - Trainer'), ('WildVictoryBGM', 'Victory - Wild Pokemon'),
                     ('BicycleBGM', 'Bike'), ('SurfBGM', 'Surf')):
    poner(0, clave, valor)
for jugador, walk, run, bike in ((1, 'trchar000', 'boy_run', 'boy_bike'), (2, 'trchar001', 'girl_run', 'girl_bike')):
    poner(jugador, 'WalkCharset', walk); poner(jugador, 'RunCharset', run); poner(jugador, 'CycleCharset', bike)
open(os.path.join(pbs, 'metadata.txt'), 'w', encoding='utf-8-sig', newline='\r\n').write(meta.replace('\r\n', '\n'))
informe.append('metadata.txt: Home, música global y jugadores como en BES')

infos = marshal.load_file(os.path.join(data, 'MapInfos.rxdata'))
bes_meta = open(os.path.join(BES, 'PBS/metadata.txt'), encoding='utf-8-sig').read()
secs = re.split(r'(?m)^\[(\d+)\]\s*$', bes_meta)
bes_mapas = {int(secs[i]): secs[i + 1] for i in range(1, len(secs), 2)}
salida = ['# See the documentation on the wiki to learn how to edit this file.']
for m in MAPAS:
    salida += ['#-------------------------------', '[%03d]' % m, 'Name = %s' % txt(infos[m]['name'])]
    for l in bes_mapas.get(m, '').splitlines():
        l = l.strip()
        if not l or l.startswith('#') or '=' not in l: continue
        k, v = (x.strip() for x in l.split('=', 1))
        if k not in METADATOS.get(m, ('MapPosition',)): continue
        if k == 'BattleBack': v = 'indoor1'          # el fondo IndoorB de BES no existe en la v21
        salida.append('%s = %s' % (k, v))
open(os.path.join(pbs, 'map_metadata.txt'), 'w', encoding='utf-8-sig', newline='\r\n').write('\n'.join(salida) + '\n')
informe.append('map_metadata.txt: los %d mapas de Ostinato, con sus datos de BES' % len(MAPAS))
cabecera = '# See the documentation on the wiki to learn how to edit this file.\n'
for f in ('encounters.txt', 'map_connections.txt'):     # los de Sky eran de sus mapas de demo, que ya no están
    open(os.path.join(pbs, f), 'w', encoding='utf-8-sig', newline='\r\n').write(cabecera)
informe.append('encounters.txt y map_connections.txt vacíos · no se pasa: ' + NO_SE_PASA)

tt = open(os.path.join(pbs, 'trainer_types.txt'), encoding='utf-8-sig').read()
nuevos = []
for p in tipos.values():
    if re.search(r'(?m)^\[%s\]' % re.escape(p[1]), tt): continue
    genero = {'Male': 'Male', 'Female': 'Female'}.get(p[7].strip() if len(p) > 7 else '', 'Unknown')
    nuevos.append('#-------------------------------\n[%s]\nName = %s\nGender = %s\nBaseMoney = %s\n' % (p[1], p[2], genero, p[3] or '30'))
if nuevos:
    open(os.path.join(pbs, 'trainer_types.txt'), 'w', encoding='utf-8-sig', newline='\r\n').write(tt.rstrip('\n').replace('\r\n', '\n') + '\n' + ''.join(nuevos))
informe.append('trainer_types.txt: %d clases de BES que faltaban' % len(nuevos))

# 6. mkxp.json y Game.ini ------------------------------------------------------------------------
mk = os.path.join(SKY, 'mkxp.json'); j = open(mk, encoding='utf-8').read()
for clave, valor in (('fullscreen', 'true'), ('smoothScaling', 'true'), ('fixedAspectRatio', 'true'),
                     ('defScreenW', '1364'), ('defScreenH', '768')):
    if re.search(r'(?m)^\s*"%s"\s*:' % clave, j):
        j = re.sub(r'(?m)^(\s*)"%s"\s*:\s*[^,\n]*' % clave, lambda m: m[1] + '"%s": %s' % (clave, valor), j, count=1)
    else:
        j = re.sub(r'(?m)^\{\s*$', lambda m: '{\n    "%s": %s,' % (clave, valor), j, count=1)
open(mk, 'w', encoding='utf-8').write(j)
gi = os.path.join(SKY, 'Game.ini'); g = open(gi, encoding='utf-8', errors='replace').read()
open(gi, 'w', encoding='utf-8').write(re.sub(r'(?m)^Title=.*$', 'Title=Pokemon Ostinato', g))
for f in ('CREDITOS.md', 'Créditos.txt'):
    if os.path.exists(os.path.join(BES, f)): shutil.copy2(os.path.join(BES, f), os.path.join(SKY, f))
informe.append('mkxp.json (pantalla completa, escalado suave), Game.ini y créditos')

print('\n'.join(informe))
