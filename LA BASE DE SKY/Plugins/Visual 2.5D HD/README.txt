VISUAL 2.5D HD — PERSPECTIVA PLANA / PRIORIDADES PERSISTENTES
================================================================
Motor base Visual 2.5D HD v3.3.0 para Pokémon Essentials 21.1.

CONFIGURACIÓN FUERA DE OPCIONES
- Depuración > Campo > Visual 2.5D HD
- Script alternativo: pbVisual25DMenu
- Inclinación, zoom, modelo, FOV y altura vertical.
- No añade ajustes al menú de Opciones del juego.
- Preset plano: clásico, inclinación 27°, zoom 100%, horizonte 0;
  GROUND_SLICES=1, sin neblina/viñeta.
- Las partidas previas pueden mantener otros valores de cámara.
  Usar Restaurar configuración base en el menú exclusivo.

EDICIONES REALES DE PRIORIDADES
- Data/Tilesets.rxdata, tileset ID 1 (NewBarkTown):
    ID 507-509: 4
    ID 515-517: 3 (era 1)
    ID 523-525: 2 (era 0)
    ID 531-533: 1 (era 0)
- Data/Map077.rxdata (Test 2.5d): 132 colocaciones actualizadas
  con priority en @extended_layers/nativeProperties de Maker Studio.
- Estos datos están guardados persistentemente en GitHub.
  Las prioridades del tileset pueden repercutir en otros mapas con
  el mismo tileset y en la pasabilidad; probar antes de fusionar.
- No se editó el binario Map079.rxdata (>1 MB) ni IDs no comprobados.
- Se eliminó el antiguo editor de prioridades solo en RAM.

INTEGRACIÓN AISLADA
- [016] Studio Bridges.rb se encarga de proyectar Animated Props
  y Lighting Studio cuando están instalados y el 2.5D está activo.
- No se modificaron los scripts de Animated Props ni Lighting Studio.
- Recalcula desde coordenadas del mapa y evita proyectar sobre
  posiciones ya proyectadas; usa caché para iluminación estática.
- Depuración > Campo > 2.5D: adaptadores externos permite
  aislar visualización y coste de cada integración.

RENDIMIENTO
- Comparar el MISMO mapa en: 2D, 2.5D sin adaptadores,
  2.5D+Props, 2.5D+Lighting y 2.5D+ambos.
- pbVisual25DPerfProbe y pbVisual25DPerfDump siguen disponibles.
- La expansión de la rejilla de tiles puede seguir costando FPS.
  No reducir márgenes sin comprobar huecos y límites del mapa.
- Código cargado desde GitHub; falta validar el juego y FPS reales.

RESPALDOS
- backup/pre-visual25d-20261023: estado anterior al plugin.
- backup/visual25d-before-sky-reset-20261023: iteración previa.
