# Pokémon Ostinato

Fangame de Pokémon dibujado a mano, sobre **Pokémon Essentials BES** (fork no
oficial de Essentials v16.2) corriendo en **MKXP-Z**.

La región se llama **Cadencia**. Cuando alguien se entiende bien con su Pokémon,
allí dicen que «hacen coro». Nadie sabe muy bien qué nombra esa palabra.

---

## Cómo se juega

Abre `Pokémon Essentials BES/Game.exe`.

## Cómo está montado

El motor guarda **todos los scripts dentro de `Data/Scripts.rxdata`**, en un
único archivo binario (Marshal de Ruby + zlib). No hay carpeta de scripts
sueltos: para editarlos hace falta RPG Maker XP o una herramienta que lea ese
formato.

Los scripts propios del juego van todos con el prefijo `Ostinato_` y se
insertan justo antes de `Main`, para que sus redefiniciones pisen a las del
motor:

| Script | Qué hace |
|---|---|
| `Ostinato_TitleScreen` | El menú del título, con los botones dibujados a mano |
| `Ostinato_Arranque` | Vídeo de marca, portada y el Diglett que asoma si no tocas nada |
| `Ostinato_Cinematica` | La cinemática de apertura al dar a «Nueva partida» |
| `Ostinato_Laboratorio` | La escena de la Profesora Arce |
| `Ostinato_Pantalla` | Ajusta el búfer al tamaño del monitor |

### Dos cosas que conviene saber antes de tocar nada

**El motor no reproduce vídeo.** `Game.exe` es MKXP-Z y no lleva enlazada
ninguna librería de códec. Todo lo que parece un vídeo son **secuencias de JPEG
más un mp3 aparte**, y el fotograma se elige por reloj (`Time.now`), no contando
vueltas del bucle: con cuatro minutos de narración, contar vueltas se
desincroniza del audio en cuanto el motor pierde un fotograma.

**El arte se hace a 1920x1080 y lo encoge el propio sprite** con
`zoom = Graphics.width / 1920.0`. La resolución nominal del motor es 682x384 y
`Ostinato_Pantalla` sube el búfer real al tamaño del monitor. Ojo: el script
`037_Sprite_Resizer` redefine `x=`, `y=`, `ox=` y `zoom_x=` multiplicando por el
factor de escala, pero **no toca `src_rect`**, que sigue yendo en píxeles del
bitmap.

## Estructura

```
Pokémon Essentials BES/     el juego
  Data/                     mapas, scripts y datos del motor
  Graphics/                 todo el arte
    Titles/                 portada, menú, cinemática y escena del laboratorio
  Audio/                    música y efectos
  PBS/                      datos en texto: Pokémon, movimientos, entrenadores
Overworlds/                 sprites de mapa
CREDITOS.md                 quién ha hecho cada cosa que no es propia
```

## Créditos

En **[CREDITOS.md](Pokémon%20Essentials%20BES/CREDITOS.md)** está la lista de
todo el material que no es propio y de quién lo hizo. Se actualiza cada vez que
se mete algo nuevo.

## Sobre la licencia

Este repositorio **no lleva licencia de código abierto a propósito**, y no puede
llevarla: contiene material de terceros —tiles, sprites y música de la saga
Pokémon y de la comunidad de fangames— cuyos derechos no son míos y que por
tanto no puedo relicenciar.

Lo que sí es mío es el arte dibujado a mano (portada, cinemática, personajes,
escenas) y el código de los scripts `Ostinato_`.

Pokémon es propiedad de Nintendo, Game Freak y The Pokémon Company. Esto es un
proyecto de aficionado, sin ánimo de lucro y sin relación con ellos.
