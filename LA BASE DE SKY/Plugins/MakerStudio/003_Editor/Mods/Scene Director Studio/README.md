# Scene Director Studio v0.6.1 — guía rápida

Editor visual de escenas de Pokémon Vermeil para MakerStudio. Utiliza el mismo runtime de Scene Engine; no sustituye scripts Ruby ni reescribe el juego original.

## Flujo básico

1. Abre **Mods → Scene Director Studio** y crea una escena o importa `010_Intro.rb`.
2. Busca gráficos, audio o acciones en **Biblioteca**; haz clic para insertar después del clip seleccionado o arrastra a la línea de tiempo.
3. Pulsa **＋ Todas las acciones** o **Ctrl+K**. El buscador muestra categorías, nombres y descripciones; puedes buscar «diálogo», «imagen», «fade», «música» o «Ruby».
4. Edita el clip en **Propiedades**. El Ruby efectivo está plegado en Ruby avanzado y se puede copiar. Arrastra bloques en la secuencia o timeline para reordenarlos.
5. Usa **▶ Reproducir** para previsualizar. El botón **Ocultar timeline** deja más espacio; el mismo botón vuelve a mostrarlo.
6. **Guardar / Ctrl+S** escribe `Data/SceneDirector/scenes.json`. Los cambios no aparecen en el juego hasta guardarse.
7. **⎘ Copiar llamada** genera el comando Ruby necesario para ejecutar la escena desde un evento o plugin.

## Ejecutar dentro del juego

Cada tarjeta de la biblioteca muestra y permite copiar el comando específico de su escena, por ejemplo:

```ruby
SceneDirector.play("mi_escena")
```

El identificador es `scene.key`; no es el nombre visible de la escena ni su `id` interno. **No copies literalmente `mi_escena`**: usa el botón del Studio para obtener la clave auténtica.

En RPG Maker se coloca en un comando **Script** dentro de un evento, o se invoca desde un plugin Ruby. Necesita **[CARNEK] Scene Director Runtime** y el archivo `scenes.json` guardado. **¿Cómo usar ingame?** abre una guía que permite guardar y copiar la llamada.

El menú **Archivo → Ver Ruby generado** muestra el código equivalente, distinto de la llamada al runtime. Ahora permite **Copiar Ruby** y **Exportar .rb**, además de copiar la llamada `SceneDirector.play(...)`. La exportación .rb no reemplaza los archivos existentes del proyecto y conserva literalmente los bloques Ruby importados sin modificaciones; revisa el nombre del método antes de usar el archivo exportado en el juego.

## Modos de pantalla

- **⛶ Pantalla completa**: ocupa el área de MakerStudio al estilo Battle Animation Studio / Battle Scene Studio, sin usar la Fullscreen API del navegador.
- **↙ Pantalla normal**: vuelve al panel original y restaura el área de trabajo donde estaba.
- **F11** alterna ambos modos; **Esc** sale del modo ampliado.
- Los cambios de tamaño reajustan el preview. El estado de la escena y el contenido editable no se destruyen al alternar.

## Atajos

| Atajo | Acción |
|---|---|
| Ctrl+S | Guardar escenas |
| Ctrl+K | Abrir buscador de comandos |
| F11 | Alternar pantalla completa / normal |
| Esc | Cerrar buscador o salir de pantalla completa |
| Espacio | Reproducir o avanzar texto (sin estar editando un input) |
| Ctrl+Z / Ctrl+Y | Deshacer / rehacer |
| Ctrl+D | Duplicar bloque seleccionado |
| Suprimir | Borrar bloque seleccionado |

## Notas de compatibilidad y seguridad

- Las rutas de imágenes y de audio se buscan dentro del proyecto, sin sobrescribir assets originales.
- El guardado conserva el formato `formatVersion=1`; **no** migra ni reestructura escenas existentes automáticamente.
- La vista previa interpreta los comandos conocidos; el Ruby arbitrario importado puede contener lógica que no sea reproducible en Studio pero sí en el juego.
- El modo pantalla completa y el flujo del portapapeles requieren una comprobación visual final dentro de MakerStudio. Si el acceso al portapapeles está bloqueado, la aplicación muestra el comando en un campo seleccionable para copiarlo manualmente.

## v0.4.1 · Compatibilidad de ventanas emergentes en pantalla completa

El workspace usa el mismo nivel base de BAS y BSS (`z-index: 5000`, en vez del anterior valor extremo). Mientras un diálogo nativo del editor está abierto (seleccionar archivos, imágenes, audio, importar Ruby, plantillas o introducir un nombre), Scene Director cede temporalmente su capa para mostrarlo por encima. Recupera el nivel normal al cerrarse y evita secuestrar las teclas del diálogo.

Las notificaciones del Studio aparecen dentro del espacio ampliado para que no queden ocultas. El editor sigue siendo utilizable en pantalla normal y el fullscreen no necesita la Fullscreen API del navegador.

**Validación:** sintaxis estática y prueba aislada del cambio de capa y restauración. Pendiente contrastar con una sesión real de MakerStudio.

## v0.5.0 · Workspace audiovisual

- Biblioteca por gráficos, audio, acciones y secuencia; búsqueda, miniaturas paginadas y arrastre a cualquier punto de inserción.
- Timeline con regla en segundos aproximados, zoom independiente, playhead de selección, ajuste de altura y arrastre con indicador de inserción. Los bordes ajustan únicamente esperas/fades/duraciones soportadas por el runtime.
- Preview con controles debajo y edición directa de la posición de imágenes `show` seleccionadas (cuando contienen coordenadas numéricas). Paneles laterales redimensionables.
- Se preserva `formatVersion=1`, el orden de comandos y Ruby importado sin cambios. El timeline muestra posiciones estimadas de ejecución, no pistas simultáneas ni keyframes independientes. Los diálogos con input y Ruby arbitrario no tienen duración determinista. El click en la regla reconstruye el estado al final del comando elegido, no hace seek exacto por frame. Los gráficos se cargan de 30 en 30, en lotes de cuatro, y se liberan al cambiar de pestaña o cerrar.

## v0.5.1 · Recursos y navegación

- Gráficos de toda la jerarquía `Graphics` (incluye `Pictures`, `Battlers`, `Pokemon`, `Characters`, etc.). La búsqueda filtra la carpeta abierta; se entra con clic y se sube con ↑. El selector del inspector usa el mismo navegador. Los gráficos existentes se referencian por ruta relativa sin copiarse.
- El importador crea `Graphics/Scenes/Imported` (o la ruta configurada de escenas) si falta y evita sobrescribir nombres existentes. `+` en la biblioteca importa un archivo externo. Las miniaturas se cargan por página.
- Timeline: rueda horizontal o Shift+rueda; Ctrl+rueda amplía alrededor del puntero; botón central arrastra el área; barra inferior desplaza toda la secuencia; regla arrastrable, zoom de .02 a 8 px/frame, centrar y seguimiento opcional. Flechas izquierda/derecha avanzan por comandos, Home/End van a extremos. Desde aquí reproduce a partir del comando elegido.
- Papel cebolla: rojo para sprites del estado anterior, cian para el siguiente, ambos o individual y opacidad regulable. Se excluyen sprites sin cambios y no se guarda ni ejecuta en el juego. Se desactiva durante la reproducción. El estado se obtiene en límites de comandos; no equivale a muestreo de fotogramas o pistas simultáneas.

## v0.6.0
Añadir Imagen crea clips editables. Seleccionar Imagen permite transformar, alinear y encajar el recurso; Animación ofrece entrada, movimiento y salida, duración e interpolación. El cursor local y la prueba de animación permiten visualizar el resultado. Solo imagen aísla el gráfico para editar bajo otros elementos. El runtime reproduce los nuevos clips; mantener visible conserva su pose final. Los clips siguen siendo secuenciales, no pistas paralelas; la intro Ruby original no cambia. La conversión de show es opcional.

## v0.6.1
Biblioteca y selector de imagen comparten un explorador con árbol de carpetas, ruta navegable, historial, búsqueda local/global explícita, miniaturas y previsualización. Seleccionar no inserta; Añadir a escena o arrastrar al timeline lo hace. Mostrar imagen conserva su comando original y ofrece centrado, encajar, llenar, tamaño en porcentaje y duración del fundido en segundos. Los clips de imagen usan la misma presentación. Seleccionar una imagen activa edición aislada; Ver escena recupera la composición real. En una escena totalmente vacía, añadir el primer gráfico mediante la biblioteca inserta una apertura de negro de un fotograma para evitar que quede tapado; las escenas existentes y Ruby original no se modifican automáticamente.

## v0.7.0
La pestaña Keyframes en cada clip permite crear, editar, mover y eliminar claves independientes de posición X/Y, escala, rotación y opacidad. La interpolación sigue el esquema del BAS (lineal, ease_in/out/both), con modo mantener. Mover o escalar el gráfico en el visor desde esta pestaña crea claves en el fotograma actual. Los diamantes de la timeline saltan a las claves. El runtime Ruby recibe los mismos datos; las claves reemplazan los presets de movimiento por propiedad, y las entradas/salidas se aplican después. La vista de edición muestra una cuadrícula gris y omite los overlays de fundido negro/blanco por defecto; Ver fundidos activa la composición con transiciones. Esto no altera el runtime ni la intro original. Los clips todavía tienen ejecución secuencial.
