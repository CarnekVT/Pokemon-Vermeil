VISUAL 2.5D HD — MAPA DE PRUEBA Y ADAPTADORES

Configuración: Depuración > Campo > Visual 2.5D HD, o pbVisual25DMenu.
No se muestran ajustes 2.5D en Opciones del juego.
Perspectiva: clásica, inclinación 27 grados, zoom 100%, horizonte plano.

Prioridades persistentes editadas manualmente:
Data/Tilesets.rxdata, tileset 1 (NewBarkTown):
507-509 = 4; 515-517 = 3; 523-525 = 2; 531-533 = 1.
Data/Map077.rxdata: 132 colocaciones registradas en Maker Studio
(nativeProperties en @extended_layers). No son cambios temporales en RAM.
No se modificaron otros tilesets ni mapas.

Compatibilidad opcional: [016] Studio Bridges.rb.
Animated Props y Lighting Studio siguen siendo independientes: no se
modificaron sus scripts. Puentes con proyección absoluta y caché para
luces estáticas. Se puede desactivar cada adaptador desde Depuración >
Campo > 2.5D: adaptadores externos, para comparar imagen y rendimiento.

Para medir FPS: 2D / 2.5D sin adaptadores / con props / con luces /
ambos; mismo mapa, mismo reloj y misma cámara.
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
- Los scripts originales de Animated Props y Lighting Studio siguen intactos;
  las adaptaciones de Z / coordenadas viven dentro del Visual 2.5D.
- Copia previa preservada en backup/tileset-priorities-before-sky-reference-20261025.
- Sintaxis y FPS en la versión del usuario: todavía no ensayados ingame.
