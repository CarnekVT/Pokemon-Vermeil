- **v1.0.86:** reconstruye el estado de **Afterimage de Element**: **Trail y Burst se activan por separado**, ninguno bloquea al otro, pueden coexistir, los frames activos del Trail usan rangos válidos por defecto y el Burst puede terminar su vida aunque el Element original ya haya acabado.
- **v1.0.85:** corrige el bloqueo del **Burst de Afterimage**. El modo Burst, su checkbox y los botones **Activar/Desactivar burst** ya no dependen de que el afterimage maestro esté activado antes; al elegir/activar Burst, BAS habilita automáticamente lo necesario.
- **v1.0.84:** el **Burst de Afterimage de Element** ahora tiene **BURST activo**, botones **Activar burst / Desactivar burst** y conserva su frame/parámetros al apagarlo.
- **v1.0.83:** corrige el error de carga **Unexpected end of input** de v1.0.82 y añade al **Trail Afterimage** un rango explícito **ACTIVO desde frame / DESACTIVAR en frame**, con botones para usar el frame actual.
- **v1.0.82:** añade **Afterimage de Element en modo Burst**: eliges un **frame exacto** y BAS genera copias de esa pose que pueden **agrandarse**, **expandirse**, **desvanecerse** y desaparecer. Trail y afterimage de partículas siguen intactos.
- **v1.0.81:** añade presets claros para **apuntar el gráfico según la dirección** del emitter (**→ / ↑ / ← / ↓**) y un preset **Acupresión** para manos/gráficos verticales, evitando tener que adivinar el offset manual.
- **v1.0.80:** corrige la intención de **Particle Change**: la secuencia puede animar ahora **la misma partícula durante su vida** (`A → B → C`) con velocidad `cada N frames`, manteniendo gráfico + frame de tira por paso. Añade además **giro continuo °/s** y rehace la explicación/presets del **afterimage de elements** para dejar claro que copia estados de frames anteriores y necesita movimiento/rotación/escala para verse.
- **v1.0.79:** la **secuencia de gráficos del emitter** ahora también puede definir el **frame de tira/spritesheet por slot**, para hacer patrones como `A f0 → A f1 → A f2` o mezclar gráfico + frame. Se edita directo en cada fila de la secuencia.
- **v1.0.78:** corrige el cambio de vista **Player → Foe / Foe → Player** para que las rutas con puntos `screen` no se roten 180° ni inviertan su altura. Ahora se intercambian los extremos User/Target manteniendo la desviación vertical de arcos, saltos y trayectorias con varios keys.
- **v1.0.77:** añade **Afterimage / estela** configurable tanto para **elements** normales como para **partículas de emitter**, ideal para manos tipo Acupresión, cortes y estelas de impacto. Mantiene además la orientación manual/viaje del gráfico y el patrón secuencial de gráficos por emitter.
- **v1.0.76:** los emitters separan explícitamente la **dirección de viaje** de la **orientación del gráfico** (Recto/manual, seguir recorrido o compatibilidad PBS), de modo que Giro 0° ya no rota por la ruta. Añade además **patrones secuenciales de gráficos** A→B→C repetibles por partícula o por emisión, con Preview y Runtime PE21/LBDS.
- **Public Fix 33:** añade modo **Pantalla completa** para desacoplar temporalmente BAS del panel de Maker Studio y ocupar todo el viewport sin solaparse con la interfaz madre. Disponible por botón, menú Vista/Herramientas y `F11`; `Esc`/`F11` restaura el editor a su posición original.
- **Public Fix 29:** corrige `Leer` dentro de Snap Trap del Initial Pack para usar interpretación **Vanilla RMXP / grid** (5 frames de 64×64) en vez de Automatic; las instalaciones existentes se reparan al cargar sin reemplazar keyframes del usuario.
- **Public Fix 28:** añade centrado de elementos/battlers a pantalla, hace que duplicar una selección copie sólo los keyframes/propiedades elegidos, corrige Explosion del Initial Pack (sheet 4×3 y capas BG/Fade) y adapta el zoom de cámara al cambiar entre formatos de pantalla como 640×480 y 640×440.
- **Public Fix 27:** `Graphics/AnimationStudio` pasa a ser una fuente oficial y prioritaria del Studio. El escáner, reparación de referencias importadas, preview, localización y Runtime PE21/LBDS encuentran los gráficos que el propio BAS copia a esa carpeta; las máscaras PBS también usan el mismo resolver en vez de asumir `Graphics/Battle animations`.
- **Public Fix 23:** mejora la edición de frames, corrige la carga visual inicial, Mostrar/Ocultar ahora crea keys de opacidad para fades y el Runtime incluye lector JSON interno cuando Ruby no trae `json`.
- **Public Fix 12:** hotfix de carga: corregido el error JavaScript `missing ) after argument list` en el diálogo de battlers introducido al restaurar los presets DBK/Gen 4. Se mantiene intacta la lógica de Fix 11 para posiciones 1v1/2v2/3v3, tamaños manuales y selección de battlers.
# Battle Animation Studio v1.0

Battle Animation Studio es un editor visual de animaciones de combate para **Pokémon Essentials v21.1**, integrado en Maker Studio. Permite crear, importar, organizar, previsualizar y exportar animaciones **Move, Common y Custom** con una timeline editable y un Runtime ingame incluido.

## Para empezar

1. Abre **Qué es el programa** desde la Library si quieres una explicación rápida del flujo general.
2. Abre **Tutoriales** en cualquier momento desde la Library o el menú Help.
3. Crea o abre una animación, selecciona User/Target o un efecto y edita sus propiedades por frame.
4. Usa **Acciones** para insertar efectos, emitters, Common visuales, animaciones rápidas o una animación completa de tu propia biblioteca.
5. Marca la variante que deba usarse ingame y exporta la biblioteca al proyecto.

## Funciones principales

- Timeline por frames con Position X/Y, escala, opacidad, rotación, Tone, Flip H/V, prioridad de capa, cámara y más.
- User/Target semánticos que se adaptan a Singles, Doubles, Triples y formaciones asimétricas.
- Preview con battlers reales del proyecto y soporte de métricas/formatos compatibles.
- Importación de PBS/New Animation Editor, RXDATA y Ruby/Code.
- Gráficos, spritesheets, partículas/emitters, SE, cámara y prioridades relativas a User/Target.
- Common y clips reutilizables.
- **Animaciones rápidas** editables: Puño, Mordisco, Golpe, Patada y Corte, integradas como prefabs internos y utilizables directamente desde **Acciones**.
- Inserción de **animaciones completas dentro de otras animaciones** como copia editable, sin crear una dependencia externa.
- Exportación portable `.animpack` y compilación para el Runtime ingame.
- Interfaz Español/English.

## Preview de battlers

Al iniciar sin una selección explícita, el Studio usa automáticamente el **primer battler real disponible en orden alfabético** para Player/Back y Foe/Front. `AnimBackTest.png` y `AnimFrontTest.png` siguen incluidos únicamente como preset de prueba opcional; nunca son la selección predeterminada.

Para el perfil **Native / Gen 4**, la escala base del Studio es **x1**. El preset **DBK** lee las escalas del proyecto; en el proyecto de referencia son **Back ×3 / Front ×2**. **Auto** usa el renderer detectado y un tamaño escrito manualmente para Player/Foe se mantiene aunque cambies de especie.

En **1v1, dobles y triples**, la formación se obtiene de `Battle::Scene.pbBattlerPosition(index, sideSize)` y después se aplican las mismas Pokémon Metrics que usa el juego/New Animation Editor. Si existe una captura viva con el mismo formato, Auto puede conservarla; el modo Script fuerza la reconstrucción desde esas reglas del proyecto.

## Propiedades y spritesheets

Las **Spritesheet Options** permanecen abiertas y visibles en las propiedades del elemento. El inspector también ofrece navegación rápida por secciones para reducir desplazamiento sin eliminar opciones avanzadas.

## Reutilización

En **Acciones** puedes insertar una Common visual, un Clip guardado, uno de los bloques rápidos o una animación completa existente. Al insertar una animación completa se copian sus elementos a la timeline actual para que puedas modificarlos de forma independiente.

## Pack inicial incluido

El **Initial Pack está embebido dentro del propio Battle Animation Studio**; no se distribuye ni se busca como ZIP/RAR externo. Contiene las animaciones de ejemplo, sus gráficos y los SE que necesitan tanto esas animaciones como los prefabs rápidos.

Al abrir esta build por primera vez, el Studio pregunta si quieres **instalar el Initial Pack**. Si aceptas, lo instala directamente desde los datos internos del mod: añade los ejemplos a la Library, reutiliza los gráficos/SE que ya existan en el proyecto y sólo crea los recursos que falten. También puedes hacerlo después desde **Library → Instalar Initial Pack**.

El pack incluido contiene ejemplos de **Explosion**, **Snap Trap** y **Volt Tackle**, además de la variante adicional de Snap Trap incluida en el pack original.

## Runtime

El plugin `Battle Animation Studio Runtime` reproduce ingame la biblioteca compilada por el Studio. Está dirigido a **Pokémon Essentials 21.1**.

**Autor:** CarnekVT

## Ajustes de la build pública (feedback)

- **Tutoriales visuales por flujo:** cada tema es desplegable y separa claramente dónde entrar, qué hacer y qué comprobar. Cubren creación, battlers/contexto, gráficos, keyframes, spritesheets, prioridad, emitters, reutilización, Initial Pack y exportación sin convertir el panel en una pared de texto.
- **Navegación de propiedades por sección:** el inspector tiene búsqueda de secciones e incluye secciones reales como `Gráfico`, `Transform`, `Tone`, `Emitter` y `Spritesheet y opciones → Prioridad de capa`.
- **Warnings:** se muestran como acceso propio en la barra del editor y ya no viven dentro de Help.
- **English UI:** se amplió la traducción de etiquetas, navegación, prioridad, gráficos y textos dinámicos para evitar fragmentos en español al usar EN.
- **Battlers/contextos:** 1v1/2v2/3v3 y formaciones asimétricas siguen `Battle::Scene.pbBattlerPosition` + Pokémon Metrics del proyecto. El Preview Bridge exporta también la tabla 1/2/3 calculada por el propio juego. Cambiar Player/Foe no fuerza `AnimTest`, no cambia el tamaño manual y cada lado conserva su selección Front/Back.
- **Copias:** duplicar elementos o insertar otras animaciones conserva las propiedades/metadata del gráfico y fuerza la carga de los recursos de la copia sin esperar a seleccionarla.
- **Prioridad:** Preview y Runtime usan la misma base de capas que el New Animation Editor (`Background = 100`, `Foreground = 2000`). Respecto a User/Target, `0` se resuelve inmediatamente encima del battler para evitar empates de Z en RGSS, `-1` queda detrás y `+1` añade otro paso por encima.
- **Redo:** enfocar o seleccionar controles ya no destruye el historial de Redo; se limpia solo cuando el proyecto realmente cambia.
- **Animaciones rápidas:** Punch, Bite, Hit, Kick y Slash intentan usar directamente `fist.png`, `fangs.png`, `hit.png`, `Kick.png` y `slash.png` desde `Graphics/Battle animations`.

Los cinco gráficos usados por esos presets también se incluyen en `Default Graphics/Battle animations` como referencia/copia de respaldo.


## v1.0.15 preview/camera fixes
- Auto/Script preview never imports battler species or temporary poses from the last live battle. Runtime is explicit-only.
- Allied targets resolve Target anchors, view/profile and local effects on the ally physical side.
- Camera Focus User/Target centers the battler and follows its authored movement; Reset returns to a free camera.

## v1.0.16 camera timeline fix

- Camera **Focus User**, **Focus Target** and **Free / Reset** are stored as explicit camera timeline keys.
- The Camera row shows a dedicated focus marker and a visible span for the interval in which User/Target tracking remains active.
- Expanding Camera exposes a **Focus / Follow** channel so focus changes are visible independently from Pan/Zoom/Rotation keys.
- Focus keys can be selected, dragged, range-selected, duplicated and deleted from the timeline.
- Triggering a focus action selects its focus key together with the camera value keys created on that frame.


## Camera Focus / límites (v1.0.17)
- Focus User/Target hace transición desde el foco anterior, sin salto intermedio a cámara neutra.
- Pan X/Y manual se conserva como offset; cambiar Focus no lo borra.
- Auto/Pantalla mantiene un battleback estándar dentro de sus límites y compensa rotación con el zoom mínimo necesario.
- Extendido/EBDX permite recorrido libre para fondos o escenas mayores que la pantalla.


## Fix 18
- Initial Pack: instalación más resistente; reutiliza gráficos existentes del proyecto cuando están disponibles y permite reintentar si falla.
- Biblioteca: nueva acción “Duplicar animación”, obligando a usar un nombre distinto.
- Exportación .animpack individual/grupal: ahora copia también los SE usados junto al paquete.
- Configuración general: el nombre visible del Studio se puede editar por proyecto.
- Animaciones rápidas: Punch, Bite, Hit, Kick y Cut usan los prefabs manuales de CarnekVT como base editable.


## Fix 19
- Corrige la regresión de sintaxis de Fix 18 (`missing ) after argument list`) en la normalización de rutas de audio/prefabs.
- Initial Pack incluye y prepara los SE usados por sus animaciones y por los prefabs rápidos.
- Importar `.animpack`: si el SE lógico ya existe en `Audio/SE`, se reutiliza sin duplicarlo; si falta, se copia desde el paquete conservando su ruta lógica cuando es posible.
- Quick Animations: sus prefabs llevan audio embebido y pueden crear el SE faltante incluso si no se instaló antes el Initial Pack.


## Fix 20
- Distribución unificada: Initial Pack y prefabs forman parte del propio Battle Animation Studio; no requieren ZIP/RAR externos.
- Initial Pack: instalación 100% interna desde datos embebidos, incluyendo gráficos y los 17 SE requeridos por ejemplos y prefabs.
- Animaciones rápidas: Puño, Mordisco, Golpe, Patada y Corte se insertan directamente desde **Acciones** como prefabs editables; no aparecen como paquete independiente que el usuario tenga que importar.
- Audio: antes de crear un SE, el Studio comprueba `Audio/SE` y reutiliza el archivo existente; sólo escribe el audio embebido cuando falta.
- Se elimina de la distribución la carpeta fuente redundante `Initial Pack`, ya que su contenido está embebido en `initial_pack.js`.

### v1.0.22

- Initial Pack: añadido **Common Snap Trap** como animación Common independiente de Move Snap Trap.
- Common Snap Trap reutiliza `Graphics/Battle animations/fangs.png` y `Audio/SE/Anim/PRSFX- Bite` si ya existen; sólo los crea desde los datos embebidos cuando faltan.


## Runtime compatibility (v1.0.30)
- **Essentials v21.1 Vanilla:** BAS installs `001_Runtime_PE21.rb` as `001_Runtime.rb`; no `Last`/`Priority` metadata and no New Animation Editor dependency. The camera uses a vanilla-safe single-render frame pump.
- **LBDS / Base de Sky:** BAS installs `001_Runtime_LBDS.rb` as `001_Runtime.rb`; keeps Sky load-order metadata. New Animation Editor is optional; if absent, BAS uses its own renderer/focus/camera path and non-BAS animations fall through to the available battle scene.


## Fix 28 — Bifros/Drac compatibility

- Added **Center on screen** for effects and battlers; it creates a screen-space position key at the current frame.
- Ctrl+D and selected-key duplication now copy **only the selected properties/keyframes**. Full-frame duplication remains an explicit frame operation.
- Fixed bundled Explosion sheet metadata (`PRAS- Explosions.png` is 4x3 at 192x192) and made both preview/runtime validate RMXP sheet metadata against the real bitmap.
- Explosion BG/Fade receive explicit background/foreground layer references so custom battle scenes do not hide them behind battlebacks/UI.
- `cameraBoundsMode=auto` is now adaptive: authored zoom-out survives resolution/aspect changes (e.g. 640x480 -> 640x440). Explicit `screen` keeps strict edge clamping; `extended` stays unrestricted.
- Applied camera and sheet fixes to both PE21 Vanilla and LBDS runtimes.


## FIX30 · Runtime sync + command bar
- Exporting the Library now compares the installed Runtime version with the Runtime embedded in BAS.
- Older Runtime: updated automatically. Same version: preserved without unnecessary writes. Newer Runtime: preserved and reported instead of being downgraded.
- A Runtime status badge in the Library shows missing, outdated, current or newer state.
- The Library header is grouped into New/Save/Undo-Redo plus Import, Game, Tools and Help menus to avoid a long row of unrelated actions.

## v1.0.31 · Tutorial overhaul

- Added **Quick Start / Tutorial fugaz**, a seven-step guided overview for creating, animating, previewing and exporting a first BAS animation.
- Rebuilt **Tutorials** as a section-based visual manual: Basics, Elements & Graphics, Frames & Keyframes, Movement & Anchors, Camera, Spritesheets, Particles, Audio, Reuse/Initial Pack, Import/Compatibility, Gameplay/Runtime and Testing/Troubleshooting.
- Tutorials remain bilingual (ES/EN) and use short *Do / Check* cards instead of long text walls.
- Runtime remains **1.0.30** in this editor-only release because gameplay/runtime code did not change.


## Fix 32
- Tutorial dialogs now resolve the live ES/EN selector and English aliases reliably.
- The implicit preview battler skips `000`; it remains manually selectable.
- Center on screen uses visual bounds and forces manual Screen space, accounting for bottom/top-left origins.
- Automatic recovery writes `animations.recovery.json`; only Save/Ctrl+S updates `animations.json`.




## v1.0.75 · Test(48) · Pausa APS/DBK + sombra
- `Pause/Resume` ya no bloquea `Battle::Scene::BattlerSprite#update`.
- BAS marca directamente el `DeluxeBitmapWrapper` (`@_iconbitmap`/`@_iconBitmap`) del User o Target seleccionado y su wrapper de sombra.
- Se interceptan `DeluxeBitmapWrapper#update` y `#update_pokemon_sprite`; mientras está pausado no avanza ningún cel del spritesheet.
- Al reanudar se compensa `@last_uptime`, por lo que continúa desde el mismo frame y con el tiempo restante del cel, sin salto ni catch-up.
- User y Target se pueden pausar independientemente y la pausa sólo vive entre las keys Pause → Resume.
- X/Y, zoom, Impact, tone, opacity, cámara, UI y efectos BAS siguen actualizándose durante la pausa.
- La opacidad del battler ahora escala proporcionalmente la opacidad base de su sombra (incluidos targets replicados), y ambos estados se restauran al terminar la animación.

## v1.0.74 · Pause/Resume ingame real

- `Pausar/Reanudar animación` ya no depende únicamente de `pbFrameUpdate`: mientras el canal `Animación sprite · Pausa` está activo, BAS intercepta cualquier `Battle::Scene::BattlerSprite#update` del battler correspondiente.
- Compatible con rutas extra de actualización usadas por DBK / Animated Pokémon System; sólo se congela la animación interna del sprite, no la timeline BAS, cámara, partículas, UI ni otros battlers.
- Los canales discretos respetan su valor base antes de la primera key: una pausa colocada en F20 ya no se considera activa desde F0.

## v1.0.73 · Focus estable + Emitters contextuales + Gen 5

- **Impact restaurado:** vuelve a usar su recoil + pulse original. El arreglo está en la cámara: Focus User/Target sigue el **slot estable** del battler y ya no compensa Impact, Dash, recoil ni otros desplazamientos BAS.
- **Emitter contextual Player/Foe:** al editar en modo **Vista**, los parámetros numéricos/booleanos del emitter y partícula crean keys `Vista · Emitter` / `Vista · Partícula` en Timeline sin contaminar la otra vista. Incluye velocidad, apertura, gravedad, spawn, radios, distancia, FIN/through, dirección, onda/zigzag, stop, orientar al viaje y vida (duración, tamaño, opacidad y giro).
- **Paridad Preview/runtime:** los tres runtimes (normal/PE21/LBDS) resuelven esas keys con el mismo lado contextual. La vida contextual se evalúa en el frame de nacimiento de cada partícula.
- **Ejemplos Gen 5 ampliados:** la biblioteca de Examples contiene 62 comportamientos editables. La tanda añadida desde el video de referencia cubre curas ascendentes/pulsos, sueño, veneno/esporas, nieve/granizo/arena/viento/tornado, bursts de fuego/agua/hielo/roca/tierra, anillos eléctricos, órbitas psíquicas/fantasma, Dark Pulse, Leaf Storm, meteoros, carga/aura, estados/corazones, beams, multishot, drain spiral, explosión, ondas sónicas, telaraña y mud splash. Los gráficos siguen siendo reemplazables.

### Variables de emitter disponibles por timeline/contexto

`emitterRate`, `emitterIntensity`, `emitX/Y`, `emitX/YRange`, `emitSpeed/Range`, `emitAngle/Range`, `emitGravity/Range`, `emitPeriodX/Y/Z` y rangos, `emitRadiusX/Y/ZRange`, `emitClockwise`, `emitZoom/ZoomX/ZoomYRange`, `particleSize/Range`, `particleOpacityStart/particleOpacity/particleOpacityEnd`, `randomFrameMax`, `randomAngleRange`, `randomInvertFlip`, `randomInvertAngle`, `radiusX/Y/Z`, `simpleDistancePx`, `simpleThroughTargetPx`, `simpleDirectionOffset`, `waveEnabled`, `waveAmplitude`, `waveCycles`, `simpleStopAtDestination`, `simpleFaceTravel`, `simpleFaceTravelOffset`, FIN personalizado X/Y y `life.duration/birth/mid/death` para escala, opacidad y rotación.
