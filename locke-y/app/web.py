"""El servidor de la ventana (127.0.0.1): estado, acciones, contrato y la ventana de la app."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler
from pathlib import Path

import errores
import comun
import conexion
import emulador
import guardado
import locke


def foto_estado():
    with comun.lock:
        activo = None
        if comun.vivo['activo'] and any(j['id'] == comun.vivo['activo'] for j in comun.biblio['juegos']):
            j = comun.buscar(comun.vivo['activo'])
            activo = {'id': j['id'], 'nombre': j['nombre'], 'vidas': locke.vidas(j),
                      'vidas_iniciales': j['vidas_iniciales'] + j['ajuste_vidas'], 'medallas': j['medallas'],
                      'vial': j.get('vial', True),
                      'vial_bloqueado': j.get('reglas') == 'mega' and bool(comun.vivo.get('en_combate')),
                      'topes': locke.niveles_tope(j)}
            muertos = j['muertos']
        else:
            muertos = []
        return {
            'juegos': [{'id': j['id'], 'nombre': j['nombre'], 'ruta': j['ruta'], 'preparado': j.get('preparado', False),
                        'random': j.get('random'), 'vidas': locke.vidas(j) if j.get('preparado') else None,
                        'reglas': j.get('reglas'), 'huevos': locke.huevos_disponibles(j) if j.get('huevos') else None,
                        'vidas_iniciales': j.get('vidas_iniciales'), 'medallas': sum(j.get('medallas', [])),
                        'registro': (comun.DATOS / 'juegos' / j['id'] / 'randomizacion.log').exists()}
                       for j in comun.biblio['juegos']],
            'activo': activo, 'jugando': emulador.jugando(), 'conectado': comun.vivo['conectado'], 'cargando': emulador.cargando(), 'tarea': comun.vivo['tarea'] and {**comun.vivo['tarea'], 'transcurrido': time.time() - comun.vivo['tarea']['inicio']},
            'equipo': [p and {**p, 'muerto': p['id'] in muertos} for p in comun.vivo['equipo']],
            'aviso': comun.vivo['aviso']['texto'] if comun.vivo['aviso'] and time.time() < comun.vivo['aviso']['hasta'] else None,
            'capa': comun.vivo['capa'], 'encaje': comun.encaje() if os.name == 'nt' else (1, 0, 0),
            'avanzado': (comun.DATOS / 'avanzado.rnqs').exists(),
            'online': conexion.online_estado(),
            'firma': comun.biblio.get('firma'),
            'ligero': bool(comun.biblio.get('ajustes', {}).get('ligero')),
        }


def arte(especie):
    """Fanart propio si existe (fanart/658.png|jpg|webp, o cualquier imagen dentro de la carpeta
    fanart/658 Greninja/); si no, el arte oficial, guardado en caché."""
    exts = ('png', 'jpg', 'jpeg', 'webp')
    for ext in exts:
        f = comun.FANART / f'{especie}.{ext}'
        if f.exists():
            return f
    if comun.FANART.exists():
        for carpeta in comun.FANART.iterdir():
            n = carpeta.name.split(' ', 1)[0]
            if carpeta.is_dir() and n.isdigit() and int(n) == especie:
                fotos = sorted(f for f in carpeta.iterdir() if f.suffix.lower().lstrip('.') in exts)
                if fotos:
                    return fotos[0]
    f = comun.CACHE_ARTE / f'{especie}.png'
    if not f.exists():
        comun.CACHE_ARTE.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(comun.ARTE_URL.format(especie), f)
    return f


MESES = ('enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
         'noviembre', 'diciembre')


def firmar():
    """La primera vez que se juega, el contrato queda firmado con el usuario (el de la sesión online o, sin
    conexión, el de Windows) y la fecha de ese momento. Después ya no cambia."""
    with comun.lock:
        if not comun.biblio.get('firma'):
            nombre = (comun.red['sesion'] or {}).get('usuario') or os.environ.get('USERNAME') or 'Entrenador'
            comun.biblio['firma'] = {'nombre': nombre, 'fecha': time.strftime('%Y-%m-%d')}
            comun.guardar()
        return comun.biblio['firma']


# normas.html está hecho para imprimir en A4 (los márgenes van en @page, que en pantalla no existe): en la app
# se ve como una hoja con márgenes, la portada más baja y, en el hueco estrecho de Opciones, sin justificar
CONTRATO_PANTALLA = '''<style>
@media screen {
  html { background: #ece6e2; }
  body { max-width: 210mm; margin: 0 auto; padding: 14mm 16mm 18mm; background: #fff; box-shadow: 0 2mm 8mm rgba(0,0,0,.12); }
  .portada { height: auto; padding: 16mm 8mm; margin: -14mm -16mm 12mm; gap: 6mm; }
  .portada img { width: min(110mm, 80%); }
  .portada h1 { font-size: 26pt; }
  .anexo { margin-top: 12mm; padding-top: 8mm; border-top: 1px dashed var(--linea); }
}
@media screen and (max-width: 640px) {
  body { padding: 7mm 6mm 10mm; font-size: 10.5pt; }
  .portada { margin: -7mm -6mm 8mm; }
  p, .clausula li { text-align: left; hyphens: manual; }
  .lugar { text-align: left; }
  .hueco { min-width: 24mm; } .hueco.largo { min-width: 40mm; }
  .firmas { gap: 6mm; } .sello { width: 22mm; height: 22mm; }
  .tabla td:first-child { white-space: normal; }
}
</style>'''


def contrato_html():
    """normas/normas.html con sus imágenes servidas por la app y, si ya se ha firmado, los huecos rellenos."""
    html = (comun.NORMAS / 'normas.html').read_text(encoding='utf-8')
    html = html.replace('src="../assets/', 'src="/assets/').replace('src="img/', 'src="/docs/img/')
    html = html.replace('</head>', CONTRATO_PANTALLA + '</head>', 1)
    html = re.sub(r'<link rel="preconnect" href="https://fonts\.googleapis\.com">\s*<link href="https://fonts\.googleapis\.com/[^"]+" rel="stylesheet">',
                  FUENTES_LOCALES, html, count=1)
    f = comun.biblio.get('firma')
    if not f:
        return html
    nombre = f['nombre'].replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    a, m, d = (int(x) for x in f['fecha'].split('-'))
    html = html.replace(
        '<span class="hueco corto"></span> de <span class="hueco"></span> de 20<span class="hueco corto"></span>',
        f'<b class="relleno">{d}</b> de <b class="relleno">{MESES[m - 1]}</b> de <b class="relleno">{a}</b>', 1)
    html = html.replace('el entrenador o entrenadora <span class="hueco largo"></span>',
                        f'el entrenador o entrenadora <b class="relleno">{nombre}</b>', 1)
    html = html.replace('<div class="firma"><div class="linea"></div><b>El Entrenador</b><small>Nombre y firma</small></div>',
                        f'<div class="firma"><div class="linea"><span class="rubrica">{nombre}</span></div>'
                        f'<b>El Entrenador</b><small>{nombre}</small></div>', 1)
    estilo = ('<style>.relleno { font: 600 15pt Caveat, cursive; color: #1d3a8a; padding: 0 1.5mm; }'
              '.firma .linea { display: flex; align-items: flex-end; justify-content: center; }'
              '.rubrica { font: 32pt "Great Vibes", cursive; color: #1d3a8a; line-height: 1; transform: rotate(-4deg); }</style>')
    return html.replace('</head>', estilo + '</head>', 1)


def elegir_rom():
    """Explorador de archivos de Windows para elegir la ROM."""
    resultado = []

    def dialogo():
        import tkinter as tk
        from tkinter import filedialog
        raiz = tk.Tk()
        raiz.withdraw()
        raiz.attributes('-topmost', True)
        resultado.append(filedialog.askopenfilename(
            parent=raiz, title='Añadir juego: elige la ROM descifrada de Pokémon Y',
            filetypes=[('Juegos de 3DS', '*.3ds *.cci *.cxi *.cia'), ('Todos los archivos', '*.*')]))
        raiz.destroy()
    hilo = threading.Thread(target=dialogo)
    hilo.start()
    hilo.join()
    return resultado[0] if resultado else ''


# ---------- servidor ----------

TIPOS = {'.html': 'text/html; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg',
         '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.js': 'text/javascript', '.css': 'text/css',
         '.pdf': 'application/pdf', '.mp4': 'video/mp4', '.woff2': 'font/woff2'}
# las tipografías van dentro de la app (web/fuentes): sin internet también, y sin esperar a Google
FUENTES_LOCALES = '<link rel="stylesheet" href="/fuentes/fuentes.css">'


class Servidor(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def enviar(self, cuerpo, tipo='application/json', codigo=200, cache='no-store'):
        if isinstance(cuerpo, (dict, list)):
            cuerpo = json.dumps(cuerpo, ensure_ascii=False).encode()
        self.send_response(codigo)
        self.send_header('Content-Type', tipo)
        self.send_header('Cache-Control', cache)
        self.end_headers()
        self.wfile.write(cuerpo)

    def archivo(self, f):
        if not f.is_file():
            return self.enviar({'error': 'no existe'}, codigo=404)
        self.enviar(f.read_bytes(), TIPOS.get(f.suffix.lower(), 'application/octet-stream'))

    def por_trozos(self, f):
        """Un archivo grande (el vídeo) con Range: así el reproductor puede adelantar y no se lee entero."""
        if not f.is_file():
            return self.enviar({'error': 'no existe'}, codigo=404)
        tam = f.stat().st_size
        m = re.fullmatch(r'bytes=(\d*)-(\d*)', self.headers.get('Range') or '')
        ini, fin = 0, tam - 1
        if m and (m[1] or m[2]):
            ini, fin = (int(m[1]), int(m[2] or tam - 1)) if m[1] else (tam - int(m[2]), tam - 1)
            fin = min(fin, tam - 1)
        self.send_response(206 if m else 200)
        self.send_header('Content-Type', TIPOS.get(f.suffix.lower(), 'application/octet-stream'))
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Content-Length', str(fin - ini + 1))
        if m:
            self.send_header('Content-Range', f'bytes {ini}-{fin}/{tam}')
        self.end_headers()
        with open(f, 'rb') as a:
            a.seek(ini)
            quedan = fin - ini + 1
            try:
                while quedan > 0:
                    trozo = a.read(min(quedan, 1 << 20))
                    if not trozo:
                        break
                    self.wfile.write(trozo)
                    quedan -= len(trozo)
            except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
                pass                                  # el reproductor corta la petición al adelantar

    def do_GET(self):
        # un error al contestar no puede dejar la petición sin respuesta: la ventana lo tomaba por Pokelocke cerrado
        try:
            self.responder_get()
        except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
            pass
        except Exception as e:
            try:
                self.enviar({'error': errores.describir(e, f'Petición {self.path.split("?")[0]}')}, codigo=500)
            except OSError:
                pass

    def responder_get(self):
        if not self.local():
            return self.enviar({'error': 'Petición no permitida'}, codigo=403)
        ruta = self.path.split('?')[0]
        if ruta == '/':
            return self.archivo(comun.WEB / 'app.html')
        if ruta == '/overlay':
            if 'capa=' not in self.path:
                return self.archivo(comun.WEB / 'overlay.html')
            # la capa: el estado va ya dentro, porque Firefox sin ventana hace la foto en cuanto carga
            estado = json.dumps(foto_estado(), ensure_ascii=False).replace('</', '<\\/')
            html = (comun.WEB / 'overlay.html').read_text(encoding='utf-8')
            return self.enviar(html.replace('</head>', f'<script>window.ESTADO = {estado};</script></head>', 1).encode(),
                               'text/html; charset=utf-8')
        if ruta == '/capa.png':
            return self.archivo(comun.CAPA_PNG)
        if ruta == '/api/estado':
            return self.enviar(foto_estado())
        if m := re.fullmatch(r'/arte/(\d{1,3})', ruta):
            try:
                return self.archivo(arte(int(m[1])))
            except OSError:
                return self.enviar({'error': 'sin arte'}, codigo=404)
        if m := re.fullmatch(r'/assets/([\w.-]+)', ruta):
            return self.archivo(comun.ASSETS / m[1])
        if m := re.fullmatch(r'/fuentes/([\w.-]+)', ruta):
            f = comun.WEB / 'fuentes' / m[1]
            if not f.is_file():
                return self.enviar({'error': 'no existe'}, codigo=404)
            return self.enviar(f.read_bytes(), TIPOS.get(f.suffix.lower(), 'application/octet-stream'), cache='max-age=86400')
        # opciones: vídeo de normas, guía y contrato (firmado si ya se ha jugado)
        if ruta == '/docs/video':
            return self.por_trozos(comun.VIDEO)
        if ruta == '/docs/guia':
            return self.archivo(comun.GUIA_PDF)
        if ruta == '/docs/contrato':
            return self.enviar(contrato_html().encode(), 'text/html; charset=utf-8')
        if m := re.fullmatch(r'/docs/img/([\w.-]+)', ruta):
            return self.archivo(comun.NORMAS / 'img' / m[1])
        self.enviar({'error': 'no existe'}, codigo=404)

    def local(self):
        """La petición va a este Pokelocke por 127.0.0.1 o localhost. Una web con un dominio que apunte a 127.0.0.1
        (DNS rebinding) llega con su propio Host y se rechaza: no puede leer el estado ni mandar acciones."""
        return self.headers.get('Host', '') in (f'127.0.0.1:{comun.PUERTO}', f'localhost:{comun.PUERTO}')

    def do_POST(self):
        # cualquier web abierta en el PC puede mandar un POST a 127.0.0.1, pero no con Content-Type JSON sin
        # pedir permiso antes (CORS), y este servidor no se lo da: así solo la ventana de Pokelocke manda acciones
        if not self.local() or not (self.headers.get('Content-Type') or '').startswith('application/json'):
            return self.enviar({'error': 'Petición no permitida'}, codigo=403)
        try:
            largo = min(int(self.headers.get('Content-Length') or 0), 20_000_000)
            datos = json.loads(self.rfile.read(largo) or b'{}')
            if not isinstance(datos, dict):
                raise ValueError('Petición no válida')
            respuesta = self.accion(self.path, datos)
            self.enviar(respuesta or {'ok': True})
        except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
            pass
        except Exception as e:
            self.enviar({'error': errores.describir(e, f'Acción {self.path}')}, codigo=400)

    def accion(self, ruta, d):
        if ruta == '/api/firmar':
            return {'firma': firmar()}
        if ruta == '/api/anadir':
            rom = elegir_rom()
            if not rom:
                return {'ok': False}
            with comun.lock:
                ruta_rom = str(Path(rom))
                if any(j['ruta'] == ruta_rom for j in comun.biblio['juegos']):
                    raise RuntimeError('Ese juego ya está en la biblioteca')
                comun.biblio['juegos'].append({'id': hashlib.sha1(ruta_rom.encode()).hexdigest()[:10],
                                         'nombre': Path(rom).stem, 'ruta': ruta_rom, 'preparado': False,
                                         'random': None, 'vidas_iniciales': 25, 'ajuste_vidas': 0,
                                         'muertos': [], 'medallas': [False] * 8})
                comun.guardar()
        elif ruta == '/api/quitar':
            with comun.lock:
                j = comun.buscar(d.get('id'))                  # solo ids de la biblioteca: nunca una ruta que llegue de fuera
                comun.biblio['juegos'].remove(j)
                shutil.rmtree(comun.DATOS / 'juegos' / j['id'], ignore_errors=True)
                comun.guardar()
        elif ruta == '/api/reiniciar':          # vuelve a pedir vidas y randomización al jugar
            with comun.lock:
                comun.buscar(d['id'])['preparado'] = False
                comun.guardar()
        elif ruta == '/api/copias':
            with comun.lock:
                return {'copias': guardado.copias_partida(comun.buscar(d.get('id')))}
        elif ruta == '/api/copias/restaurar':
            with comun.lock:
                guardado.restaurar_partida(comun.buscar(d.get('id')), str(d.get('nombre', '')))
        elif ruta == '/api/ajustes':
            with comun.lock:
                ajustes = comun.biblio.setdefault('ajustes', {})
                if 'ligero' in d:
                    ajustes['ligero'] = bool(d['ligero'])
                comun.guardar()
                return {k: v for k, v in ajustes.items() if k == 'ligero'}
        elif ruta == '/api/actualizar/comprobar':
            conexion.comprobar_actualizacion()
            return conexion.online_estado()
        elif ruta == '/api/actualizar/instalar':
            comun.en_segundo_plano('Actualizar Pokelocke', conexion.instalar_actualizacion)
        elif ruta == '/api/borrar_partida':
            with comun.lock:
                guardado.borrar_partida(comun.buscar(d['id']))
        elif ruta == '/api/registro':
            log = comun.DATOS / 'juegos' / comun.buscar(d.get('id'))['id'] / 'randomizacion.log'
            if not log.exists():
                raise RuntimeError('Este juego no tiene registro: no se ha randomizado')
            os.startfile(log)
        elif ruta == '/api/preparar':
            j = comun.buscar(d['id'])
            comun.en_segundo_plano('Preparar el juego', emulador.preparar, j, d.get('opciones', {}), d.get('vidas', 25),
                             bool(d.get('randomizar')), bool(d.get('avanzado')),
                             'mega' if d.get('reglas') == 'mega' else None, minimo=60)
        elif ruta in ('/api/huevos', '/api/huevos/coger'):
            with comun.lock:
                j = comun.buscar(d['id'])
                if not j.get('huevos'):
                    raise RuntimeError('La caja de huevos es de las normas Mega Pokelocke')
                if ruta.endswith('coger'):
                    i = int(d['i'])
                    if not 0 <= i < len(j['huevos']):
                        raise RuntimeError('Ese huevo no existe')
                    return locke.coger_huevo(j, i)
                return locke.huevos_estado(j)
        elif ruta == '/api/jugar':
            j = comun.buscar(d['id'])
            comun.en_segundo_plano('Abrir el juego', lambda: (emulador.herramientas(), emulador.lanzar(j)))
        elif ruta == '/api/upr_completo':
            comun.en_segundo_plano('Abrir el randomizador completo', lambda: (
                emulador.herramientas(), comun.DATOS.mkdir(exist_ok=True),
                subprocess.Popen([emulador.java(), '-jar', str(emulador.upr_jar())], cwd=emulador.upr_jar().parent)))
        elif ruta == '/api/medalla':
            with comun.lock:
                i = int(d['i'])
                if not 0 <= i < 8:
                    raise RuntimeError('Esa medalla no existe')
                comun.buscar(comun.vivo['activo'])['medallas'][i] = bool(d['valor'])
                comun.guardar()
        elif ruta == '/api/vidas':
            with comun.lock:
                comun.buscar(comun.vivo['activo'])['ajuste_vidas'] += int(d['delta'])
                comun.guardar()
        elif ruta.startswith('/api/online/'):
            return conexion.online_accion(ruta.rsplit('/', 1)[1], d)
        elif ruta.startswith('/api/pokehex/'):
            return guardado.pokehex_accion(ruta.rsplit('/', 1)[1], d)
        else:
            raise RuntimeError('Acción desconocida')


def abrir_ventana_app():
    nav = emulador.navegador()
    url = f'{comun.URL}/'
    if nav:
        subprocess.Popen([nav, f'--app={url}', f'--user-data-dir={comun.TOOLS / "edge-perfil"}',
                          '--window-size=1280,820', '--no-first-run'])
    elif ff := emulador.firefox():
        # Firefox no tiene modo app: perfil propio con la barra de título de Windows y sin pestañas ni barra de direcciones
        perfil = emulador.perfil_firefox('firefox-perfil', {'toolkit.legacyUserProfileCustomizations.stylesheets': True,
                                                   'browser.tabs.inTitlebar': 0},
                                '#TabsToolbar, #nav-bar, #PersonalToolbar { visibility: collapse !important; }\n')
        subprocess.Popen([ff, '-profile', perfil, '-width', '1280', '-height', '820', url])
    else:
        import webbrowser
        webbrowser.open(url)
