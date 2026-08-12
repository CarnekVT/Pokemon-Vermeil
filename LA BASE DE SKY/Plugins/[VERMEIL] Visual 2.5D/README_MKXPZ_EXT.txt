[VERMEIL] Visual 2.5D V5.0 - NDS CAMERA SPACE / HIGH FPS
======================================================

V5 usa Sprite#corners del MKXP-Z nuevo y no reutiliza
Terrain Tags viejos como Mountains/Ladders/Mode7Tag para decidir geometria.

La regla central es:
  suelo       -> plano horizontal
  pared       -> plano vertical
  techo       -> plano horizontal elevado
  billboard   -> arte 2D rigido
  estructura  -> edificio 2D rigido con escala uniforme F/depth
  volumen     -> top original + caras laterales
  indoor      -> reglas propias Affine

Terrain Tags principales: 19-26. Casos especializados: 27-36.
Consulta TAG_MAP_V5.txt o Debug > Guia Terrain Tags NDS V5.

CAMARA BASE
-----------
  PROJECTION = :perspective
  OUTDOOR_DEFAULT_ALPHA = 40
  DISTANCE_H = 640.0
  PERSPECTIVE_PIVOT_RATIO = 0.52
  PERSPECTIVE_FOCAL_BALANCE = 0.30
  INDOOR_PROJECTION = :affine
  INDOOR_DEFAULT_ALPHA = 24

Priority queda reservado para orden Z. No define altura de roofs, volumen ni
tipo de objeto.

RENDIMIENTO
-----------
Usa NDS_PERFORMANCE_PROFILE = :performance para priorizar tres cifras de FPS.
El suelo usa bandas/quads nativos con Sprite#corners; volumen usa culling y
buckets; estructuras, personajes y billboards usan la misma escala de camara.

Para 120 FPS consulta MKXP_HIGH_FPS_SETTINGS.txt.
