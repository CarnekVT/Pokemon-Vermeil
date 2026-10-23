VISUAL 2.5D HD — PREVIEW DE TESTEO (CAMARA / RENDIMIENTO)
================================================================
Base funcional: Visual 2.5D HD v3.3.0. Essentials 21.1.
Objetivo visual: profundidad estilo quinta generación con horizonte plano.
No modifica mapas 2D ni sustituye el motor por un renderer 3D real.

AJUSTES DE CAMARA (SE PUEDEN CAMBIAR SIN EDITAR SCRIPTS)
  Opciones > Graficos:
    Modo 2.5D       : activa / desactiva
    Mundo 2.5D      : plano / redondo (recomendado: plano)
    2.5D Inclinacion: 0, 15, 20, 25, 27, 30, 35, 40, 45, 50 grados
    2.5D Zoom       : 75, 85, 90, 100, 110, 120, 135%
    2.5D Proyeccion : clasica / camara experimental
    2.5D Campo vision: 35, 45, 55, 65, 75, 85 (solo modelo Camara)
    2.5D Margen de render:
      4 tiles (FPS)   : reduce trabajo; puede mostrar bordes vacios
      6 tiles (medio) : equilibrio visual y rendimiento
      8 tiles         : máxima cobertura de este perfil de prueba
  Los valores de camara y margen se guardan en la partida.
  En depuracion tambien sigue disponible pbVisual25DMenu.
  Cambios guardados anteriormente se respetan; usar Restaurar valores
  desde pbVisual25DMenu para volver a valores por defecto.

PERFIL POR DEFECTO
  Inclinacion 27; zoom 100%; proyeccion Clasica; FOV 55;
  convergencia lateral 0.25; horizonte plano; GROUND_SLICES 1;
  neblina y vigneta apagadas; maximo de margen 8.
  HOTKEY deshabilitada: no secuestrar Q ni el turbo.

PRIORIDADES DE TILES (PRUEBA TEMPORAL)
  Depuracion > Campo > 2.5D: prioridad de tiles (PRUEBA)
  Elige un ID de tile y prioridad visual entre 0 y 12.
  El cambio afecta SOLO al renderer 2.5D en el mapa activo.
  No reescribe prioridades de tilesets, PBS, colisiones ni pasabilidad.
  No persiste en la partida. Se puede borrar desde el mismo menu o
  reiniciando el juego.

DIAGNOSTICO DE FPS
  Comparar el mismo mapa en 2D y 2.5D, con idéntica iluminación y props.
  Probar 2.5D: Margen de render 8 y 6, luego 4 para identificar cuellos.
  Si el margen 4 produce huecos en pantalla, volver a 6 u 8.
  Depuracion > Campo > Visual 2.5D HD: probe FPS:
  vuelca contadores a la consola / mkxp.log para estudiar rendimiento.
  No se garantiza recuperar los FPS originales sin test ingame.

CAMBIOS DE ESTA RAMA
  Visual 2.5D HD mantiene la logica de alturas, cliffs, caps, aristas
  compartidas, tilemap expandido y puente con MakerStudio.
  Animated Props y Lighting Studio tienen adaptaciones de proyeccion.
  No eliminar ni duplicar el plugin: conservar su carpeta y meta.txt.

HISTORIAL Y RECUPERACION
  Branch de respaldo anterior a incorporar 2.5D:
    backup/pre-visual25d-20261023
  Commit de referencia:
    ac275cc2c52d82cad420e4751119228541f3e536
  NO regresar toda la rama con reset --hard salvo que tambien se
  quieran revertir los cambios no relacionados introducidos despues.

NOTA
  No hay verificacion ingame del perfil actual. Ejecutar pruebas
  de camara, prioridad y rendimiento en el motor real.
  Sprite#taper requiere un ejecutable que incluya dicha extension.
