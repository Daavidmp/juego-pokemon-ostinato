# Pokémon Ostinato

Fangame de Pokémon dibujado a mano, sobre **La Base de Sky** (Pokémon Essentials
v21.1) corriendo en **MKXP-Z**.

La región se llama **Cadencia**. Cuando alguien se entiende bien con su Pokémon,
allí dicen que «hacen coro». Nadie sabe muy bien qué nombra esa palabra.

---

## Cómo se juega

Abre `Pokémon Ostinato/Game.exe`. Está pensado para pantalla completa.

Para editar mapas y eventos, abre `Pokémon Ostinato/Game.rxproj` con RPG Maker XP.

## Cómo está montado

Los scripts propios del juego son un plugin de Essentials, en texto, en
`Pokémon Ostinato/Plugins/Ostinato/`:

| Plugin | Qué hace |
|---|---|
| `001_Compatibilidad` | Lo que el juego necesitaba de Essentials BES: pantalla 682x384, menú del título por `MenuHandlers`, música en mp3 |
| `002_Arranque` | Vídeo de marca, portada y el Diglett que asoma si no tocas nada |
| `003_Titulo` | El menú del título, con los botones dibujados a mano |
| `004_Cinematica` | La cinemática de apertura al dar a «Nueva partida» |
| `005_Laboratorio` | La presentación de la Profesora Arce |
| `006_Prologo` | El cuadro de diálogo y el prólogo: despertar, cocina, telediario, Lira en la puerta, laboratorio y la fuga de los tres iniciales |
| `007_Farolas` | Las farolas de Villa Bambalina, que se encienden al caer la noche |
| `008_Pantallas512` | Centra las pantallas de menú y los combates de Sky, que son de 512x384 |

Al arrancar en modo depuración, Essentials recompila los plugins en
`Data/PluginScripts.rxdata`, que es lo que lee el juego normal: después de tocar
un plugin hay que arrancar una vez en depuración y subir ese archivo también.

### Cosas que conviene saber antes de tocar nada

**El motor no reproduce vídeo.** Todo lo que parece un vídeo son **secuencias de
JPEG más el audio aparte**, y el fotograma se elige por reloj, no contando
vueltas del bucle.

**El arte se hace a 1920x1080.** La resolución del juego es 682x384 (16:9). Las
escenas propias a pantalla completa suben la resolución a 1920x1080 mientras
duran (`OstinatoHD`); el mapa y los menús se escalan por un número entero y se
suavizan solo en el último tramo. **No activar `enableHires`** en `mkxp.json`:
con él, este mkxp dibuja el texto de Essentials con una fuente de sustitución.
Y `fixedAspectRatio` va en `false` a propósito (está explicado en el archivo).

**Las pantallas de Sky son de 512x384.** Mochila, equipo, Pokédex, combates y
demás se muestran centradas con bandas negras a los lados
(`008_Pantallas512`); el mapa y las escenas propias ocupan toda la pantalla.

**Los interruptores 39-50 los reserva La Base de Sky.** Los del prólogo son el
101-104; los del guion van numerados como en el guion más 50 (la fuga es el 72
y el 73, la salida del pueblo el 78).

**Las pruebas automáticas** están en `Plugins/ZZ_PruebaMigracion/` y no hacen
nada salvo que exista su archivo disparador (`PRUEBA_MIGRACION.txt`,
`HERRAMIENTA.rb` o `DIAGNOSTICO.txt`) en la carpeta del juego.

## Estructura

```
Pokémon Ostinato/           el juego
  Plugins/Ostinato/         los scripts propios
  Data/                     mapas y datos del motor
  Graphics/                 todo el arte
    Titles/                 portada, menú, cinemática, escenas y diálogos
  Audio/                    música y efectos
  PBS/                      datos en texto: Pokémon, movimientos, entrenadores
Overworlds/                 sprites de mapa
recursos/                   guiones, piezas de mapas y herramientas
```

El juego empezó en Essentials BES y se pasó a La Base de Sky el 29 de septiembre
de 2026; el proyecto antiguo sigue en el historial de git, y
`recursos/migracion/` tiene los scripts con los que se hizo el paso.

## Créditos

En **[CREDITOS.md](Pokémon%20Ostinato/CREDITOS.md)** está la lista de todo el
material que no es propio y de quién lo hizo. Se actualiza cada vez que se mete
algo nuevo.

## Sobre la licencia

Este repositorio **no lleva licencia de código abierto a propósito**, y no puede
llevarla: contiene material de terceros —tiles, sprites y música de la saga
Pokémon y de la comunidad de fangames— cuyos derechos no son míos y que por
tanto no puedo relicenciar.

Lo que sí es mío es el arte dibujado a mano (portada, cinemática, personajes,
escenas) y el código de los plugins de Ostinato.

Pokémon es propiedad de Nintendo, Game Freak y The Pokémon Company. Esto es un
proyecto de aficionado, sin ánimo de lucro y sin relación con ellos.
