# Command Studio 0.5.0 — asistente para principiantes

Integrado en Pokémon Vermeil, bajo `LA BASE DE SKY/Plugins/MakerStudio/003_Editor/Mods/com.carnek.command-studio`.

## Abrir y crear

1. Actualiza la rama **new-MK-for-2.5D-Testeo** y reinicia Maker Studio.
2. Abre un mapa y ve a **Mods → Command Studio** (también **Tools**).
3. Verás cuatro pestañas:
   - **Crear evento**: empezar con seis tareas habituales o escribir en lenguaje cotidiano lo que quieres hacer.
   - **Editor de mensajes**: escribir un diálogo, añadir controles desde botones y ver una aproximación legible.
   - **Enciclopedia**: 76 fichas de funciones y 57 directivas de mensajes.
   - **Avanzado**: conserva el compositor de secuencias y la indexación recursiva de métodos del proyecto.
4. Elige tarea → configura opciones → selecciona evento y página → pulsa «Añadir al evento».
5. Maker Studio aplica la edición por su API, con historial de deshacer. No sobrescribe otras páginas.

## Mensajes · Essentials Docs + LA BASE DE SKY + Vermeil

El archivo `messages-catalog.js` reúne **57 directivas** ordenadas por Variables, Formato, Colores, Alineación, Ventana, Velocidad, Sonido, Extras y Avanzado, explicadas en español.

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

- 29 acciones funcionales de evento.
- 76 fichas de recetas y funciones, configurables en modo avanzado.
- Indexador local de `Data/Scripts/**/*.rb` y `Plugins/**/*.rb`: puede detectar cientos/miles de métodos, pero eso **no significa** que todos se puedan ejecutar en eventos.
- La documentación Fandom indicada es antigua, no se mantiene activamente, así que los ejemplos se subordinan al motor instalado.
- Hay funciones internas, metaprogramación, `.rxdata` binarios y comandos específicos que el indexador no interpreta completamente. No se declara **100 % de cobertura**.
- Por ahora el asistente inserta acciones al final de una página existente. No cambia las condiciones, sprites ni páginas automáticamente.
- Requiere **Maker Studio Mod API 1.0.1 o superior**.

## Pruebas

`node tests/beginner-smoke.cjs`

Pruebas de sintaxis, cobertura de catálogo, generación de 29 acciones, códigos de mensaje y preservación de otras páginas usando un contexto falso de eventos. Hace falta validar la UI en la instalación del usuario.
