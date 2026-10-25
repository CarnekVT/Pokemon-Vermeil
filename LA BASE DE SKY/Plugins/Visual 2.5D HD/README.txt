VISUAL 2.5D HD — MAPA DE PRUEBA Y ADAPTADORES

Configuración: Depuración > Campo > Visual 2.5D HD, o pbVisual25DMenu.
No se muestran ajustes 2.5D en Opciones del juego.
Perspectiva predeterminada: Gen 5 (plano afín sin deformación por fila),
inclinación 45 grados (compresión coseno real), zoom 100%, horizonte plano.

Prioridades persistentes editadas manualmente:
Data/Tilesets.rxdata, tileset 1 (NewBarkTown):
507-509 = 4; 515-517 = 3; 523-525 = 2; 531-533 = 1.
Data/Map077.rxdata: 132 colocaciones registradas en Maker Studio
(nativeProperties en @extended_layers). No son cambios temporales en RAM.
No se modificaron otros tilesets ni mapas.

Compatibilidad opcional: [016] Studio Bridges.rb.
Animated Props detecta Visual25D en tiempo de ejecución: cuando está activo,
el plugin principal deja a Visual25D calcular la posición UNA sola vez, sin
pasar antes por coordenadas 2D. Si está ausente o desactivado, utiliza 2D
vanilla. Lighting Studio no se ha modificado. El puente mantiene proyección
absoluta y caché para luces estáticas. Se puede desactivar cada adaptador desde Depuración >
Campo > 2.5D: adaptadores externos, para comparar imagen y rendimiento.

Para medir FPS: activar la sonda de rendimiento desde Depuración > Campo.
El registro ahora muestra tilemapMs/f, propMs/f, propGeom/f y propN
además de la rejilla y capas MakerStudio. Comparar 2D, 2.5D con y sin
adaptadores en el mismo mapa y con el mismo reloj.
El resultado aún requiere pruebas visuales y de FPS dentro del juego.

Puntos de recuperación:
backup/pre-visual25d-20261023
backup/visual25d-before-sky-reset-20261023

REFERENCIA VISUAL SKY / REVISION MANUAL DE TILESETS (2026-10-25)
- Archivo de referencia recibido: Tilesets.rxdata de Sky con nombres Exterior,
  Interior, Mazmorra cueva, Ruinas y Estadio. NO coincide por IDs con Vermeil.
  Se comparó el criterio de bandas verticales, sin copiar índices a ciegas.
- Data/Tilesets.rxdata del juego sigue en formato Ruby Marshal / RPG::Table.
  Revisados gráficos 001-NewBarkTown.png (256x2816) y nsaeqMZ.png
  (256x27168); los IDs siguen el orden de 8 columnas de 32 px.
- Mantener las prioridades existentes más altas cuando forman tejados/copas.
- NewBarkTown: revisadas bandas de edificaciones filas del gráfico 23-32
  columnas 0-5; 34-43 columnas 0-6; 60-68 columnas 1-7. La nueva
  secuencia por zonas usa techos 4, cuerpos intermedios 3/2 y bases 1.
- BW Tiles: banda vertical que ya tenía nivel 4 en filas 106-107,
  columnas 0-1, se completó con prioridades 3/2/1 en filas 108-110.
- Resultado conjunto de esta pasada: 126 prioridades adicionales
  (120 NewBarkTown; 6 BW Tiles). La corrección anterior del conjunto
  NewBarkTown 507-533 (4/3/2/1) continúa conservada.
- Las demás estructuras extensas de BW Tiles aún NO están clasificadas
  íntegramente; hacerlas sin identificar sus celdas podría levantar
  terreno plano. Este paso no debe presentarse como una revisión total.
- El juego y Maker Studio leen el archivo persistente editado al abrirse.
- Los datos guardados por mapa también pueden incluir nativeProperties,
  y su valor pintado puede prevalecer para ciertas capas.
- Actualización 2026-10-25: LBDS Animated Props sí incorpora la detección
  condicional para evitar doble posicionamiento y doble coste de geometría.
  Lighting Studio se conserva intacto. La geometría opcional del 2.5D
  continúa en [016] Studio Bridges.rb.
- Copia previa preservada en backup/tileset-priorities-before-sky-reference-20261025.
- Sintaxis y FPS en la versión del usuario: todavía no ensayados ingame.

CONDICIONAL DE ANIMATED PROPS / POSICIONAMIENTO (ACTUAL)
Un placement puede usar visual25dMode: "surface" para animaciones del suelo,
"billboard" para objetos verticales, o "auto" (predeterminado) en su JSON.
El adaptador no modifica x/y del placement, colisiones ni datos persistentes.
La transición 2D/2.5D restaura zoom y taper del sprite. Las animaciones solo
actualizan src_rect si la cámara no ha cambiado.
El FPS real de 110 → 30/40 comunicado por el usuario aún necesita medición
ingame; los tests Ruby validan geometría y cambios de modo, no tiempos de GPU.
