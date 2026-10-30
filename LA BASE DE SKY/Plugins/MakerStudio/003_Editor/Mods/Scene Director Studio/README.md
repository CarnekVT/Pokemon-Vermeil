# Scene Director Studio v0.4.0 — guía rápida

Editor visual de escenas de Pokémon Vermeil para MakerStudio. Utiliza el mismo runtime de Scene Engine; no sustituye scripts Ruby ni reescribe el juego original.

## Flujo básico

1. Abre **Mods → Scene Director Studio** y crea una escena o importa `010_Intro.rb`.
2. En **Secuencia**, selecciona el bloque anterior a la posición donde quieres insertar uno nuevo.
3. Pulsa **＋ Añadir comando** o **Ctrl+K**. El buscador muestra categorías, nombres y descripciones; puedes buscar «diálogo», «imagen», «fade», «música» o «Ruby».
4. Edita el bloque en el **Inspector**. El Ruby efectivo se ve abajo y se puede copiar. Arrastra bloques en la secuencia o timeline para reordenarlos.
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

El menú **Archivo → Ver Ruby generado** muestra el código equivalente, distinto de la llamada al runtime. Los bloques Ruby importados sin modificaciones conservan su fuente.

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
