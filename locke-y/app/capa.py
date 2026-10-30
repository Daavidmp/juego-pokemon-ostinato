"""La capa del layout encima del juego y el navegador sin ventana que la pinta."""
import base64
import ctypes
import json
import os
import socket
import subprocess
import time
import traceback
import urllib.request

import comun
import emulador
import web


def huella_capa():
    """Lo que se ve en la capa: si cambia, hay que volver a pintarla."""
    e = web.foto_estado()
    a = e['activo']
    # también el fanart de cada carta (ruta y fecha): pegar o cambiar uno se ve al momento
    artes = []
    for p in e['equipo']:
        try:
            f = web.arte(p['especie']) if p and not p['huevo'] else None
            artes.append(f and [str(f), f.stat().st_mtime])
        except OSError:
            artes.append(None)
    return json.dumps([a and [a['vidas'], a['vidas_iniciales'], a['medallas'], a['vial'], a['vial_bloqueado'], a['topes']], e['equipo'], artes, e['aviso']],
                      sort_keys=True)


class Fotografo:
    """Un Edge (o Chrome) sin ventana que se queda abierto mientras se juega: cada foto de la capa es recargar la
    página y capturarla por su protocolo de depuración, unas décimas de segundo. Antes se lanzaba un navegador nuevo
    por foto (segundos y cientos de MB cada vez), y en un combate la vida cambia a cada golpe."""
    # la página está lista: cargada (la primera vez) o repintada con el estado de ahora (las demás: el overlay ya
    # sabe pedirlo y repintarse con actualizar(), sin recargar letras ni imágenes), con sus imágenes, y pintada
    LISTA = """(async (n, repintar) => {
      while (!location.search.includes('n=' + n) || document.readyState !== 'complete') await new Promise((r) => setTimeout(r, 25));
      if (repintar) await actualizar();
      await document.fonts.ready;
      await Promise.all([...document.images].map((i) => i.complete ? 0 : new Promise((r) => { i.onload = i.onerror = r; })));
      await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
      return true;
    })"""

    def __init__(self, nav, escala):
        import websocket                                   # websocket-client: va en el instalador
        with socket.socket() as so:
            so.bind(('127.0.0.1', 0))
            puerto = so.getsockname()[1]
        self.n, self.ids, self.escala = 0, 0, escala
        self.proc = subprocess.Popen([nav, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--mute-audio',
                                      f'--user-data-dir={comun.TOOLS / "edge-capa"}', f'--remote-debugging-port={puerto}',
                                      'about:blank'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                     creationflags=0x08000000 if os.name == 'nt' else 0)
        limite = time.time() + 30
        while True:
            try:
                with urllib.request.urlopen(f'http://127.0.0.1:{puerto}/json/list', timeout=2) as r:
                    pagina = next(x for x in json.load(r) if x['type'] == 'page')
                break
            except (OSError, ValueError, StopIteration):
                if time.time() > limite or self.proc.poll() is not None:
                    self.cerrar()
                    raise RuntimeError('El navegador de la capa no arranca')
                time.sleep(0.3)
        self.ws = websocket.create_connection(pagina['webSocketDebuggerUrl'], timeout=30, suppress_origin=True)
        self.cdp('Emulation.setDeviceMetricsOverride', width=1920, height=1080, deviceScaleFactor=escala, mobile=False)

    def cdp(self, metodo, **params):
        self.ids += 1
        self.ws.send(json.dumps({'id': self.ids, 'method': metodo, 'params': params}))
        while True:
            m = json.loads(self.ws.recv())
            if m.get('id') == self.ids:
                if 'error' in m:
                    raise RuntimeError(f'{metodo}: {m["error"].get("message")}')
                return m.get('result', {})

    def foto(self, destino):
        repintar = self.n > 0
        if not repintar:                      # la primera vez se carga la página; después solo se repinta
            self.n = 1
            self.cdp('Page.navigate', url=f'{comun.URL}/overlay?capa=1&n={self.n}')
        for _ in range(5):                    # justo al navegar, la página vieja puede desaparecer a mitad: otra vez
            try:
                self.cdp('Runtime.evaluate', expression=f'{self.LISTA}({self.n}, {str(repintar).lower()})',
                         awaitPromise=True, returnByValue=True)
                break
            except RuntimeError:
                time.sleep(0.1)
        datos = self.cdp('Page.captureScreenshot', format='png', optimizeForSpeed=True)['data']
        destino.write_bytes(base64.b64decode(datos))

    def cerrar(self):
        try:
            self.ws.close()
        except Exception:
            pass
        if self.proc.poll() is None:          # Edge deja procesos hijos: se cierra el árbol entero
            if os.name == 'nt':
                subprocess.run(['taskkill', '/F', '/T', '/PID', str(self.proc.pid)], stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, creationflags=0x08000000)
            else:
                self.proc.terminate()


fotografo = {'f': None}


def cerrar_fotografo():
    if fotografo['f']:
        fotografo['f'].cerrar()
        fotografo['f'] = None


def renderizar_capa():
    """Pinta /overlay?capa=1 a la resolución del monitor: con el navegador que se queda abierto si se puede, y si no
    lanzando uno sin ventana para esta foto (como antes)."""
    nav, ff = emulador.navegador(), None
    if nav:
        tmp = comun.TOOLS / 'capa-nueva.png'
        try:
            if not fotografo['f']:
                fotografo['f'] = Fotografo(nav, comun.encaje()[0])
            fotografo['f'].foto(tmp)
        except Exception:
            traceback.print_exc()
            cerrar_fotografo()                # este intento, como antes; el siguiente vuelve a probar
        else:
            try:
                tmp.replace(comun.CAPA_PNG)
            except OSError:                   # la capa la está leyendo justo ahora: el siguiente intento
                return False
            comun.vivo['capa'] += 1
            return True
    if not nav:
        ff = emulador.firefox()
        if not ff:
            return
    s, _, _ = comun.encaje()
    comun.CAPA_PNG.parent.mkdir(exist_ok=True)
    tmp = comun.TOOLS / 'capa-nueva.png'
    tmp.unlink(missing_ok=True)
    if ff:
        # Firefox sin ventana: el zoom va en el perfil y la foto se hace al cargar (el estado viene ya en la página)
        perfil = emulador.perfil_firefox('firefox-capa', {'layout.css.devPixelsPerPx': str(s)})
        subprocess.run([ff, '-headless', '-no-remote', '-profile', perfil, '--window-size=1920,1080',
                        '--screenshot', str(tmp), f'{comun.URL}/overlay?capa=1'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000, timeout=60)
    else:
        # sin capturar la salida: Edge deja procesos hijos con la tubería abierta y esperar a que la cierren
        # podía dejar colgado el pintor para siempre (la capa se quedaba con el equipo de ese momento). Pero el
        # msedge.exe que se lanza le pasa el trabajo a un hijo y sale enseguida: hay que esperar a que la captura
        # aparezca y deje de crecer, con un límite
        subprocess.run([nav, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                        f'--user-data-dir={comun.TOOLS / "edge-capa"}', f'--force-device-scale-factor={s}',
                        f'--window-size={round(1920 * s)},{round(1080 * s)}', '--virtual-time-budget=4000',
                        f'--screenshot={tmp}', f'{comun.URL}/overlay?capa=1'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000, timeout=60)
    tam, limite = -1, time.time() + 20
    while time.time() < limite:
        ahora = tmp.stat().st_size if tmp.exists() else 0
        if ahora and ahora == tam:
            break
        tam = ahora
        time.sleep(0.4)
    else:
        return False
    try:
        tmp.replace(comun.CAPA_PNG)
    except OSError:                       # la capa la está leyendo justo ahora: el siguiente intento
        return False
    comun.vivo['capa'] += 1
    return True


def pintor_capa():
    """Repinta la capa cuando cambia lo que se ve. Nunca se para: si algo falla, lo vuelve a intentar."""
    ultima = None
    while True:
        try:
            if emulador.jugando() and emulador.cargando() is None:          # mientras Citra carga, todo el procesador para él
                huella = huella_capa()
                if huella != ultima and renderizar_capa():
                    ultima = huella                       # si no se pudo pintar, se reintenta en el siguiente
                    if comun.biblio.get('ajustes', {}).get('ligero'):
                        time.sleep(2)                     # modo ligero: como mucho una foto cada 3 s
            elif not emulador.jugando():
                ultima = None
                cerrar_fotografo()
        except Exception:
            traceback.print_exc()
            ultima = None
        time.sleep(1)


# ---------- capa del layout encima de Azahar ----------

def capa():
    """Ventana sin bordes, siempre delante, con los huecos (color clave) transparentes y sin coger
    el foco: se ve y se toca el juego a través de ella y el teclado sigue en Azahar.
    Mientras el juego se abre es solo un cartel pequeño en el centro («Abriendo el juego…», con los segundos),
    para que se vea que no se ha colgado y para no tapar Citra (ni sus avisos) antes de tiempo: Alt+Q del
    lanzador solo funciona cuando ya está la ventana del juego, así que antes el layout no se podía quitar."""
    import tkinter as tk
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
    w, h = comun.pantalla()
    s, ox, oy = comun.encaje()
    raiz = tk.Tk()
    raiz.overrideredirect(True)
    raiz.attributes('-topmost', True)
    raiz.attributes('-transparentcolor', comun.CLAVE)
    etiqueta = tk.Label(raiz, bd=0, bg=comun.CLAVE)
    # el cartel de carga
    FONDO, TINTA, ACENTO = '#1b1820', '#ffffff', '#c8102e'
    cartel = tk.Frame(raiz, bg=FONDO, highlightthickness=3, highlightbackground=ACENTO)
    titulo = tk.Label(cartel, text='Abriendo el juego…', bg=FONDO, fg=TINTA, font=('Segoe UI Semibold', 20))
    detalle = tk.Label(cartel, bg=FONDO, fg='#f2b8c2', font=('Segoe UI', 12), justify='center')
    barra = tk.Canvas(cartel, width=380, height=10, bg='#3a2f3d', highlightthickness=0)
    bloque = barra.create_rectangle(0, 0, 90, 10, fill=ACENTO, width=0)
    for wdg, pad in ((titulo, (26, 6)), (detalle, (0, 14)), (barra, (0, 26))):
        wdg.pack(padx=34, pady=pad)
    raiz.update_idletasks()
    hwnd = ctypes.windll.user32.GetParent(raiz.winfo_id())
    GWL_EXSTYLE, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW = -20, 0x08000000, 0x00000080
    estilo = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, estilo | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW)
    vista = {'version': -1, 'imagen': None, 'arrancado': time.time(), 'modo': None, 'x': 0, 'fallos': 0}

    def modo_cartel(segundos):
        if vista['modo'] != 'cartel':
            vista['modo'] = 'cartel'
            etiqueta.place_forget()
            raiz.configure(bg=FONDO)
            cartel.pack()
            raiz.update_idletasks()
            cw, ch = cartel.winfo_reqwidth(), cartel.winfo_reqheight()
            raiz.geometry(f'{cw}x{ch}+{(w - cw) // 2}+{(h - ch) // 2}')
        texto = f'Lleva {segundos} s · En un PC lento puede tardar hasta un minuto.\nNo cierres nada: el juego saldrá aquí solo.'
        if segundos > 90:
            texto = (f'Lleva {segundos} s: está tardando más de lo normal.\n'
                     'Si Citra enseña un error, ciérralo y vuelve a darle a Jugar.')
        detalle.configure(text=texto)

    def modo_layout():
        if vista['modo'] != 'layout':
            vista['modo'] = 'layout'
            cartel.pack_forget()
            raiz.configure(bg=comun.CLAVE)
            raiz.geometry(f'{w}x{h}+0+0')
            etiqueta.place(x=ox, y=oy)

    def animar():
        if vista['modo'] == 'cartel':                    # la barra va y viene: se ve que sigue vivo
            vista['x'] = (vista['x'] + 6) % 470
            barra.coords(bloque, vista['x'] - 90, 0, vista['x'], 10)
        raiz.after(40, animar)

    def refrescar():
        try:
            with urllib.request.urlopen(f'{comun.URL}/api/estado', timeout=2) as r:
                e = json.load(r)
            vista['fallos'] = 0
        except (OSError, ValueError):
            # un fallo suelto no cierra el layout en mitad de la partida: solo si Pokelocke no contesta en 10 s
            vista['fallos'] += 1
            if vista['fallos'] >= 10:
                return raiz.destroy()
            return raiz.after(1000, refrescar)
        if not e['jugando'] and time.time() - vista['arrancado'] > 15:
            return raiz.destroy()
        if e.get('cargando') is not None:
            modo_cartel(e['cargando'])
        else:
            modo_layout()
            if e['capa'] != vista['version'] and comun.CAPA_PNG.exists():
                vista['version'] = e['capa']
                vista['imagen'] = tk.PhotoImage(file=str(comun.CAPA_PNG))
                etiqueta.configure(image=vista['imagen'])
        raiz.attributes('-topmost', True)
        raiz.after(1000, refrescar)

    refrescar()
    animar()
    raiz.mainloop()
