# Créditos de Pokémon Ostinato

Registro de todo el material que no es propio y de quién lo hizo. Se actualiza
cada vez que se mete algo nuevo en el proyecto, para que al final no haya que
reconstruirlo de memoria.

Formato de cada entrada: qué es, dónde vive en el proyecto, y quién lo hizo.

---

## Tilesets

### Tileset exterior estilo Gen 5

Recopilación comunitaria de tiles de exteriores: árboles, caminos, agua,
acantilados, puentes, edificios, Centros Pokémon, tiendas y gimnasios.

**Autores:**

- Kyle-Dove
- Heavy-Metal-Lover *(Sailorvicious)*
- WesleyFG
- Dewitty *(Iametrine)*
- Zetavares852
- XDinky
- Newtiteuf
- Alucus
- Erma96
- Hydrargirium
- Poison-Master
- Thedeadheroalistair
- Shutwig
- Asdsimone
- Xxdevil *(Kaess-desu)*
- Steinnaples
- Hek-el-grande
- sylver1984
- NikNak93
- TeaAddiction
- Cuddlesthefatcat
- Magiscarf
- Gigatom
- The-Red-eX
- ChaoticCherryCake

**Instalado el 2026-09-17** como el tileset «Public Tiles» (`Graphics/Tilesets/PublicTiles.png`,
índice 24 en `Data/Tilesets.rxdata`). La hoja original no es un tileset de RPG Maker: es un
mural de referencia con cientos de objetos sueltos a distintos tamaños, con barcos, camiones y
un avión mezclados en medio (esos se han dejado fuera, no son terreno pintable). Se localizó
cada objeto automáticamente y se recompuso en una columna de 256 px con la que sí entiende el
motor. Limitaciones a tener en cuenta:
- **No son autotiles de verdad.** La hoja no trae los bordes de transición (solo la baldosa
  «llena» de cada terreno), así que la hierba, el agua y los caminos de este tileset van como
  tiles sueltos para colocar a mano, sin que se fundan solas con la de al lado.
  Para agua/hierba con transición semiautomática hay que seguir usando el tileset de Anil o el
  «Outside» que ya trae la base.
- **La intransitabilidad es una suposición mía**, no dato real: todo lo más alto que ancho (un
  árbol, un edificio) se marcó impasable, y el resto pasable. Conviene repasarlo a mano en el
  editor antes de usarlo en un mapa real.
- Los árboles y edificios llevan ya la prioridad puesta para que el jugador pueda pasar por
  delante y por detrás (la fila de los pies pisa normal, el resto tapa como un árbol de verdad).

### Tilesets y autotiles de Pokémon Armonía (Beta 3.2)

22 tilesets completos (bosque, nieve, jungla, sabana, ciudades, gimnasios, interiores
temáticos, pirámides, cuevas, valle...) y 8 autotiles de arbustos, elegidos a mano de entre
los 41 tilesets y 75 autotiles que trae el juego — se ha dejado fuera lo que era una copia
tal cual de los gráficos de base de Essentials (esos ya estaban en el proyecto) y algún
tileset con marcas de depuración visibles.

- **En el proyecto:** `Graphics/Tilesets/` (`bosque.png`, `nieve.png`, `Jungla.png`,
  `sabana.png`, `primeraciudadgrande.png`, `tilesciudadnueva.png`, `TileCiudadBicho.png`,
  `terrenonaveast.png`, `Gimnasios.PNG`, `gimnasioagua.png`, `balneario.png`,
  `casacampeona.png`, `museo.png`, `teatroflorent.png`, `NytiaLab.png`, `casasegipto.png`,
  `casaelefantes.png`, `cuevas.png`, `tilesetscascada.png`, `ciudadFlorent.png`,
  `tileegipto.png`, `Valle_Kalmer.png`) y `Graphics/Autotiles/` (`hierba_decorativa.png`,
  `Jungla.png`, `forest_grass.png`, `valley_grass.png`, `grassfantasma.png`,
  `magicforest_grass.png`, `hierba3.png`, `grass.png` — llevan nombre de «grass» pero son
  arbustos: matas redondeadas, no hierba plana)
- **Registrados** como tilesets 26-47 de `Data/Tilesets.rxdata`, clonados enteros (passages,
  priorities, terrain_tags, autotile_names) del propio `Tilesets.rxdata` de Armonía, así que
  la intransitabilidad y las prioridades sí son las reales del juego, no una suposición.
- Los 8 autotiles de arbustos están copiados como archivo, pero **para poder pintarlos en un
  mapa hace falta añadirlos a la lista de autotiles de algún tileset concreto** (cada tileset
  solo tiene 7 huecos de autotile); decir a cuál para conectarlos.
- **Autor:** equipo de **Pokémon Armonía** — @Sir_Bohemian (interfaces y tiles, el que
  arregla estos tilesets en concreto), @Miguel_Horo (gráficos), con @Exio, @Lauz y @Javigarni.
  Los tiles base sueltos con los que están compuestos son el mismo fondo comunitario de la
  entrada de arriba (Kyle-Dove y compañía), más estos otros del propio crédito de Armonía:
  Midnitez-REMIX, Phyromatical, kaliser, Matwert, tyranitardark, Clara-Wah, PeekyChew,
  RBRNNova, AdalKroofs, Thurpok.

### Tilesets y autotiles de Pokémon Anil V4.13

13 hojas de tileset (exteriores, interiores, cuevas) y 28 autotiles, incluidos
los de agua animada.

- **En el proyecto:** `Graphics/Tilesets/` y `Graphics/Autotiles/`
- **Autor:** equipo de **Pokémon Anil** (v4.13)

> Pendiente: pedir permiso al equipo de Anil. Parte del material son tiles
> oficiales de 5ª generación reeditados y parte es trabajo propio suyo.
> Falta además averiguar los nombres concretos del equipo.

### Distribución de una casa pequeña genérica

Igual que la de Kaia: la disposición de muebles está calcada de Pokémon Anil V4.13, esta vez
la SEGUNDA pareja sala+habitación de su mapa «Casa» (id 28) — el mismo diseño de casa que usa
el juego para otros vecinos del pueblo, con el mobiliario en espejo respecto al de Kaia.

- **En el proyecto:** `Data/Map004.rxdata` («Casa Genérica - Planta Baja») y
  `Data/Map005.rxdata` («Casa Genérica - Piso Superior»)
- **Origen:** Pokémon Anil V4.13, `Data/Map028.rxdata`
- **Autor:** equipo de Pokémon Anil
- Sin puerta de salida conectada todavía: falta decidir a qué casa del pueblo pertenece antes
  de saber a qué punto exterior debe llevar.

### Distribución de las habitaciones de la casa de Kaia

No es solo el tileset: la disposición de los muebles (cocina, mesa, sofá,
cama, escritorio, cómoda, escaleras) de **Sala Mama** y **Habitación Kaia**
está calcada de una de las casas genéricas de Pokémon Anil V4.13 (su mapa
«Casa», id 28), no dibujada desde cero. Se aprovechó también el hueco de la
escalera para conectar las dos plantas.

- **En el proyecto:** `Data/Map003.rxdata` (Sala Mama) y `Data/Map043.rxdata`
  (Habitación Kaia)
- **Origen:** Pokémon Anil V4.13, `Data/Map028.rxdata`
- **Autor:** equipo de **Pokémon Anil** (mismo pendiente de permiso que el
  tileset)

---

## Sprites

### Entrenadores genéricos, estilo Gen 5

52 sprites de combate de clases genéricas: montañero, pescadora, karateka,
científico, médium, nadadores, parejas, reclutas, etc.

- **En el proyecto:** `Graphics/Battlers/Trainers/trainer<CLASE>.png`
- **Origen:** Pokémon Anil V4.13, `Graphics/Trainers/`
- **Autor:** sprites oficiales de 5ª generación (Game Freak), recopilados y
  renombrados por el equipo de Pokémon Anil

### Mudkip animado

Sprite frontal animado de 139 fotogramas, recortado y reescalado para la escena
del laboratorio.

- **En el proyecto:** `Graphics/Titles/EscMudkip.png`
- **Origen:** Pokémon Anil V4.13, `Graphics/Pokemon/Front/MUDKIP.png`
- **Autor:** por confirmar. Los sprites animados estilo Gen 5 suelen venir de
  proyectos comunitarios de recreación; hay que localizar cuál antes de
  publicar.

### Plataforma circular

La base elíptica bajo Mudkip, recoloreada a tono neutro y con sombra añadida.

- **En el proyecto:** `Graphics/Titles/EscBase.png`
- **Origen:** Pokémon Essentials, `Graphics/Pictures/introbase.png`

---

## Motor

### Pokémon Essentials

Base del juego.

- **Autores:** Flameguru, Poccil *(Peter O.)* y Maruno

### Pokémon Essentials BES

Fork no oficial de Essentials v16.2 y sucesor de la llamada «Base de Pira».
Es la base concreta sobre la que está montado Ostinato. Lo que sigue viene del
`Créditos.txt` que trae la propia base.

**Recopilación:** Pira · Clara

**PBS:** Alexandrite · Clara · Jaizu · Nero

**Scripts:** WolfPP · Alberto · Selfish · Rot8er_ConeX · Mybusiness ·
BlackOutG5 · Telemetius · rigbycwts · MotoxChmpn10 · Crystal Noel · Zerokid ·
Clara · Slaqueen / Ele-nya · Jonas930 · derFischae · Marcello · Zumi ·
Ice Cream Sand Witch · Amethyst · Jan · Sardines · Inuki · pKa · Deo · FL ·
Luka SJ · Bezier · FiaPlay · Stochastic · bo4p5687 · Skyflyer ·
DerxwnaKapsyla · josmancia · Lucifer666

**Sprites y otros gráficos:** Smogon Sprite Project · leParagon · N-Kin ·
fishbowlsoul90 · MrDollSteak · BlackWhiteRobin · Wobblebuns · princessofmusic ·
Z-nogyroP · MyMarshlands · MBCMechachu · Megax Rocker · JaegerLucciano23 ·
academico95 · KajiAtsui · Chaos Rush · BlackstarG5 · mangamanga · HeXeR ·
Tetra · goranthegreat · Trev · xiechayghe · Lucidious89 · lichenprincess ·
Caruban · jinxed · Alfpixel · Ezerart · SrGio · SageDeoxys · DarkusShadow ·
LarryTurbo · Princess-Phoenix · Kidkatt · Zender1752

**Animaciones:** Pokémon Reborn Team · Gen 8 Animation Project, dirigido por
StCooler con DarrylBD99, WolfPP, ardicoozer y riddlemeree · Gen 9 Animation
Project, dirigido por KRLW890 y Nut0066 con Toxillian, QuahogTheCreator, Lcorp
y Shashu-Greninja · josmancia · julieharu · sakDayne

**Música y sonidos:** ENLS · BellBlitzKing

**Otros:** MasterYuri

---

## Pokémon

Pokémon es propiedad de **Nintendo**, **Game Freak** y **The Pokémon Company**.
Este es un proyecto de aficionado, sin ánimo de lucro y sin relación con ellos.

Si falta alguien, avisad y se añade.

---

## Propio

Todo lo que sigue está dibujado o compuesto por el autor del juego y no
necesita permiso de nadie:

- La portada y el logotipo de POKÉMON OSTINATO
- La cinemática de apertura completa (los dos actos)
- La Profesora Arce, Kaia y Lira
- El fondo del laboratorio y el contenedor de diálogo de pergamino
- Los botones del menú del título y el Diglett
- La pantalla de auriculares
