"""El cliente del online: sesión, latidos, encargos, actualizaciones y encender el servidor."""
import base64
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
import locke
import vigia


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
            'mi_foto': s and comun.red.get('fotos', {}).get(s['usuario'], {}).get('v'),
            'recordada': recordada_usuario(),
            'error': comun.red['error'], 'servidor': bool(comun.red['servidor']), 'upnp': comun.red['upnp'], 'ip': comun.red['ip'],
            'sala': bool(comun.red['servidor']) and comun.red['servidor'].sala_viva(),
            'direccion': online_config().get('direccion'), 'version': comun.VERSION_APP, 'actualizacion': comun.red.get('actualizacion'),
            'tablero': comun.red.get('tablero', []), 'coronas': comun.red.get('coronas', {}), 'duelos': comun.red.get('duelos', [])}


# ---------- recordar la cuenta: con «Guardar sesión» (marcado por defecto) Pokelocke vuelve a entrar solo, también
# cuando el anfitrión reinicia el servidor y el token deja de valer. La contraseña va cifrada con DPAPI de Windows:
# solo la puede descifrar este usuario de Windows en este PC.
def _dpapi(datos, cifrar):
    import ctypes
    from ctypes import wintypes

    class BLOB(ctypes.Structure):
        _fields_ = [('cbData', wintypes.DWORD), ('pbData', ctypes.POINTER(ctypes.c_char))]
    buf = ctypes.create_string_buffer(datos, len(datos))
    entrada, salida = BLOB(len(datos), ctypes.cast(buf, ctypes.POINTER(ctypes.c_char))), BLOB()
    crypt = ctypes.windll.crypt32
    f = crypt.CryptProtectData if cifrar else crypt.CryptUnprotectData
    if not f(ctypes.byref(entrada), None, None, None, None, 0x1, ctypes.byref(salida)):    # 0x1: sin diálogos
        raise OSError('DPAPI')
    try:
        return ctypes.string_at(salida.pbData, salida.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(salida.pbData)


def recordar_guardar(usuario, clave):
    try:
        cifrada = base64.b64encode(_dpapi(clave.encode('utf-8'), True)).decode()
        comun.F_RECORDAR.write_text(json.dumps({'usuario': usuario, 'clave': cifrada}), encoding='utf-8')
    except (OSError, AttributeError):          # sin DPAPI (no es Windows): no se recuerda
        recordar_borrar()


def recordada_usuario():
    """El nombre de la cuenta guardada (sin descifrar nada), o None."""
    try:
        return json.loads(comun.F_RECORDAR.read_text(encoding='utf-8'))['usuario']
    except (OSError, ValueError, KeyError, TypeError):
        return None


def recordar_borrar():
    comun.F_RECORDAR.unlink(missing_ok=True)


def recordar_leer():
    try:
        r = json.loads(comun.F_RECORDAR.read_text(encoding='utf-8'))
        return r['usuario'], _dpapi(base64.b64decode(r['clave']), False).decode('utf-8')
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return None


def volver_a_entrar(direccion):
    """Con la cuenta recordada, una sesión nueva. True si ha entrado. Si el servidor dice que la contraseña ya no
    vale (la han cambiado en otro PC), se olvida."""
    cuenta = recordar_leer()
    if not cuenta or not direccion:
        return False
    try:
        r = online.peticion(direccion, '/entrar', {'usuario': cuenta[0], 'clave': cuenta[1]}, espera=8)
    except OSError:
        return False
    if 'error' in r:
        if 'incorrectos' in r['error']:
            recordar_borrar()
        return False
    comun.red['sesion'], comun.red['error'] = {k: r[k] for k in ('token', 'usuario', 'admin', 'sala')}, None
    online_guardar_sesion()
    return True


def online_guardar_sesion():
    if comun.red['sesion']:
        comun.F_SESION.write_text(json.dumps(comun.red['sesion']), encoding='utf-8')
    else:
        comun.F_SESION.unlink(missing_ok=True)


def traer_fotos(direccion, token, conectados):
    """Las fotos de perfil que han cambiado, sin esperar a nadie: si fallan, se ven las iniciales."""
    fotos = comun.red.setdefault('fotos', {})
    faltan = [c['usuario'] for c in conectados if c.get('foto') and fotos.get(c['usuario'], {}).get('v') != c['foto']]
    if not faltan:
        return
    try:
        r = online.peticion(direccion, '/fotos', {'token': token, 'usuarios': faltan}, espera=8)
        for u, f in r.get('fotos', {}).items():
            fotos[u] = {'v': f['v'], 'imagen': base64.b64decode(f['imagen'].split(',', 1)[1])}
    except (OSError, ValueError, KeyError, AttributeError, IndexError):
        pass


def online_latidos():
    """Cada pocos segundos: «sigo aquí» al servidor, la lista de conectados y los encargos del PokéHex."""
    try:
        comun.red['sesion'] = json.loads(comun.F_SESION.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        pass
    while True:
        s, direccion = comun.red['sesion'], online_direccion()
        if not s and direccion and comun.F_RECORDAR.exists() and volver_a_entrar(direccion):
            s = comun.red['sesion']
        if s and direccion:
            with comun.lock:
                j = comun.buscar(comun.vivo['activo']) if comun.vivo['activo'] and emulador.jugando() else None
                mio = locke.mi_locke()
                cuentas = mio and {'medallas': sum(mio.get('medallas', [])), 'perdidas': locke.perdidas(mio)}
            estado = {'jugando': bool(j), 'juego': j and j['nombre'], 'tablero': comun.biblio.get('mi_tablero'), 'locke': cuentas}
            # los eventos que aún no tiene el servidor; hasta que diga cuántos tiene, solo se le dice cuántos hay
            eventos, total = vigia.para_mandar(comun.red.get('eventos_hasta', float('inf')))
            try:
                r = online.peticion(direccion, '/latido', {'token': s['token'], 'estado': estado, 'eventos': eventos, 'total': total}, espera=8)
                if r.get('sesion') is False:              # el servidor se ha reiniciado: con la cuenta recordada, otra vez dentro
                    comun.red['sesion'], comun.red['conectados'] = None, []
                    online_guardar_sesion()
                    volver_a_entrar(direccion)
                elif 'error' in r:
                    comun.red['error'] = r['error']
                else:
                    traer_fotos(direccion, s['token'], r['conectados'] + r.get('tablero', []))
                    comun.red['tablero'], comun.red['coronas'] = r.get('tablero', []), r.get('coronas', {})
                    comun.red['duelos'] = r.get('duelos', [])
                    with comun.lock:
                        locke.duelos_tick(comun.red['duelos'], s['usuario'])
                    comun.red['error'], comun.red['conectados'] = None, r['conectados']
                    comun.red['eventos_hasta'] = r.get('eventos_hasta', float('inf'))
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


def huella(pem):
    import ssl
    try:
        return hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem)).hexdigest()
    except (ValueError, TypeError, AttributeError):        # sin certificado o roto
        return None


def comprobar_dueno_pokehex():
    """El PokéHex es solo para DUENO_POKEHEX: con su sesión abierta y confirmada por EL servidor del anfitrión. La
    sesión guardada en el PC se puede tocar a mano, y cualquiera puede montar su propio servidor y llamarse allí
    Daavidmp: por eso solo vale un servidor con el certificado cuya huella va compilada dentro del .exe
    (huella_oficial, la pone empaquetar.py). Sin conexión, nadie. En la copia de desarrollo no hay huella."""
    s, direccion = comun.red['sesion'], online_direccion()
    if not s or not direccion:
        raise RuntimeError(f'El PokéHex solo lo puede abrir {comun.DUENO_POKEHEX}, con su sesión online abierta')
    pem = certificado_servidor()
    try:
        import huella_oficial
        oficial = huella_oficial.HUELLA
    except ImportError:
        oficial = None
    if (oficial and huella(pem) != oficial) or (not oficial and comun.VERSION_APP != 'desarrollo'):
        raise RuntimeError('El PokéHex solo se abre con el servidor del anfitrión')
    try:
        r = online.peticion(direccion, '/yo', {'token': s['token']}, espera=8, pem=pem)
    except OSError as e:
        raise RuntimeError(f'Para abrir el PokéHex hace falta conexión con el servidor ({online_motivo(e)})')
    if r.get('error') == 'No existe':
        raise RuntimeError('El servidor todavía no comprueba el PokéHex: el anfitrión tiene que actualizar Pokelocke')
    if r.get('usuario') != comun.DUENO_POKEHEX:
        raise RuntimeError(f'El PokéHex solo lo puede abrir {comun.DUENO_POKEHEX}')


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
        if d.get('recordar', True):
            recordar_guardar(r['usuario'], str(d.get('clave') or ''))
        else:
            recordar_borrar()
        return online_estado()
    if que == 'salir':                       # cerrar sesión: también se olvida la cuenta
        recordar_borrar()
        if comun.red['sesion'] and direccion:
            try:
                online.peticion(direccion, '/salir', {'token': comun.red['sesion']['token']}, espera=4)
            except OSError:
                pass
        comun.red['sesion'], comun.red['conectados'] = None, []
        online_guardar_sesion()
        return online_estado()
    if que in ('torneo', 'torneo_editar', 'foto', 'duelo_retar', 'duelo_responder'):    # el torneo lo cambia el administrador
        if not comun.red['sesion']:
            raise RuntimeError('Entra con tu usuario')
        ruta = {'torneo': '/torneo', 'torneo_editar': '/torneo/editar', 'foto': '/foto',
                'duelo_retar': '/duelo/retar', 'duelo_responder': '/duelo/responder'}[que]
        try:
            r = online.peticion(direccion, ruta, {**d, 'token': comun.red['sesion']['token']}, espera=15)
        except OSError as e:
            raise RuntimeError(f'No se puede conectar con el servidor ({online_motivo(e)})')
        if r.get('error') == 'No existe':       # un servidor de antes de los duelos
            raise RuntimeError('El servidor todavía no tiene duelos: el anfitrión tiene que actualizar Pokelocke')
        if 'error' in r:
            raise RuntimeError(r['error'])
        if 'duelos' in r:
            comun.red['duelos'] = r['duelos']
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
    if que in ('cuenta_nombre', 'cuenta_clave'):
        if not comun.red['sesion']:
            raise RuntimeError('Entra con tu usuario')
        ruta = '/cuenta/nombre' if que == 'cuenta_nombre' else '/cuenta/clave'
        try:
            r = online.peticion(direccion, ruta, {**d, 'token': comun.red['sesion']['token']})
        except OSError as e:
            raise RuntimeError(f'No se puede conectar con el servidor ({online_motivo(e)})')
        if r.get('error') == 'No existe':       # un servidor de antes de esta opción
            raise RuntimeError('El servidor todavía no tiene esta opción: el anfitrión tiene que actualizar Pokelocke')
        if 'error' in r:
            raise RuntimeError(r['error'])
        cuenta = recordar_leer()                 # la cuenta recordada sigue a los cambios
        if cuenta and que == 'cuenta_clave':
            recordar_guardar(cuenta[0], str(d.get('nueva') or ''))
        if cuenta and que == 'cuenta_nombre':
            recordar_guardar(r['usuario'], cuenta[1])
        if que == 'cuenta_nombre':
            viejo = comun.red['sesion']['usuario']
            comun.red['sesion']['usuario'] = r['usuario']
            online_guardar_sesion()
            with comun.lock:                     # el contrato firmado sigue siendo suyo
                firma = comun.biblio.get('firma')
                if firma and firma.get('nombre') == viejo:
                    firma['nombre'] = r['usuario']
                    comun.guardar()
        return online_estado()
    if que == 'actividad':                   # lo que ha hecho cada jugador, aunque no esté conectado (solo el administrador)
        if not comun.red['sesion']:
            raise RuntimeError('Entra con tu usuario')
        try:
            r = online.peticion(direccion, '/actividad', {'token': comun.red['sesion']['token'], 'usuario': d.get('usuario')})
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
