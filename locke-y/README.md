# Mega Pokelocke Y

Lanzador, seguimiento del locke y overlay de stream (1920×1080) para un Nuzlocke de
Pokémon Y en el emulador de 3DS Azahar.

![Maqueta](maqueta.png)

Todo vive dentro de esta carpeta. No se instala nada en el PC: Azahar y el randomizador
se descargan en versión portable dentro de `tools/`.

## Requisitos

- Windows con Python 3 (`py`) y Java 11 o superior. Se usa el primero que encuentre en
  `JAVA_HOME`, en `%USERPROFILE%\.jdks` o en el `PATH`.
- Tu ROM de Pokémon Y **descifrada** (`.3ds`, `.cci`, `.cxi` o `.cia`) en `rom/`.

## Uso

1. Abre `Pokelocke.bat`. Se abre el lanzador en `http://localhost:8765`.
2. **Preparación**: descarga Azahar y el randomizador desde el lanzador y elige la ROM.
3. **Randomización**: elige las opciones y pulsa *Randomizar*. El juego randomizado se
   instala como mod de Azahar (LayeredFS) y la ROM original no se toca. El registro
   queda en `datos/randomizacion.log`. Si quieres todas las opciones del
   Universal Pokemon Randomizer, pulsa *Opciones avanzadas*, guarda los ajustes en
   `datos/avanzado.rnqs` y marca *Usar los ajustes avanzados*.
4. **Locke**: pon las vidas (25 por defecto) y pulsa *Empezar un locke nuevo*. Después, *Jugar*.
5. En OBS, añade una **Fuente de navegador** con la URL `http://localhost:8765/overlay`, a
   1920×1080, y pon las capturas del emulador **por encima**, en estos huecos:

| Pantalla | Tamaño | Posición |
|---|---|---|
| Superior (5:3) | 1000×600 | x=72, y=244 |
| Inferior (4:3) | 680×510 | x=1168, y=530 |

## Qué se actualiza solo

- **Equipo**: se lee de la memoria del juego cada segundo, mediante el servidor RPC de Azahar,
  que el lanzador activa. Los huecos vacíos salen en negro.
- **Vidas**: cada Pokémon que llega a 0 PS resta una vida, una sola vez aunque luego lo revivas.
  En el lanzador hay botones − y + para corregir a mano.
- **Medallas**: de momento se marcan en el lanzador con un clic, y el líder sale en color en
  el overlay. Falta localizar en memoria dónde guarda el juego las medallas.

El progreso del locke se guarda en `datos/estado.json`, así que puedes cerrar y seguir otro día.

## Arte del equipo

Cada carta usa el arte oficial de su especie, que se descarga una vez a `tools/arte/`. Para usar
un fanart, déjalo en `fanart/` con el número de la Pokédex nacional: `fanart/658.png` para
Greninja. Admite `.png`, `.jpg` o `.webp`. La carpeta no se sube al repositorio. Usad fanart
con permiso de sus autores y acreditadlo en el stream.

## Carpetas

| Carpeta | Contenido | ¿En git? |
|---|---|---|
| `app/` | Lanzador (`main.py`), lectura del juego (`juego.py`), ajustes del UPR (`LockeSettings.java`) y páginas web | Sí |
| `assets/` | Fondo, marcos, logo, líderes y medallas del overlay | Sí |
| `index.html` | Overlay estático, la foto del diseño | Sí |
| `tools/` | Azahar, randomizador, caché de arte | No |
| `rom/`, `datos/`, `fanart/` | Tu ROM, la partida del locke y tus fanarts | No |

Prueba del descifrado de Pokémon: `py -3 app\test_juego.py`.

## Créditos

- Lectura de memoria: protocolo RPC de [Azahar](https://github.com/azahar-emu/azahar); direcciones y
  descifrado PK6 de [CitraRNG](https://github.com/Admiral-Fish/CitraRNG).
- Randomización: [Universal Pokemon Randomizer ZX](https://github.com/Ajarmar/universal-pokemon-randomizer-zx).
- Líderes, medallas, logo de Pokémon Y y arte oficial de los Pokémon: © Nintendo / Game Freak / The Pokémon Company.
- Fondo de Xerneas e Yveltal: wallpaper de fans encontrado en internet.
- Marcos, contenedores y corazón pixel art: generados con Adobe Firefly y retocados.
- Uso no comercial, para streams entre amigos.
