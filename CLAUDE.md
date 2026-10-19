# Pokémon Ostinato: instrucciones para Claude

Lee primero `recursos/CONTEXTO_CLAUDE.txt`, que es el contexto completo del proyecto.

## Reglas que no se saltan
- **Prohibido abrir el juego** (Game.exe, modo debug, RPG Maker XP o pruebas con ventana) en el PC de David. Todo se comprueba leyendo los `.rxdata` con pkmn-devkit (`C:\Users\david.martinez\pkmn-devkit`), dibujando los mapas con código y con Ruby suelto. El juego lo prueba David.
- Antes de escribir mapas o `Tilesets.rxdata`, RPG Maker tiene que estar cerrado (`tasklist | findstr RPGXP`).
- Los plugins solo se leen de `Data/PluginScripts.rxdata`, que se compila sin abrir el juego. El script está en `recursos/tunel_partes3y4/` y la explicación en la sección 9 de CONTEXTO.
- Todo mapa nuevo necesita `SnapEdges = true` en `PBS/map_metadata.txt` **y** en `Data/map_metadata.dat` (es «lo del negro de los límites del mapa»).

## Túnel de la ruta 4 (mapas 15-18): paso y prioridad (hecho el 2026-10-16)
Los cuatro mapas son una imagen troceada: un tile por casilla, todo en la capa 0. Cada tile es único, así que cambiar su paso o su prioridad en el tileset solo afecta a esa casilla. El script es `recursos/tunel_prioridades/aplicar.rb` (comprueba antes que no se corta ningún camino ni queda un evento sin acceso).
- **Prioridad** (cómo tapa a Kaia): una casilla de la fila `y` con prioridad `p` tapa a Kaia mientras ella esté en la fila `y + p - 1` o más arriba. Kaia mide 64 px y solo asoma a la fila de encima de la suya, así que la parte de arriba de un arco va a **2** (tapa su cabeza cuando está debajo, y no cuando pasa por delante) y las patas del arco, en la misma fila que ella, a **1**.
  - Hecho: mapa 15 (10-13, 2) a 2; mapa 16 (16-19, 3) a 2 y (16, 4) y (19, 4) a 1; mapa 17 (40-41, 16) a 2. En el mapa 18 no hace falta: por la vía de la izquierda Kaia va por delante del andén.
  - Nunca se pone prioridad a una casilla que mezcla suelo y objeto: taparía a Kaia con el suelo también. Esas se bloquean (o habría que separar capas).
- **Paso**: bloqueado lo que era el dibujo de un objeto en una casilla pisable: el poste de la acera y los bidones del canal del 16 (y el agua de (7, 31-33)), el techo del autobús y los postes de abajo del puente del 17, los pies de las tuberías y el techo del vagón del 18.

## PENDIENTE
- **La escalera de salida del mapa 18** (x 36-39, arriba) todavía no lleva a ningún sitio. Saldrá a una ciudad que aún no está construida.
