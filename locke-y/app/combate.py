"""El motor del combate en línea (2.3.0): un combate individual 6 contra 6 con los Pokémon de las partidas.

Lo lleva el servidor del anfitrión (online.Servidor.combate) para que los dos vean lo mismo: cada jugador manda su acción
(ataque o cambio) y, con las dos, se resuelve el turno. Lo que pasa sale como una lista de sucesos ('log') que cada
Pokelocke va reproduciendo (mensajes, daño, cambios, debilitados...).

Fórmulas de la 6.ª generación: daño con nivel, potencia, ataque/defensa reales de la partida y sus cambios (−6 a +6),
STAB ×1,5, eficacia de tipos, crítico ×1,5 (1/16, o más con los ataques de crítico alto), aleatorio 85-100 % y la
quemadura que divide entre dos el físico. Orden por prioridad y velocidad (parálisis ×0,25). Estados: parálisis,
quemadura, veneno, veneno grave, sueño (1-3 turnos), congelación (20 % de descongelarse), confusión y retroceso.
Ataques con efectos: cambios de características, estados, absorber, retroceso, curarse, golpes múltiples, daño fijo,
fulminantes, Protección y autodestrucción. Sin habilidades ni objetos (se dicen en la sala, pero no hacen nada aún).
Normas: Sleep Clause (no se duerme a un segundo Pokémon del rival). Sin PP: Forcejeo.
"""
import json
import math
import random
import sys
from pathlib import Path

_CARPETA = Path(sys._MEIPASS) / 'app' if getattr(sys, 'frozen', False) else Path(__file__).resolve().parent
DATOS = json.loads((_CARPETA / 'datos_combate.json').read_text(encoding='utf-8'))
ATAQUES = {int(k): v for k, v in DATOS['ataques'].items()}
ESPECIES = {int(k): v for k, v in DATOS['especies'].items()}
EFICACIA = DATOS['eficacia']
FORCEJEO = ['Forcejeo', None, 'F', 50, 0, 1, 0, {'rc_max': 0.25}]
NOMBRE_STAT = {'atk': 'Ataque', 'def': 'Defensa', 'spa': 'Ataque Especial', 'spd': 'Defensa Especial', 'spe': 'Velocidad',
               'acc': 'Precisión', 'eva': 'Evasión'}
ESTADOS = {'par': 'paralizado', 'brn': 'quemado', 'psn': 'envenenado', 'tox': 'gravemente envenenado', 'slp': 'dormido',
           'frz': 'congelado'}
INMUNE_ESTADO = {'brn': {'FIRE'}, 'par': {'ELECTRIC'}, 'psn': {'POISON', 'STEEL'}, 'tox': {'POISON', 'STEEL'}, 'frz': {'ICE'}}


def eficacia(tipo, tipos):
    if not tipo:
        return 1
    e = 1
    for t in tipos:
        e *= EFICACIA.get(t, {}).get(tipo, 1)
    return e


def etapa(s, precision=False):
    base = 3 if precision else 2
    return (base + max(0, s)) / (base + max(0, -s))


ESTADO_CORTO = {'par': 'paralizar', 'brn': 'quemar', 'psn': 'envenenar', 'tox': 'envenenar gravemente', 'slp': 'dormir',
                'frz': 'congelar'}


def _cambios(b, quien):
    partes = []
    for st, n in b.items():
        partes.append(f'{"sube" if n > 0 else "baja"}{" mucho" if abs(n) >= 2 else ""} {"el " if st in ("atk", "spa") else "la "}'
                      f'{NOMBRE_STAT[st]} {quien}')
    return ' y '.join(partes)


def describir(mid):
    """Una frase corta de lo que hace el ataque (para la banda de información del combate)."""
    _, _, cat, potencia, _, _, prioridad, ef = ATAQUES[mid]
    frases = []
    if ef.get('ohko'):
        frases.append('Debilita al objetivo de un golpe si acierta.')
    if ef.get('fijo'):
        frases.append('Quita tantos PS como el nivel del usuario.' if ef['fijo'] == 'level' else f'Quita siempre {ef["fijo"]} PS.')
    if ef.get('multi'):
        lo, hi = ef['multi']
        frases.append(f'Golpea {lo} veces.' if lo == hi else f'Golpea de {lo} a {hi} veces seguidas.')
    if ef.get('protege'):
        frases.append('Se protege de los ataques de ese turno. Falla más si se repite.')
    if ef.get('cura'):
        frases.append(f'Recupera {round(ef["cura"] * 100)} % de sus PS máximos.')
    if ef.get('dr'):
        frases.append(f'Recupera {round(ef["dr"] * 100)} % del daño causado.')
    if ef.get('rc'):
        frases.append(f'El usuario también recibe {round(ef["rc"] * 100)} % del daño.')
    if ef.get('explota'):
        frases.append('El usuario se debilita.')
    if ef.get('st'):
        frases.append(f'Intenta {ESTADO_CORTO.get(ef["st"], "afectar")} al objetivo.')
    if ef.get('conf'):
        frases.append('Confunde al objetivo.')
    if ef.get('b'):
        frases.append(_cambios(ef['b'], 'del objetivo')[0].upper() + _cambios(ef['b'], 'del objetivo')[1:] + '.')
    if ef.get('yo'):
        frases.append(_cambios(ef['yo'], 'del usuario')[0].upper() + _cambios(ef['yo'], 'del usuario')[1:] + '.')
    sec = ef.get('sec')
    if sec:
        que = []
        if sec.get('st'):
            que.append(ESTADO_CORTO.get(sec['st'], 'afectar') + ' al objetivo')
        if sec.get('b'):
            que.append(_cambios(sec['b'], 'del objetivo').replace('sube', 'subir').replace('baja', 'bajar'))
        if sec.get('yo'):
            que.append(_cambios(sec['yo'], 'del usuario').replace('sube', 'subir').replace('baja', 'bajar'))
        if sec.get('acobardar'):
            que.append('hacer retroceder al objetivo')
        if sec.get('conf'):
            que.append('confundir al objetivo')
        if que:
            frases.append(f'Puede {" y ".join(que)} ({sec["p"]} %).')
    if ef.get('crit'):
        frases.append('Más probabilidad de golpe crítico.')
    if prioridad > 0 and not ef.get('protege'):
        frases.append('Suele atacar primero.')
    elif prioridad < 0:
        frases.append('Ataca de los últimos.')
    if not frases:
        frases.append('Un ataque sin más efectos.' if cat != 'S' else 'Un movimiento de estado.')
    return ' '.join(frases)


class Combate:
    def __init__(self, jugadores, equipos, normas=None, azar=None):
        """jugadores: [nombre A, nombre B]; equipos: dos listas de Pokémon del perfil (ya en su orden de salida)."""
        self.azar = azar or random.Random()
        self.normas = normas or {}
        self.lados = [{'nombre': jugadores[k], 'equipo': [self._pokemon(p) for p in equipos[k]], 'activo': 0} for k in (0, 1)]
        self.log, self.turno, self.fin = [], 0, None
        self.acciones, self.cambio = [None, None], [False, False]
        self.ev('msg', txt='¡Empieza el combate!')
        for k in (0, 1):
            self._salir(k, 0, primero=True)

    # --- datos ---
    @staticmethod
    def _pokemon(p):
        st = p.get('stats') or [1, 1, 1, 1, 1, 1]          # PS, Ataque, Defensa, Velocidad, At. Esp., Def. Esp. (PK6)
        tipos = ESPECIES.get(p['especie'], ['NORMAL'])
        ataques = [{'id': a, 'pp': ATAQUES[a][5], 'max': ATAQUES[a][5]} for a in (p.get('ataques') or []) if a in ATAQUES][:4]
        return {'especie': p['especie'], 'nombre': p.get('mote') or p.get('nombre') or '?', 'nivel': p.get('nivel', 50),
                'tipos': tipos, 'shiny': bool(p.get('shiny')), 'sexo': p.get('genero', 2),
                'st': {'hp': st[0], 'atk': st[1], 'def': st[2], 'spe': st[3], 'spa': st[4], 'spd': st[5]},
                'ps': st[0], 'ataques': ataques, 'estado': None, 'sueno': 0, 'tox': 0,
                'b': dict.fromkeys(NOMBRE_STAT, 0), 'conf': 0, 'acobardado': False, 'protegido': False, 'proteccion_seguida': 0}

    def ev(self, que, **d):
        self.log.append({'t': que, **d})

    def activo(self, k):
        return self.lados[k]['equipo'][self.lados[k]['activo']]

    def _resumen(self, k, i=None):
        lado = self.lados[k]
        p = lado['equipo'][lado['activo'] if i is None else i]
        return {'especie': p['especie'], 'nombre': p['nombre'], 'nivel': p['nivel'], 'ps': p['ps'], 'max': p['st']['hp'],
                'estado': p['estado'], 'shiny': p['shiny'], 'sexo': p['sexo'], 'tipos': p['tipos']}

    def _vivos(self, k):
        return [i for i, p in enumerate(self.lados[k]['equipo']) if p['ps'] > 0]

    def _salir(self, k, i, primero=False):
        lado = self.lados[k]
        viejo = lado['equipo'][lado['activo']]
        viejo['b'], viejo['conf'] = dict.fromkeys(NOMBRE_STAT, 0), 0
        if viejo['estado'] == 'tox':
            viejo['tox'] = 1
        lado['activo'] = i
        p = lado['equipo'][i]
        self.ev('cambio', lado=k, i=i, pk=self._resumen(k), txt=f'¡{lado["nombre"]} saca a {p["nombre"]}!')

    # --- lo que manda cada jugador ---
    def accion(self, k, a):
        """a = {'tipo': 'ataque', 'i': 0-3} | {'tipo': 'cambio', 'i': hueco} | {'tipo': 'rendirse'}."""
        if self.fin is not None:
            raise ValueError('El combate ya ha terminado')
        tipo = a.get('tipo')
        if tipo == 'rendirse':
            self.ev('msg', txt=f'{self.lados[k]["nombre"]} se rinde.')
            return self._acabar(1 - k)
        if self.cambio[k] or any(self.cambio):
            if not self.cambio[k]:
                raise ValueError('Espera a que tu rival saque otro Pokémon')
            if tipo != 'cambio':
                raise ValueError('Tienes que sacar otro Pokémon')
        if tipo == 'cambio':
            i = int(a.get('i', -1))
            equipo = self.lados[k]['equipo']
            if not 0 <= i < len(equipo) or equipo[i]['ps'] <= 0 or i == self.lados[k]['activo']:
                raise ValueError('No puedes sacar a ese Pokémon')
            if self.cambio[k]:
                self.cambio[k] = False
                self._salir(k, i)
                return
            self.acciones[k] = {'tipo': 'cambio', 'i': i}
        elif tipo == 'ataque':
            p = self.activo(k)
            i = int(a.get('i', 0))
            if not any(x['pp'] > 0 for x in p['ataques']):
                self.acciones[k] = {'tipo': 'ataque', 'i': -1}            # Forcejeo
            elif 0 <= i < len(p['ataques']) and p['ataques'][i]['pp'] > 0:
                self.acciones[k] = {'tipo': 'ataque', 'i': i}
            else:
                raise ValueError('A ese ataque no le quedan PP')
        else:
            raise ValueError('Acción no válida')
        if all(self.acciones):
            self._turno()

    def espera(self, k):
        """Lo que tiene que hacer ese jugador ahora: 'cambio', 'accion' o None (esperar al otro / fin)."""
        if self.fin is not None:
            return None
        if self.cambio[k]:
            return 'cambio'
        if any(self.cambio):
            return None
        return None if self.acciones[k] else 'accion'

    # --- el turno ---
    def _velocidad(self, k):
        p = self.activo(k)
        v = p['st']['spe'] * etapa(p['b']['spe'])
        return v * 0.25 if p['estado'] == 'par' else v

    def _turno(self):
        self.turno += 1
        self.ev('turno', n=self.turno)
        acc, self.acciones = self.acciones, [None, None]
        for k in (0, 1):
            self.activo(k)['acobardado'] = False
            self.activo(k)['protegido'] = False
        # los cambios, antes que nada
        for k in sorted((0, 1), key=lambda k: -self._velocidad(k)):
            if acc[k]['tipo'] == 'cambio':
                self.ev('msg', txt=f'¡{self.activo(k)["nombre"]}, vuelve!')
                self._salir(k, acc[k]['i'])
        ataques = [k for k in (0, 1) if acc[k]['tipo'] == 'ataque']

        def prioridad(k):
            i = acc[k]['i']
            mov = FORCEJEO if i < 0 else ATAQUES[self.activo(k)['ataques'][i]['id']]
            return (-mov[6], -self._velocidad(k), self.azar.random())
        for k in sorted(ataques, key=prioridad):
            if self.fin is not None:
                return
            if self.activo(k)['ps'] > 0 and not self.cambio[k]:
                self._usar(k, acc[k]['i'])
            self._mirar_debilitados()
        if self.fin is None:
            self._final_de_turno()
            self._mirar_debilitados()

    def _puede_moverse(self, k):
        p = self.activo(k)
        if p['estado'] == 'slp':
            p['sueno'] -= 1
            if p['sueno'] <= 0:
                p['estado'] = None
                self.ev('estado', lado=k, estado=None, txt=f'¡{p["nombre"]} se ha despertado!')
            else:
                self.ev('msg', txt=f'{p["nombre"]} está dormido como un tronco.')
                return False
        if p['estado'] == 'frz':
            if self.azar.random() < 0.2:
                p['estado'] = None
                self.ev('estado', lado=k, estado=None, txt=f'¡{p["nombre"]} se ha descongelado!')
            else:
                self.ev('msg', txt=f'{p["nombre"]} está congelado.')
                return False
        if p['acobardado']:
            self.ev('msg', txt=f'¡{p["nombre"]} se ha amedrentado y no puede moverse!')
            return False
        if p['conf'] > 0:
            p['conf'] -= 1
            if p['conf'] == 0:
                self.ev('msg', txt=f'¡{p["nombre"]} ya no está confuso!')
            else:
                self.ev('msg', txt=f'{p["nombre"]} está confuso.')
                if self.azar.random() < 1 / 3:
                    d = self._dano_base(p, p, 40, 'atk', 'def', False)
                    self._quitar(k, d, txt='¡Está tan confuso que se ha herido a sí mismo!')
                    return False
        if p['estado'] == 'par' and self.azar.random() < 0.25:
            self.ev('msg', txt=f'¡{p["nombre"]} está paralizado! No se puede mover.')
            return False
        return True

    def _usar(self, k, i):
        yo, el = self.activo(k), self.activo(1 - k)
        if not self._puede_moverse(k):
            yo['proteccion_seguida'] = 0
            return
        if i < 0:
            mov, mid = FORCEJEO, 165
            self.ev('msg', txt=f'¡A {yo["nombre"]} no le quedan movimientos!')
        else:
            a = yo['ataques'][i]
            a['pp'] -= 1
            mid, mov = a['id'], ATAQUES[a['id']]
        nombre, tipo, cat, potencia, precision, _, _, ef = mov
        self.ev('ataque', lado=k, id=mid, tipo=tipo, cat=cat, txt=f'¡{yo["nombre"]} usa {nombre}!')
        if ef.get('protege'):
            if self.azar.random() < 1 / (3 ** yo['proteccion_seguida']):
                yo['protegido'], yo['proteccion_seguida'] = True, yo['proteccion_seguida'] + 1
                self.ev('msg', txt=f'¡{yo["nombre"]} se está protegiendo!')
            else:
                yo['proteccion_seguida'] = 0
                self.ev('msg', txt='¡Pero ha fallado!')
            return
        yo['proteccion_seguida'] = 0
        sobre_mi = cat == 'S' and not ef.get('b') and not ef.get('st') and not ef.get('conf')
        if not sobre_mi:
            if el['protegido']:
                self.ev('msg', txt=f'¡{el["nombre"]} se ha protegido!')
                return
            if not self._acierta(yo, el, precision, ef):
                self.ev('msg', txt=f'¡{el["nombre"]} ha esquivado el ataque!' if precision else '¡Pero ha fallado!')
                return
        if cat != 'S':
            self._golpear(k, yo, el, mov)
        else:
            self._estado_del_ataque(k, yo, el, ef)
        if ef.get('explota') and yo['ps'] > 0:
            self._quitar(k, yo['ps'], txt=None)

    def _acierta(self, yo, el, precision, ef):
        if ef.get('ohko'):
            return yo['nivel'] >= el['nivel'] and self.azar.random() * 100 < 30 + yo['nivel'] - el['nivel']
        if not precision:
            return True
        return self.azar.random() * 100 < precision * etapa(yo['b']['acc'] - el['b']['eva'], precision=True)

    def _dano_base(self, yo, el, potencia, a, d, critico):
        ba, bd = yo['b'][a], el['b'][d]
        if critico:
            ba, bd = max(ba, 0), min(bd, 0)
        ataque = yo['st'][a] * etapa(ba)
        defensa = max(1, el['st'][d] * etapa(bd))
        return math.floor(math.floor(math.floor(2 * yo['nivel'] / 5 + 2) * potencia * ataque / defensa) / 50) + 2

    def _golpear(self, k, yo, el, mov):
        nombre, tipo, cat, potencia, _, _, _, ef = mov
        e = eficacia(tipo, el['tipos'])
        if e == 0:
            self.ev('msg', txt=f'No afecta a {el["nombre"]}…')
            return
        if ef.get('ohko'):
            self._quitar(1 - k, el['ps'], txt='¡Es un ataque fulminante!')
            return
        golpes = 1
        if ef.get('multi'):
            lo, hi = ef['multi']
            golpes = lo if lo == hi else self.azar.choice([2, 2, 2, 3, 3, 3, 4, 5]) if (lo, hi) == (2, 5) else self.azar.randint(lo, hi)
        total, dado = 0, 0
        for g in range(golpes):
            if el['ps'] <= 0:
                break
            if ef.get('fijo'):
                d, critico = (yo['nivel'] if ef['fijo'] == 'level' else int(ef['fijo'])), False
            else:
                critico = self.azar.random() < {1: 1 / 16, 2: 1 / 8, 3: 1 / 2}.get(ef.get('crit', 1), 1)
                a, dfn = ('atk', 'def') if cat == 'F' else ('spa', 'spd')
                d = self._dano_base(yo, el, potencia, a, dfn, critico)
                if critico:
                    d = math.floor(d * 1.5)
                d = math.floor(d * self.azar.randint(85, 100) / 100)
                if tipo and tipo in yo['tipos']:
                    d = math.floor(d * 1.5)
                d = math.floor(d * e)
                if cat == 'F' and yo['estado'] == 'brn':
                    d = math.floor(d / 2)
                d = max(1, d)
            dado = min(d, el['ps'])
            total += dado
            self._quitar(1 - k, d, efic=e if not ef.get('fijo') else 1, critico=critico)
        if golpes > 1:
            self.ev('msg', txt=f'¡Ha golpeado {golpes} veces!')
        if ef.get('dr') and yo['ps'] > 0 and total:
            self._curar(k, max(1, math.floor(total * ef['dr'])), txt=f'¡{el["nombre"]} ha perdido energía!')
        if ef.get('rc') and total:
            self._quitar(k, max(1, math.floor(total * ef['rc'])), txt=f'¡{yo["nombre"]} también se ha hecho daño!')
        if ef.get('rc_max'):
            self._quitar(k, max(1, math.floor(yo['st']['hp'] * ef['rc_max'])), txt=f'¡{yo["nombre"]} también se ha hecho daño!')
        if ef.get('yo') and yo['ps'] > 0:
            self._subir(k, ef['yo'])
        s = ef.get('sec')
        if s and self.azar.random() * 100 < s['p']:
            if s.get('st') and el['ps'] > 0:
                self._poner_estado(1 - k, s['st'], callado=True)
            if s.get('b') and el['ps'] > 0:
                self._subir(1 - k, s['b'])
            if s.get('yo') and yo['ps'] > 0:
                self._subir(k, s['yo'])
            if s.get('acobardar') and el['ps'] > 0:
                el['acobardado'] = True
            if s.get('conf') and el['ps'] > 0 and not el['conf']:
                el['conf'] = self.azar.randint(2, 5)
                self.ev('msg', txt=f'¡{el["nombre"]} se ha quedado confuso!')

    def _estado_del_ataque(self, k, yo, el, ef):
        hizo = False
        if ef.get('cura'):
            if yo['ps'] >= yo['st']['hp']:
                self.ev('msg', txt=f'¡{yo["nombre"]} tiene los PS al máximo!')
            else:
                self._curar(k, math.floor(yo['st']['hp'] * ef['cura']), txt=f'¡{yo["nombre"]} ha recuperado salud!')
            hizo = True
        if ef.get('yo'):
            hizo = self._subir(k, ef['yo']) or hizo
        if ef.get('b'):
            hizo = self._subir(1 - k, ef['b']) or hizo
        if ef.get('st'):
            hizo = self._poner_estado(1 - k, ef['st']) or hizo
        if ef.get('conf'):
            if el['conf']:
                self.ev('msg', txt=f'¡{el["nombre"]} ya está confuso!')
            else:
                el['conf'] = self.azar.randint(2, 5)
                self.ev('msg', txt=f'¡{el["nombre"]} se ha quedado confuso!')
            hizo = True
        if not hizo:
            self.ev('msg', txt='¡Pero no ha tenido ningún efecto!')

    def _poner_estado(self, k, st, callado=False):
        p = self.activo(k)
        falla = p['estado'] or p['ps'] <= 0 or INMUNE_ESTADO.get(st, set()) & set(p['tipos'])
        if st == 'slp' and self.normas.get('sleep', True) and any(x['estado'] == 'slp' for x in self.lados[k]['equipo'] if x is not p and x['ps'] > 0):
            if not callado:
                self.ev('msg', txt='¡No funciona! (Sleep Clause: ya hay un Pokémon dormido en su equipo)')
            return True
        if falla:
            if not callado:
                self.ev('msg', txt=f'¡Pero no ha afectado a {p["nombre"]}!' if not p['estado'] else f'¡{p["nombre"]} ya está {ESTADOS[p["estado"]]}!')
            return not callado
        p['estado'] = st
        if st == 'slp':
            p['sueno'] = self.azar.randint(1, 3)
        if st == 'tox':
            p['tox'] = 1
        self.ev('estado', lado=k, estado=st, txt=f'¡{p["nombre"]} está {ESTADOS[st]}!')
        return True

    def _subir(self, k, cambios):
        p = self.activo(k)
        algo = False
        for s, n in cambios.items():
            antes = p['b'][s]
            p['b'][s] = max(-6, min(6, antes + n))
            dif = p['b'][s] - antes
            if dif == 0:
                self.ev('msg', txt=f'¡{NOMBRE_STAT[s]} de {p["nombre"]} no puede {"subir" if n > 0 else "bajar"} más!')
            else:
                algo = True
                cuanto = {1: 'ha subido', 2: 'ha subido mucho', -1: 'ha bajado', -2: 'ha bajado mucho'}.get(max(-2, min(2, dif)), 'ha cambiado')
                if abs(dif) >= 3:
                    cuanto = 'ha subido muchísimo' if dif > 0 else 'ha bajado muchísimo'
                self.ev('stat', lado=k, stat=s, n=dif, txt=f'¡{NOMBRE_STAT[s]} de {p["nombre"]} {cuanto}!')
        return algo

    def _quitar(self, k, d, txt=None, efic=1, critico=False):
        p = self.activo(k)
        p['ps'] = max(0, p['ps'] - int(d))
        self.ev('dano', lado=k, ps=p['ps'], max=p['st']['hp'], efic=efic, critico=critico, txt=txt)

    def _curar(self, k, d, txt=None):
        p = self.activo(k)
        p['ps'] = min(p['st']['hp'], p['ps'] + int(d))
        self.ev('cura', lado=k, ps=p['ps'], max=p['st']['hp'], txt=txt)

    def _final_de_turno(self):
        for k in (0, 1):
            p = self.activo(k)
            if p['ps'] <= 0:
                continue
            if p['estado'] == 'brn':
                self._quitar(k, max(1, p['st']['hp'] // 16), txt=f'¡{p["nombre"]} se resiente de la quemadura!')
            elif p['estado'] == 'psn':
                self._quitar(k, max(1, p['st']['hp'] // 8), txt=f'¡El veneno resta PS a {p["nombre"]}!')
            elif p['estado'] == 'tox':
                self._quitar(k, max(1, p['st']['hp'] * p['tox'] // 16), txt=f'¡El veneno resta PS a {p["nombre"]}!')
                p['tox'] = min(15, p['tox'] + 1)

    def _mirar_debilitados(self):
        hubo = False
        for k in (0, 1):
            p = self.activo(k)
            if p['ps'] <= 0 and not p.get('caido'):
                p['caido'], hubo = True, True
                self.acciones[k] = None
                self.ev('debil', lado=k, txt=f'¡{p["nombre"]} se ha debilitado!')
        vivos = [bool(self._vivos(k)) for k in (0, 1)]
        if not all(vivos):
            return self._acabar(0 if vivos[0] else 1 if vivos[1] else None) or True
        for k in (0, 1):
            if self.activo(k)['ps'] <= 0:
                self.cambio[k] = True
        return hubo

    def _acabar(self, ganador):
        self.fin = ganador if ganador is not None else 'empate'
        self.acciones, self.cambio = [None, None], [False, False]
        txt = 'Empate.' if ganador is None else f'¡{self.lados[ganador]["nombre"]} gana el combate!'
        self.ev('fin', ganador=ganador, txt=txt)
        return True

    # --- lo que ve cada uno ---
    def vista(self, k, desde=0):
        lado = self.lados[k]
        return {
            'lado': k, 'turno': self.turno, 'fin': self.fin, 'espera': self.espera(k), 'eligio': bool(self.acciones[k]),
            'n': len(self.log), 'log': self.log[max(0, int(desde or 0)):],
            'equipo': [{**self._resumen(k, i), 'ataques': [{'id': a['id'], 'pp': a['pp'], 'max': a['max'], 'nombre': ATAQUES[a['id']][0],
                                                            'tipo': ATAQUES[a['id']][1], 'cat': ATAQUES[a['id']][2],
                                                            'potencia': ATAQUES[a['id']][3], 'precision': ATAQUES[a['id']][4],
                                                            'desc': describir(a['id']),
                                                            'efic': None if ATAQUES[a['id']][2] == 'S' else eficacia(ATAQUES[a['id']][1], self.activo(1 - k)['tipos'])}
                                                           for a in p['ataques']]}
                       for i, p in enumerate(lado['equipo'])],
            'activo': lado['activo'], 'rival_activo': self.lados[1 - k]['activo'],
            'rival_bolas': [('debil' if p['ps'] <= 0 else 'estado' if p['estado'] else 'bola') for p in self.lados[1 - k]['equipo']],
        }
