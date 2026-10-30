"""Pokelocke: biblioteca de juegos, randomizador, Azahar con el layout del stream y seguimiento del locke.

Todo vive dentro de locke-y/ y no se instala nada en el sistema:
  tools/   Azahar portable, Universal Pokemon Randomizer ZX, perfil de Edge, caché de arte (no se sube a git)
  datos/   biblioteca, lockes, ajustes y mods randomizados de cada juego (no se sube a git)
  fanart/  arte propio por especie: 658.png, 658.jpg... (no se sube a git)

Pokelocke.exe (o Pokelocke.bat) abre la biblioteca. Con --capa abre solo la capa del layout
que va encima de Azahar mientras se juega.
"""
import ctypes
import os
import sys
import threading
import time
from http.server import ThreadingHTTPServer

import capa
import comun
import conexion
import locke
import web


def main():
    if os.name == 'nt':
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
        # que la barra de tareas agrupe las ventanas de Pokelocke con su propio icono
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID('Pokelocke')
    if '--capa' in sys.argv:
        return capa.capa()
    comun.RAIZ.mkdir(parents=True, exist_ok=True)
    if getattr(sys, 'frozen', False):
        # el .exe no tiene consola: los errores van a pokelocke.log (y el de la vez anterior a pokelocke.old.log)
        log = comun.RAIZ / 'pokelocke.log'
        try:
            log.replace(comun.RAIZ / 'pokelocke.old.log')
        except OSError:
            pass
        sys.stdout = sys.stderr = open(log, 'a', encoding='utf-8', buffering=1)
        import faulthandler
        faulthandler.enable(sys.stderr)                    # también si Python se cae de golpe
        print(time.strftime('%Y-%m-%d %H:%M:%S'), 'Pokelocke abierto', flush=True)
    for carpeta in (comun.TOOLS, comun.DATOS, comun.FANART):
        carpeta.mkdir(exist_ok=True)
    comun.cargar()
    # sin SO_REUSEADDR: en Windows deja que dos Pokelocke escuchen a la vez en el mismo puerto (y los dos
    # contaban muertes); así el segundo falla al abrir el puerto y solo enseña la ventana del primero
    ThreadingHTTPServer.allow_reuse_address = False
    try:
        servidor = ThreadingHTTPServer(('127.0.0.1', comun.PUERTO), web.Servidor)
    except OSError:                       # ya está abierto: solo enseña la ventana
        return web.abrir_ventana_app()
    threading.Thread(target=locke.seguimiento, daemon=True).start()
    threading.Thread(target=locke.normas_mega, daemon=True).start()
    threading.Thread(target=capa.pintor_capa, daemon=True).start()
    threading.Thread(target=conexion.online_latidos, daemon=True).start()
    if os.name == 'nt':
        threading.Thread(target=locke.atajos, daemon=True).start()
    print(f'Pokelocke en {comun.URL}  ·  overlay para OBS: {comun.URL}/overlay')
    if '--sin-ventana' not in sys.argv:       # --sin-ventana: solo el servidor (pruebas u OBS)
        web.abrir_ventana_app()
    servidor.serve_forever()


if __name__ == '__main__':
    main()
