# Cámara cinematográfica v2 — Pokémon Vermeil

**Sistema:** BSS controla la cámara permanente del escenario y BAS controla exclusivamente la cámara durante los ataques. **Sin importar scripts de EBS.**

## Archivos

- `LA BASE DE SKY/Plugins/[CARNEK] Battle Scene Studio Runtime/99_Hotfix/044_Cinematic_Camera_Director.rb`: nuevo director de encuadres y proyección absoluta de Pokémon/sombras.
- `LA BASE DE SKY/Plugins/[CARNEK] Battle Scene Studio Runtime/99_Hotfix/042_Shared_Camera_Cooperation.rb`: bloqueo compartido durante BAS.
- `LA BASE DE SKY/Plugins/Battle Animation Studio Runtime/002_BSS_Camera_Cooperation.rb` y `003_Visible_Attack_Camera.rb`: animaciones de ataque / movimientos relativos, separados de BSS.

## Diferencias visibles

- Cámara **en reposo**: zoom de campo 1.045× y respiración lenta sin saltos aleatorios.
- **Menú de acciones**: encuadre desplazado y zoom 1.105× con transición interpolada.
- **Selección de movimientos**: acercamiento de 1.145× mientras el jugador elige un movimiento.
- Pokémon y sombras ahora participan del zoom/pan mediante sus posiciones nativas **calculadas desde cero en cada actualización**, evitando acumulaciones.
- En BAS, se congela solamente la autoridad base mientras se ejecuta la animación; la cámara específica del ataque puede moverse sin que BSS reemplace su encuadre.

## Configuración

Este director aprovecha los controles **ya existentes** de cámara en BSS (`idleStrength`, `commandStrength`, `fightStrength`, `panX`, `panY` y `cinematicSmooth` si se proporciona). Las opciones avanzadas pueden configurarse en el objeto global `ebdxCamera` de los datos BSS:

- `cinematicCamera`: `true` por defecto; `false` vuelve al sistema anterior.
- `cinematicIdleZoom`: `1.045`.
- `cinematicCommandZoom`: `1.105`.
- `cinematicFightZoom`: `1.145`.
- `cinematicSmooth`: `0.09` por actualización (límite 0.025–0.18).
- `cinematicIdlePan`: `8.0` (límite 0–20).
- `cinematicBattlerFollow`: `100` (0–100); ajusta cuánto acompañan Pokémon y sombras a la cámara.

El perfil **static / static_gen4** continúa siendo estático de forma intencional. El nuevo director se aplica a los escenarios **EBDX** habilitados en BSS, no a los combates de Essentials puro sin escenario EBDX.

## Verificación

1. Actualizar la rama `new-MK-for-2.5D-Testeo` en la carpeta local del juego. Un `push` a GitHub **no actualiza** por sí solo el proyecto que ya tienes abierto.
2. Cerrar y volver a iniciar Pokémon Vermeil para recargar los scripts de los plugins.
3. Iniciar un combate con escenario EBDX activo y comparar reposo, menú de acciones y menú de movimientos. La cámara debe cambiar de encuadre antes de usar un ataque.
4. Probar un ataque exportado desde BAS. Durante el ataque su cámara debe tomar prioridad; al terminar se vuelve suavemente al estado de BSS.
5. Si permanece igual, consultar `@scene.vermeil_cinema_status` desde el contexto de un evento/script que disponga de la escena de combate. Su `:active` debe ser `true` y su `:version` debe ser `2.0.0`. El log `BSS064` emite `[Camera v2] active` la primera vez que funciona.

La sintaxis y el contrato básico se prueban con `ruby tests/bss_cinematic_camera_v2_test.rb`. **Esto no reemplaza una prueba visual en RPG Maker XP/mkxp.**