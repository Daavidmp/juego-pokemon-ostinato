# Maqueta del combate doble contra los campistas, con las piezas y posiciones reales del combate HD (016)
from PIL import Image, ImageDraw, ImageFont
G = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/Pokémon Ostinato/Graphics/"
UI = G + "UI/Ostinato/Combate/"
PROPIO, RIVAL = (554, 842), (1374, 418)
OFF_X, OFF_Y = [-48, 48, 32, -32], [0, 0, 16, -16]
def spr(p, zoom):
    im = Image.open(p).convert("RGBA"); return im.resize((im.width * zoom // 2 * 2 // 2 if False else im.width * zoom, im.height * zoom), Image.NEAREST)
def pegar(can, im, x, y):            # anclado por abajo y en el centro
    can.alpha_composite(im, (int(x - im.width / 2), int(y - im.height)))
try:
    f = ImageFont.truetype("/mnt/c/Windows/Fonts/cambriab.ttf", 44); fp = ImageFont.truetype("/mnt/c/Windows/Fonts/cambriab.ttf", 34)
except Exception: f = fp = None
def escena(k, sep_x, sep_y, ficha_esc, titulo, rival=None, pies=None):
    RV = rival or RIVAL
    can = Image.open(G + "Battlebacks/tunel_bg.png").convert("RGBA")
    # rivales (indices 3 detras y 1 delante) y propios (2 detras, 0 delante); las posiciones de la base x k
    rivales = [("ROOKIDEE", 3), ("SEEDOT", 1)]; propios = [("ZUBAT", 2), ("MUDKIP", 0)]
    if pies:
        t = spr(G + "Trainers/HERMANOS_CAMPISTAS.png", 2); t = t.crop((0, 0, t.width, t.getbbox()[3]))
        pegar(can, t, RV[0] + 120, pies[1] - 30)
    for sp, i in rivales:
        im = spr(G + "Pokemon/Front/%s.png" % sp, 1)
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        if pies:   # apoyado por los pies de verdad (sin el margen vacio de abajo), sobre el suelo del tunel
            im = im.crop((0, 0, im.width, im.getbbox()[3]))
            pegar(can, im, RV[0] + OFF_X[i] * sep_x, pies[0 if i == 1 else 1])
        else:
            pegar(can, im, RV[0] + OFF_X[i] * sep_x, RV[1] + 40 + OFF_Y[i] * sep_y)
    for sp, i in propios:
        im = spr(G + "Pokemon/Back/%s.png" % sp, 1)
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        pegar(can, im, PROPIO[0] + OFF_X[i] * sep_x, PROPIO[1] + OFF_Y[i] * sep_y)
    # fichas: rival arriba a la izquierda, propia a la derecha, una por Pokemon
    fr = Image.open(UI + "ficha_rival.png").convert("RGBA"); fpr = Image.open(UI + "ficha_propia.png").convert("RGBA")
    fr = fr.resize((int(fr.width * ficha_esc), int(fr.height * ficha_esc)), Image.LANCZOS); fpr = fpr.resize((int(fpr.width * ficha_esc), int(fpr.height * ficha_esc)), Image.LANCZOS)
    paso_r = 150 if ficha_esc == 1 else fr.height + 6; paso_p = 150 if ficha_esc == 1 else fpr.height + 6
    d = ImageDraw.Draw(can)
    for j, (sp, nv) in enumerate([("Seedot", 11), ("Rookidee", 12)]):
        x, y = (79, 13 + j * paso_r) if ficha_esc == 1 else (24, 70 + j * paso_r); can.alpha_composite(fr, (x, y))
        d.text((x + int(60 * ficha_esc), y + int(70 * ficha_esc)), sp, font=ImageFont.truetype("/mnt/c/Windows/Fonts/cambriab.ttf", int(64 * ficha_esc)), fill=(30, 30, 30))
    for j, (sp, nv) in enumerate([("Mudkip", 12), ("Zubat", 11)]):
        x = 1112 if ficha_esc == 1 else 1920 - fpr.width - 24     # entera, sin que la corte la pantalla
        y = 474 - j * paso_p if ficha_esc == 1 else 1080 - 346 - 14 - fpr.height - j * paso_p
        can.alpha_composite(fpr, (x, y))
        d.text((x + int(112 * ficha_esc), y + int(40 * ficha_esc)), sp, font=ImageFont.truetype("/mnt/c/Windows/Fonts/cambriab.ttf", int(64 * ficha_esc)), fill=(30, 30, 30))
    can.alpha_composite(Image.open(UI + "barra.png").convert("RGBA"), (0, 1080 - 346))
    d.text((110, 1080 - 346 + 128), "¿Qué debería hacer Mudkip?", font=f, fill=(40, 34, 30))
    d.rectangle([0, 0, 1920, 56], fill=(0, 0, 0, 170)); d.text((20, 6), titulo, font=fp, fill=(255, 230, 150))
    return can
a = escena(3, 3, 3, 1.0, "AHORA: tal como esta el combate HD (Pokemon a x3, separacion de la base) -> se pisan")
b = escena(2, 5, 3, 0.62, "PROPUESTA para dobles: Pokemon a x2 pisando el suelo, mas separados, fichas mas pequenas", (1060, 418), (605, 550))
a.convert("RGB").save("/mnt/c/Users/david.martinez/Downloads/maqueta_doble_ahora_v2.png")
b.convert("RGB").save("/mnt/c/Users/david.martinez/Downloads/maqueta_doble_v3.png")
# la entrada: los dos campistas antes de sacar a sus Pokemon
c = Image.open(G + "Battlebacks/tunel_bg.png").convert("RGBA")
t = Image.open(G + "Trainers/HERMANOS_CAMPISTAS.png").convert("RGBA"); t = t.resize((t.width * 3, t.height * 3), Image.NEAREST)
pegar(c, t, RIVAL[0], RIVAL[1] + 40)
c.alpha_composite(Image.open(UI + "barra.png").convert("RGBA"), (0, 1080 - 346))
d = ImageDraw.Draw(c); d.text((110, 1080 - 346 + 128), "¡Campistas Lía y Nico te desafían!", font=f, fill=(40, 34, 30))
c.convert("RGB").save("/mnt/c/Users/david.martinez/Downloads/maqueta_doble_entrada_v2.png")
h = Image.new("RGB", (960 * 3 + 20, 540), (20, 20, 20))
for i, im in enumerate([c, a, b]): h.paste(im.convert("RGB").resize((960, 540)), (i * 970, 0))
h.save("maquetas_doble.png")

# --- el individual en el tunel, como el combate HD de siempre (Pokemon a x3, fichas a su tamano), con el rival
#     apoyado en el suelo (en el tunel habra que bajarlo, como en la ruta 4)
def individual():
    can = Image.open(G + "Battlebacks/tunel_bg.png").convert("RGBA")
    t = spr(G + "Trainers/MONTANERO_VETERANO.png", 3); t = t.crop((0, 0, t.width, t.getbbox()[3]))
    pegar(can, t, RIVAL[0] + 300, 455)
    im = spr(G + "Pokemon/Front/MACHOP.png", 3); im = im.crop((0, 0, im.width, im.getbbox()[3]))
    pegar(can, im, RIVAL[0] - 60, 470)
    im = spr(G + "Pokemon/Back/MUDKIP.png", 3)
    pegar(can, im, PROPIO[0], PROPIO[1])
    d = ImageDraw.Draw(can)
    fr = Image.open(UI + "ficha_rival.png").convert("RGBA"); can.alpha_composite(fr, (79, 13))
    d.text((79 + 60, 13 + 70), "Machop", font=ImageFont.truetype("/mnt/c/Windows/Fonts/cambriab.ttf", 64), fill=(30, 30, 30))
    fp_ = Image.open(UI + "ficha_propia.png").convert("RGBA"); can.alpha_composite(fp_, (1112, 474))
    d.text((1112 + 112, 474 + 40), "Mudkip", font=ImageFont.truetype("/mnt/c/Windows/Fonts/cambriab.ttf", 64), fill=(30, 30, 30))
    can.alpha_composite(Image.open(UI + "barra.png").convert("RGBA"), (0, 1080 - 346))
    d.text((110, 1080 - 346 + 128), "¡Montañero Cumbre saca a Machop!", font=f, fill=(40, 34, 30))
    return can
ind = individual()
ind.convert("RGB").save("/mnt/c/Users/david.martinez/Downloads/maqueta_individual_tunel_v3.png")
doble = b.convert("RGB")
dd = ImageDraw.Draw(doble); dd.rectangle([0, 0, 1920, 56], fill=(0, 0, 0)); dd.text((20, 6), "COMBATE DOBLE (campistas)", font=fp, fill=(255, 230, 150))
ii = ind.convert("RGB"); di = ImageDraw.Draw(ii); di.rectangle([0, 0, 1920, 56], fill=(0, 0, 0)); di.text((20, 6), "COMBATE INDIVIDUAL (Machop del montanero)", font=fp, fill=(255, 230, 150))
both = Image.new("RGB", (1920, 2180), (15, 15, 15)); both.paste(ii, (0, 0)); both.paste(doble, (0, 1100))
both.save("/mnt/c/Users/david.martinez/Downloads/maqueta_individual_y_doble_v3.png")
both.resize((960, 1090)).save("ambos_peq.png")
