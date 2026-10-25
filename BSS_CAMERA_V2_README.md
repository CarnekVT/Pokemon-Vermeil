# Cámara cinematográfica v2 — Pokémon Vermeil

**Sistema:** BSS controla la cámara permanente del escenario y BAS controla exclusivamente la cámara durante los ataques. **Sin importar scripts de EBS.** La v2.1 estabiliza la escala nativa de los sprites y conserva la perspectiva del escenario.

## Archivos

- `LA BASE DE SKY/Plugins/[CARNEK] Battle Scene Studio Runtime/99_Hotfix/044_Cinematic_Camera_Director.rb`: nuevo director de encuadres y proyección absoluta de Pokémon/sombras.
- `LA BASE DE SKY/Plugins/[CARNEK] Battle Scene Studio Runtime/99_Hotfix/042_Shared_Camera_Cooperation.rb`: bloqueo compartido durante BAS.
- `LA BASE DE SKY/Plugins/Battle Animation Studio Runtime/002_BSS_Camera_Cooperation.rb` y `003_Visible_Attack_Camera.rb`: animaciones de ataque / movimientos relativos, separados de BSS.

## Diferencias visibles (v2.1: tamaño de Pokémon y perspectiva estabilizados)

- En reposo: desplazamiento suave y limitado, **sin zoom automático**.
- En el menú de acciones: desplazamiento moderado hacia el lado del jugador, sin modificar el tamaño de los Pokémon.
- Al seleccionar un movimiento: encuadre ligeramente más próximo por desplazamiento, **no por aumentar la escala**.
- **Sprites y sombras conservan exactamente los valores nativos de `zoom_x` y `zoom_y`**; no se acumulan ni se multiplican por el zoom EBDX.
- Se preservan los componentes de ángulo, profundidad y escala del vector principal de EBDX, evitando deformaciones del horizonte y saltos de tamaño.
- BAS sigue controlando sus propios zooms **solo durante las animaciones de ataque**, con prioridad sobre BSS.

## Configuración

El director utiliza los parámetros existentes `idleStrength`, `commandStrength`, `fightStrength`, `panX`, `panY` y `cinematicSmooth` del objeto global `ebdxCamera`.

- `cinematicCamera`: `true` por defecto; `false` recupera la cámara anterior.
- `cinematicSmooth`: `0.085` por actualización (límite 0.025–0.18).
- `cinematicIdlePan`: `5.0` (límite 0–10).
- `cinematicBattlerFollow`: `100` (0–100); controla únicamente cuánto siguen Pokémon y sombras el **desplazamiento**, sin escalar los sprites.
- `cinematicIdleZoom`, `cinematicCommandZoom` y `cinematicFightZoom`: se conservan por compatibilidad con datos antiguos, pero **el director v2.1 ya no los aplica** para evitar cambios inesperados de tamaño.

El perfil **static / static_gen4** continúa siendo estático de forma intencional. El nuevo director se aplica a los escenarios **EBDX** habilitados en BSS, no a los combates de Essentials puro sin escenario EBDX.

## Correcciones de atardecer y cámara de ataques (24/10/2026)

- \`99_Hotfix/045_Sunset_Sky_and_Clouds.rb\` elimina el tinte cian de la franja del horizonte y del cielo en el horario \`:dawn\` (mañana/atardecer), conservando el sol, los árboles y el terreno. Los sprites de nubes reciben un tono cálido, y el original se recupera al cambiar de horario.
- No se alteran los archivos PNG originales ni la geometría del escenario. La conversión del cielo se ejecuta al dividir/recrear el fondo o cambiar el tramo horario, no en cada fotograma.
- \`044_Cinematic_Camera_Director.rb\` mantiene bloqueado el encuadre base de BSS durante animaciones nativas de movimientos y efectos comunes. **Las cámaras de ataques provienen únicamente de las secuencias creadas en BAS.**
- \`Battle Animation Studio Runtime/003_Visible_Attack_Camera.rb\` tiene \`ENABLED = false\`: BAS ya no inventa zooms o movimientos automáticos cuando una animación carece de claves de cámara. Las animaciones con cámara configurada manualmente en BAS siguen funcionando.

Comprobación específica: reproducir una batalla al atardecer con cielo EBDX, observar que desaparecen la franja cian y las nubes azules, usar un movimiento **sin** cámara BAS (BSS debe mantener el mismo encuadre) y otro **con** cámara BAS (solo BAS debe moverla).

## Verificación

1. Actualizar la rama `new-MK-for-2.5D-Testeo` en la carpeta local del juego. Un `push` a GitHub **no actualiza** por sí solo el proyecto que ya tienes abierto.
2. Cerrar y volver a iniciar Pokémon Vermeil para recargar los scripts de los plugins.
3. Iniciar un combate con escenario EBDX activo y comparar reposo, menú de acciones y menú de movimientos. La cámara debe desplazarse suavemente, **sin cambiar el tamaño de Pokémon o sombras**.
4. Probar un ataque exportado desde BAS. Durante el ataque su cámara debe tomar prioridad; al terminar se vuelve suavemente al estado de BSS.
5. Si permanece igual, consultar `@scene.vermeil_cinema_status` desde el contexto de un evento/script que disponga de la escena de combate. Su `:active` debe ser `true` y su `:version` debe ser `2.1.0`. El log `BSS064` emite `[Camera v2] active` la primera vez que funciona.

La sintaxis y el contrato básico se prueban con `ruby tests/bss_cinematic_camera_v2_test.rb`. **Esto no reemplaza una prueba visual en RPG Maker XP/mkxp.**