# Bifröst Capture 1.2 — UI con arte editable, cooldown visible y persecución reactiva

**Pokémon Vermeil · Essentials 21.1 · rama `feature/bifrost-overworld-capture-studio`**

Motor OW propio y configurable; no depende de VOWE. El recurso ZIJUK ICS y
los videos aportados son referencias de experiencia, no código copiado.
**Estado:** implementación experimental, pruebas Ruby/JavaScript aisladas;
todavía no validada dentro de mkxp con Visual 2.5D HD.

## Controles de exploración

| Acción | Teclado predeterminado | Comportamiento |
|---|---|---|
| Apuntar/lanzar | **A / JUMPUP** | Mantener para apuntar; soltar para lanzar |
| Cambiar objetivo | **Tab** | Siguiente Pokémon visible en el mapa |
| Objetivo anterior | **Mayús + Tab** | Recorrer Pokémon visibles en sentido inverso |
| Alternar Ball/Team | **E** | Cambio inmediato sin mantener otra tecla |
| Siguiente Ball/Pokémon | **S / JUMPDOWN** | Recorre el inventario o equipo seleccionado |
| Anterior Ball/Pokémon | **Mayús + S** | Selección inversa sin activar cambio de modo |
| Ciclo con mouse | **Rueda** | Selección anterior/siguiente |
| Alternar con mouse | **Clic derecho** | Cambiar Ball/Team |
| Lanzamiento directo | **C / USE** | Lanzar sin soltar A |
| Cancelar | **X / BACK** | Salir de apuntado |

**Teclado sin ratón:** mantener A, alternar Pokémon visibles con Tab,
cambiar Ball/Team con E, escoger con S (Mayús+S para retroceder),
y soltar A o pulsar C para lanzar. Mantener S no cambia el modo,
incluso si se deja pulsada durante varios segundos. Cuando se selecciona un objetivo
bloqueado o fuera de rango, la mira lo indica; no se ignora en silencio.
El autoapuntado inicial conserva prioridad de objetivos alcanzables.

El HUD muestra los atajos de teclado compactos. Tab/E solo se procesan
durante el apuntado y jamás cambian de modo fuera de esa interfaz. Los
atajos físicos usan `Input.triggerex?` de mkxp-z; se configuran en
`config.ini` como `keyboard_target_key=tab` y `keyboard_mode_key=e`.
Se admiten `tab/e/r/f/t/g/none`; `none` desactiva el atajo.
Estos dos atajos son físicos, **no se reasignan desde F1**, a diferencia de
las acciones lógicas A/S/C/X, que respetan los keybindings del usuario.
Si el usuario asigna una tecla física de Bifröst a una acción reservada,
el menú/acción original prevalece.

**Sin colisiones:** D / SPECIAL sigue abriendo accesos rápidos,
Q / AUX1 conserva Turbo, W / AUX2 el debug de pasabilidades,
Shift/Z la carrera, F9 el debug y las flechas el movimiento.
El nuevo control no consume las direcciones, no introduce
`Graphics.update` ni `Input.update` adicionales y es compatible con
`aim_mouse=0`. Mantener S nunca alterna Ball/Team; cada pulsación de S avanza una
selección, y Mayús+S retrocede. E (o clic derecho) es el único
cambio de modo predeterminado. El antiguo parámetro
`ball_hold_mode_frames` deja de ser un ajuste editable y, si permanece
en archivos INI heredados, no afecta a los controles.
El mouse continúa siendo opcional.


## Guía de controles contextual

La franja inferior del **HUD Ball/Team existente** actúa como guía.
No aparece ninguna ventana adicional que tape el mapa. Al empezar
a apuntar se muestran hasta seis acciones relevantes en dos líneas;
tras unos instantes, la guía se compacta automáticamente en una sola.
Los avisos importantes (p. ej. objetivo bloqueado) tienen prioridad
sobre la expansión. La guía reaparece al cambiar de Ball/Team o si
cambian las etiquetas efectivas de las teclas.

Los valores proceden directamente de las acciones lógicas actuales
del juego y de `config.ini`. Para acciones reasignadas mediante F1,
se consulta `KeybindingReader.key_name` cuando está presente o el
lector de nombres que exponga `Input`. Si ninguno está disponible, se
muestra el nombre de la **acción lógica** en vez de inventar una tecla
física. Los atajos directos Tab/E reflejan la configuración Bifröst y
se omiten si mkxp no admite `triggerex?`. Se muestran controles del
modo activo: Ball o Pokémon.

Ajustes:

```ini
hud_controls=auto
hud_controls_intro_frames=150
```

- `auto`: guía de bienvenida y después recordatorios compactos.
- `always`: guía desplegada siempre que no tape avisos importantes.
- `off`: ocultar indicaciones de teclas sin desactivar el HUD normal.
- `hud_controls_intro_frames`: duración de la guía inicial (30–360 frames).

No se crean nuevos `Viewport` ni se interceptan acciones; se dibuja
dentro del bitmap del HUD ya existente y desaparece al cerrar el apuntado.
La duración son fotogramas de juego, no segundos fijos.

## Bifröst UI Art Studio: cinco capas gráficas reales

La interfaz del mapa ya no depende solo de rectángulos dibujados con Ruby:
el juego carga las siguientes capas **PNG con transparencia**, de
`Graphics/UI/Bifrost/`, con alternativas procedurales si faltan.

| PNG | Uso en el juego | Fuente editable |
|---|---|---|
| `panel.png` | HUD general 392×116 | `_source/panel.svg` |
| `slot.png` | Icono de Ball inactiva | `_source/slot.svg` |
| `slot_selected.png` | Ball seleccionada | `_source/slot_selected.svg` |
| `target.png` | Estado y especie apuntada | `_source/target.svg` |
| `keycap.png` | Teclas contextualizadas | `_source/keycap.svg` |

Los SVG se entregan como **fuentes editables por capas** para Inkscape,
Illustrator y otras aplicaciones, y los PNG se pueden modificar en
Aseprite, GIMP, Photoshop o Krita. Si se edita un SVG, exporta su resultado
con el mismo nombre y dimensiones del PNG correspondiente.
No se necesita IA para ajustar la presentación.

**Reutilización del juego:** los sprites de Balls y el inventario provienen
de `Graphics/Items/<ITEM>.png`, y los Pokémon del equipo se dibujan
desde `Graphics/Pokemon/Icons`. Las cinco capas nuevas son fondos,
marcos y controles; **no sustituyen** los sprites del juego.

**Desde Maker Studio:** entra en `Bifröst Capture Studio → UI Art Studio`.
Hay una vista previa de 640×480 con modos Ball y Team, biblioteca de
recursos, selección de capas, controles de tamaño/posición/opacidad y
reubicación del HUD arrastrando. Pulsa `Importar PNG` para incorporar
un archivo desde tu equipo: el editor escribe el archivo binario en la
ruta del proyecto y lo vuelve a leer para comprobarlo; `Recargar PNG`
refresca la vista al modificarlo externamente. Los recursos originales
de Pokémon se muestran como referencias de solo lectura.
La vista previa utiliza la misma imagen que el juego, pero **no ejecuta**
el renderer mkxp ni es un sustituto de las pruebas visuales.

El editor mantiene guardado explícito de reglas; solo la operación
`Importar PNG` sobrescribe inmediatamente la capa seleccionada.
Los cambios de posición y de cooldown requieren pulsar **Guardar**.

**Cooldown visible:** en modo Ball aparece la barra `BALL LISTA` o
`RECARGA Nf`. `throw_cooldown_frames=17` limita solo Poké Balls,
no el cambio a Team. El contador continúa después de cerrar la mira.
Los ajustes de enfriamiento también figuran en `UI Art Studio →
Interacción` y `Lanzamiento`.

**Persecución:** un agresivo prepara la acción, hace una embestida
breve a velocidad 5 (configurable de 4 a 6) y mantiene una persecución
activa a velocidad 5–6, con pausas cortas de 3 fotogramas por defecto
entre pasos. Durante la embestida no se introduce ninguna pausa entre
casillas. Los valores anteriores de velocidad de paseo se elevan
automáticamente al mínimo de persecución 5.

## Gamefeel 1.1: riesgo, fauna expresiva y HUD personalizable

**Cooldown de lanzamientos:** `throw_cooldown_frames=17` evita el
spam de pulsaciones sin bloquear la exploración ni las animaciones de otras
Poké Balls. Se mantiene el límite de hasta tres vuelos en paralelo y se
comprueba la cantidad de Balls disponible. El contador continúa entre
sesiones de apuntado para que no se eluda cerrando y abriendo el HUD.

**Reacción al liberarse:** cada Ball fallida tiene una probabilidad
configurable (`escape_reaction_chance=25`) de provocar una respuesta.
La criatura avisa durante `escape_reaction_windup=30` fotogramas y
solo afecta al equipo cuando el jugador todavía se encuentra en su
radio (`escape_reaction_range=4`). Se puede evitar alejándose o
interrumpiendo la preparación mediante otro lanzamiento. Si alcanza,
resta `escape_reaction_hp_percent=8` % de PS máximos a un Pokémon
disponible del equipo, sin dejarlo a 0 PS. La reacción tiene un
enfriamiento global (`escape_reaction_recovery=180`) para evitar
castigos superpuestos. Desactivar con `escape_reaction_enabled=0`.
La finalidad es dar un coste jugable y evitable a capturas repetidas,
no sustituir el combate tradicional.

**Agresivos:** detectan a distancia, se preparan con señal visual y
solo comienzan una embestida dentro de su radio interno
(`aggressive_lunge_distance=3`), a velocidad y duración configurables
(`aggressive_lunge_speed=4`, `aggressive_charge_steps=2`).
Después reducen la velocidad y hacen pausas; no aparecen corriendo
directamente contra el jugador desde la distancia de detección.
La bonificación real al entrar en combate tradicional es
`aggressive_level_bonus`: **+2 niveles al Pokémon salvaje**
(por defecto), sin superar nivel 100. El editor lo muestra en
**Comportamiento → VENTAJA EN COMBATE** para no confundirlo con una
recompensa para el entrenador.

**Señales visuales por temperamento:** sobre cada Pokémon visible
aparece un marcador discreto: neutro verde, tímido azul con interrogante,
agresivo naranja con exclamación. Durante alerta/embestida/amenaza
cambia de color y énfasis. Los indicadores usan
`Spriteset_Map.viewport`, siguen la posición y profundidad de los
sprites en 2.5D y se eliminan al abandonar el mapa o entrar en combate.
Se pueden ocultar con `temperament_indicators=0`.

**Personalización del HUD:** `hud_position` admite `bottom_right`,
`bottom_left`, `top_right` o `top_left`; `hud_scale`
admite 70–140 % y `hud_opacity` 30–100 %. Se mantiene
`hud_controls=auto/always/off`. Las opciones también están en
Bifröst Capture Studio; posición, escala, visibilidad y opacidad
pueden ajustarse desde el menú de reglas durante la partida.
Las etiquetas siguen los keybindings detectables por el motor.

**Pruebas necesarias:** ejecutar mkxp-z para verificar que la señal de
temperamento no tapa eventos, el zoom de Visual 2.5D respeta el
encuadre, el HUD cabe en 640×480 y no se pierden PS en cambios de escena.

## Gamefeel de exploración (revisión 1.0)

- **Lanzamientos encadenados:** con `aim_chain=1`, se puede mantener A,
  lanzar mediante C y seguir apuntando a otros Pokémon. Cada Pokémon tiene
  un bloqueo individual; no es posible duplicar capturas del mismo individuo.
  `max_flights=3` limita los proyectiles a la vez y reserva la cantidad
  de cada tipo de Ball antes de que impacte. Soltar A después de lanzar con C
  cierra la mira sin lanzar otra Ball accidentalmente.
- **Múltiples capturas:** los vuelos y las sacudidas se actualizan por separado
  en la misma escena, sin detener el mapa ni las demás criaturas. El Team
  no se lanza mientras hay capturas sin resolver, para no interrumpir un
  combate pendiente.
- **Aparición ambiental:** las criaturas generadas en el mapa se funden
  progresivamente durante `spawn_intro_frames=26` y dejan una onda suave a
  nivel del suelo, en el mismo viewport del mapa para respetar el 2.5D.
- **Agresivos:** primero detectan al jugador, lo miran, avanzan por pasos
  separados y avisan antes de iniciar el combate. Parámetros:
  `aggressive_notice_frames`, `aggressive_step_pause`,
  `aggressive_attack_windup` y `aggressive_chase_speed`.
  El nivel adicional (`aggressive_level_bonus`, 0–20) se puede editar
  desde Maker Studio y desde `pbBifrostRulesMenu`.
- **Capturas críticas:** el vuelo luce una estela cian y reproduce una
  señal especial al lanzar; el impacto tiene una fase de absorción más
  marcada, una onda brillante y una sola sacudida. El cue propio es
  `sfx_critical=none`, con fallback CC0 `real_critical.wav`.
  Es una interpretación original del gamefeel Legends, no su audio comercial.
- **Notificaciones:** se limpian al cambiar de escena o iniciar un combate.
- **HUD:** el panel Ball/Team ahora mide hasta 392×116 píxeles, permanece
  abajo a la derecha y utiliza indicaciones de teclas más grandes.

La experiencia debe verificarse en mkxp-z con movimiento, 2.5D,
prioridades de tiles, audio y accesibilidad. Los tests automáticos
no sustituyen ese test visual.

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

## Audio real incorporado (CC0)

El perfil `audio_profile=za_like` **continúa seleccionado por defecto**. Bifröst
prioriza los 12 archivos personalizados `za_*.ogg/.wav/.mp3` que proporcione
el autor; cuando no se dispone de ellos, reproduce 12 sonidos **reales**
`real_*.wav` ya incluidos en `Audio/SE/Bifrost/`.

Los archivos `real_*` proceden de **Kenney — Interface Sounds (CC0)**:
no pertenecen a Pokémon Legends: Z-A ni son muestras oficiales. Se ha
retirado la generación de tonos sintéticos. Los antiguos `za_*.wav`
generados por versiones anteriores se ignoran si conservan su formato y
duración original; es recomendable eliminarlos del disco local para
evitar confusión. El fallback Essentials solo se utiliza si faltan
también los archivos CC0.

Ver [AUDIO_GUIDE.md](AUDIO_GUIDE.md) y
[AUDIO_LICENSES.md](AUDIO_LICENSES.md) para la asignación de eventos,
su procedencia, licencia y las instrucciones para sustituir archivos.

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
