# Bifröst Capture · seguimiento 0.4.0

Actualización: 29-10-2026, rama `feature/bifrost-overworld-capture-studio`.
**Criterio de estado:** «Código integrado» = publicado en GitHub, NO significa probado dentro del juego.
«Parcial» = primera versión sin completar o confirmar. «Pendiente» = no desarrollado.

## Revisión basada en los tres videos — 0.4.0

| Objetivo | Estado actual |
|---|---|
| No consumir Balls al apuntar a un sprite no autorizado | Implementado; `allow_empty_throw=0` por defecto |
| Reconocer el sprite real, incluso con zoom/cámara 2.5D | Implementado con `Sprite_Character`; comprobar en partida |
| Mantener la identidad del Pokémon durante el vuelo | Implementado; la Ball sigue su posición y resuelve contra el mismo evento |
| Sombra en el suelo, arco y rotación | Implementado; pendiente de pulido visual in-game |
| Recuperar huida con desplazamiento visible | Implementado con pasos/velocidad/distancia configurables |
| Evitar eliminar permanentemente Pokémon que huyeron | Implementado; solo captura aplica marca persistente |
| Evitar combates iniciados debajo del HUD | Implementado; ataque y envío de Pokémon diferidos hasta cerrar el apuntado |
| Sacudidas de la Ball, aparición al fallar y desaparición al capturar | Implementado; aún requiere prueba real en mkxp |
| Casos en los que un OW externo no lleva etiqueta `[OWCAP]` | Disponible `BifrostCapture.register_ow(event,species,level,form)` y aviso en HUD |
| Verificación automatizada | Tests Ruby/JS integrados en GitHub Actions |
| Validación y equilibrio en juego | Pendiente: precisión visual, 2.5D, Turbo, rendimiento, ritmo y audio |
| Animación corporal de lanzamiento y sonido según videos | Pendiente |
| Sincronización del estado global de errantes Essentials | Pendiente |

## Editor Maker Studio

| Área | Estado | Alcance |
|---|---|---|
| Rediseño BAS/BSS | Código integrado | Navegación izquierda, escenario central, inspector contextual, toolbar y estado de guardado. |
| Vista general de reglas | Código integrado | Perfil, disponibilidad, forma de encuentro, conteo de especies y flujo. |
| Comparador de perfiles | Código integrado | Valores actuales y propuestos; aplicación explícita y guardado posterior. |
| Perfiles Bifröst / Classic / Adventure / Safari / Custom | Código integrado | Presets intercambiables. |
| Nuevo perfil Full OW | Código integrado | Enciende sistema de encuentros visible, libera catálogo, permite apuntar siempre. |
| Catálogo de Pokémon | Código integrado | Búsqueda en PBS, filtro Bifröst, lista de spawn y bloqueo. |
| Configuración por especie | Código integrado | Niveles, forma Galar, probabilidad individual, alarma, comportamiento y captura. |
| Ámbitos global / mapa / especie / evento | Código integrado | Sobrescrituras vía INI. |
| Editor de encuentros / densidad | Código integrado | Clásico, híbrido y OW completo, filtros, distancias y límite. |
| Simulador de alcance (solo Maker Studio) | Parcial | Visualiza reglas y rango; en juego ya no existe la cuadrícula de selección. |
| Verificación de guardado de INI y roster | Código integrado | Guarda y vuelve a leer ambos archivos; falta prueba en Maker Studio real. |
| Previsualización de modelos/sprites, mapa real y trayectoria | Pendiente | Requiere un visor compatible con mapas y geometría. |

## Runtime / captura / encuentros

| Funcionalidad | Estado | Alcance |
|---|---|---|
| Acceso por evento, cercano y permanente | Código integrado | Disponible en config, editor y menú de juego. |
| Atajos R / L / ninguno | Código integrado | No modifica el input original de Scene_Map. |
| Cambiar el tipo de encuentro desde el juego | Código integrado | Menú opcional permite clásico, mixto u OW completo y restricción de especies, por partida. |
| Captura y combate OW solo de legendarios Bifröst | Código integrado | Catálogo inicial editable en `roster.ini`. |
| Exclusión de Pokémon decorativos | Código integrado | Etiquetas OWCAP / OWDECOR; no captura NPC sin marcar. |
| Área frontal 7×7; distancia óptima 4; octava fuera | Código integrado | Regla de alcance interna; no se dibuja una cuadrícula sobre el mapa. |
| Precisión menor a mayor distancia | Código integrado | Cálculo inicial configurable. |
| Captura crítica y bonificación trasera | Código integrado | Cálculo inicial sin animación física. |
| Alerta a 3 casillas, huida/ataque/ignorar | Parcial | Reacciones simplificadas, falta IA/animaciones reales. |
| Consumo de Poké Balls | Código integrado | Consumir siempre al impactar y opcionalmente al fallar. Falta validar ingame. |
| Lanzar un Pokémon escogido | Parcial | Se utiliza como líder temporal; falta animación del lanzamiento. |
| Captura directa, Pokédex, cajas | Parcial | Ruta de captura escrita; falta prueba de PC, formas y guardado. |
| Generación automática de fauna OW desde hierba | Parcial | Lee tablas PBS; genera eventos de mapa temporales con sprite Followers. |
| Modo 100 % OW sin aleatorios terrestres | Parcial | Suprime los aleatorios terrestres y de cueva, con frecuencia de spawn ajustable. |
| Modo híbrido OW + encuentros clásicos | Código integrado | No suprime los encuentros de hierba. |
| Cantidad, duración y distancia de spawns | Código integrado | Límites editables. |
| Listas de elegibilidad y veto de aparición | Código integrado | Configuración desde roster.ini. |
| Forma OW y niveles por especie | Código integrado | Aplicados a eventos temporales autogenerados. |
| Formas Galar en combate OW | Código integrado | Pokémon previo al combate con forma del evento; falta prueba. |
| Preservar encuentros de Surf, pesca y por script | Código integrado | No se modifica su activación habitual. |
| Sincronizar estado con sistema de errantes Essentials | Pendiente | Necesario para desaparición, captura y persistencia global. |
| Puntería contextual sobre sprites del mapa | Código integrado; requiere prueba | Ahora permite flechas en movimiento continuo, fijación de objetivo mediante ACTION y ratón opcional. Falta probar Visual 2.5D HD. |
| Entrada adaptada a los Key bindings reales | Código integrado; requiere prueba | AUX2=W abre; flechas apuntan; USE=C/Espacio/Enter lanza; AUX1=Q cambia Ball; SPECIAL=D cambia modo; BACK=X/Esc cancela; ACTION=Shift/Z fija. |
| Coincidencia entre retícula y cálculo de impacto | Código integrado; pruebas añadidas | Se recalcula el objetivo en el disparo y la geometría se comparte entre controles. La cuarta casilla alineada tiene 100% de contacto, no de captura. |
| Diagnóstico de fallo en el HUD | Código integrado | Sin objetivo / fuera de alcance / obstáculos / tiro desviado. |
| Vuelo animado de Poké Ball y efecto de contacto | Código integrado; requiere prueba | Usa íconos originales de Items, arco y giro en pantalla, destello localizado y pausa de impacto. No es física 3D. |
| Animación del brazo del jugador, rebotes y shakes de captura | Pendiente | Requiere sprites/animaciones propias y sincronización con resultados de captura. |
| Colisiones completas de paredes y altura | Pendiente | Versión actual comprueba tiles y eventos, no todas las geometrías. |
| Fórmulas completas de cada Poké Ball | Pendiente | Multiplicadores iniciales simplificados. |
| IA avanzada de huida, persecución y visión | Pendiente | El sistema actual tiene reacción básica. |
| Compatibilidad real con BSS/BAS, Turbo y Smooth Movement | Pendiente | Requiere sesión de juego y depuración. |

## Pruebas

- **CI GitHub Actions superada:** sintaxis Ruby de los scripts, sintaxis JavaScript del editor y pruebas de geometría/perfiles. Una nueva prueba `tests/bifrost_capture_aim_test.rb` valida la selección de objetivos y el impacto a 4 casillas sin mkxp. Revisar la ejecución de GitHub Actions más reciente.
- **Lanzamiento revisado:** retícula en mapa controlada con flechas o ratón; W/AUX2 apunta; USE/C/Espacio/Enter lanza; Q/AUX1 cambia Ball; D/SPECIAL cambia modo; X/BACK sale; Shift/Z/ACTION fija al objetivo elegible más cercano.
- **Control configurable:** `aim_keyboard`, `aim_speed`, `aim_mouse`, `aim_target_radius`, `throw_frames`, `throw_arc`, `aim_chain`.

- **Verificación JavaScript realizada:** sintaxis compilable y renderizado aislado de las 9 secciones del editor.
- **Verificación de consistencia realizada:** los 35 parámetros del editor coinciden con los 35 parámetros del runtime.
- **Tests Ruby añadidos:** `tests/bifrost_capture_core_test.rb`, para ejecutar desde la raíz con `ruby tests/bifrost_capture_core_test.rb`.
- **Sin verificación en mkxp:** no se ha iniciado el ejecutable, guardado partida ni ejecutado combates o mapas en esta revisión.

## Orden prioritario siguiente

1. Abrir Maker Studio real, probar carga de catálogo y guardado de perfiles/especies.
2. Activar perfil Full OW, probar hierba en mapa real: spawn, sprite, eventos y no encuentros aleatorios.
3. Probar captura completa en combate/directa, Pokédex, PC, forma de Galar y guardar/cargar.
4. Vincular estados del sistema de legendarios errantes con la fauna OW.
5. Validar y pulir el nuevo render de la retícula contextual y vuelo de la Poké Ball; completar animación del entrenador, rebotes y sacudidas.
6. Desarrollar IA de persecución/huida y colisiones 2.5D, compatibilidad Turbo y cámaras.
