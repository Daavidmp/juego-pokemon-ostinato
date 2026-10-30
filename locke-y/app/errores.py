"""Los errores que se enseñan en pantalla: concretos y con un código que también queda en pokelocke.log.

Los que la app ya prevé (un RuntimeError con un mensaje para el jugador: «Cierra el juego antes de…») se enseñan tal
cual. Los demás dicen qué se estaba haciendo, el tipo de error y su detalle, en qué archivo y línea ha fallado y un
código; el mismo código va en el registro junto a la traza entera, así que se encuentra al momento (el administrador
lo ve con «Registro» en el panel de conectados).
"""
import os
import time
import traceback
from pathlib import Path


def describir(e, accion, previstos=(RuntimeError,), registro='pokelocke.log'):
    if type(e) in previstos:
        return str(e)
    codigo = 'E-' + os.urandom(2).hex().upper()
    marcos = traceback.extract_tb(e.__traceback__) if e.__traceback__ else []
    donde = f' en {Path(marcos[-1].filename).name}:{marcos[-1].lineno} ({marcos[-1].name})' if marcos else ''
    print(time.strftime('%Y-%m-%d %H:%M:%S'), f'[{codigo}] {accion}', flush=True)
    traceback.print_exception(type(e), e, e.__traceback__)
    return f'{accion}: {type(e).__name__} ({str(e) or "sin más detalle"}){donde}. Código {codigo}: está en {registro}.'
