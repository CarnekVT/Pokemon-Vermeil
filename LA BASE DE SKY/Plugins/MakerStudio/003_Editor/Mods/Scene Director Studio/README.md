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

## v0.8.0
El cabezal admite segundos decimales (1.5 o 1,5), a 60 pasos/s. Arrastra diálogos, audio, transiciones y acciones visuales compatibles dentro de un clip de imagen o pausa, o usa Inicio en timeline en el inspector. Añadir Diálogo usa el cabezal. El runtime ejecuta el grupo mediante fibras cooperativas y mantiene la animación mientras espera confirmación del jugador. Los eventos de la misma pista se ejecutan en orden; el grupo termina cuando todas sus acciones concluyen, por lo que la duración del diálogo es estimada. Ruby arbitrario, entradas de nombre y otras acciones no admitidas permanecen secuenciales. Los cuadros de texto permiten seleccionar Windowskins con el navegador de gráficos; Estilo de cuadro permite regresar a Scenes. El runtime usa SpriteWindow_Base#setSkin, la preview aproxima los bordes mediante nueve regiones. El formato original permanece compatible. El scrubbing de grupos reconstruye estados de eventos, no simula cada fotograma de texto.

## v0.8.1
Ctrl+Z, Ctrl+Y y Ctrl+Shift+Z restauran proyecto, selección y cabezal. Botones visibles y estado del historial. Al añadir una clave posterior a frame 0 se guarda explícitamente el valor inicial de esa propiedad. Auto key permite animar desde Imagen y la manipulación en canvas; las propiedades ya animadas actualizan su clave en el fotograma actual. Inicio/fin y tiempo local decimal facilitan el zoom. Las claves antiguas se mantienen; al editar una propiedad con claves se materializa su inicio.

## v0.9.0
Control de escena: finalizar, encadenar, reservar evento común al salir, esperar confirmación, cambiar interruptor/variable y condiciones por acción. Activación secuencial, por tiempo en grupos compatibles, al inicio o tras confirmar un diálogo. Las acciones paralelas compatibles esperan su final real; las no compatibles esperan el grupo completo. Preview no ejecuta eventos ni evalúa condiciones del juego. Spritesheet en el clip: columnas/filas, rango, FPS, bucle, una pasada, ida/vuelta, manual mediante clave de fotograma. Recorte nativo de textura. Mantener visible conserva la última pose y celda. Encadenar limpia la escena anterior y detecta bucles.

## v0.9.1
Las escenas ejecutadas por SceneDirector.play inician con el overlay negro transparente. Los guiones originales de SceneEngine conservan su inicio negro por defecto; los fundidos explícitos siguen funcionando. El editor inicia con el mismo estado y ya no añade un fundido automático al primer gráfico. Los errores al cargar una imagen en SDS muestran su ruta y error en lugar de ocultar el fallo silenciosamente. No es necesario regenerar los JSON ya exportados para cambiar el estado inicial del overlay, pero sí actualizar los plugins Ruby.

## v0.9.2
Arrastrar un clip de imagen a un tiempo ocupado por otra imagen o una pausa crea una pista simultánea independiente. Se muestran filas de imagen según sus solapamientos. Clips del mismo archivo conservan instancias independientes; Ocultar imagen permite elegir el clip o todas las instancias de un archivo. Activación > Al confirmar diálogo espera la última página (en grupo paralelo o secuencia). El runtime reemplaza \\PN por el nombre actual del jugador; la preview usa el nombre introducido o Jugador como muestra. Para eventos de mapa de una sola ejecución usa SceneDirector.play_once("clave", @map_id, @event_id, "A") y una segunda página condicionada por A, o cambia a otro interruptor local libre. La llamada play normal sigue siendo repetible y bloquea llamadas reentrantes. Guarda las escenas otra vez para exportar IDs de instancias y dependencias. Las pistas son paralelas dentro de grupos compatibles, no un timeline global arbitrario.

## v0.9.3
El canvas de previsualización usa nearest-neighbor en cada dibujo y después de redimensionarse; también en spritesheets, estelas y edición aislada. Los sprites sin rotación se dibujan en coordenadas y tamaños enteros del lienzo sin modificar sus valores ni claves. El visor usa escalas de zoom predeterminadas y accesos 1×/2×, y no se encoge por flexbox. Ajustar puede usar una escala fraccionaria; las rotaciones y los tamaños no enteros pueden mostrar píxeles desiguales, no suavizado intencional. El runtime y la configuración global de MKXP no cambian en esta versión.

## v0.9.4
Un clip que sirve como ancla de acciones paralelas puede vincular su inicio a un diálogo sin mover manualmente las otras acciones. El editor crea un Grupo paralelo neutro y conserva los desplazamientos de las acciones que ya pertenecían al grupo; la imagen pasa a comenzar tras la confirmación del diálogo. Si el diálogo está en otro grupo, el clip se reubica, pero sus antiguos compañeros conservan el grupo de origen. La duración total puede cambiar según la vinculación. Para mantener la imagen visible y ocultarla al final de un diálogo, usa Desaparición al terminar diálogo en el inspector del clip: genera o actualiza una acción Ocultar con destino al clip y mantiene el recurso visible hasta entonces. La activación general controla el inicio, no el final. Guardar regenera el Ruby; no requiere cambios al runtime de v0.9.2.

## v0.9.5
SceneDirector.play consume la pulsación final y espera soltar los botones de interacción, limpia interact_calling antes de devolver el control al mapa. No convierte las escenas repetibles en únicas; play_once sigue disponible. En Spritesheet, Reproducción infinita mantiene el bucle o ping-pong tras la duración del clip, sin bloquear la secuencia y hasta ocultar/finalizar. Finalizar escena ofrece En seco/Desaparición fluida, pausa previa, duración del fundido y pausa posterior. El runtime conserva el mapa congelado hasta completar la salida. La preview aproxima el fundido sobre su fondo de edición, no sobre el mapa real. Guardar de nuevo para exportar nuevas opciones.

## v0.9.6
Fundido de imagen vinculado editable directamente sin volver a vincular. Ocultar/Reaparecer cuadro de texto conserva contenido y nombre; pista lógica de visibilidad independiente. Los windowskins nativos ajustan los márgenes y paginado del cuerpo. Cada diálogo admite windowskin independiente para nombre, color y sombra del speaker, y retorno explícito al cuadro de Scenes. La preview reproduce el formato XP/VX y las medidas custom de Essentials; el juego usa el renderer nativo. Inicio exacto en segundos o fotogramas, nudges y colocar en cabezal dentro de grupos compatibles; al mover una imagen ancla se crea un grupo neutro conservando sus hijos y tiempo original. Desvanecer música usa pbBGMFade y espera en su pista. No se modifica la intro original. Guarda para regenerar Ruby.

## v0.10.0
Transformar imagen: sustitución de recurso por instancia, corte, crossfade, destello o encogimiento; destino estático o spritesheet en bucle. Encadena varias transformaciones como Fase 9 de Intro.rb. Aura / partículas: 23 perfiles originales BSS adaptados al espacio SDS, con gráficos originales TotemCharged, color, trayectoria, mezcla, cantidad, ciclo, radio, escala, oscilación, opacidad, destino y duración persistente. Límite 48 por efecto y 128 global, sprites y texturas reutilizados. No reproduce animaciones BAS completas ni usa el runtime de combate; adapta el concepto de emisor y perfiles BSS (sin silueta de contorno ni capas paralelas originales). Fondo de color persistente y cambio de personaje jugador completan acciones de Intro. No modifica Intro.rb. Guardar para generar Ruby. Las transformaciones simultáneas toman control de la pose del clip original; para mantener sus keyframes posteriores crea una nueva etapa. Preview aproxima mezcla/color del motor.
