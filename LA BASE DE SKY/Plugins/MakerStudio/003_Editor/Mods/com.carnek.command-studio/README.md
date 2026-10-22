# Command Studio 0.9.1 — navegador de eventos, NameBox y Windowskins corregidos

Integrado en Pokémon Vermeil, bajo `LA BASE DE SKY/Plugins/MakerStudio/003_Editor/Mods/com.carnek.command-studio`.

## Abrir y crear

1. Actualiza la rama **new-MK-for-2.5D-Testeo** y reinicia Maker Studio.
2. Abre un mapa y ve a **Mods → Command Studio** (también **Tools**).
3. Verás cuatro pestañas:
   - **Crear evento**: empezar con seis tareas habituales o escribir en lenguaje cotidiano lo que quieres hacer.
   - **Editor de mensajes**: escribir un diálogo, añadir controles desde botones y ver una aproximación legible.
   - **Enciclopedia**: 134 fichas de funciones y 65 directivas de mensajes.
   - **Avanzado**: conserva el compositor de secuencias y la indexación recursiva de métodos del proyecto.
4. Elige tarea → configura opciones → selecciona evento y página → pulsa «Añadir al evento».
5. Maker Studio aplica la edición por su API, con historial de deshacer. No sobrescribe otras páginas.

## Mensajes · Essentials Docs + LA BASE DE SKY + Vermeil

El archivo `messages-catalog.js` reúne **65 directivas** ordenadas por Variables, Formato, Colores, Alineación, Ventana, Velocidad, Sonido, Extras y Avanzado, explicadas en español.

- Editor visual con botones rápidos y cursor.
- Control de parámetro para variables, color, sonidos, marcos y velocidades.
- Vista previa orientativa que *no* pretende reproducir al 100 % el motor gráfico del juego.
- Los códigos controvertidos fueron contrastados contra `Data/Scripts/018_Objects and windows/012_Messages.rb` de **este proyecto**. El parser local reconoce `\\!` como pausa interactiva, `\\wt[n]`, `\\wtnp[n]`, `\\op`, `\\cl`, `\\se[...]`, `\\me[...]`, `\\sh`, `\\pt`, `\\ff[...]` y `\\ch[...]`. La wiki de Sky puede describir algunas claves de manera distinta.
- Mensajes con NameBox, opciones con imágenes de objetos (s:ChoiceImage), pbEnterText, pbMessageFreeText y confirmaciones se incluyen en acciones/fichas.

Fuentes:
- https://essentialsdocs.fandom.com/wiki/Messages
- https://la-base-de-sky-wiki-1070f3.gitlab.io/pages/mensajes.html
- Scripts locales de Vermeil, especialmente `012_Messages.rb` y `014_NameBox.rb`.

## Funciones y compatibilidad

- 39 acciones funcionales de evento.
- 134 fichas de recetas y funciones, configurables en modo avanzado.
- Indexador local de `Data/Scripts/**/*.rb` y `Plugins/**/*.rb`: puede detectar cientos/miles de métodos, pero eso **no significa** que todos se puedan ejecutar en eventos.
- La documentación Fandom indicada es antigua, no se mantiene activamente, así que los ejemplos se subordinan al motor instalado.
- Hay funciones internas, metaprogramación, `.rxdata` binarios y comandos específicos que el indexador no interpreta completamente. No se declara **100 % de cobertura**.
- Por ahora el asistente inserta acciones al final de una página existente. No cambia las condiciones, sprites ni páginas automáticamente.
- Requiere **Maker Studio Mod API 1.0.1 o superior**.

## Pruebas

`node tests/beginner-smoke.cjs`

Pruebas de sintaxis, cobertura de catálogo, generación de 39 acciones, códigos de mensaje y preservación de otras páginas usando un contexto falso de eventos. Hace falta validar la UI en la instalación del usuario.

## Ampliación de investigación 0.6

Se revisó el índice de LA BASE DE SKY y las páginas de Essentials Docs recuperables. Se añadieron 58 recetas nuevas: Pokémon, atributos, equipo, acompañantes, medallas, economía, reglas de combate, clima, calendario, audio, obstáculos, elecciones, interfaz y módulos opcionales. Se incorporaron 10 asistentes para principiantes: compañero, despedida, medallas, puerta por medallas, trueque de objetos, clima, NPC según día, huevo, fanfarria y rival dinámico.

**Advertencias verificadas:** no todas las llamadas documentadas están presentes en Vermeil. Los nombres de algunos métodos de guardería de la wiki no coinciden con los del módulo DayCare de `037_Overworld/008_Overworld_DayCare.rb`; por eso no se han añadido como asistentes de un clic. Asimismo `pbStrengthBoulder` no se ha confirmado en `037_Overworld/005_Overworld_FieldMoves.rb`, que contiene `pbStrength`. Los controles de mensajes `\\1` y `\\cn` deben seguir el comportamiento real de `012_Messages.rb` (pausa y ventana de monedas respectivamente), aunque ciertas tablas LBDS los describan de otro modo. `pbGetChoiceImages` tampoco debe construirse con un ID de evento sin comprobar su firma real.

**Alcance:** es una ampliación basada en las secciones consultables y el código existente, no una garantía de extracción exhaustiva del 100 % de dos wikis. Los ejemplos avanzados pueden requerir configuración de otros sistemas o comprobación de argumentos.

 
## Pantalla completa como BAS/BSS

- Pulsa **⛶ Pantalla completa** en la cabecera o **F11** con Command Studio enfocado.
- Ocupa el espacio de trabajo de Maker Studio, sin entrar en Fullscreen API del navegador.
- **Esc**, **F11** o **↙ Restaurar ventana** devuelven el mismo editor y su contenido al panel.
- La sesión ampliada permite **✕ Cerrar Command Studio**, restaurando el nodo antes de cerrar.
- El ancho del editor y las dos columnas del área de mensajes se adaptan al nuevo tamaño.

## Ayudas visuales del editor de mensajes

- **12 muestras de color** con clic para pintar el texto seleccionado.
- **Selector RGB personalizado**. Produce etiquetas de Essentials de forma automática: <c=RRGGBB>texto</c>.
- **Color de texto más sombra** con dos selectores: <c3=RRGGBB,RRGGBB>texto</c3>.
- **13 índices de color** (0–12): son muestras orientativas; el tono real depende del Windowskin. Corregido el índice 0 en el formulario.
- **Miniaturas de posición** arriba, centro y abajo; insertan \wu, \wm o \wd al inicio del mensaje.
- **Vista esquemática de mensaje** sobre un entorno de mapa, con color de texto y ubicación. Señala efectos de sonido, caras, pausas y otros comandos.
- **Deslizadores visuales** de tiempo y velocidad, con lectura de duración aproximada.
- Los colores RGB y sus etiquetas están verificados en 011_DrawText.rb y 012_Messages.rb de Vermeil.
- Las 39 acciones, 134 fichas técnicas y la sección avanzada se conservan.

Prueba autónoma: node tests/visual-smoke.cjs

La vista es un esquema, no una simulación del motor; hace falta comprobar su comportamiento dentro de la instalación real de Maker Studio.


## Actualización 0.8.0 · Reducir saturación

- **Inicio:** solo 6 tareas frecuentes de entrada. «Explorar más tareas» despliega los otros asistentes por categorías, **10 por tanda**.
- **Búsqueda rápida:** resultados relevantes ordenados por intención. Las estrellas añaden accesos rápidos **durante la sesión**; no se promete persistencia entre reinicios.
- **Asistentes:** cuando hay más de 4 campos, se muestran los 3 principales y los demás bajo «Personalizar otros ajustes (opcional)» con sus valores por defecto.
- **Paso final:** resumen explicativo y valores elegidos. Los comandos técnicos solo aparecen si se abre «Ver comandos técnicos generados».
- **Enciclopedia:** 12 fichas por tanda, filtro de categorías, ficha contextual, lista de parámetros, notas sobre compatibilidad y enlace a fuente. Acción «Configurar esta función» independiente de la ficha.
- **Editor de mensajes:** columnas de texto/vista previa y herramientas. Solo una herramienta visible a la vez: **Color**, **Ventana**, **Pausas**, **Más efectos**.
  - Color: ocho muestras iniciales, más colores detrás de «Mostrar los demás», picker RGB y sombra como opción adicional.
  - Ventana: posición con miniaturas, cambio de Windowskin a demanda.
  - Pausas: cuatro acciones rápidas y dos deslizadores.
  - Más efectos: búsqueda + categoría + lista de 10 por tanda; inspector de parámetros cuando se elige un control.
  - Botones de ejemplos «Saludo», «Aviso», «Narración» bajo una sección desplegable; se añaden sin borrar lo ya escrito.
- **Protección de cursor:** al insertar un prefijo \wu / \wm / \wd se recalcula la selección para no romper etiquetas RGB al añadir otros efectos.
- **Modos existentes:** pantalla completa BAS/BSS, indexador de código, composición avanzada y la inserción por la API Maker Studio se mantienen.

## Pruebas específicas

Ejecuta:
node tests/ux-smoke.cjs

Verifica el límite inicial de tarjetas, paginación de tareas, flujo de asistente, enciclopedia paginada, selección de color, cambio de ubicación de ventana, slider de espera e integridad del mensaje.

**Importante:** se hicieron pruebas con DOM y eventos simulados, no con una sesión de Maker Studio/Electron del usuario. Es necesario comprobar la visualización y el envío de eventos en una instalación real.


## 0.9 — Navegación, eventos y diálogo

### Eventos
La pestaña Eventos es un navegador del mapa activo: crear, renombrar, mover, borrar eventos, consultar páginas y comandos. Muestra miniaturas de Graphics/Characters mediante el backend Tauri get_graphic_image cuando está disponible, '?' si no hay sprite y un símbolo de tiles si usan un tile. La lista se sincroniza con map.loaded/map.unloaded/event.changed/undo/redo y al recuperar foco.

Inserción: elige evento, página y posición exacta con '+' entre comandos o desde el selector. No separa los continuadores de textos/scripts; inserta con la indentación de la rama seleccionada. Valida events.validateEvent antes de actualizar. Hay estructuras muy especiales que podrían requerir revisión manual.

### Pokémon personalizados
Los asistentes para entregar Pokémon cuentan con más de 35 opciones agrupadas: especie, nivel, mote, sexo, forma, Shiny/Super Shiny, Poké Ball, naturaleza, habilidad, objeto, movimientos, IV, EV, felicidad, entrenador original, idioma, texto de obtención, cinta y Pokérus. Comprueban el máximo habitual de 510 EV.
Construyen un objeto Pokemon.new y después usan pbAddPokemon o pbAddPokemonSilent, disponibles en Vermeil. En la entrega única, el interruptor local se activa solo si el método devuelve true; si falla, se permite reintentar. Las siguientes interacciones muestran otro mensaje.

### Mensajes
NameBox permite nombre fijo, jugador o variable. Genera NameBox.load, el mensaje y NameBox.dispose. El corrector ofrece subrayado nativo español, sugerencias locales y corrección individual o en lote; preserva secuencias Essentials y advierte etiquetas de formato sin cerrar. No es un corrector de IA ni un diccionario exhaustivo.
Preview: permite elegir Marco del editor o Windowskin del juego. Lee Graphics/Windowskins mediante el backend gráfico cuando está disponible, con representación orientativa (no emula el renderer del juego).

### Auditoría
La enciclopedia puede analizar Scripts y Plugins para clasificar las fichas como localizadas, opcionales, pendientes o sin localizar. No considera automáticamente ausentes los métodos dinámicos.

### Pruebas
node tests/v09-smoke.cjs
node tests/ux-smoke.cjs
node tests/visual-smoke.cjs
node tests/beginner-smoke.cjs

Pruebas de lógica y DOM simulado, no una sesión real de Maker Studio. Confirmar compatibilidad y apariencia en una instalación del juego.
## Versión 0.9.1 — Correcciones a partir de capturas reales

### Eventos
- Se evita la acumulación de códigos individuales: las continuaciones de textos y Ruby se agrupan en tarjetas con nombre claro y detalles técnicos plegables.
- Los puntos de inserción siguen usando los índices reales y la validación de event-writer. No se modifica la semántica del evento.
- Panel de eventos más amplio y legible: lista con búsqueda, tarjetas de sprites, evento seleccionado, páginas y botón «Crear acción aquí».
- Desplazamiento independiente en la lista de NPC y la secuencia de comandos, conservando la posición al cambiar de evento.
- Los controles para crear, renombrar, mover o eliminar eventos se mantienen, pero aparecen en secciones opcionales.
- Los sprites tienen recorte inteligente por transparencia y escalado que conserva proporciones; gráficos invisibles = signo de interrogación. Los eventos con tiles muestran un marcador de tile.

### Windowskins / mensajes
- Compositor Canvas de nueve piezas basado en el código real de SpriteWindow.rb y MessageConfig.rb de Vermeil.
- Soporta RPG Maker XP 192x128, compatibilidad VX 128x128, HGSS speech 96x48, marcos 80x48 y 80x80 y marcos compactos 48x48.
- No muestra la hoja entera de recursos en el diálogo: usa la zona central para fondo y las piezas de bordes/esquinas para el marco.
- Determina contraste inicial del texto según claridad del fondo, manteniendo intactos los colores explícitos del usuario.
- NameBox visible debajo del campo de texto, con entrada directa y botones «Usar jugador» y «Sin nombre».
- En pantalla completa queda un solo botón para restaurar, F11 alterna y Esc devuelve la ventana al panel.
- La sección avanzada elimina la cabecera duplicada y mejora la distribución de columnas, separación y tamaño de previsualizaciones.

### Verificación y limitaciones
- Comprobación independiente de formatos de Windowskin, recorte alfa, códigos de color por defecto y agrupación de tarjetas en DOM simulado.
- Prueba propia: node tests/v091-smoke.cjs
- El compositor de Windowskin reproduce las piezas principales pero sigue siendo una PREVISUALIZACIÓN: no ejecuta transiciones, animaciones o fuente RGSS. Pueden existir windowskins personalizados con parámetros extra de .txt.
- El navegador de eventos no altera el guardado ni la compatibilidad de Maker Studio; comprobarlo en una instalación real antes de usar en mapas definitivos.
