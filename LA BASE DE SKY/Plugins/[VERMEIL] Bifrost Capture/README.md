# Bifröst Capture 0.5.1 — corrección de encuentro OW y compatibilidad de batalla

**Pokémon Vermeil · Pokémon Essentials 21.1 · rama `feature/bifrost-overworld-capture-studio`**

Los archivos Ruby 001–006 y el editor Maker Studio se sustituyeron por implementaciones nuevas. No se añadió el plugin chino ICS ni se copiaron sus scripts; se tomó como referencia su separación de componentes, su HUD compacto y los modos de pulsación. El recurso original de ZIJUK está diseñado para trabajar junto con **Visible Overworld Wild Encounters (VOWE)**; esta reconstrucción tiene su propia integración con las tablas de encuentros de Essentials y no necesita VOWE instalado.

## Dos formas de usarlo

**Configuración Bifröst (preset):** `profile=bifrost`, `encounter_mode=classic`, `restricted_species=1`. Permanece disponible en Maker Studio. **En esta rama de pruebas se activa `profile=full_ow` por defecto**, para que el modo de fauna visible realmente se ejecute. Los legendarios OW colocados manualmente y declarados mediante etiquetas pueden capturarse.

**Proyecto con fauna visible completa:** abre Maker Studio → **Perfiles** → **OW completo** → **Aplicar perfil** → **Guardar cambios**. Se establece:

```ini
[global]
profile=full_ow
encounter_mode=overworld
restricted_species=0
access_mode=always
capture_enabled=1
```

La tirada normal del encuentro de hierba o cueva se convierte en **un evento Pokémon visible y capturable**. Ya no existe una tirada independiente que haga aparecer un OW diferente del encuentro original. La misma entidad mantiene especie, nivel, forma, event_id y estado de captura/huida.

En modo completo, **todos los Pokémon naturales generados son capturables** incluso si una configuración heredada conserva `restricted_species=1`. Esa restricción continúa aplicándose a los eventos manuales. Los eventos decorativos marcados `[OWDECOR]` nunca se vuelven capturables.

**Límite conocido:** es necesario un gráfico de personaje `Graphics/Characters/Followers/ESPECIE` o variante de forma. En OW completo, si falta el recurso o no se encuentra una casilla válida, **se cancela el encuentro sin abrir batalla normal** y se registra un aviso de diagnóstico. Se intenta también una casilla cercana transitable. En modo mixto sí se puede mantener el encuentro normal. Surf, pesca y encuentros por script permanecen originales. La integración específica con otras bibliotecas OW se puede hacer mediante `register_ow`, no detectando NPCs indiscriminadamente.

## Controles de Essentials (según Key bindings compartido)

| Acción | Teclado actual | Uso |
|---|---|---|
| AUX2 | **W** | Entrar/salir del apuntado |
| AUX1 | **Q** | Cambiar Ball o Pokémon equipado |
| USE | **C, Espacio, Enter** | Lanzar |
| BACK | **X, Esc** | Cancelar |
| SPECIAL | **D** | Alternar Ball / Pokémon |
| ACTION | **Z, Shift** | Enfoque rápido al OW más cercano |
| Direcciones | Flechas | Mover la retícula |
| Ratón | Movimiento/clic | Apuntar y lanzar (si mkxp expone la entrada) |

`control_mode=toggle`: W abre, USE lanza. `control_mode=hold`: mantener W prepara; soltar lanza. Todos los controles se interpretan mediante las acciones de Essentials, no mediante caracteres del teclado.

## Encadenamiento del sistema

1. **Encuentro nativo:** `PokemonEncounters#encounter_triggered?` realiza su cálculo habitual. Si el modo lo permite, la tirada se transforma en un evento OW (solo tierra/cueva).
2. **Registro único:** `[OWCAP:PIKACHU:6:0]` y `BifrostCapture.register_ow(event, species, level, form)` son las dos formas de enlazar especies y eventos.
3. **Apuntado:** la retícula consulta las coordenadas visuales de `Sprite_Character` cuando están disponibles. No hace visible una malla de 7x7 en juego.
4. **Lanzamiento:** la animación sigue al objeto `Game_Event` elegido, con arco, giro, sombra de contacto y retícula; al terminar, la colisión se recalcula respecto a ese mismo evento.
5. **Impacto y captura:** se separa acertar el lanzamiento de capturar el Pokémon. A cuatro casillas alineadas, el impacto tiene una precisión predeterminada del 100 %, no un 100 % de captura. Hay bonus por espalda y sacudidas visuales.
6. **IA:** un OW con `reaction=flee` intenta correr varias casillas antes de desaparecer. Escapar nunca escribe la bandera de captura persistente. `reaction=attack` inicia combate cuando termina la interfaz de apuntado.

## Eventos OW manuales

Para un evento en el editor, el nombre puede ser:

```text
[OWCAP:RAIKOU:50]
[OWCAP:ARTICUNO:70:1]
[OWDECOR]
```

Para un OW generado por otro script:

```ruby
evento = $game_map.events[17]
BifrostCapture.register_ow(evento, :RAIKOU, 50, 0)
```

El ID es ilustrativo. Se registra cuando el evento se crea. Un sprite sin etiqueta o registro no consume una Ball por accidente. Para incluir especies fuera del catálogo legendario en eventos manuales, usar `restricted_species=0`.

## Configuración y editor

`config.ini` guarda los **53 parámetros** del motor y permite `[global]`, `[map:ID]`, `[species:SPECIES]` y `[event:MAP:ID]`.

`roster.ini` guarda el listado Bifröst exclusivo, lista permitida de apariciones (para `spawn_filter=allowlist`) y especies bloqueadas.

Maker Studio 0.5 se rehizo con navegación por módulos, escenario, inspector contextual, comparación de perfiles y catálogo editable. Al guardar, vuelve a leer `config.ini` y `roster.ini` para confirmar la escritura. Si se edita el INI fuera de Maker Studio, usar **Recargar** en el editor y reiniciar el juego para reabrir las opciones de ejecución.

El menú opcional dentro de la partida está disponible por `pbBifrostRulesMenu` y conserva sobrescrituras únicamente en el guardado de la partida.

## Validación y límites

- Hay pruebas automatizadas para perfiles, alcance de 7 casillas, aparición desde encuentros naturales, captura/almacenamiento, lanzamiento vacío y huida visible.
- GitHub Actions comprueba sintaxis de todos los módulos Ruby, sintaxis ES module del editor y tests Ruby aislados.
- **NO se ha ejecutado el juego en mkxp en esta revisión**. Falta validar visualmente posición real de proyectiles y retícula con Visual 2.5D HD, FPS, sincronización con Turbo, sonido, animación del entrenador, guardado/cargas y captura de legendarios errantes de Essentials.
- El mapa debe tener las tablas naturales de encuentros y gráficos Followers para poder ofrecer fauna visible. En OW completo no se abre combate normal si faltan recursos; la aparición se omite y se deja un aviso.
- No se modifica BSS/BAS ni la cámara de combate: los combates OW pasan por el disparador habitual de `WildBattle`.

**Parche 0.5.1:** se corrigió el enlace de `pbFrameUpdate` entre SleepAnimations y Suncorona/Eclipsora, se activó OW completo en la configuración de pruebas, se impidió la caída de OW completo a batallas normales y se añadió `Game_Map#register_event` al generar un OW para garantizar que Essentials lo actualice. Hay tests aislados de esos tres casos.

Consultar `ROADMAP.md` para la lista de seguimiento actualizada.
