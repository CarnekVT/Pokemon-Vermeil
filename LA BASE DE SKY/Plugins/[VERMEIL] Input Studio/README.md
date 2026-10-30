# Input Studio 1.0.1 · Pokémon Vermeil

## Qué aporta
- Teclado y mando gestionados por acciones lógicas independientes de los ocho botones RGSS.
- Editor ingame con **F1** y edición de las dos primeras asignaciones por acción.
- Overrides por jugador fuera del proyecto: `System.data_directory/InputStudio/controls.json`.
- Acción de diseño en Maker Studio: Mods → Input Studio o Tools → Input Studio.
- Configuración por proyecto: `Plugins/[VERMEIL] Input Studio/actions.json`, escrita **solo** por el editor Maker Studio.
- Los archivos fuente de Pokémon Essentials y la base de keybindings de MKXP no se reemplazan.

## Entrada y compatibilidad
El runtime consulta las teclas físicas con `Input.pressex?/:triggerex?/:repeatex?/:releaseex?`, los botones del mando mediante `Input::Controller` y el stick izquierdo mediante `axes_left`. Un adaptador responde a `Input.press?/trigger?/repeat?/release?` para los botones lógicos de Essentials y proporciona `dir4/dir8` independientes durante el overworld. En el resto de contextos conserva la dirección nativa. El botón de menú original sigue funcionando con BACK, y se mantiene el F8 de capturas de pantalla.

### Para integraciones nuevas
```ruby
InputStudio.trigger?("bifrost_ball_next")
InputStudio.press?("bifrost_aim")
InputStudio.label("bifrost_ball_next") # Para HUD/key hints
```
Las acciones de Bifröst quedan declaradas en el catálogo, pero **el propio plugin consumidor** debe consultar esos IDs en vez de leer teclas fijas. Al entrar en su interacción, establecer el contexto explícitamente:
```ruby
InputStudio.with_context("bifrost") { # procesar entrada de Bifröst aquí }
```
Para una escena Bifröst persistente, puede ofrecer `InputStudio.context = ...` mediante una extensión local, pero el runtime base solo implementa contextos con `with_context`, para evitar fugas de estado.

### Teclas del F1
- `F1` abrir/cerrar, `Escape` cancelar/cerrar, `Tab` teclado/mando.
- Flechas izquierda/derecha: categoría; arriba/abajo: acción.
- `Enter` o clic: capturar asignación principal. `2`: capturar secundaria.
- `Supr`: limpiar bindings de ese dispositivo. `R`: restablecer la acción.
- Teclas reservadas: F1, F8, F9 y F12. Capturar F1/Escape cancela sin guardar.
- El F1 es un modal de sprites en `Graphics.update`: no ejecuta el mapa o combate en segundo plano.

## Limitaciones y siguiente integración
- Las acciones personalizadas se registran pero deben ser utilizadas por los scripts consumidores.
- Captura de entrada física simple (una tecla o botón). No hay soporte de acordes Ctrl+tecla ni mapeo manual de ejes todavía.
- La vista ingame está optimizada para 640×480 y escala según Graphics.width/height.
- El panel Maker Studio modifica el catálogo predeterminado. No edita el perfil personal del jugador.
- No se ha podido ejecutar Game.exe en este entorno: verificar F1, movimiento, menús, combate, Plugins y persistencia en Windows/mkxp-z.

## Pruebas manuales recomendadas
1. Iniciar mapa → F1 → reasignar arriba a I → cerrar → pulsar I y comprobar que ↑ anterior deja de mover.
2. Confirmar que el menú, caja de texto, mochila y combate siguen respondiendo y Esc cancela.
3. Crear perfil, cerrar Game.exe, volver a abrir: las asignaciones deben persistir.
4. Con mando, probar cruceta, stick y reasignación por F1; desconectar el mando.
5. Cambiar de tamaño de ventana/alt-enter, abrir F1 y confirmar que no hay interferencia con la ventana del juego.
6. En Maker Studio, editar action.json, guardar, reabrir: lectura idéntica.
7. Verificar que F8 continúa haciendo capturas y F9 mantiene debug.

## Correcciones 1.0.1 (30-10-2026)
- `Input.dir4` vuelve a aceptar el argumento opcional `@moved_last_frame` que envía Game_Player y Vermeil Smooth Movement. `Input.dir8` también admite argumentos sin romper la API antigua.
- Los controles de F1 pueden reasignar una tecla previamente ocupada: se muestra el conflicto y el jugador confirma con Enter/A o cancela con Esc/B. La confirmación libera esa tecla de las otras acciones en contextos compartidos; ningún override se elimina sin confirmación.
- Captura SDL por cambios físicos de estado, con alternativa mediante `triggerex?` si `raw_key_states` o `raw_button_states` no están expuestas en el build utilizado.
- Selector de categorías dinámico para no mostrar categorías vacías.
- Guardado con mecanismo de respaldo en Windows, y recuperación de perfil en memoria si falla el guardado.
- Comprobaciones lógicas aisladas de runtime y ventana en `DeveloperTests/input_studio_regression.rb`.

**Nota:** estas verificaciones no son una prueba del motor gráfico ni de todos los plugins. Antes de publicar, probar movimiento, captura, carga y restauración de keybindings, F1 y tránsito mapa/menú/combate dentro de Game.exe.
