# Mega Pokelocke Y

App para jugar un Nuzlocke de Pokémon Y en el emulador de 3DS Azahar con el layout del stream
(1920×1080): biblioteca de juegos, randomizador, pantallas colocadas en su sitio y seguimiento del locke.

![Maqueta](maqueta.png)

Todo vive dentro de esta carpeta. No se instala nada en el PC: Azahar y el randomizador
se descargan en versión portable dentro de `tools/`.

## Requisitos

- Windows con Java 11 o superior. Se usa el primero que encuentre en `JAVA_HOME`, en
  `%USERPROFILE%\.jdks` o en el `PATH`.
- Tu ROM de Pokémon Y **descifrada** (`.3ds`, `.cci`, `.cxi` o `.cia`), esté donde esté.

## Uso

1. Abre **`Pokelocke.exe`**. Se abre la biblioteca de juegos en una ventana propia (Edge en
   modo aplicación, con su perfil dentro de `tools/`).
2. **+ Añadir juego** abre el explorador de archivos: elige tu ROM.
3. La primera vez que juegas una ROM sale la pantalla de preparación: vidas (25 por defecto)
   y randomización. Pulsa **Continuar**.
   - Si faltan Azahar o el randomizador, se descargan solos en `tools/`.
   - El juego randomizado se guarda como mod (LayeredFS) en `datos/juegos/<id>/`. La ROM original no se toca.
   - El registro de la randomización queda en `datos/juegos/<id>/randomizacion.log`.
4. Se abre Azahar a pantalla completa con **las dos pantallas ya colocadas en los huecos del
   layout**, y el layout encima. El layout no coge el foco: el teclado va al juego y la pantalla
   táctil se puede pulsar a través del hueco. Al cerrar Azahar se cierra el layout.
5. Mientras juegas, la ventana de la biblioteca muestra el panel de la partida, con las vidas
   (− y + para corregir) y las medallas (clic para marcar).
6. Para el stream, captura la pantalla completa en OBS. Si prefieres montar tú las capturas, el
   overlay está en `http://localhost:8765/overlay` (fuente de navegador, 1920×1080) y los huecos son:

| Pantalla | Tamaño | Posición |
|---|---|---|
| Superior (5:3) | 1000×600 | x=72, y=244 |
| Inferior (4:3) | 680×510 | x=1168, y=530 |

Cada juego de la biblioteca guarda su propio locke en `datos/biblioteca.json`. **Nuevo locke**
vuelve a pedir vidas y randomización.

Si el monitor no es de 1920×1080, el layout se escala y se centra, y las pantallas de Azahar se
colocan a la misma escala.

## Qué se actualiza solo

- **Equipo**: se lee de la memoria del juego cada segundo, mediante el servidor RPC de Azahar,
  que la app activa. Los huecos vacíos salen en negro.
- **Vidas**: cada Pokémon que llega a 0 PS resta una vida, una sola vez aunque luego lo revivas.
- **Medallas**: de momento se marcan a mano en el panel de la partida. Falta localizar en memoria
  dónde guarda el juego las medallas.

## Arte del equipo

Cada carta usa el arte oficial de su especie, que se descarga una vez a `tools/arte/`. Para usar
un fanart, déjalo en `fanart/` con el número de la Pokédex nacional: `fanart/658.png` para
Greninja. Admite `.png`, `.jpg` o `.webp`. La carpeta no se sube al repositorio. Usad fanart
con permiso de sus autores y acreditadlo en el stream.

## Carpetas

| Carpeta | Contenido | ¿En git? |
|---|---|---|
| `Pokelocke.exe` | La app. `app/construir.bat` la vuelve a crear con PyInstaller (en `tools/build-venv`). `Pokelocke.bat` arranca lo mismo con Python | Sí |
| `app/` | Servidor y capa (`main.py`), lectura del juego (`juego.py`), ajustes del UPR (`LockeSettings.java`) y páginas web | Sí |
| `assets/` | Fondo, marcos, logo, líderes y medallas del overlay | Sí |
| `index.html` | Overlay estático, la foto del diseño | Sí |
| `tools/` | Azahar, randomizador, perfiles de Edge, caché de arte, entorno de construcción | No |
| `datos/`, `fanart/` | Biblioteca, lockes, mods randomizados y tus fanarts | No |

Prueba del descifrado de Pokémon: `py -3 app\test_juego.py`.

## Créditos

- Lectura de memoria: protocolo RPC de [Azahar](https://github.com/azahar-emu/azahar); direcciones y
  descifrado PK6 de [CitraRNG](https://github.com/Admiral-Fish/CitraRNG).
- Randomización: [Universal Pokemon Randomizer ZX](https://github.com/Ajarmar/universal-pokemon-randomizer-zx).
- Líderes, medallas, logo de Pokémon Y y arte oficial de los Pokémon: © Nintendo / Game Freak / The Pokémon Company.
- Fondo de Xerneas e Yveltal: wallpaper de fans encontrado en internet.
- Marcos, contenedores y corazón pixel art: generados con Adobe Firefly y retocados.
- Uso no comercial, para streams entre amigos.
