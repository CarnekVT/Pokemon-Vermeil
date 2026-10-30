# Bifröst Capture 0.9.1 — profundidad, menús y audio Z-A por defecto

**Pokémon Vermeil · Essentials 21.1 · rama `feature/bifrost-overworld-capture-studio`**

Motor OW propio y configurable; no depende de VOWE. El recurso ZIJUK ICS y
los videos aportados son referencias de experiencia, no código copiado.
**Estado:** implementación experimental, pruebas Ruby/JavaScript aisladas;
todavía no validada dentro de mkxp con Visual 2.5D HD.

## Controles de exploración

| Acción | Tecla según el keybinding compartido | Comportamiento |
|---|---|---|
| Apuntar/lanzar | **A / JUMPUP** | Mantener para apuntar, soltar para lanzar |
| Cambiar selección | **S / JUMPDOWN** | Ciclo inmediato de Ball o Pokémon |
| Alternar Ball/Team | **S dos veces** | Doble pulsación rápida durante apuntado |
| Ciclo bidireccional | **Rueda del ratón** | Anterior o siguiente Ball/Pokémon |
| Alternar con ratón | **Clic derecho** | Cambiar modo Ball/Team |
| Lanzamiento directo | **C / USE** | Lanzar sin esperar a soltar A |
| Cancelar | **X / BACK** | Cierra apuntado sin lanzar |
| Objetivos | Ratón o autoapuntado | Selecciona OW válido en movimiento |

Los controles utilizan **acciones configurables de Essentials**, no códigos
físicos de teclado. **D / SPECIAL** sigue abriendo accesos rápidos,
**Q / AUX1** conserva Turbo, **W / AUX2** el debug de pasabilidades, **Shift/Z** la carrera, **F9** el debug y
las flechas el movimiento. W no se intercepta. El doble toque de S se ajusta
mediante `mode_double_tap_frames=16` y el clic derecho sigue disponible.
La selección y las asociaciones se pueden ajustar en Maker Studio.

La rueda usa `Input.scroll_v` únicamente si está disponible en mkxp-z.
En runtimes sin esta extensión, el sistema sigue funcionando con S.
`control_mode=toggle` permite pulsar para entrar y USE para lanzar.

## Memoria de selección

Los atributos `bifrost_last_ball`, `bifrost_last_party_index` y
`bifrost_last_mode` residen en `$PokemonGlobal` (datos de guardado).
Se recuerda la **Ball por su ID**, no por la posición en la Mochila,
y el Pokémon por índice dentro del equipo elegible. Si una Ball se agota,
se selecciona otra disponible; si cambia el equipo, se ajusta el índice.
`remember_selection=0` desactiva esta función.

## HUD del Team y feedback progresivo

- **Ball:** rueda compacta de tres iconos con cantidad y selección central.
- **Team:** tarjeta con icono de `Graphics/Pokemon/Icons`, nombre,
  nivel, índice, barra de PS y entrada deslizante al cambiar de miembro.
- **Objetivo:** color asociado a neutral/miedoso/agresivo y señales de huida.
- **Resultado:** tarjeta **lateral izquierda** con icono y texto,
  12 fotogramas de entrada suave, 72 de permanencia y 16 de salida;
  configuración independiente de cada fase y cola de hasta 5 avisos.
- **Estados:** atrapado, captura crítica, liberación, error de lanzamiento,
  objetivo bloqueado y escape. No requieren mensajes bloqueantes.

Ni el apuntado, ni la trayectoria, ni las sacudidas llaman a
`Graphics.update` en un bucle propio: se ejecutan con el mapa en movimiento.

## Perfiles y apariciones OW

La configuración Bifröst exclusiva permanece como preset:
`profile=bifrost`, `restricted_species=1`,
`encounter_mode=classic`. En **esta rama de pruebas de Vermeil**
el INI usa `profile=full_ow`, `encounter_mode=overworld`,
`restricted_species=0`: los encuentros de hierba/cueva pueden convertirse
en individuos OW capturables mediante la tabla PBS nativa.

Si falta un gráfico de `Graphics/Characters/Followers/ESPECIE` o una
casilla válida, OW completo omite el spawn sin forzar una batalla invisible.
En modo mixto, cuando corresponda, se conserva el encuentro tradicional.

`ow_extra_spawn_chance=12` habilita una segunda tirada OW por paso y
`ow_extra_spawn_cooldown=7` controla el ritmo sin alterar las tiradas de
batalla normales. Hay límite de OW por mapa, expiración y reglas de
terreno/obstáculos.

Los tres temperamentos se pueden fijar por especie, mapa y evento:

- **Neutral:** observa, puede apartarse tras un fallo.
- **Miedoso:** detecta antes y huye varias casillas.
- **Agresivo:** persigue y puede iniciar combate; admite bonus de nivel.

## Integración manual

Los eventos decorativos no se capturan. Los eventos OW capturables se nombran
`[OWCAP:RAIKOU:50]` o `[OWCAP:ARTICUNO:70:1]`.
Para registrar otro evento:

```ruby
BifrostCapture.register_ow($game_map.events[17], :RAIKOU, 50, 0)
```

`[OWDECOR]` excluye expresamente a los Pokémon decorativos.

## Audio

`audio_profile=za_like` es el **predeterminado**, mientras `pla_like` y otros
perfiles siguen disponibles para reutilizar el sistema. Estos perfiles asignan **nombres
de recursos opcionales** para 12 eventos: apuntar, cambiar Ball, cambiar
modo, cambiar miembro del equipo, fijar objetivo, lanzar, impactar,
sacudir, atrapar, liberarse, huir y alertar.

Los recursos se colocan en `Audio/SE/Bifrost/`. Para que el perfil Z-A no
quede silencioso, `009_Audio.rb` genera automáticamente **efectos WAV originales**
en esa carpeta cuando faltan. Si no puede escribir allí, utiliza el SFX de
Essentials correspondiente. No son grabaciones ni copias de efectos oficiales
de Arceus, Z-A o Tetris 99.
Ver [AUDIO_GUIDE.md](AUDIO_GUIDE.md) para nombres y referencias.


## Correcciones 0.9.1 de composición y menús

El vuelo, la sombra, la estela y la Ball de captura ya no usan viewports
de dibujo forzados por encima de todo el mapa. Comparten el viewport mundial
de `Spriteset_Map` y emplean Z derivada de `screen_z` de jugador y objetivo,
incluyendo la transformación de Visual 2.5D. Esto permite que los tiles y
animated props con prioridad mayor oculten correctamente la Ball.

El centro de rotación de la Ball de captura se fija en su **base** (`oy`
en la parte inferior), con `y` alineada a los pies del OW. Se elimina el
deslizamiento hacia abajo al absorber: las sacudidas no deben pivotar desde
arriba del sprite.

Al abrir Mochila, menú de registrados, debug o cambiar de mapa,
`010_MapInputGuard.rb` cierra el apuntado y limpia las animaciones de
mundo. No se consumen Balls hasta resolver realmente el impacto y los
Pokémon ya almacenados se eliminan del OW al abortar efectos.
Queda pendiente la prueba visual real con todas las transiciones de escenas.

## Editor, ajustes y verificación

Maker Studio tiene inspector por `[global]`, `[map:ID]`,
`[species:SPECIES]` y `[event:MAP:ID]`, catálogo editable,
comparación de perfiles, parámetros de input/audio/feedback y guardado
verificado en `config.ini` y `roster.ini`.
Dentro del juego puede invocarse `pbBifrostRulesMenu`.

Las pruebas de GitHub Actions verifican reglas, aparición, captura,
almacenamiento en equipo y cajas, estado de huida, inputs sin bloqueo,
memoria de Ball/Team/modo, y animación temporal de notificaciones.
No verifican por sí solas el aspecto final, la acústica ni el rendimiento
con el juego ejecutado. Validar la nueva versión en mkxp con
Visual 2.5D HD, Turbo, BAS/BSS, guardados, transferencias y mando.

Consultar [ROADMAP.md](ROADMAP.md) para seguimiento pendiente.
