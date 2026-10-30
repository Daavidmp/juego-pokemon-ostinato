"""El cliente del online: sesión, latidos, encargos, actualizaciones y encender el servidor."""
import hashlib
import hmac
import json
import socket
import subprocess
import threading
import time

import online
import comun
import emulador
import guardado


def certificado_servidor():
    """El certificado del anfitrión en que confía este Pokelocke: el que trae su instalador, o en el PC anfitrión el
    suyo propio."""
    pem = online_config().get('certificado')
    if not pem:
        try:
            pem = json.loads((comun.APP / 'online.json').read_text(encoding='utf-8')).get('certificado')
        except (OSError, ValueError):
            pem = None
    if not pem and (comun.DATOS / 'servidor' / 'cert.pem').exists():
        pem = (comun.DATOS / 'servidor' / 'cert.pem').read_text(encoding='utf-8')
    return pem


online.certificado = certificado_servidor


def online_motivo(e):
    """Por qué no se ha podido hablar con el servidor, en pocas palabras."""
    import ssl
    if isinstance(e, online.SinCertificado):
        return str(e)
    if isinstance(e, ssl.SSLCertVerificationError) or 'CERTIFICATE_VERIFY_FAILED' in str(e):
        return 'el servidor no tiene el certificado del anfitrión: o no es él, o hay que reinstalar con su instalador'
    if isinstance(e, (TimeoutError, socket.timeout)) or 'timed out' in str(e):
        return 'no contesta a tiempo'
    if isinstance(e, ConnectionRefusedError) or 'refused' in str(e).lower() or '10061' in str(e):
        return 'rechaza la conexión: el servidor está apagado'
    if 'getaddrinfo' in str(e) or '11001' in str(e):
        return 'no se encuentra la dirección'
    return f'{type(e).__name__}: {e}'


def online_config():
    for f in (comun.F_ONLINE, comun.APP / 'online.json'):
        try:
            return json.loads(f.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            pass
    return {}


def online_direccion():
    if comun.red['servidor']:                     # este PC es el servidor: se habla con él directamente
        return '127.0.0.1'
    return online_config().get('direccion')


def online_estado():
    s = comun.red['sesion']
    return {'sesion': s and {'usuario': s['usuario'], 'admin': s['admin']}, 'conectados': comun.red['conectados'],
            'error': comun.red['error'], 'servidor': bool(comun.red['servidor']), 'upnp': comun.red['upnp'], 'ip': comun.red['ip'],
            'sala': bool(comun.red['servidor']) and comun.red['servidor'].sala_viva(),
            'direccion': online_config().get('direccion'), 'version': comun.VERSION_APP, 'actualizacion': comun.red.get('actualizacion')}


def online_guardar_sesion():
    if comun.red['sesion']:
        comun.F_SESION.write_text(json.dumps(comun.red['sesion']), encoding='utf-8')
    else:
        comun.F_SESION.unlink(missing_ok=True)


def online_latidos():
    """Cada pocos segundos: «sigo aquí» al servidor, la lista de conectados y los encargos del PokéHex."""
    try:
        comun.red['sesion'] = json.loads(comun.F_SESION.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        pass
    while True:
        s, direccion = comun.red['sesion'], online_direccion()
        if s and direccion:
            with comun.lock:
                j = comun.buscar(comun.vivo['activo']) if comun.vivo['activo'] and emulador.jugando() else None
            estado = {'jugando': bool(j), 'juego': j and j['nombre']}
            try:
                r = online.peticion(direccion, '/latido', {'token': s['token'], 'estado': estado}, espera=8)
                if r.get('sesion') is False:
                    comun.red['sesion'], comun.red['conectados'] = None, []
                    online_guardar_sesion()
                elif 'error' in r:
                    comun.red['error'] = r['error']
                else:
                    comun.red['error'], comun.red['conectados'] = None, r['conectados']
                    for t in r['tareas']:
                        threading.Thread(target=online_tarea, args=(direccion, s['token'], t), daemon=True).start()
            except OSError as e:
                comun.red['error'], comun.red['conectados'] = f'No se puede conectar con el servidor ({online_motivo(e)})', []
        if time.time() - comun.red.get('actualizacion_mirada', 0) > CADA_CUANTO_ACTUALIZACION:
            comun.red['actualizacion_mirada'] = time.time()
            threading.Thread(target=comprobar_actualizacion, daemon=True).start()
        time.sleep(online.LATIDO)


# ---------- actualizaciones: el anfitrión reparte el instalador; cada Pokelocke compara versiones ----------
CADA_CUANTO_ACTUALIZACION = 30 * 60


def version_tupla(v):
    try:
        return tuple(int(x) for x in str(v).split('.'))
    except ValueError:
        return None


def comprobar_actualizacion():
    """Pregunta al servidor qué versión del instalador reparte. Hay actualización si es más nueva que esta."""
    direccion = online_direccion()
    comun.red['actualizacion_mirada'] = time.time()
    if not direccion:
        comun.red['actualizacion'] = None
        return
    try:
        with online.abrir(direccion, '/version', espera=6) as r:
            datos = json.load(r)
    except (OSError, ValueError) as e:
        comun.red['actualizacion'] = {'servidor': None, 'nueva': False, 'error': f'No se puede preguntar al servidor ({online_motivo(e)})'}
        return
    servidor = str(datos.get('version') or '')
    yo, suya = version_tupla(comun.VERSION_APP), version_tupla(servidor)
    comun.red['actualizacion'] = {'servidor': servidor, 'nueva': bool(yo and suya and suya > yo), 'error': None,
                            'sha256': datos.get('sha256')}


def instalar_actualizacion():
    """Descarga el instalador del servidor y lo abre en silencio: cierra Pokelocke, se instala encima (las partidas
    no se tocan) y lo vuelve a abrir."""
    if emulador.jugando():
        raise RuntimeError('Cierra el juego antes de actualizar')
    direccion = online_direccion()
    if not direccion:
        raise RuntimeError('Falta la dirección del servidor')
    comprobar_actualizacion()
    esperada = (comun.red.get('actualizacion') or {}).get('sha256')
    if not esperada:
        raise RuntimeError('El servidor no dice la huella del instalador: no se instala nada sin poder comprobarlo')
    comun.tarea('Descargando la actualización…', paso=1)
    destino, tmp = comun.TOOLS / 'PokelockeSetup.exe', comun.TOOLS / 'PokelockeSetup.descarga'
    huella = hashlib.sha256()
    with online.abrir(direccion, '/descargar', espera=60) as r, open(tmp, 'wb') as f:
        for trozo in iter(lambda: r.read(1 << 20), b''):
            huella.update(trozo)
            f.write(trozo)
    if not hmac.compare_digest(huella.hexdigest(), esperada):
        tmp.unlink(missing_ok=True)
        raise RuntimeError('El instalador descargado no coincide con su huella (se ha cortado o lo han cambiado por el '
                           'camino): no se instala. Vuelve a intentarlo.')
    tmp.replace(destino)
    comun.tarea('Instalando: Pokelocke se cerrará y volverá a abrirse solo…', paso=3)
    time.sleep(2)
    subprocess.Popen([str(destino), '/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'], creationflags=0x00000008)  # DETACHED_PROCESS


MAX_LOG = 150_000          # bytes del final de cada registro que se mandan (el servidor admite 1 MB por petición)


def registro_errores():
    """El final de pokelocke.log y de pokelocke.old.log (la vez anterior), para el administrador."""
    partes = {}
    for nombre in ('pokelocke.log', 'pokelocke.old.log'):
        f = comun.RAIZ / nombre
        try:
            with open(f, 'rb') as a:
                a.seek(max(0, f.stat().st_size - MAX_LOG))
                partes[nombre] = a.read().decode('utf-8', errors='replace')
        except OSError:
            partes[nombre] = ''
    return {'version': comun.VERSION_APP, 'registros': partes, 'jugando': emulador.jugando(), 'hora': time.strftime('%Y-%m-%d %H:%M:%S')}


def online_tarea(direccion, token, t):
    """Un encargo del administrador: el PokéHex de este jugador, en su partida (con el juego cerrado), o su registro
    de errores."""
    if t.get('que') == 'log':
        try:
            res = registro_errores()
        except Exception as e:
            res = {'error': str(e)}
        online.peticion(direccion, '/resultado', {'token': token, 'id': t['id'], 'resultado': res})
        return
    try:
        with comun.lock:
            juegos = [j for j in comun.biblio['juegos'] if j.get('preparado')]
        if not juegos:
            raise RuntimeError('Este jugador no tiene ninguna partida')
        datos = dict(t.get('datos') or {})
        datos.setdefault('id', juegos[0]['id'])
        res = guardado.pokehex_accion(t['que'], {**datos, 'token': guardado.hex_vivo['interno']})
        if t['que'] == 'leer':
            res['juegos'] = [{'id': j['id'], 'nombre': j['nombre']} for j in juegos]
    except Exception as e:
        res = {'error': str(e)}
    online.peticion(direccion, '/resultado', {'token': token, 'id': t['id'], 'resultado': res})


def online_servidor(activar):
    if activar and not comun.red['servidor']:
        exe = emulador.azahar_exe()
        sala = next((exe.parent / n for n in ('citra-room.exe', 'azahar-room.exe') if exe and (exe.parent / n).exists()), None)
        admin = online_config().get('admin') or json.loads((comun.APP / 'online.json').read_text(encoding='utf-8')).get('admin', '')
        srv = online.Servidor(comun.DATOS / 'servidor', sala, admin)
        srv.arrancar()
        comun.red['servidor'] = srv
        comun.red['upnp'], comun.red['ip'] = online.abrir_puertos()
        if not comun.red['upnp']:
            # la primera vez en un PC, el cortafuegos pregunta y mientras tanto el router no contesta: se reintenta
            def reintentar():
                for _ in range(6):
                    time.sleep(10)
                    if not comun.red['servidor']:
                        return
                    comun.red['upnp'], ip = online.abrir_puertos()
                    comun.red['ip'] = ip or comun.red['ip']
                    if comun.red['upnp']:
                        return
            threading.Thread(target=reintentar, daemon=True).start()
        # la dirección que se reparte con la app: el nombre fijo de DuckDNS si lo hay (datos/servidor/duckdns.json,
        # {"dominio": "...", "token": "..."}, solo en el PC del anfitrión) y si no, la IP pública de ahora
        try:
            dd = json.loads((comun.DATOS / 'servidor' / 'duckdns.json').read_text(encoding='utf-8'))
        except (OSError, ValueError):
            dd = None
        cfg = online_config()
        if dd and dd.get('dominio') and dd.get('token'):
            comun.red['duckdns'] = online.duckdns(dd['dominio'], dd['token'])
            cfg['direccion'] = dd['dominio'].strip() if dd['dominio'].endswith('.duckdns.org') else dd['dominio'].strip() + '.duckdns.org'
        elif comun.red['ip']:
            cfg['direccion'] = comun.red['ip']
        comun.F_ONLINE.write_text(json.dumps(cfg, indent=1), encoding='utf-8')
    elif not activar and comun.red['servidor']:
        comun.red['servidor'].parar()
        comun.red['servidor'] = None
        threading.Thread(target=online.cerrar_puertos, daemon=True).start()
        comun.red['conectados'] = []


def online_accion(que, d):
    if que == 'servidor':
        online_servidor(bool(d.get('activar')))
        return online_estado()
    if que == 'direccion':
        cfg = online_config()
        cfg['direccion'] = str(d.get('direccion', '')).strip()
        comun.F_ONLINE.write_text(json.dumps(cfg, indent=1), encoding='utf-8')
        return online_estado()
    direccion = online_direccion()
    if que in ('entrar', 'registro'):
        if not direccion:
            raise RuntimeError('Falta la dirección del servidor')
        try:
            datos = {'usuario': d.get('usuario'), 'clave': d.get('clave')}
            if que == 'registro' and comun.red['servidor']:      # registrarse desde el anfitrión: cuenta de administrador
                datos['anfitrion'] = comun.red['servidor'].clave_anfitrion
            r = online.peticion(direccion, '/' + que, datos)
        except OSError as e:
            raise RuntimeError(f'No se puede conectar con el servidor ({online_motivo(e)}). ¿Está encendido?')
        if 'error' in r:
            raise RuntimeError(r['error'])
        comun.red['sesion'], comun.red['error'] = {k: r[k] for k in ('token', 'usuario', 'admin', 'sala')}, None
        online_guardar_sesion()
        return online_estado()
    if que == 'salir':
        if comun.red['sesion'] and direccion:
            try:
                online.peticion(direccion, '/salir', {'token': comun.red['sesion']['token']}, espera=4)
            except OSError:
                pass
        comun.red['sesion'], comun.red['conectados'] = None, []
        online_guardar_sesion()
        return online_estado()
    if que in ('torneo', 'torneo_editar', 'foto'):    # el torneo lo ven todos; lo cambia el administrador
        if not comun.red['sesion']:
            raise RuntimeError('Entra con tu usuario para ver el torneo')
        ruta = {'torneo': '/torneo', 'torneo_editar': '/torneo/editar', 'foto': '/foto'}[que]
        try:
            r = online.peticion(direccion, ruta, {**d, 'token': comun.red['sesion']['token']}, espera=15)
        except OSError as e:
            raise RuntimeError(f'No se puede conectar con el servidor ({online_motivo(e)})')
        if 'error' in r:
            raise RuntimeError(r['error'])
        return r
    if que == 'log':                         # el registro de errores de un jugador conectado (solo el administrador)
        if not comun.red['sesion']:
            raise RuntimeError('Entra con tu usuario')
        try:
            r = online.peticion(direccion, '/log', {'token': comun.red['sesion']['token'], 'usuario': d.get('usuario')}, espera=40)
        except OSError as e:
            raise RuntimeError(f'No se puede conectar con el servidor ({online_motivo(e)})')
        if 'error' in r:
            raise RuntimeError(r['error'])
        return r
    if que == 'pokehex':                     # el PokéHex de otro jugador (solo el administrador)
        if not comun.red['sesion']:
            raise RuntimeError('Entra con tu usuario')
        try:
            r = online.peticion(direccion, '/pokehex', {'token': comun.red['sesion']['token'],
                                                         'usuario': d.get('usuario'), 'que': d.get('que'),
                                                         'datos': d.get('datos') or {}}, espera=40)
        except OSError as e:
            raise RuntimeError(f'No se puede conectar con el servidor ({online_motivo(e)})')
        if 'error' in r:
            raise RuntimeError(r['error'])
        return r
    raise RuntimeError('Acción desconocida')
