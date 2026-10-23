# Mega Pokelocke Y

App para jugar un Nuzlocke de Pokémon Y en el emulador de 3DS Azahar con el layout del stream
(1920×1080): biblioteca de juegos, randomizador, pantallas colocadas en su sitio y seguimiento del locke.

![Maqueta](maqueta.png)

Todo vive dentro de esta carpeta. No se instala nada en el PC: Azahar y el randomizador
se descargan en versión portable dentro de `tools/`.

## Requisitos

- Windows. El randomizador necesita un JDK de Java 11 o superior (un JRE no vale): se usa el primero que encuentre en
  `JAVA_HOME`, en `%USERPROFILE%\.jdks`, en `tools\java` o en el `PATH`. Si no hay ninguno, la app
  descarga sola un Java 17 portable (Temurin) en `tools\java` al pulsar **Continuar**.
- Tu ROM de Pokémon Y **descifrada** (`.3ds`, `.cci`, `.cxi` o `.cia`), esté donde esté. Un `.cia`
  se convierte solo a `.cci` con makerom (se descarga en `tools/makerom`) y se guarda en
  `datos/juegos/<id>/rom.cci`, porque el randomizador no abre `.cia`. Un `.cia` **cifrado** no sirve:
  descífralo antes en la 3DS con GodMode9.

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
5. Mientras juegas, corrige el locke con el teclado, sin salir del juego:
   **F7** quita una vida, **F8** añade una, **F9** marca la siguiente medalla y **Mayús+F9**
   desmarca la última. Los atajos solo están activos con un juego abierto.
   - **Vial** (al lado de las vidas): **E** cura a todo el equipo vivo (PS, estado y PP). Los
     debilitados no reviven. Tiene una sola carga: se pone gris al usarlo y se recarga solo cuando te
     curas en un Centro Pokémon (o a mano con **Mayús+E**). La E solo se captura con la ventana del
     juego delante (Azahar no la usa; la V es su botón de encendido). Durante un combate el juego usa
     una copia del equipo, así que el efecto se nota al terminar la batalla.
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

## Usar Citra en vez de Azahar

Azahar no abre ROMs cuya cabecera dice «cifrada» (error 8 en su registro). Un Citra antiguo (probado con
Nightly 1920) sí, y Pokelocke lo usa si se pone en el sitio de Azahar:

1. Copia la carpeta de Citra a `tools\azahar\citra-1920\` (y mueve fuera la de Azahar).
2. Compila el lanzador como `azahar.exe` junto a `citra-qt.exe`:
   `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:winexe /out:azahar.exe app\citra\lanzador.cs`

El lanzador quita el `-f` que este Citra no entiende, corrige los ajustes que Pokelocke escribe para Azahar,
pinta el juego en una ventana sin bordes por debajo del layout (la pantalla completa de Citra lo tapa) y con
**Alt+Q** cambia a ventana normal. Este Citra habla el protocolo RPC 1 (lecturas de 32 bytes): Pokelocke lo
detecta solo.

## Qué se actualiza solo

- **Equipo**: se lee de la memoria del juego cada segundo, mediante el servidor RPC de Azahar,
  que la app activa. Los huecos vacíos salen en negro.
- **Vidas**: cada Pokémon que llega a 0 PS resta una vida, una sola vez aunque luego lo revivas.
- **Medallas**: de momento se marcan con F9 (Mayús+F9 para desmarcar). Falta localizar en memoria
  dónde guarda el juego las medallas.

## Arte del equipo

Cada carta usa el arte oficial de su especie, que se descarga una vez a `tools/arte/`. Para usar
un fanart, déjalo en `fanart/` con el número de la Pokédex nacional (`fanart/658.png` para
Greninja) o pégalo, con cualquier nombre, dentro de la carpeta de ese Pokémon (`fanart/658 Greninja/`).
Hay una carpeta para cada Pokémon de la Pokédex de Kalos; si tiene varias imágenes, se usa la primera
por orden alfabético. Admite `.png`, `.jpg` o `.webp`. La carpeta no se sube al repositorio. Usad fanart
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
- Pikachu corriendo del modal de carga: sprite de Pokémon Mystery Dungeon (Chunsoft), recopilado por [PMDCollab SpriteCollab](https://github.com/PMDCollab/SpriteCollab).
- Líderes, medallas, logo de Pokémon Y y arte oficial de los Pokémon: © Nintendo / Game Freak / The Pokémon Company.
- Fondo de Xerneas e Yveltal: wallpaper de fans encontrado en internet.
- Marcos, contenedores y corazón pixel art: generados con Adobe Firefly y retocados.
- Uso no comercial, para streams entre amigos.
