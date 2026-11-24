"""El combate en línea con el motor de Pokémon Ostinato (2.4.0).

El servidor del anfitrión arranca UNA vez un Ruby con el motor de combate del juego (Essentials v21 y los plugins de
Ostinato, sin gráficos: tools/ostinato/motor/motor.rb) y le habla por líneas JSON. Cada combate de una sala es un
CombateOstinato, con la misma forma que el motor de antes (combate.Combate): accion, espera, vista, empezar, tiempo y fin.
Los relojes (80 s por turno, 50 min el combate) se llevan aquí; el motor no sabe de tiempo.

Lo que manda cada Pokelocke de su partida (números de Pokémon X/Y) se traduce a los nombres internos del motor con
app/ids_ostinato.json (hacer_ids_ostinato.py).
"""
import json
import secrets
import subprocess
import sys
import threading
import time
from pathlib import Path

import comun

TURNO = 80
PARTIDO = 50 * 60
IDS = json.loads(((Path(sys._MEIPASS) / 'app' if getattr(sys, 'frozen', False) else Path(__file__).resolve().parent)
                  / 'ids_ostinato.json').read_text(encoding='utf-8'))
# el juego de David en el PC donde se construye (en desarrollo); en el instalado, la copia de tools/ostinato
JUEGO_DESARROLLO = Path(__file__).resolve().parent.parent.parent / 'Pokémon Ostinato'


CARPETA_APP = Path(sys._MEIPASS) / 'app' if getattr(sys, 'frozen', False) else Path(__file__).resolve().parent


def rutas():
    """(ruby.exe, motor.rb, carpeta con Data del juego). El Ruby portátil va en tools/ruby; los datos del juego (Data/*.dat,
    Scripts.rxdata y PluginScripts.rxdata), en tools/ostinato (los copia empaquetar.py); en desarrollo, el juego mismo."""
    ruby = comun.TOOLS / 'ruby' / 'bin' / 'ruby.exe'
    motor = CARPETA_APP / 'ostinato' / 'motor.rb'
    copia = comun.TOOLS / 'ostinato'
    juego = copia if (copia / 'Data' / 'Scripts.rxdata').exists() else JUEGO_DESARROLLO
    return ruby, motor, juego


class Motor:
    """El Ruby con el motor: uno para todo el servidor, una orden cada vez."""
    def __init__(self):
        self.lock = threading.Lock()
        self.proc = None

    def _arrancar(self):
        ruby, motor, juego = rutas()
        if not ruby.exists() or not motor.exists():
            raise ValueError('Falta el motor de combate de Ostinato en este Pokelocke (tools/ruby y tools/ostinato)')
        self.proc = subprocess.Popen([str(ruby), str(motor), str(juego)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=open(comun.DATOS / 'motor_ostinato.log', 'a', encoding='utf-8'),
                                     encoding='utf-8', bufsize=1, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        hola = json.loads(self.proc.stdout.readline() or '{}')
        if not hola.get('listo'):
            raise ValueError('El motor de combate de Ostinato no ha arrancado')

    def pedir(self, orden):
        with self.lock:
            for intento in range(2):
                if not self.proc or self.proc.poll() is not None:
                    self._arrancar()
                try:
                    self.proc.stdin.write(json.dumps(orden, ensure_ascii=False) + '\n')
                    self.proc.stdin.flush()
                    linea = self.proc.stdout.readline()
                    if linea:
                        return json.loads(linea)
                except (OSError, ValueError):
                    pass
                self.proc = None                      # se ha caído: otra vez (los combates en marcha se pierden)
            raise ValueError('El motor de combate de Ostinato no responde')


MOTOR = Motor()


def pokemon(d):
    """Un Pokémon del perfil (números de X/Y) en los nombres del motor."""
    num = lambda tabla, n: IDS[tabla].get(str(n)) if n else None
    nat = d.get('naturaleza')
    return {'especie': num('especies', d['especie']), 'nivel': d.get('nivel', 50), 'mote': d.get('mote') or '',
            'forma': d.get('forma', 0), 'genero': d.get('genero', 2), 'shiny': bool(d.get('shiny')),
            'naturaleza': IDS['naturalezas'][nat] if isinstance(nat, int) and 0 <= nat < 25 else None,
            'habilidad': num('habilidades', d.get('habilidad_n')), 'objeto': num('objetos', d.get('objeto')),
            'ivs': d.get('ivs'), 'evs': d.get('evs'), 'pp_up': d.get('pp_up'),
            'ataques': [IDS['ataques'].get(str(a)) for a in d.get('ataques') or [] if IDS['ataques'].get(str(a))]}


NUMERO = {v: int(k) for k, v in IDS['especies'].items()}         # del nombre interno al número de la Pokédex
ESTADO = {'sleep': 'slp', 'poison': 'psn', 'burn': 'brn', 'paralysis': 'par', 'frozen': 'frz'}


def _arreglar(pk):
    """El número de la especie (para el dibujo y la animación) y el estado con los códigos de la app."""
    if isinstance(pk, dict) and 'especie' in pk:
        pk['numero'] = NUMERO.get(pk['especie'], 0)
        pk['estado'] = ESTADO.get(pk.get('estado'))
    return pk


class CombateOstinato:
    def __init__(self, jugadores, equipos, normas=None):
        self.id = secrets.token_hex(6)
        self.log, self.fin, self.esperas, self.vistas = [], None, [None, None], [{}, {}]
        self.inicio = self.plazo = None
        self.eligio = [False, False]
        r = MOTOR.pedir({'cmd': 'nuevo', 'id': self.id, 'jugadores': list(jugadores),
                         'equipos': [[pokemon(p) for p in e] for e in equipos], 'normas': normas or {}})
        if not r.get('ok'):
            raise ValueError(r.get('error') or 'No se ha podido empezar el combate')
        self._tomar(r)

    def _tomar(self, r):
        for e in r.get('log') or []:
            _arreglar(e.get('pk'))
            if e.get('t') == 'ficha':
                e['estado'] = ESTADO.get(e.get('estado'))
        for v in r.get('vistas') or []:
            for p in v.get('equipo') or []:
                _arreglar(p)
            _arreglar(v.get('rival'))
        self.log += r.get('log') or []
        self.esperas = r.get('espera') or [None, None]
        self.vistas = r.get('vistas') or self.vistas
        self.fin = r.get('fin')
        if self.fin == 'error':
            self.fin = 'empate'
        for k in (0, 1):
            if self.esperas[k]:
                self.eligio[k] = False

    @property
    def turno(self):
        return (self.vistas[0] or {}).get('turno', 0)

    def accion(self, k, a, ahora=None):
        antes = len(self.log)
        r = MOTOR.pedir({'cmd': 'accion', 'id': self.id, 'lado': k, 'accion': a})
        if not r.get('ok'):
            raise ValueError(r.get('error') or 'Acción no válida')
        self._tomar(r)
        error = (r.get('errores') or [None, None])[k]
        if error:
            raise ValueError(error)
        if not self.esperas[k]:
            self.eligio[k] = True
        if len(self.log) != antes and self.inicio is not None and self.fin is None:
            self.plazo = (ahora or time.time()) + TURNO + min(45, 1.4 * (len(self.log) - antes))

    def espera(self, k):
        return None if self.fin is not None else self.esperas[k]

    def empezar(self, ahora=None):
        if self.inicio is None:
            self.inicio = ahora or time.time()
            self.plazo = self.inicio + TURNO + 12

    def tiempo(self, ahora=None):
        """80 s por turno (si no, elige Pokelocke) y 50 min el combate (gana quien conserve más Pokémon, y si no más PS)."""
        if self.inicio is None or self.fin is not None:
            return
        ahora = ahora or time.time()
        if ahora > self.inicio + PARTIDO:
            cuenta = []
            for v in self.vistas:
                eq = v.get('equipo') or []
                cuenta.append((sum(1 for p in eq if p['ps'] > 0), sum(p['ps'] / max(1, p['max']) for p in eq)))
            ganador = None if cuenta[0] == cuenta[1] else 0 if cuenta[0] > cuenta[1] else 1
            self.log.append({'t': 'msg', 'txt': '¡Se ha acabado el tiempo del combate!'})
            self.log.append({'t': 'fin', 'ganador': ganador})
            self.fin = ganador if ganador is not None else 'empate'
            self.cerrar()
            return
        if self.plazo and ahora > self.plazo:
            import random
            for k in (0, 1):
                e, v = self.espera(k), self.vistas[k]
                if not e:
                    continue
                self.log.append({'t': 'msg', 'txt': f'\x06{k}\x02'})          # «se acabó el tiempo de X: elige Pokelocke»
                try:
                    eq = v.get('equipo') or []
                    if e == 'cambio':
                        vivos = [i for i, p in enumerate(eq) if p['ps'] > 0 and i != v.get('activo')]
                        self.accion(k, {'tipo': 'cambio', 'i': random.choice(vivos)}, ahora)
                    else:
                        movs = [i for i, a in enumerate(eq[v['activo']]['ataques']) if a['pp'] > 0 and a.get('elegible', True)] or [0]
                        self.accion(k, {'tipo': 'ataque', 'i': random.choice(movs)}, ahora)
                except (ValueError, IndexError, KeyError):
                    pass

    def vista(self, k, desde=0):
        v = dict(self.vistas[k] or {})
        v.update({'lado': k, 'fin': self.fin, 'espera': self.espera(k), 'eligio': self.eligio[k], 'n': len(self.log),
                  'log': self.log[max(0, int(desde or 0)):], 'plazo': self.plazo,
                  'fin_partido': self.inicio + PARTIDO if self.inicio else None})
        return v

    def cerrar(self):
        try:
            MOTOR.pedir({'cmd': 'cerrar', 'id': self.id})
        except ValueError:
            pass
