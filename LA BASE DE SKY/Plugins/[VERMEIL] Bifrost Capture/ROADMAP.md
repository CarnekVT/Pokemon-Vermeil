# Bifröst Capture · seguimiento 0.2.0

Actualización: 29-10-2026, rama `feature/bifrost-overworld-capture-studio`.
**Criterio de estado:** «Código integrado» = publicado en GitHub, NO significa probado dentro del juego.
«Parcial» = primera versión sin completar o confirmar. «Pendiente» = no desarrollado.

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
| Simulador de alcance | Parcial | Parrilla interactiva esquemática; no renderiza el mapa real. |
| Verificación de guardado de INI y roster | Código integrado | Guarda y vuelve a leer ambos archivos; falta prueba en Maker Studio real. |
| Previsualización de modelos/sprites, mapa real y trayectoria | Pendiente | Requiere un visor compatible con mapas y geometría. |

## Runtime / captura / encuentros

| Funcionalidad | Estado | Alcance |
|---|---|---|
| Acceso por evento, cercano y permanente | Código integrado | Disponible en config, editor y menú de juego. |
| Atajos R / L / ninguno | Código integrado | No modifica el input original de Scene_Map. |
| Captura y combate OW solo de legendarios Bifröst | Código integrado | Catálogo inicial editable en `roster.ini`. |
| Exclusión de Pokémon decorativos | Código integrado | Etiquetas OWCAP / OWDECOR; no captura NPC sin marcar. |
| Área frontal 7×7; distancia óptima 4; octava fuera | Código integrado | Interfaz inicial sin puntería perspectiva real. |
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
| Puntería 2.5D con proyectil en mapa real | Pendiente | Requiere composición con Visual 2.5D HD. |
| Animación de lanzamiento, rebote, shakes y captura crítica | Pendiente | Solo flash de impacto inicial. |
| Colisiones completas de paredes y altura | Pendiente | Versión actual comprueba tiles y eventos, no todas las geometrías. |
| Fórmulas completas de cada Poké Ball | Pendiente | Multiplicadores iniciales simplificados. |
| IA avanzada de huida, persecución y visión | Pendiente | El sistema actual tiene reacción básica. |
| Compatibilidad real con BSS/BAS, Turbo y Smooth Movement | Pendiente | Requiere sesión de juego y depuración. |

## Pruebas

- **Verificación JavaScript realizada:** sintaxis compilable y renderizado aislado de las 9 secciones del editor.
- **Verificación de consistencia realizada:** los 35 parámetros del editor coinciden con los 35 parámetros del runtime.
- **Tests Ruby añadidos:** `tests/bifrost_capture_core_test.rb`, para ejecutar desde la raíz con `ruby tests/bifrost_capture_core_test.rb`.
- **Sin verificación en mkxp:** no se ha iniciado el ejecutable, guardado partida ni ejecutado combates o mapas en esta revisión.

## Orden prioritario siguiente

1. Abrir Maker Studio real, probar carga de catálogo y guardado de perfiles/especies.
2. Activar perfil Full OW, probar hierba en mapa real: spawn, sprite, eventos y no encuentros aleatorios.
3. Probar captura completa en combate/directa, Pokédex, PC, forma de Galar y guardar/cargar.
4. Vincular estados del sistema de legendarios errantes con la fauna OW.
5. Mejorar el render del apuntado sobre el mapa y la animación de Poké Ball.
6. Desarrollar IA de persecución/huida y colisiones 2.5D, compatibilidad Turbo y cámaras.
