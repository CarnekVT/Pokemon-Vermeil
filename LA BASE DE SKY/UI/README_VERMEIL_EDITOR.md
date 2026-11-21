# Interfaces nativas de Vermeil — MakerStudio

La Libreta y la Nueva Pokédex son escenas **nativas** con datos, navegación,
sprites y progreso propios. El Editor de Interfaces controla sus **perfiles
visuales**: los guarda en `LA BASE DE SKY/UI/vermeil_*.json` y el juego
vuelve a leerlos cada vez que abre la pantalla. No son interfaces de prueba
separadas que haya que llamar con `pbInterfaz`.

## Cómo editarlas

1. Abre MakerStudio en el **proyecto correcto** (`LA BASE DE SKY`).
2. Abre **Editor de Interfaces**. Arriba está la navegación rápida:
   - **Libreta:** Catálogo · Ficha
   - **Pokédex:** Listado · Ficha · Área · Formas
3. Elige el perfil y selecciona una capa en el panel izquierdo o el lienzo.
4. Modifica sus propiedades. **Ctrl+S** guarda el diseño en `UI/`.
5. En el juego, **cierra y vuelve a abrir** la Libreta o Pokédex para
   cargar el JSON recién guardado. No uses el menú de pruebas de `pbInterfaz`
   para evaluar las pantallas nativas.

**Navegación y comodidad:** usa los botones **Anterior/Siguiente**, el
buscador superior o **Alt+← / Alt+→** para cambiar de página. **Ctrl+J** enfoca
la búsqueda de pantallas. El zoom y el desplazamiento se mantienen al cambiar
de página o tamaño de panel. Pulsa **Encajar** para centrar deliberadamente.

## Qué elementos controla el editor de verdad

| Tipo de capa | Cambio real en el juego |
| --- | --- |
| Un panel nativo con ID reservado | Posición, imagen del PNG indicada, dimensiones del arte, opacidad del PNG; si se cambia a tipo `panel`, relleno y borde |
| `focus_sprite` (Libreta) / `portrait_pokemon` (Pokédex) | Anclaje del Pokémon; se mantiene el sprite real y sus formas |
| Pestañas y paneles nativos | Posición y sustitución por el PNG indicado |
| `cover` y paneles con entrada | Duración de apertura y transición en los puntos ya conectados |
| **Elementos adicionales** (ID nuevo) de tipo `imagen`, `texto`, `panel`, `animado` y `barra` | Se crean y animan con el propio motor de Interfaces dentro de la escena nativa: posición, tamaño, capa relativa, opacidad y efectos de entrada/animación compatibles |

Los ID existentes son **anclas reservadas**. Renombrarlos desactiva su enlace
nativo; un ID nuevo se usa para capas **decorativas adicionales**.

Los PNG opcionales indicados por defecto pueden **no existir** todavía. En
MakerStudio el recuadro con el nombre del panel es una representación de
sus límites, no una imagen ni una captura de la Pokédex real. Si quieres
sustituir el arte, selecciona la capa e indica un PNG existente en
`Graphics/UI/...`. No se crea automáticamente un PNG.

**Límites vigentes:** la selección de especies, formularios, textos
dinámicos y filas de cuadrícula/listado siguen calculándose en Ruby; editar
sus anchos o posiciones no convierte cada fila en un componente separado.
Los botones nuevos del editor **no controlan las escenas nativas**; usa
decoración con los tipos indicados arriba. La capa de una pieza nativa
rasterizada dentro del mismo bitmap no se puede reordenar individualmente
respecto a cada texto dinámico. No presentar esos controles como
enteramente conectados.

## Prueba que confirma la conexión

1. Abre `vermeil_pokedex_lista` en el editor.
2. Añade un **Texto** con un ID nuevo, por ejemplo `test_conexion`.
3. Pon `texto` = `PRUEBA EDITOR`, posición `x=30`, `y=400`,
   tamaño `16`, color claro y `capa=20`.
4. Guarda (**Ctrl+S**). Abre `LA BASE DE SKY/UI/vermeil_pokedex_lista.json`
   para verificar que el elemento existe.
5. Abre la **Nueva Pokédex del juego**. El texto debe verse encima de la
   pantalla. Si no aparece, revisa en la consola del juego las líneas
   `[Vermeil Interface Studio]`: indican perfiles leídos o errores de
   JSON. También comprueba que MakerStudio no haya escrito en un proyecto
   distinto.
6. Borra el texto de prueba, vuelve a guardar y reabre la Pokédex.

Realiza la misma prueba en `vermeil_libreta` para la Libreta. Las
modificaciones de Ruby del plugin sí necesitan que el juego arranque con los
scripts actualizados; cambiar **solo JSON** no necesita recompilar Ruby.

## Regresión tras editar

- Libreta: abrir, ver la cuadrícula ya poblada, cambiar de catálogo a ficha
  y volver, mover `detail_panel` provisionalmente y restaurar
- Pokédex: Listado / Ficha / Área / Formas; probar todas las entradas,
  filtros, shiny y formas conocidas sin sustituir datos o sprites
- Comprobar que una imagen nueva y un texto adicional aparecen y desaparecen
  al guardar y reabrir sin dejar sprites fantasma en otras páginas

La validación de esta integración es todavía **estática**: requiere probar
MakerStudio y `Game.exe` en Windows para confirmar el comportamiento visual.
