# Visual 2.5D Tools

Panel Maker Studio para asignar Volume ID por celda sin cambiar terrain tag,
priority, pasabilidad ni capas. Guarda metadata en
`Plugins/[VERMEIL] Visual 2.5D/volume_ids.json`.

1. Selecciona las celdas de un objeto conectado.
2. Abre `Mods > Visual 2.5D`.
3. Escribe un ID único, por ejemplo `casa_01`, y pulsa **Asignar**.
4. Usa el mismo ID para piezas del mismo objeto aunque usen `Mountains`,
   `Mode7Tag` o `HoneyTree`. Usa otro ID para cada objeto distinto.
5. El ID se guarda al pulsar **Asignar**. Recarga/reentra al mapa en juego.

El renderer usa el ID solo para decidir composición visual. Terrain tag sigue
siendo fuente de mecánicas y el valor de prioridad sigue siendo fuente de
orden de dibujo.

## Zoom progresivo

1. Escribe un ID de tramo y elige direccion.
2. Selecciona una celda y pulsa **Tomar inicio**.
3. Repite con **Tomar intermedio** y **Tomar final** siguiendo la direccion.
4. Define el zoom del punto intermedio. Inicio y final usan el zoom base actual.
5. Selecciona toda la zona transitable del tramo y pulsa **Guardar zona**.

El mismo perfil funciona en ambos sentidos. Al cruzarlo en sentido inverso, la
interpolacion tambien se recorre al reves. Los datos se guardan en
`Plugins/[VERMEIL] Visual 2.5D/progressive_zoom.json`.

## Zona de zoom fijo

1. Selecciona todas las celdas de la zona.
2. Escribe ID y zoom en **ZONA DE ZOOM FIJO**.
3. Pulsa **Guardar zona**.

El zoom se mantiene hasta salir. Si una zona fija y un tramo progresivo se
superponen, inicio/final del tramo usan el zoom fijo como base.
