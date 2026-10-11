# v0.11.28 — Evolution Method Classification Fix

- Corrige el parseo de evoluciones con métodos sin parámetro (`Trade`, `Happiness`, etc.) sin desplazar la especie/método siguiente.
- Un método añadido hacia una evolución ya existente ya no activa `New Evo`.
- Separa evoluciones nuevas, métodos añadidos y métodos modificados.
- Los parámetros de objetos usan nombres localizados (`THUNDERSTONE` → `Piedra Trueno`).
- Normaliza en memoria strings legacy mal alineados sin escribir en PBS.
- Desactiva el parche temporal de registro de especies de v0.11.27.

# v0.11.26 — Hard shutdown del runtime legacy PBS Changes

- El paquete ahora sobrescribe físicamente los cuatro scripts históricos de `Plugins/[CARNKEVT]ChangeDex/`.
- Esos scripts pertenecían al runtime antiguo que realizaba escaneos `PBS Changes / PBS Vanilla Delta`.
- La limpieza ya no depende de abrir ChangeDex Studio antes de compilar.
- Se mantienen neutralizadas las copias legacy de MakerStudio.
- No se modifica ningún PBS ni los datos de Golden Power.

# v0.11.26 — Real MakerStudio legacy path cleanup

- Corrige la ruta de despliegue del stub legacy: el archivo que realmente carga tu proyecto es `Plugins/MakerStudio/001_ChangeDex.rb`, porque `[MakerStudio]` en la traza es el **nombre del plugin**, no el nombre de la carpeta.
- Las versiones 0.11.21–0.11.24 neutralizaban por error `Plugins/[MakerStudio]/001_ChangeDex.rb`; esa ruta no reemplazaba la copia legacy real.
- `Plugins/MakerStudio/001_ChangeDex.rb` ahora es un stub puro sin `install_hooks!`, sin aliases de `GameData` y sin llamadas a `Compiler`.
- Se conserva además el stub en `Plugins/[MakerStudio]/001_ChangeDex.rb` solo como limpieza defensiva.
- El runtime activo `[CARNKEVT] ChangeDex` mantiene la arquitectura compiler-transparent de v0.11.24: el JSON se aplica después de Compiler, desde `Game.initialize`.
- El paquete de actualización está enraizado en `Plugins/` para instalarse desde la raíz del proyecto y reemplazar la ruta correcta.

# v0.11.24 — Compiler Transparent

- ChangeDex deja de parchear por completo `Compiler` (`main`, `compile_*`, `write_*`, etc.).
- Elimina los aliases globales de `GameData::Species`, `GameData::Move` y `GameData::Ability` (`get`, `try_get`, `each`, `each_species`, `load`).
- `pokemon_changes.json` se aplica únicamente al entrar al runtime desde `Game.initialize`, después de que la compilación PBS haya terminado.
- Al abrir ChangeDex se fuerza un refresh del overlay JSON, sin tocar PBS ni Compiler.
- Esto devuelve a LA BASE DE SKY/New Animation Editor el control completo del compilador y evita que ChangeDex aparezca dentro de `validate_all_compiled_pokemon`.
- Se retiran los experimentos de expansión automática de `pokemon*.txt` de v0.11.22/0.11.23; ChangeDex ya no modifica los argumentos del compilador.

## v0.11.23

- Corrige el orden de carga tras retirar el hook de `Compiler.main`: el guard de ChangeDex se instala de forma diferida desde `GameData.get_all_pbs_base_filenames`, justo antes de que Essentials compile PBS.
- `compile_pokemon` vuelve a quedar protegido antes de vaciar `GameData::Species`, incluso si `Compiler` todavía no existía cuando cargó el plugin.
- Mantiene la compatibilidad con New Animation Editor sin reintroducir el bucle `main -> main`.
- Golden Power/Arcane no son la causa directa del `CROBAT` ausente; sus cambios de PBS pueden forzar una recompilación y exponer este fallo de orden de carga.

## v0.11.22

- Corrige la causa real del falso `Valor CROBAT no definido en GameData::Species`: Essentials vacía el registro completo al iniciar `compile_PBS_file_generic`, por lo que compilar una sola capa (`pokemon_Vermeil.txt`) dejaba fuera las especies de `pokemon.txt`.
- Si cualquier editor/plugin pide compilar solo un `pokemon_*.txt`, ChangeDex expande la llamada a todas las capas hermanas (`pokemon.txt`, `pokemon_balance.txt`, `pokemon_Vermeil.txt`, etc.) antes de validar.
- La misma protección se aplica a capas partidas de `items*.txt`, `moves*.txt` y `abilities*.txt`, evitando falsos IDs ausentes como `BLACKAUGURITE`.
- `pokemon_forms*.txt` y `pokemon_metrics*.txt` quedan excluidos de la compilación base de Species y conservan sus compiladores propios.
- No se salta `validate_all_compiled_pokemon`: la validación de Essentials sigue activa y ahora recibe el registro completo.

## v0.11.21

- Desactiva el runtime legacy `Plugins/[MakerStudio]/001_ChangeDex.rb` al instalar/copiar el paquete.
- ChangeDex sale inmediatamente de cualquier llamada `GameData` hecha desde Compiler/validación PBS.
- El contexto de compilación se comprueba antes del atajo `@applied`, evitando que un overlay previo contamine registros que Essentials está reconstruyendo.
- Mantiene el fix de recursión con New Animation Editor de v0.11.20.

## v0.11.20

- Corrige `SystemStackError: stack level too deep` al coexistir ChangeDex con **New Animation Editor**.
- ChangeDex deja de envolver `Compiler.main`, que New Animation Editor también modifica; así se elimina el ciclo `ChangeDex#main -> New Animation Editor#main -> ChangeDex#main`.
- Se mantienen los guards de `compile_*`, `write_*` y la detección por call stack, por lo que siguen protegidos los fixes de PBS parciales, `regional_dexes.dat`, `BLACKAUGURITE` y `GOLBAT -> CROBAT`.
- No requiere modificar New Animation Editor ni cambiar el orden de plugins.

## v0.11.19

- Corrige el falso `Valor CROBAT no definido en GameData::Species` al validar `GOLBAT` con PBS divididos (`pokemon.txt` + `pokemon_Vermeil.txt`).
- El guard ya no depende de que `Compiler` exista cuando se carga el plugin: se instala de forma diferida en cuanto está disponible.
- Añade fallback por contexto de llamada para impedir que `GameData::Species/Move/Ability` activen el JSON desde scripts `Compiler`, incluso si la compilación ya había empezado antes de instalar el guard.
- Protege también `compile_PBS_file_generic`, compilación individual de Pokémon/Formas/Regional Dex y las rutas `write_all`, `write_PBS_file_generic`, `write_pokemon`, `write_pokemon_forms` y `write_regional_dexes`.
- ChangeDex solo reaplica `pokemon_changes.json` cuando existen los `.dat` finales de Species, Moves, Abilities y Regional Dexes; no durante un estado intermedio.
- No requiere mover `CROBAT` ni cambiar la evolución de Golbat en PBS.

## v0.11.18

- Corrige la recompilación PBS en Essentials v21.1: ChangeDex ya no aplica `pokemon_changes.json` mientras `Compiler.compile_all` / `compile_pbs_files` están reconstruyendo GameData.
- Evita accesos prematuros a `Data/regional_dexes.dat` durante la compilación.
- Evita falsos `Unknown ID` en parámetros de evolución (por ejemplo `BLACKAUGURITE`) causados por validar contra registros todavía incompletos.
- Al terminar la compilación, ChangeDex marca el overlay como stale y lo reaplica una sola vez sobre los GameData ya completos.
- No modifica el PBS: `BLACKAUGURITE` puede permanecer definido normalmente en `items.txt`.

## v0.11.17

- Diferencia visualmente **CANON**, **JSON**, **JSON RETOCADO**, **JSON NUEVO** y cambios de nivel/asignación en Moves, Habilidades, Tipos, Evoluciones y learnsets.
- Los Moves/Habilidades asignados a un Pokémon muestran por separado si la asignación viene del canon y si la entidad global está retocada por `pokemon_changes.json`.
- Elimina `window.confirm`/`window.prompt`: las confirmaciones y altas de IDs usan un modal interno de ChangeDex Studio, evitando `plugin:dialog|confirm not allowed by ACL`.
- Guardado reforzado para Windows/OneDrive: reintentos, fallback al escritor de texto absoluto de Maker Studio y `Data/ChangeDex/pokemon_changes.recovery.json` si el archivo principal sigue bloqueado.
- El editor y el runtime cargan automáticamente la recuperación si es más reciente que `pokemon_changes.json`, para no perder ni ignorar cambios cuando Windows devuelve `os error 5`.

## v0.11.16

- Añade procedencia visual **CANON / JSON** en ChangeDex Studio.
- En el editor global de Moves/Habilidades: `CANON`, `JSON RETOCADO` y `JSON NUEVO`, con filtros dedicados.
- En learnsets, Tutor, Egg, Habilidades, Hidden Abilities, Tipos y Evoluciones: cada asignación indica si viene del canon/PBS o del JSON.
- Un Move/Habilidad asignado de forma canon puede mostrar además `JSON RETOCADO` si su propia ficha global fue modificada.
- Movimientos por nivel distinguen `CANON`, `JSON` y `JSON NIVEL` cuando el Move era canon pero cambiaste su nivel.
- Se muestran también asignaciones canon retiradas/cambiadas por JSON para que el diff sea legible en ambas direcciones.
- Sustituye `window.confirm`/`window.prompt` por diálogos internos del propio mod, evitando `Command plugin:dialog|confirm not allowed by ACL`.

## v0.11.15

- Corrige `ReferenceError: sameField is not defined`: `index.js` ahora importa `sameField` desde `model.js`, donde ya estaba implementado.
- Corrige también el log de activación obsoleto (`v0.11.1`) para que reporte `v0.11.15`.
- Mantiene Mutadex ES/ChangeDex EN, resaltado de Moves nuevos y comparación contra baseline real.

## v0.11.14

- Corrige `Unexpected token .` al abrir ChangeDex Studio: los estilos de resaltado de Moves nuevos habían quedado fuera del template CSS de `styles.js`.
- Mantiene los cambios funcionales de v0.11.13.

## v0.11.13
- Nombre localizado: **Mutadex** en español y **ChangeDex** en inglés.
- Los Moves realmente nuevos se resaltan en verde en el editor global y en los learnsets.
- Los Moves añadidos a un learnset se distinguen de los originales.
- El runtime ya no considera cambio real a un override PBS cuyo valor efectivo coincide con el baseline.
- Target entra en la comparación real de Moves y la caché se invalida/reconstruye.
- Metadatos `_beforeText/_afterText/_notes` importados no crean falsos cambios si los campos PBS ya coinciden; los reworks de script editados manualmente quedan marcados explícitamente.

# ChangeDex Studio v0.11.1

> La traducción ya no pertenece a ChangeDex. Se gestiona desde el mod independiente **Translate Studio**. ChangeDex conserva balance, comparación y ChangeDex ingame; cuando Translate Studio está instalado, usa su idioma/localización como servicio externo.

## v0.10.2

- Preview: fila horizontal dedicada al final del grid, separada visualmente y no seleccionable.
- Descripciones ingame con margen vertical adicional.
- Prewarm de Pokémon/Moves/Abilities/New/Carriers durante el arranque para evitar el estado inicial 0 y la carga al entrar por primera vez.
- Caché detect v28.

## v0.10.1

Preview ingame restaurada, precarga de índices y carriers, blacklist de Moves/Habilidades y fallback vanilla de localización.

# ChangeDex Studio v0.9.0

Editor visual de overrides para Pokémon Essentials. El PBS del proyecto sigue siendo la base y `Data/ChangeDex/pokemon_changes.json` guarda el delta de gameplay y la localización propia de ChangeDex.

## v0.9.0
- Fullscreen real basado en BAS y compatible con paneles Maker Studio dentro de ShadowRoot.
- Workspace reorganizado para dar prioridad a la edición y dejar resumen/diferencias como contexto.
- Ocultación múltiple de formas desde `Gestionar`; nunca elimina ni desactiva sus cambios ingame.
- Índice runtime basado en el JSON delta y Move/Ability indexes bajo demanda.
- Grid ingame calibrado para iconos 42×42 a 84×84 y menú de categorías rediseñado para 640×480.
- English usa la referencia CanonData para nombres/descripciones oficiales y nombres de tipos en inglés.
- El contenido custom sin traducción inglesa no reutiliza silenciosamente el texto español.
- `🌐 Editar textos` permite Name, Description/Pokedex, BeforeText, AfterText y Notes en ES/EN.
- `config.json`, `pokemon_changes.json` y gráficos Custom existentes no se sobrescriben al actualizar.

Actualizar Studio/runtime no reemplaza `pokemon_changes.json`, `config.json` ni gráficos Custom existentes.

## Histórico v0.11.0 · Language Studio (retirado de ChangeDex)

- En v0.11.0, `Language Studio` podía localizar Pokémon/formas, categoría Pokédex, Moves, Abilities, Items y Types en ES/EN sin reescribir el PBS.
- La localización ya no es exclusiva de ChangeDex: el runtime también se integra con `MessageTypes.getFromHash`, por lo que menús, combates, Pokédex y plugins que usan el sistema normal de Essentials reciben el mismo idioma.
- Si `gameLanguageMode = auto`, se respeta `Settings::LANGUAGES` y `$PokemonSystem.language`.
- Si hay 2+ idiomas en `Settings::LANGUAGES`, se añade `Language / Idioma` al menú de Opciones del juego.
- `🗨 Textos generales / INTL` permite overrides puntuales ES/EN para cadenas `_INTL`/eventos.
- En Debug se añaden accesos `ChangeDex Translator` para extraer Game/Core Text y compilar de nuevo `messages_<idioma>_game/core.dat` usando el traductor nativo de Essentials v21.1.
- El índice de ChangeDex se prepara tras `GameData.load_all` y antes del gameplay. Al abrir ChangeDex sólo se hidrata un caché ya listo; si no existe, la pantalla aparece primero y la categoría elegida se construye después.

- JSON/localización se cachea en memoria con comprobación de cambios espaciada; los getters globales ya no consultan tamaño/mtime del archivo en cada nombre o descripción.
