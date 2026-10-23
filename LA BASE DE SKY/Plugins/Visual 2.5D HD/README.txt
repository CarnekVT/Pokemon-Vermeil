VISUAL 2.5D HD — PRUEBA DE PERSPECTIVA PLANA (2026-10-23)
========================================================
Base funcional: Visual 2.5D HD v3.3.0 para Essentials 21.1.
Esta revisión parte otra vez del renderizador original, no de la
Preview de camara :camera / efecto maqueta.

CAMARA
- SOLO terreno plano; no existe opcion 'mundo redondo' en menus.
- Perfil recomendado: inclinacion 27 grados, zoom 100, proyeccion
  Clasica, convergencia 0.3, sin neblina ni vineteado.
- GROUND_SLICES = 1 para medir el rendimiento sin franjas extra.
- Maximo de margen = 12, igual que el renderizador base. Ajuste
  automatico con zoom / inclinacion para evitar bordes vacios.
- Menu normal: Opciones > Graficos > 2.5D (activar, angulo, zoom,
  proyeccion, FOV).
- Menu debug: Depuracion > Campo > Visual 2.5D HD.
- Las partidas anteriores pueden mantener inclinacion y zoom antiguos:
  utilizar "Restaurar configuracion base" en el menu debug.

PRIORIDADES NATIVAS PARA PRUEBAS
- Depuracion > Campo > "2.5D: prioridades nativas (test)".
- Al introducir ID del tile inferior, ancho y alto del objeto, el
  programa modifica RPG::Tileset#priorities en memoria.
- Para un arbol de 3 tiles de alto, prioridad 1 en base, 2 en medio
  y 3 en copa. Para un objeto de 2 filas: base 1 y superior 2.
- El tileset usa 8 columnas: el editor asciende hacia la fila
  superior restando 8 al ID por nivel y sin desbordar columnas.
- Afecta temporalmente la interpretacion nativa del motor, y podria
  influir en pasabilidad/capas mientras dure la sesion.
- No reescribe Data/Tilesets.rxdata ni las partidas guardadas.
- Se revierte con "Restaurar originales" o al reiniciar el juego.
- El ID exacto de los arboles/tejados del mapa capturado no se pudo
  verificar desde el PNG; hay que seleccionarlo en el juego.
- La herramienta puede mostrar IDs nativos en la casilla del jugador
  y en las cuatro casillas vecinas para localizar las piezas.

COMPATIBILIDAD SIN MODIFICAR OTROS PLUGINS
- LBDS Animated Props y Lighting Studio Runtime estan restaurados
  a sus archivos anteriores al 2.5D, sin cambios propios.
- Las adaptaciones opcionales viven UNICAMENTE en
  [016] Studio Bridges.rb.
- Depuracion > Campo > "2.5D: puentes de Studio (test)" permite
  comparar con o sin adaptaciones sin apagar los Studio.
- Si un puente provoca deformaciones, desactivarlo desde este menu.
  Esto solo cambia la proyeccion; el plugin externo sigue funcionando.

DIAGNOSTICO
- Comparar el MISMO mapa en 2D y 2.5D con iluminacion y props iguales.
- Usar la sonda de rendimiento: Depuracion > Campo > Visual 2.5D HD
  probe FPS. Tambien esta disponible pbVisual25DPerfDump.
- Esta revision no ha sido probada en el ejecutable del proyecto:
  se requiere validar imagen y FPS reales.

RESPALDOS GITHUB
- Antes de incluir el 2.5D:
  backup/pre-visual25d-20261023
  ac275cc2c52d82cad420e4751119228541f3e536
- Antes de reiniciar la prueba y revertir los cambios de Studio:
  backup/visual25d-before-sky-reset-20261023
  bfbfc4bf55af7a3303ff5ca1e6b45b58b272f100
Ambas ramas son puntos de referencia; no restaurar toda la rama
de trabajo sin considerar cambios posteriores no relacionados.
