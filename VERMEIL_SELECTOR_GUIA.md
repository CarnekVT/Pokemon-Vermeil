# Pokémon Vermeil — selector visual y Scene Director

## Estado de integración
- `Plugins/[LBDS_CUST] Scene Engine/004_VermeilTreatment.rb`: nuevo selector en el runtime, persistente por partida.
- `Plugins/[LBDS_CUST] Scene Engine/010_Intro.rb`: selección integrada antes del nombre y diálogos reescritos para no anticipar el tratamiento.
- `Plugins/MakerStudio/003_Editor/Mods/Scene Director Studio/model.js`: comando `treatment_input` y compilación Ruby.
- `importer.js`: reconocimiento del comando al importar Ruby.
- `editor.js`: inspector y atajos de navegación.
- `preview.js`: reloj común para tiempos en frames y previsualización interactiva.

## Maqueta (640 × 480)
- Barra de título: x=41..599, y=30..98.
- Retrato de medio cuerpo: área objetivo x=168..472, y=102..422.
- Flechas laterales: x≈83 / x≈557, y≈260.
- Indicaciones al pie: y=433..456.
- Orden de opciones: femenino, neutro, masculino; opción inicial neutro.

## Recursos pendientes
Copiar los PNG transparentes al juego en:
```
LA BASE DE SKY/Graphics/Scenes/Intro/GenderSelect/
  solen_femenino.png
  solen_neutro.png
  solen_masculino.png
```
La UI está separada del retrato. No usar capturas de la pantalla completa como sprites. Los tres PNG se entregan aparte y todavía deben revisarse visualmente; no están incluidos en este commit.

## Persistencia / uso
```ruby
VermeilTreatment.current
VermeilTreatment.text(
  masculino: "Está preparado.",
  femenino: "Está preparada.",
  neutro: "Ya puede continuar."
)
```

El tratamiento neutro omite tanto «elle» como terminaciones en «-e». La elección no altera el sprite ni `trainer_type`. Para un diálogo narrativo se puede usar `treatment_text(masculino: ..., femenino: ..., neutro: ..., speaker: ...)`.

## Verificación de juego pendiente
- Reproducir intro original ingame desde nueva partida.
- Confirmar funcionamiento de Input izquierdo/derecho y aceptación de pantalla.
- Verificar guardado/carga de la opción y las frases gramaticales.
- Comparar tiempos runtime/preview de fades, esperas y bucles Ruby.
- Revisar ajuste final de retratos a 640×480, sin recortes ni halos.
- Comprobar que la versión exportada desde Scene Director conserve bloques Ruby avanzados.


## Corrección de velocidad, texto y versión Studio (29/10/2026)

- `mkxp.json` fija `fixedFramerate: 120`. Scene Engine ahora realiza pasos
  lógicos a 60 Hz: consume dos actualizaciones gráficas por paso cuando
  `Graphics.frame_rate` informa 120.
- Los mensajes de la intro usan explícitamente `speed: :slow`. Antes el
  narrador utilizaba `:slow` pero la guardiana y el Gran Espíritu heredaban
  `:normal`, el doble de caracteres por paso aproximadamente.
- Todos los `text_inline` de la intro carecen de saltos `\\n` forzados;
  el texto se ajusta por ancho y el paginador reequilibra la última página.
- El selector dibuja destellos, órbitas de partículas, pulso lateral,
  animación de entrada, balanceo del retrato y flash suave de confirmación.
- Studio importa y edita `treatment_input` y `treatment_text`, conserva
  los bloques Ruby y sincroniza los tiempos de texto de su preview.

### Actualizar una escena vieja del Studio sin duplicarla
1. Cierra y vuelve a abrir el juego / MakerStudio para cargar los plugins.
2. En Scene Director Studio, usa **Importar Ruby**, elige `010_Intro.rb`.
3. Si existe otra importación del mismo script y método, acepta **Actualizar
   escena desde Ruby**. Esto sustituye los comandos guardados en Studio de
   esa escena; se solicita confirmación antes.
4. Pulsa **Guardar** para regenerar `Data/SceneDirector/scenes.json`.
5. Reinicia la prueba. Comparar tanto la intro Ruby como la del menú
   Scene Director usando el mismo `mkxp.json`.

**Nota:** el `scenes.json` local no está versionado en esta rama. La nueva
versión del script fuente no modifica por sí sola escenas ya importadas.
Validar en ejecución real y revisar la compilación local; solo se han
verificado de forma estática/importación los archivos de la rama.


## Revisión de game feel y lectura (29/10/2026, segunda pasada)

### Timing en RPG Maker / mkxp-z
`LA BASE DE SKY/mkxp.json` establece `fixedFramerate: 120`.
Los scripts de Scene Engine están diseñados a 60 pasos lógicos/s.
Ahora `000_Settings.rb` expone:
- `CINEMATIC_RENDER_FPS = 120.0`
- `CINEMATIC_LOGIC_FPS = 60.0`
- `ELLIPSIS_HOLD_FRAMES = 42`

`003_ScenePlayer.rb#update` no depende de `Graphics.frame_rate`,
que puede devolver la tasa lógica de RGSS y no la física de mkxp-z.
Si se cambia la tasa de mkxp.json, actualizar también
`CINEMATIC_RENDER_FPS` para mantener la paridad temporal.

### Selección visual 640×480
Los tres PNG transparentes siguen en `Graphics/Scenes/Intro/GenderSelect/`.
Las flechas se cargan del juego en `Graphics/UI/left_arrow.png` y
`Graphics/UI/right_arrow.png`, sin añadir nuevas imágenes obligatorias.
Capas: fondo/placa, partículas, retrato anterior, retrato actual, flechas,
fundido negro. Efectos en runtime:
- Entrada: 36 pasos, ease-out desde negro.
- Cambio: 12 pasos, deslizamiento lateral y cruce de opacidad.
- Confirmación: 16 pasos de anticipación y 32 pasos de fundido a negro.
- Las flechas pulsan ligeramente y el retrato flota unos píxeles.
- Se espera indefinidamente al usuario sin confirmar automáticamente.

### Ritmo de la intro
- Descenso de Solen: `speed: 0.45`, `fade: 42`, `wait 645`.
- Pausas adicionales entre preguntas, confirmación del tratamiento y nombre.
- La respuesta al tratamiento neutro es amistosa, no impersonal.
- El Gran Espíritu ya no termina el diálogo con una línea residual
  «demasiado pronto.».
- `Despierta...` se revela con puntos suspensivos ralentizados y espera 114
  pasos antes de desvanecer el texto.
- Los saltos de párrafo explícitos continúan disponibles para otras escenas.

### Scene Director Studio
La previsualización incorpora flechas del mismo juego, entrada/salida con
curvas y retratos precargados. También incorpora la pausa de puntos
suspensivos, mejora el timeline para scripts `N.times do` y acepta
Enter/C además de espacio. **No se ha podido acceder al JSON local del
proyecto**; importar de nuevo `010_Intro.rb` y guardar en Studio para
recompilar la versión visual a partir de los últimos diálogos.

**Estado:** scripts actualizados en la rama. JS verificado por análisis
sintáctico e importador real probado. Requiere prueba ingame para validar
el comportamiento de Ruby/mkxp y las transiciones con los PNG definitivos.


## Revisión a partir de capturas, 29/10/2026 — tercera pasada

- Diálogos simplificados y sin suspensivos decorativos. Solo se conserva
  `Despierta...`; la pausa dramática global ahora es de 14 pasos.
- Despedida con un **único salto narrativo antes de «Cuídate»**. El cierre de
  la frase se acorta para evitar una línea aislada.
- Descenso de Solen: velocidad 0.78, fade 28, espera 355 + 18 pasos
  (comparar en la ejecución real; el periodo de caída se calcula tras el fade).
- Texto centrado `Despierta...`: velocidad normal + pausa de 14 pasos
  y 24 pasos de permanencia final, evitando desincronización con el despertar.
- Selector: entrada 22 pasos, cruce de retratos 8, confirmación 8,
  salida 18. No se repinta una flecha completa: `src_rect` recorta
  únicamente el primer fotograma de cada tira `Graphics/UI/left_arrow`
  y `Graphics/UI/right_arrow`.
- Mugshots: centrar según contorno alfa de cada PNG, en lugar de
  centrar el lienzo con márgenes transparentes desiguales. El Studio
  usa el mismo criterio mediante lectura de alfa de cada imagen.
- Pie de controles desplazado a y=414, separado del marco inferior
  para que no aparezca cortado.

### Avisos de sombras tras el teletransporte
La consola reporta búsquedas de `Graphics/Shadows/042_1`,
`042_4`, `042_5`, `042_6` en
`[MakerStudio] 002_RendererOverride.rb:1278`.

El directorio versionado `Graphics/Shadows/` contiene únicamente
`079_1.png`; no hay ninguno de los cuatro `042_*.png` solicitados.
El archivo `002_RendererOverride.rb` tampoco está versionado bajo la
carpeta `Plugins/MakerStudio` en la rama consultada. Por ello **no se ha
parcheado el renderer externo** ni se han creado PNG vacíos que oculten
sombras previstas. Corregir en el editor la referencia a sombras del
mapa 042, o restaurar sus gráficos reales, resolverá los recursos
ausentes. Si se requieren ajustes al loader, debe incorporarse el
archivo fuente exacto del renderer.

### Estado de pruebas
Los JS del Studio se han comprobado por sintaxis y la importación
de la intro reconoce las nueve fases y el selector; aún falta
la prueba visual ingame y reexportar la escena local desde el Studio.


## Selección de nombre y UI unificada (29/10/2026)

### Intro
El guion usa `custom_name_input(default: "Solen", min: 1, max: 12)`
después del tratamiento y antes del pacto. Los cinco diálogos revisados
priorizan castellano natural de alcance general. La despedida tiene un
único salto de párrafo antes de «Cuídate». `Despierta...` usa `:slow`
con una pausa final breve para no desincronizar el despertar.

### Nueva UI de nombre: 640 × 480
Se implementa en `[LBDS_CUST] Scene Engine/004_VermeilTreatment.rb`.
El marco, el panel del nombre y la barra inferior se dibujan por código,
con paleta crema/cobre/ciruela. A la izquierda aparece el retrato según
el tratamiento seleccionado. Se usa `Window_TextEntry_Keyboard` de
Essentials para manejar el texto (acentos, teclado, retroceso) con su
ventana de dibujo oculta. Así se evita la pantalla de nombre vanilla,
sin crear un editor de texto inseguro ni romper la entrada habitual.
Enter confirma si el nombre satisface el mínimo; no hay límite de
tiempo para escribir. Se conserva la actualización de `$player.name`.
Si una distribución no incluye `Window_TextEntry_Keyboard`, se utiliza
la entrada de nombre original como último recurso.

### Selector retocado
- Flechas nativas `Graphics/UI/left_arrow.png` y `right_arrow.png`.
- Estos PNG tienen **40 × 224**, con siete fotogramas de **40 × 32**;
  se muestra solo el primero mediante `src_rect`.
- Panel central, cabecera y pie rediseñados en crema/cobre para
  mantener continuidad con la UI de nombre.
- Retratos centrados por contorno opaco y ajustes artísticos de pose:
  femenino 0, neutro -21, masculino +30 píxeles.
- Las transiciones existentes de entrada, cruce y salida se conservan
  en las duraciones cortas ya ajustadas.

### Scene Director Studio
`custom_name_input` está reconocido por el modelo, el importador,
el inspector, la compilación Ruby y la previsualización 640 × 480.
La preview deja escribir caracteres, borrar con retroceso y
confirmar con Enter. Reimporta `010_Intro.rb` y vuelve a guardar
`Data/SceneDirector/scenes.json` para actualizar escenas antiguas.

### Pruebas pendientes en mkxp-z
- Verificar el teclado real, incluidas teclas de borrar y acentos,
  en `Window_TextEntry_Keyboard` con la ventana invisible.
- Revisar recorte y posición del retrato de las tres variantes.
- Verificar escritura/persistencia del nombre y restauración de
  `Input.text_input` tras confirmar.
- Comprobar sincronía de `Despierta...` con su secuencia de despertar.

No se han ejecutado aún estas pruebas de integración dentro del juego.


## Integración real de fondos y confirmaciones (29/10/2026)

Esta sección **reemplaza las indicaciones antiguas** que señalaban que los marcos
solo se dibujaban por código. Ahora ambos menús cargan sus fondos PNG desde:

- `LA BASE DE SKY/Graphics/Scenes/Intro/UI/treatment.png` — selector de
  tratamiento, 640×480, sin texto ni mugshots incrustados.
- `LA BASE DE SKY/Graphics/Scenes/Intro/UI/name.png` — entrada del nombre,
  640×480, sin texto ni mugshots incrustados.

Los PNG son **reemplazables** con los mismos nombres y resolución; el programa
dibuja las opciones, ayuda, retrato y nombre encima. Si falta un recurso, el
plugin conserva el diseño anterior como respaldo. Las capas de retrato no son
parte del fondo y se siguen cargando desde `GenderSelect/solen_*.png`.

**Alineación del selector:** se ha reservado el área superior para los
controles y reducido la altura máxima del retrato a 244 px. La indicación de
teclas ya no queda detrás de la imagen de Solen.

**Confirmación del tratamiento:** tras seleccionar una opción, aparece un
cuadro que permite **Confirmar** o **Cambiar**. La preferencia se guarda solo
después de confirmar.

**Confirmación del nombre:** Enter abre «¿Usar el nombre X?» con las opciones
**Confirmar** y **Cambiar**. Volver no borra lo escrito y no actualiza
`$player.name` hasta aceptar. El texto no incluye un cursor animado visible;
la ventana de teclado de Essentials se mantiene oculta, y su cursor interno se
coloca al final para una escritura más sencilla.

**Diálogos:** se compactaron frases susceptibles a cortes y se eliminó la
introducción redundante previa a la pantalla de nombre. La secuencia de
«Despierta...» usa `:slow` y permanece 70 pasos tras terminar de mostrarse.

**Scene Director Studio:** la vista previa carga los mismos dos fondos PNG,
las confirmaciones se pueden manejar mediante teclado o clic, y el editor
conserva la integración de `treatment_input` y `custom_name_input`.

**Verificación:** cabeceras y estructura de ambos PNG, 640×480; sintaxis JS
de model/importer/editor/preview. Sin prueba real de partida ni del teclado
mkxp-z en esta sesión. Volver a importar y guardar la escena local del Studio
para aplicar las modificaciones de guion.


## Corrección de nombre y despertar: última revisión

- **Escritura del nombre:** la confirmación del editor de texto escucha
  exclusivamente `Input.triggerex?(:RETURN)`. Ya no usa `Input::USE`,
  pues en los controles de Vermeil esa acción también se activa con la tecla
  C. La confirmación posterior («Confirmar / Cambiar») sigue siendo navegable
  con los botones habituales.
- **Campo de nombre:** línea guía fija y aviso «Escribe aquí» cuando está
  vacío. Se dibuja tanto sobre `Graphics/Scenes/Intro/UI/name.png` como
  en el respaldo gráfico generado por Ruby. La vista previa de Scene Director
  reproduce el mismo indicador, sin cursor oscilante.
- **Diálogos:** «¿Mantendrás el nombre Solen?» y una despedida compacta
  («Bueno, {1}, llegó la hora. ¡Cuídate y disfruta del viaje!»), evitando
  saltos forzados o páginas con una palabra aislada.
- **Despierta...:** nuevo ajuste exclusivo de escritura `:crawl`,
  `SPEED_CRAWL = 0.16` caracteres por paso lógico. El texto centrado conserva
  su tratamiento de puntos suspensivos y **ya no añade una espera posterior
  de 70 frames**. Después de revelarse completamente se oculta y la escena
  continúa de manera automática.
- **Scene Director:** `:crawl` se reconoce al importar, exportar,
  previsualizar y editar desde su inspector, y también en la estimación
  temporal de la línea de tiempo.

Verificación estática: 5 archivos JS sin errores sintácticos; el importador
mantiene 9 fases y 127 comandos, incluyendo `custom_name_input`,
`treatment_input` y `show_centered_text` con `:crawl`.
Prueba en mkxp-z aún pendiente.
