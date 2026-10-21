# Command Studio 0.4.0 · Pokémon Vermeil
Una herramienta **de creación de eventos**, no un diccionario de código para copiar y pegar.

## Uso

1. Actualiza `new-MK-for-2.5D-Testeo` y **reinicia Maker Studio**.
2. Abre un mapa del proyecto.
3. Entra en **Mods → Command Studio**.
4. Arriba selecciona **evento** y **página**; define si deseas insertar **al principio** o **al final** (no sobreescribe los comandos previos).
5. En **Crear evento** escribe una intención: "curar equipo", "recompensa una vez", "entrenador", "diálogo", etc.
6. Configura sus campos. Puedes pulsar **Insertar esta acción en el evento** o **+ Añadir a secuencia** para combinar acciones.
7. Reordena los pasos del panel Secuencia y aplica la secuencia completa. Maker Studio lo trata como una actualización **deshacible**.
8. Usa **Guardar plantilla** y Biblioteca para reutilizar rutinas.

## Estructura de la herramienta

- **27 acciones de uso real:** diálogos, opciones, regalos únicos, Pokémon, entrenadores, combates, condiciones, switches, variables, transferencias, audio, escenas, servicios.
- **Búsqueda por intención:** sinónimos y ranking, no requiere memorizar Ruby.
- **Compositor de eventos:** pasos configurables, ordenables, editables, plantilla personalizada por proyecto y vista previa estructurada.
- **Inserción real y deshacible:** `ctx.events.getFull` → `createCommand` → `validateEvent` → `update`. Solo cambia la lista de comandos de la página indicada.
- **Selector nativo de comandos:** añade una pestaña **Pokémon Essentials** con asistentes reeditables para objetos, regalos Pokémon, combates y reglas.
- **Biblioteca avanzada:** 67 plantillas referenciales de la wiki LBDS, en un área aparte de los flujos curados.
- **Código fuente:** indexación bajo demanda de `Data/Scripts/` y `Plugins/`, con firmas y ubicaciones. Un método indexado no es automáticamente una función válida de evento.
- **PBS:** sugerencias para identificadores internos.

## Qué no incluye

- **No promete cobertura semántica del 100 %:** el repositorio tiene código interno, callbacks y métodos que no deben ejecutarse desde eventos. La búsqueda avanzada conserva esas referencias pero la portada solo presenta acciones útiles.
- La búsqueda por intención es local, basada en etiquetas y sinónimos; no utiliza un modelo de IA externo.
- Los asistentes de audio generan Ruby (por ejemplo `pbSEPlay`), evitando objetos RMXP difíciles de serializar desde JavaScript.
- Por seguridad solo inserta en la raíz de una página, al principio o al final: no rompe bucles, condicionales ni grupos de comandos existentes.
- No crea ni cambia condiciones de páginas automáticamente (trigger, gráfico, etc.). El usuario puede editarlas con el editor nativo.
- No modifica `.rxdata` directamente. Maker Studio debe soportar **Mod API >= 1.0.1**.
- La validación del editor verifica los tipos de comando; no garantiza que todos los scripts Ruby funcionen correctamente en ejecución.

## Fuente de integración

Maker Studio, Mod API 1.0.1: https://makerstudio.toskan.es/es/mods/api-reference/#events
Wiki LBDS: https://la-base-de-sky-wiki-1070f3.gitlab.io/

## Desarrollo

Puedes ejecutar las pruebas automatizadas Node del mod:

`node tests/smoke.cjs`

Se preserva la herramienta externa anterior de `DevTools/CommandStudio`, pero ya no es necesaria para insertar comandos desde Maker Studio.
