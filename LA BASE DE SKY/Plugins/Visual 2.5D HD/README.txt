VISUAL 2.5D HD — CAMERA PREVIEW 01
======================================
Base: Visual 2.5D HD v3.3.0 (Pokemon Essentials 21.1).
Variante inicial de cámara orientada a la quinta generación. Créditos originales en meta.txt.

OBJETIVO
- Sensacion visual proxima a la quinta generacion de Pokemon: perspectiva
  lineal, fondo con profundidad, personajes con sprites y sin horizonte curvado.
- No es un motor 3D ni reproduce la camara 3D original de Nintendo DS.
- No se ha validado dentro del juego. Es una primera calibracion para pruebas.

CAMBIOS
[001] Settings.rb:
  TILT_DEGREES = 40 (antes 50)
  PROJECTION_MODEL = :camera (antes :classic)
  CAMERA_FOV = 55 (antes 45)
  VANISHING_STRENGTH = 0.4 (antes 0.3)
  VERTICAL_GAIN = 0.5 (antes 0.4)
  HAZE, NEAR_HAZE, VIGNETTE = false (antes true)
  MODE_LABEL = false (antes true)
  HOTKEY = nil (antes Q)
[006] Atmosphere.rb: no interviene en las teclas de turbo del proyecto.
[008] Options.rb: en partidas nuevas, mundo plano por defecto.
[002] Core.rb: 'Restaurar valores' recupera horizonte plano.

SIN CAMBIOS
- Motor de proyeccion y funciones matematicas originales.
- Optimizaciones, caches, culling, capas MakerStudio y tags 19/20/21.
- HORIZON_CURVE sigue 14 si activas manualmente el modo 'Redondo'; asi se
  puede comparar la version plana con el efecto original.
- GROUND_SLICES=2, ROW_BATCH=false, BAND_BLUR=false.

INSTALACION
1. Haz copia de seguridad del plugin anterior y de tu partida.
2. No instales dos copias activas del mismo plugin.
3. Usa la carpeta del plugin (conserva meta.txt).
4. Abre el juego y comprueba la perspectiva sobre un mapa habitual.
5. Los parametros zoom/tilt/mundo estan guardados en cada partida: en una
   partida existente usa 'Restaurar valores' desde pbVisual25DMenu, o ejecuta:
      Visual25D.projection_model = :camera
      Visual25D.camera_fov = 55
      Visual25D.tilt = 40
      Visual25D.camera_zoom = 100
      $PokemonSystem.visual25d_round = false
      Visual25D.horizon_curve = 0
   Guarda la partida despues si deseas mantener los valores persistentes.
6. Q deja de estar asignada al modo 2.5D. El turbo original no se modifica.
   El 2.5D se puede cambiar desde opciones/depuracion.

PRUEBAS RECOMENDADAS
- Caminata 8 direcciones, turbo, transicion combates, mapas conectados.
- Enfoques frontal y lateral de edificios grandes; bordes de tiles y arboles.
- Cliff 19, InteriorWall 20, Shelf 21, mapas con MakerStudio extendido.
- Zoom 80, 100 y 120; angulo 35, 40, 45; FOV 50, 55 y 60.
- Evaluar sobre capturas comparativas de rutas y ciudades Gen5.

IMPORTANTE
Ruby -c solo valida sintaxis; no prueba los hooks ni el ejecutable mkxp.
La calidad de GROUND_SLICES depende de Sprite#taper (si el ejecutable lo tiene).
