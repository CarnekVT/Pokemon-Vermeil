# Bifröst Capture — prototipo experimental 0.3.1

Compatible con la estructura de Pokémon Essentials 21.1 del repositorio. Integrado como plugin separado y editor de Maker Studio. **Requiere pruebas dentro de mkxp/Essentials.** No se modifican scripts de cámara BSS/BAS, 2.5D ni movimiento.

## Diseño oficial Bifröst

- Pokémon elegibles: Raikou, Suicune, Entei, Latias, Latios, Articuno, Zapdos, Moltres (incluidas formas de Galar), Mesprit, Uxie, Azelf, Cobalion, Virizion, Terrakion, Genesect, Landorus, Thundurus, Tornadus, Eternatus y Tapu Koko, Tapu Lele, Tapu Bulu, Tapu Fini.
- **Eventos elegibles solamente**: otros Pokémon visibles no se convierten accidentalmente en encuentros.
- El apuntado utiliza **7 columnas × 7 filas hacia delante** (3 columnas a cada lado), no un área centrada en el jugador. Distancia óptima: 4. Fila 8: fallo garantizado en perfil Bifröst.
- El jugador puede lanzar Poké Ball o enviar su Pokémon para iniciar un combate.
- Distancia ≤3 (Manhattan): reacción de huida o ataque. Efecto breve de impacto visual al acertar por espalda, bonus de captura y mayor probabilidad de captura crítica.
- La captura directa usa probabilidad propia del mod basada en el ratio de captura de la especie y modificadores simples de Ball, NO reproduce toda la fórmula de combate de Essentials. Sin presión de captura, estado alterado ni aturdimiento en la versión inicial.
- Los encuentros originales en hierba alta permanecen intactos.
- Las opciones para otras experiencias: perfiles **Classic**, **Adventure**, **Safari** o **Custom**, además de ajustes globales, por mapa, especie y evento.

## Lanzamiento sobre el mapa · nueva experiencia (video-referencia)

La versión actual dejó de utilizar una cuadrícula dibujada en toda la pantalla.
Su lanzamiento utiliza una retícula contextual que sigue la posición en pantalla
de los eventos Pokémon y se apoya en `screen_x/screen_y`, de modo que no
reescribe la cámara de Visual 2.5D HD. La referencia de los dos videos es:
mantener el mapa visible, elegir una Poké Ball desde un HUD discreto, apuntar
al Pokémon real y ver un proyectil que viaja hasta él, con efecto local al
impactar. Se usa el icono de la Ball existente en `Graphics/Items`.

**Controles basados en acciones de Essentials**, según la ventana de Key bindings:
- **W (AUX2)** abre/cierra el apuntado si `access_mode=always` o
  `nearby`. Con `access_mode=event` solo se abre por `pbBifrostAim`.
- **Flechas de movimiento** desplazan la retícula libremente en el mapa,
  sin mover al personaje, incluso cuando el ratón está desconectado.
- **C / Espacio / Enter (USE)** lanza la Poké Ball al Pokémon enfocado.
- **Q (AUX1)** cambia de Ball. Si la tecla de apertura se configura como AUX1,
  el cambio de Ball utiliza la acción ACTION.
- **Shift / Z (ACTION)** fija la retícula al Pokémon válido más cercano;
  mantenerla pulsada acelera el movimiento de retícula.
- **D (SPECIAL)** alterna Poké Ball y Pokémon para iniciar combate.
- **X / Esc (BACK)** sale del apuntado sin lanzar.
- **Ratón opcional:** desplazarlo cerca de un Pokémon coloca la retícula;
  clic izquierdo lanza si el motor expone `Input::MOUSELEFT`.
  El botón USE funciona sin ratón.

AUX1, AUX2, USE, BACK, SPECIAL y ACTION son acciones de Essentials.
Si reasignas las teclas en Key bindings, el plugin sigue esas acciones.
La retícula es verde cuando hay un objetivo dentro del alcance y con
trayectoria libre; roja cuando el objetivo está fuera o hay obstáculos.
El cálculo de impacto es idéntico para ratón y teclado, con geometría
recalculada al lanzar. En la configuración base, el contacto en la cuarta
casilla alineada tiene **100 % de precisión**, pero **capturar** al Pokémon
sigue siendo probabilístico. El HUD explica los fallos y la proximidad
de tres casillas continúa pudiendo provocar la reacción del Pokémon.

Opciones nuevas en Maker Studio → Lanzamiento:

```ini
[global]
aim_mouse=1
aim_keyboard=1
aim_speed=5
aim_target_radius=36
throw_frames=18
throw_arc=42
aim_chain=1
```

`aim_mouse` activa retícula bajo el ratón;
`aim_target_radius` ajusta el radio de enfoque (en píxeles);
`throw_frames` regula cuánto dura el vuelo y `throw_arc` su elevación
aparente; `aim_chain` permite lanzar de nuevo sin reabrir menús.
La trayectoria es una interpolación en pantalla, con arco visual, giro de la
Ball y destello de contacto. **No es una simulación balística con alturas
físicas ni un modelo 3D real.**

**Estado de validación:** el código está publicado; las animaciones, ratón,
transiciones, versión exacta de mkxp, modalidades de control y compatibilidad
con Turbo/Visual 2.5D siguen pendientes de pruebas en el juego.

## Activación en cualquier momento (nuevo)

En la configuración Bifröst revisada el lanzamiento está disponible en el mapa
con `access_mode=always` por defecto; otros proyectos pueden elegir `event`
o `nearby` desde el editor. También se puede habilitar el
apuntado en todos los mapas jugables, aunque en ese momento no haya un Pokémon
delante. Esta opción **no** hace capturables a los Pokémon decorativos ni
elimina la lista de especies admitidas. Para permitir otras especies además
de los legendarios, hay que desactivar `restricted_species` y etiquetar los
OWs correspondientes.

En `config.ini` dentro de `[global]` (o en un `[map:ID]`), configura:

```ini
; event: solo a traves de pbBifrostAim (por defecto)
; always: apuntado disponible en cualquier mapa jugable
; nearby: acceso solo cuando existe un OW elegible en el area de apuntado
access_mode=always

; aux2: W / aux1: Q / none: sin atajo (según Key bindings)
hotkey=aux2
```

Además, desde el juego se pueden cambiar **Acceso** y **Atajo**
mediante `pbBifrostRulesMenu`. Estos cambios se guardan con la partida y
prevalecen sobre el archivo INI hasta seleccionar "Restaurar reglas del
proyecto". Por defecto, Bifröst sigue siendo "Solo por evento".

Desde Maker Studio se cambian estos mismos parámetros con **Disponibilidad
de lanzamiento** y **Tecla de apuntado**. Si se elige `always`, pulsar W (AUX2)
abre la selección de Poké Ball/Pokémon y el apuntado sin necesidad de tocar
un evento. `none` desactiva solamente el atajo; los scripts continúan
funcionando con `pbBifrostAim`.

La apertura automática se bloquea durante combates, mensajes, menús,
transferencias, movimientos forzados, movimiento en curso e intérpretes de
eventos, para evitar interrupciones de escenas y de los controles del mapa.
Al lanzar sin seleccionar un Pokémon elegible, un lanzamiento puede fallar
y consumir una Ball según `consume_on_miss`.

## Maker Studio 0.2 · rediseño BAS/BSS

El panel se ha reconstruido con la organización de BAS y BSS:
**navegación de módulos (izquierda), escenario/previsualización (centro)
e inspector contextual (derecha)**, barra de herramientas, estado de cambios
y guardado explícito. Sus módulos son Vista general, Perfiles, Catálogo
Pokémon, Encuentros OW, Lanzamiento, Captura, Comportamiento, Ámbitos y
Diagnóstico.

En **Perfiles** se puede seleccionar Bifröst, Classic, Adventure, Safari,
OW completo o Custom, inspeccionar una tabla de diferencias (valor actual
frente a propuesto) y **Aplicar perfil**. Seleccionar una tarjeta no cambia
los datos. Aplicar no borra las sobrescrituras por mapa/especie/evento y hay
que guardar después.

El nuevo **Catálogo Pokémon** se guarda en `roster.ini` junto al INI de
reglas. Carga especies de `PBS/pokemon.txt` y
`PBS/pokemon_Vermeil.txt` cuando están disponibles, con búsqueda y
casillas para:
- Elegibilidad en la lista exclusiva Bifröst.
- Especies seleccionadas para aparición cuando `spawn_filter=allowlist`.
- Bloqueo de spawns de especies concretas.

**Editar** una especie abre el ámbito `species:ID`. Se pueden cambiar
forma OW (0 por defecto; 1 para las aves de Galar), niveles mínimos/máximos,
probabilidad individual de aparición, reacción, radio de alerta y captura.
El nivel y forma de eventos OW **ya colocados manualmente** siguen
definiéndose en su etiqueta. Las opciones por especie en el inspector
afectan en primer lugar a los OWs generados automáticamente.

## Encuentros: clásico, mixto y OW completo

En **Encuentros OW → Sistema de encuentros**:

- **classic** — encuentros originales de hierba y cuevas; no genera fauna OW.
- **hybrid** — conserva los encuentros aleatorios y también puede crear
  Pokémon visibles desde las tablas del mapa.
- **overworld** — reemplaza los encuentros espontáneos terrestres/cueva por
  apariciones visibles en casillas elegibles. El jugador puede abrir el
  apuntado o aproximarse al Pokémon para interactuar.

El perfil **full_ow** configura `encounter_mode=overworld`,
`access_mode=always`, `restricted_species=0`. Esta última configuración
permite capturar especies de las tablas de encuentros aunque no pertenezcan
al catálogo legendario Bifröst, pero los Pokémon decorativos originales siguen
sin ser capturables si no llevan su etiqueta.

Ejemplo:

```ini
[global]
profile=full_ow
encounter_mode=overworld
access_mode=always
restricted_species=0
spawn_chance=24
spawn_min_distance=3
spawn_max_distance=6
spawn_limit=4
spawn_lifetime=40
spawn_filter=all
spawn_grass_only=1

[species:ARTICUNO]
ow_form=1
ow_min_level=65
ow_max_level=70
ow_spawn_probability=60
reaction=attack
```

`spawn_chance` significa el porcentaje de **intento por paso** en terreno
elegible (24 no significa que solo el 24% de los encuentros serán OW). En
modo `overworld`, el **100% de los encuentros terrestres gestionados por
este sistema se realiza mediante OW**, pero no se fuerza una aparición en
cada paso; depende de la frecuencia configurada y de encontrar un tile válido.

Los OW autogenerados aprovechan los sprites de
`Graphics/Characters/Followers/ESPECIE[_FORMA].png`. Si falta sprite,
no se crea un OW invisible. Los eventos son temporales, con límite de cantidad
y duración, y usan las tablas PBS existentes del mapa. No sobrescriben ni
reescriben los mapas, encuentros PBS, BSS, BAS, Smooth Movement o Visual 2.5D.
**Pesca, Surf y encuentros guionizados conservan el comportamiento original.**

**Advertencia:** el generador de eventos es nuevo, y todavía debe probarse
en el ejecutable mkxp para verificar aparición, colisión, sprite y guardado.
No se considera listo para distribución.

## Preparar los eventos

En el nombre del evento, coloca:

- `[OWCAP:RAIKOU:50]` — Raikou salvaje, nivel 50, interactivo.
- `[OWCAP:ARTICUNO:70:1]` — Articuno de Galar, nivel 70, forma 1.
- `[OWDECOR]` — decorativo; no es capturable ni combatible con este sistema.

El evento debe contener su sprite de OW habitual. **No marca como objetivo a NPC, Pokémon de tejados, árboles ni decoración** salvo que se etiqueten expresamente con `OWCAP`. No uses esta etiqueta en los eventos decorativos.

Para abrir la interfaz desde un evento de mapa / controlador de captura, utiliza un comando de script:

```ruby
pbBifrostAim
```

Puedes enlazarlo a un objeto clave o comando de un menú mediante ese mismo método. Bifröst empieza con `access_mode=always` y atajo AUX2. Al configurar `access_mode=always` o `nearby`, la acción AUX2 (W) o AUX1 (Q) habilitada abre el apuntado sin necesitar un evento de mapa. Para abrir las opciones en una zona de juego:

```ruby
pbBifrostRulesMenu
```

Para fijar o restaurar opciones por evento desde scripts:

```ruby
BifrostCapture.set_rule("capture_enabled", "0")
BifrostCapture.set_rule("capture_enabled", "1")
BifrostCapture.reset_event(12,4)
```

Las opciones ingame se guardan en `PokemonGlobalMetadata` del archivo de partida. Las opciones del editor modifican el archivo `config.ini`. Las opciones ingame prevalecen sobre el INI donde se apliquen.

## Maker Studio

Menú **Mods → Bifröst Capture Studio**. Tiene controles de reglas, previsualización de la parrilla, perfiles y ámbitos `global`, `map:12`, `species:RAIKOU`, `event:12:4`. Se guardan cambios exclusivamente al pulsar **Guardar**, con lectura de verificación. Ajustar parámetros y reglas NO reescribe otros plugins.

## Limitaciones y pruebas pendientes

1. Comprobar la carga del plugin y el editor en la versión exacta de Maker Studio de Vermeil.
2. Validar nombres de eventos, obtención/consumo de Balls, captura y almacenamiento en PC, registro de Pokédex, formularios regionales y reacción de huida.
3. Validar que el evento no reaparece tras salvar y recargar, y restauración por script.
4. Probar los cuatro sentidos, los límites laterales, obstáculos, casilla 8, distancia 3, Turbo y mapas 2.5D.
5. Se ha implementado una **primera trayectoria animada en pantalla**, icono real de Ball, retícula contextual y destello local. Falta validarla ingame y completar lanzamiento del personaje, sonidos, shakes de captura y efectos de vuelo/rebote; todavía no es física balística real.
6. Los errantes que usan la mecánica de Roaming de Essentials no se vinculan automáticamente al estado del evento `OWCAP`. La aparición y desaparición de OWs, la sincronización de su captura con el sistema de errantes y la persistencia de individuos requieren integración adicional.
7. `WildBattle.start` inicia el combate normal, pero la versión inicial no bloquea automáticamente el lanzamiento de Balls durante ese combate; si el diseño lo requiere se integrará una regla de batalla aparte.
8. Las opciones in-game son un menú opcional invocado por script, no una entrada añadida al menú de pausa por defecto.
9. El atajo configurable depende del mapeo de `Input::AUX1` y `Input::AUX2` de Vermeil. Comprobar conflictos con otros plugins y testear su respuesta junto a Turbo y Movimiento. La apertura en `always` se añade como código, pero aún no se ha validado ingame.

## Archivos

- `001_Core.rb`: INI + perfiles + cálculos + eventos + persistencia.
- `002_Runtime.rb`: selección de bolas/Pokémon, apuntado y resolución.
- `003_RulesMenu.rb`: ajustes opcionales ingame.
- `004_OverworldEncounters.rb`: fauna visible temporal basada en las tablas de encuentros, con modo completo o mixto.
- `roster.ini`: catálogo Bifröst editable y filtros de fauna por especie.
- `config.ini`: reglas oficiales Bifröst, incluyendo `access_mode` y `hotkey`.
- `Plugins/MakerStudio/003_Editor/Mods/com.vermeil.bifrost-capture`: editor de tres paneles estilo BAS/BSS, módulos, comparador de perfiles y catálogo.
- `ROADMAP.md`: seguimiento de funciones, límites y pruebas.
- `tests/bifrost_capture_core_test.rb` (raíz del repositorio): pruebas básicas Ruby.
