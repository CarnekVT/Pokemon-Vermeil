# Biblioteca de interfaces de Pokémon Vermeil

## Organización real de carpetas

La carpeta `LA BASE DE SKY/UI` contiene una biblioteca de interfaces.
**Una carpeta representa una interfaz**, con tantas pantallas como necesite:

```text
UI/
├── Libreta/
│   ├── Catalogo.json
│   └── Ficha.json
├── Pokedex/
│   ├── Lista.json
│   ├── Ficha.json
│   ├── Area.json
│   └── Formas.json
└── ...otras interfaces creadas desde MakerStudio
```

El editor de MakerStudio tiene ahora una **Biblioteca** en el panel izquierdo:
abre carpetas, elige una subpantalla o pulsa **+ Carpeta** / **+ Pantalla**.
En el encabezado conserva Anterior/Siguiente, búsqueda de pantallas,
**Alt+← / Alt+→**, **Ctrl+J** para buscar y **Ctrl+S** para guardar.

La cámara del lienzo no se vuelve a centrar ni cambiar de zoom al abrir
capas, animaciones o inspector. Solo **Encajar** reajusta deliberadamente.

## Se refleja en el juego

Las pantallas nativas mantienen su selección, progreso, Pokémon, formas,
mapa y lógica de navegación en Ruby. El editor enlaza las capas visuales
configuradas en JSON (PNG, paneles, colores, posiciones, tamaños y otros
ajustes implementados), y admite capas **adicionales** de imagen, panel,
texto, animación o barra mediante el motor de Interfaces.

Las capas nativas con ID fijo (por ejemplo `list_panel`, `grid_panel`,
`entry_description`, `list_row_selected`) se leen directamente.
Si cambias una capa nativa de imagen a `panel`, su color y borde se
renderizan en el juego aunque no exista un PNG. El fondo de ficha de
Pokédex debe conservar **transparencia en la zona del sprite** si lo
sustituyes por un PNG, o puede tapar al Pokémon.

**No son seis interfaces independientes para `pbInterfaz`.** Son perfiles
gráficos de las escenas originales de Libreta y Pokédex.

Los nombres antiguos `vermeil_libreta*.json` y
`vermeil_pokedex*.json` siguen disponibles en **Compatibilidad**,
pero **no se aplican si existe el archivo dentro de su carpeta**.
La fuente de verdad es siempre `UI/Libreta/...` o `UI/Pokedex/...`;
el JSON antiguo solo se utiliza como respaldo si falta el nuevo.
Así los cambios que haces en la biblioteca no pueden quedar anulados
por una fecha de modificación más reciente del perfil antiguo.
No borres los diseños viejos hasta trasladar cualquier edición pendiente.

## Qué sigue generado desde Ruby

No todo está convertido a elementos libres de MakerStudio: el contenido
dinámico de las filas, las Poké Balls, las estadísticas, el mapa, el
progreso y los sprites de Pokémon siguen dependiendo de sus escenas.
No confundas un fondo editable con una sustitución integral del código
de juego. El diseño usa el editor **para la presentación vinculada y
capas adicionales**, sin copiar ni falsificar el estado del juego.

## Prueba de conexión editor → juego

1. Abre `Pokedex/Lista` en MakerStudio.
2. Cambia temporalmente el color del panel `list_row_selected`.
   Guarda con **Ctrl+S**. Abre la Pokédex real y selecciona otra especie;
   la fila resaltada debe mostrar el nuevo color.
3. Añade un **texto** con ID nuevo `prueba_editor`, texto
   `CONECTADO`, x=30, y=405, capa=20. Guarda y reabre la Pokédex real.
   Debe mostrarse encima del panel nativo.
4. Repite en `Libreta/Catalogo` cambiando el color de `focus_panel`
   y colocando un texto adicional.
5. Quita los cambios de prueba y guarda nuevamente.

Si un cambio no aparece, verifica el **proyecto abierto en MakerStudio**,
que se esté escribiendo `LA BASE DE SKY/UI/`, que Game.exe tenga
los Ruby actualizados y que estés modificando el JSON nuevo dentro de su carpeta.
En debug, la consola identifica errores de perfil como
`[Vermeil Interface Studio]`.

## Pruebas de batalla tras los cambios de intro

- Salvaje diurno, nocturno y de distinto bioma: fondo visible, sin
  parpadeo, grito presente, Pokémon plenamente visible y cámara que
  acerca y regresa suavemente.
- Entrenador: intro NDS sin slide independiente; el entrenador
  **aparece ya a la derecha** de todos los rivales y reproduce
  su animación DBK después del entorno.
- Diálogo guionizado: el mismo entrenador a la derecha, paneo EBDX
  coordinado con Pokémon/sombras, aparición y desaparición fluidas.
- Dobles, SOS, movimientos y enfriamientos de cámara: revisar que no
  se acumulen escalas, no aparezcan bordes negros ni se desplacen
  sprites durante movimientos.

Los controles pasan una comprobación estática de sintaxis de JS y JSON;
para declarar una corrección visual como confirmada hay que reproducir
estas pruebas en MakerStudio y Game.exe.

## Pruebas de regresión prioritarias (20/11/2026)

1. **Entrenador:** debe estar a la derecha, completamente dentro del
   encuadre, inmóvil antes del primer fotograma de la animación DBK; el
   escenario se abre mediante el wipe opaco NDS (no fundido translúcido).
2. **Cámara:** el encuadre derecho debe mantenerse hasta terminar la
   intervención del entrenador. Al cerrar un diálogo o entrar al menú de
   comandos, el actor debe desaparecer con un fade y la cámara volver con
   un solo tween; no debe ejecutarse un snap de vuelta a MAIN en medio.
3. **Salvaje:** textura NDS completamente opaca hasta el wipe, nada de
   snapshot congelado, Pokemon siempre en color normal tras la aparición,
   zoom breve compartido con el fondo EBDX y cry una única vez.
4. **Editor:** cambia `Pokedex/Lista > list_row_selected`, `seen_counter`
   y `Pokedex/Ficha > detail_name` (color/tamaño/posición); guarda, cierra
   y abre la Pokédex real. Cambia `Libreta/Catalogo > focus_panel` y
   `focus_name` y comprueba que no aparezcan dos paneles o dos textos.
5. **Animación de UI:** la apertura nativa y el `entrada` de elementos
   extra ocurren en el mismo intervalo. No debe reproducirse una segunda
   entrada decorativa después de abrirse la pantalla.

La sintaxis de JavaScript y JSON se verifica de forma estática; **estas
pruebas de render en Game.exe todavía deben ejecutarse en Windows**.
