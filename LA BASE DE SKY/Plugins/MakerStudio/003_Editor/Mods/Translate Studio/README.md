# Translate Studio v1.4.0

- Usa `Data(20260906-012634).zip`, la base limpia inglesa entregada por el proyecto, como referencia autoritativa para **Scripts base**.
- Añade traducción contextual por archivo/línea para textos españoles ambiguos. `Guardar` ya no se fuerza a una sola palabra: **Save** en el menú de pausa, **Take** al retirar un objeto equipado y **Store** al guardar un Pokémon en las cajas.
- Corrige el Ability Splash en inglés: muestra `Persian's` arriba y `Intimidate` debajo, igual que la base inglesa; en español conserva `Intimidación` / `de Persian`.
- Las asociaciones contextuales automáticas solo se aceptan cuando la estructura de código coincide exactamente con la base limpia o cuando el punto de código fue verificado expresamente. Esto evita desplazamientos de listas que daban traducciones falsas.
- Los eventos siguen excluidos de estas fuentes de referencia. Las referencias inglesas de plugins/BSS/SDS de versiones anteriores se conservan.

# Translate Studio v1.3.3

- **Scripts base: 0 sin traducir** para el catálogo actual: se cerraron los 103 huecos que quedaban tras ZBox.
- Se usó `Data(20260905-033545).zip` como referencia inglesa oficial/base y se conservaron placeholders, saltos y códigos de control.
- Los packs ingleses de Deluxe Battle Kit, Enhanced Battle UI y Raid Battles quedan registrados como referencias de plugins; no aportan ni contaminan Eventos.
- **Eventos siguen siendo exclusivamente los del proyecto real.** No se importó ningún Map/CommonEvent desde las referencias.
- Al actualizar desde v0.9.0, la semilla añade solo traducciones que estén vacías; no pisa traducciones manuales del usuario.

# Translate Studio v0.9.0

- **ZBox 1.1.0 completo salvo eventos:** se importan las 8144 filas PBS y todas las filas de Script/Plugin aprovechables de `Translations_ScriptEvents.csv`.
- **Cero mapas/eventos de ZBox:** no se importan `Map###`, `CommonEvent` ni catálogos de eventos. Las 1268 filas que solo pertenecen a eventos quedan fuera. Las 33 filas mixtas conservan únicamente su lado Script/Plugin.
- **PBS completo:** además de Pokémon, movimientos, habilidades, objetos y tipos, se conservan Trainer Types, nombres/discursos de entrenadores, regiones, ribbons/descripciones, mensajes de teléfono, Storage Creator y nicknames mediante un fallback contextual por `MessageTypes`.
- **Scripts/Plugins completos:** se recuperan las referencias de ZBox en sus buckets correspondientes, sin meterlas dentro de Eventos.
- **UI:** se incluyen las 48 variantes gráficas English de ZBox, byte por byte.
- Las 6 filas no-evento que vienen con la columna English vacía en ZBox (3 de PluginManager y 3 descripciones de berries) también quedan cubiertas por Translate Studio; las filas vacías que sí son eventos siguen excluidas.
- El bucket PBS de referencia es interno y persiste al abrir/guardar Translate Studio; no se pierde al fusionar la semilla con un proyecto existente.

# Translate Studio v0.8.0

- Apertura rápida: ya no escanea RXDATA, todos los scripts, todos los plugins, BSS, SDS e imágenes antes de mostrar el editor. Cada biblioteca pesada se carga al entrar y queda catalogada.
- Bibliotecas visuales: Eventos por mapa, Scripts base por script, Plugins por plugin, BSS por combate y SDS por escena.
- Pantalla completa estilo BAS: botón dedicado, F11 para entrar/salir y Esc para volver al panel.
- Detectar cambios sigue haciendo una revisión completa cuando tú la pides.

# Translate Studio v1.3.3

Translate Studio aplica la localización directamente desde `Data/TranslateStudio/translations.json`. No necesita Extraer -> Compilar para usar una traducción.

## Cambios v1.2.0

- **Eventos RXDATA reales:** el Studio lee directamente `Data/MapInfos.rxdata`, luego únicamente los `MapXXX.rxdata` registrados ahí, además de `CommonEvents.rxdata`. No depende de un catálogo de ZBox ni de mapas de muestra, y detecta eventos nuevos al pulsar **Detectar cambios**.
- **BSS organizado:** `Integraciones > BSS` abre por defecto **Combates**. Puedes cambiar entre **Textos generales** y **Combates**, y dentro de Combates elegir cada blueprint por nombre.
- **SDS organizado:** `Integraciones > SDS` abre **Librería de escenas**. Los scripts de Scene Engine/Scene Director se agrupan por archivo/escena; por ejemplo `010_Intro.rb` aparece como **Intro**, y dentro ves solo sus textos.
- **Debug realmente dinámico:** además de los listers, se intercepta `pbChooseFromGameDataList`, que Essentials v21 usa con `real_name`. Movimientos, especies, tipos, objetos y habilidades se resuelven con `GameData#name` en el idioma activo cada vez que se abre el selector. El menú Debug también traduce sus comandos al renderizarse.
- **UI de idioma en imágenes incluida:** el ZIP ya trae PNG editables en `Graphics/UI/TranslateStudio/`. El modo predeterminado es **UI con gráficos**.
- **Código Ruby + imágenes:** el modo Ruby no sustituye las imágenes obligatoriamente; puede usar el mismo fondo, cabecera, tarjetas, cursor y pie y cambiar solo la lógica/animación que quieras.
- **Selector limpio:** fondo opaco; sin cuadrados inferiores; textos/tarjetas grandes; `ESP/ENG` centrado verticalmente. Atrás solo cancela/vuelve y nunca abre `pbShowCommands` ni un textbox de idiomas.
- **ZBox usado con límite:** no se importan sus eventos, mapas, catálogos ni textos del propio traductor. Se recupera únicamente una semilla de traducciones útiles de UI/Debug/plugins de la base anterior y **48 variantes gráficas English de UI** (Summary, Battle, Party, Pokédex, Storage, etc.). Esas traducciones de texto no crean entradas visibles por sí solas: el Studio solo las muestra cuando el texto existe en el proyecto actual.
- Los plugins de referencia `ZBox Translator`, `ZBox Traductor` y `Translator Helper` se excluyen del escaneo de catálogo para que su propia interfaz no aparezca como texto del juego.

## Imágenes del selector

- `language_bg.png` — fondo completo.
- `language_header.png` — título/subtítulo.
- `language_es.png` — tarjeta Español.
- `language_en.png` — tarjeta English.
- `language_cursor.png` — cursor.
- `language_footer.png` — controles inferiores.

Desde **UI de idioma** puedes cambiar las rutas. En modo `code`, el Ruby de `Data/TranslateStudio/language_menu_custom.rb` puede usar esas mismas imágenes o dibujar una interfaz completamente distinta.

## Integraciones

**BSS:** traduce únicamente campos de lectura (`title`, `message`, `text`, `prompt`, etc.) de `Data/BattleSceneStudio/battles.json`/recovery y textos detectados en su runtime. IDs, especies, movimientos, condiciones y lógica no se traducen.

**SDS:** detecta `Data/SceneDirector/scenes.json`, `compiledRuby`, `text_inline`, `show_centered_text`, speakers y Scene Engine/Scene Director instalados. Los textos quedan agrupados por escena/librería.

## Datos

- `Data/TranslateStudio/translations.json`: traducciones y overrides.
- `Data/TranslateStudio/catalog.json`: catálogo incremental generado desde el proyecto real.
- `Data/TranslateStudio/config.json`: idioma y UI.
- `Data/TranslateStudio/language_menu_custom.rb`: selector Ruby + imágenes.
- `Plugins/[CARNKEVT] Translate Studio/001_TranslateStudio.rb`: runtime.


## v1.2.0 — English completion
Base scripts and plugins now use supplied English source references directly during detection. Known reversed ZBox entries are repaired on upgrade, custom plugin/BSS/SDS rows from the project snapshot are prefilled, and ZBox events remain excluded.

## Auditoría v1.2.0 — English completo

- Scripts base: **4449 textos únicos auditados · 0 pendientes**.
- Plugins: **1189 textos únicos auditados · 0 pendientes**.
- BSS runtime: **12 textos únicos auditados · 0 pendientes**.
- SDS/Scene Engine: **27 textos únicos auditados · 0 pendientes**.
- La referencia principal para la base es el `Data` inglés adjuntado por el proyecto.
- DBK, Enhanced Battle UI, Raid Battles, EBDX, SOS Battles e Improved Item AI usan sus paquetes ingleses adjuntados como referencia.
- Cuando una cadena custom no existe en esos paquetes se incluye una localización inglesa explícita; no queda como `BASE`.
- Los eventos de ZBox siguen excluidos.
- Al actualizar desde una versión anterior, las filas inglesas que habían quedado como copia del texto español se sustituyen por el inglés completado; las ediciones manuales distintas del texto fuente se conservan salvo reparaciones conocidas de dirección ZBox.


## v1.3.3 — nombres y títulos custom de BSS

- `boss.hud.displayName` se detecta como texto traducible.
- Los nombres/títulos custom mostrados por BSS pueden tener traducción independiente por idioma, por ejemplo `Dragonite el Indomable` → `Dragonite the Indomitable`.
- También se mantienen traducibles `boss.title`, `databoxTitle` y demás campos de título player-facing.
- Los nombres internos de Blueprints/IDs no se traducen ni se alteran.

## v1.3.0 — calidad ENG y traducción automática
- Reparación por ID de PBS para impedir cruces de contexto heredados de ZBox (por ejemplo, `Malicioso` como movimiento = `Leer`, mientras la categoría de especie puede seguir siendo `Devious`).
- Nombres/descripciones estándar se priorizan desde las fuentes inglesas y la localización canónica incluida.
- Intro SDS revisada: `Elder Spirit` con registro solemne, Solen neutral antes de elegir género y `Despierta...` = `Wake up...`.
- Textos SDS ordenados por archivo/línea para conservar el orden narrativo.
- BSS filtra campos técnicos que no son texto para el jugador.
- Auto ENG disponible por entrada, selección múltiple o global; las filas manuales explícitas no se pisan en el global.
- Reparados auxiliares custom (`recordar`/`aprender`), abreviaturas y fugas de español detectadas en la columna ENG.

## v1.3.3 — regex de Auto-traducción

- Corrige `Invalid regular expression: missing /` al abrir el mod en Maker Studio.
- La restauración de placeholders ya no construye una regex de escape innecesaria; los tokens internos son alfanuméricos y se buscan directamente.
- Se sincroniza también la copia runtime incluida en `Plugins/[CARNKEVT] Translate Studio`.
