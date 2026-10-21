# Overlay Mega Pokelocke Y

Overlay de stream (1920×1080) para un Nuzlocke de Pokémon Y jugado en emulador de 3DS.

![Maqueta](maqueta.png)

## Contenido

- `index.html`: el overlay, listo para usar como fuente de navegador en OBS.
- `assets/`: fondo, marcos de las pantallas, logo, líderes y medallas.
- `maqueta.png`: captura del overlay.

## Uso en OBS

1. Añade una **Fuente de navegador** → *Archivo local* → `index.html`, a 1920×1080.
2. Pon las capturas del emulador **por encima** del overlay, en estos huecos:

| Pantalla | Tamaño | Posición |
|---|---|---|
| Superior (5:3) | 1000×600 | x=72, y=244 |
| Inferior (4:3) | 680×510 | x=1168, y=530 |

## Equipo

Las cartas del equipo cargan `assets/equipo-1.jpg` … `assets/equipo-6.jpg`.
Esos archivos **no se suben al repositorio** (están en `.gitignore`): pon ahí los
fanarts que vayáis a usar, con permiso de sus autores, y acreditadlos en el stream.
Sin imagen, la carta se ve vacía con su mote.

## Estado fijo

Este `index.html` es una foto del diseño: 25 vidas, 3 medallas y los motes de ejemplo.
Para cambiarlos hay que editar el HTML (la versión editable está en el lienzo de diseño).

## Créditos

- Líderes, medallas y logo de Pokémon Y: arte oficial © Nintendo / Game Freak / The Pokémon Company.
- Fondo de Xerneas e Yveltal: wallpaper de fans encontrado en internet.
- Marcos, contenedores y corazón pixel art: generados con Adobe Firefly y retocados.
- Uso no comercial, para streams entre amigos.
