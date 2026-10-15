# Pokémon Ostinato: instrucciones para Claude

Lee primero `recursos/CONTEXTO_CLAUDE.txt`, que es el contexto completo del proyecto.

## Reglas que no se saltan
- **Prohibido abrir el juego** (Game.exe, modo debug, RPG Maker XP o pruebas con ventana) en el PC de David. Todo se comprueba leyendo los `.rxdata` con pkmn-devkit (`C:\Users\david.martinez\pkmn-devkit`), dibujando los mapas con código y con Ruby suelto. El juego lo prueba David.
- Antes de escribir mapas o `Tilesets.rxdata`, RPG Maker tiene que estar cerrado (`tasklist | findstr RPGXP`).
- Los plugins solo se leen de `Data/PluginScripts.rxdata`, que se compila sin abrir el juego. El script está en `recursos/tunel_partes3y4/` y la explicación en la sección 9 de CONTEXTO.
- Todo mapa nuevo necesita `SnapEdges = true` en `PBS/map_metadata.txt` **y** en `Data/map_metadata.dat` (es «lo del negro de los límites del mapa»).

## PENDIENTE (dejado el 2026-10-15): prioridades del túnel de la ruta 4 (mapas 15, 16, 17 y 18)
Los cuatro mapas son una imagen troceada: un tile por casilla, **todo en la capa 0 y con prioridad 0**. Eso hace que Kaia se dibuje siempre por encima de todo. Falta:

1. **Arcos y bocas de túnel.** La parte de arriba del arco tiene que tapar a Kaia cuando se mete por debajo. Esas casillas son pared, así que basta con poner `priorities[tile] = 1` en su tileset.
   - El tile de una casilla es `384 + y*ancho + x` en los tilesets 48 (mapa 17) y 49 (mapa 18).
   - En el tileset 39, el mapa 15 empieza en 384 y el 16 en 1416 (24 de ancho).

   | Mapa | Sitio | Casillas con prioridad 1 | Se pasa por debajo |
   |---|---|---|---|
   | 15 | boca de arriba | x 10-13, y 1-2 | fila 3 |
   | 16 | arco de la carretera | x 16-19, y 2-3 (y quizá las patas (16,4) y (19,4)) | (17-18, 4) |
   | 17 | boca de la vía (derecha) | x 40-41, y 13-16 | (39-41, 17-19) |
   | 18 | entrada de la vía (izquierda) | quizá el canto (0-1, 15): no es arco, decidir mirándolo | (0-1, 16-18) |

   - En el mapa 17, (39,15) y (39,16) mezclan suelo y arco. No pueden llevar prioridad sin separar capas, así que se dejan así.
   - Comprobar con recortes de `m<N>.png`, con la rejilla y las coordenadas pintadas encima.
2. **Objetos altos.** Al hacer las partes 3 y 4 se bloqueó toda la superficie dibujada de cada objeto, incluida la parte de arriba. Kaia nunca se pone «detrás» de un objeto, así que no hace falta prioridad. Hay que revisarlo también en los mapas 15 y 16, que se hicieron en otra sesión. Si en algún sitio Kaia puede pisar una casilla donde el dibujo de un objeto sube por encima de ella, hay dos opciones:
   - separar ese tile en dos capas: capa 0 con el suelo limpio y capa 1 con el dibujo del objeto, con prioridad 1;
   - o bloquear la casilla.
3. **La escalera de salida del mapa 18** (x 36-39, arriba) todavía no lleva a ningún sitio. Saldrá a una ciudad que aún no está construida.

Cuando esté hecho, borra esta sección PENDIENTE.
