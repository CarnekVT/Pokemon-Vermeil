# PBS v16/v17 -> v21 Studio

Mod de Maker Studio para convertir datos PBS de Essentials v16/v17 al formato de Essentials v21 y dejarlos listos para copiar y pegar.

## Uso

1. Abre Maker Studio y activa el mod desde el Mod Manager.
2. Abre `Mods > PBS v16/v17 -> v21`.
3. Elige `Moves`, `Abilities`, `Pokemon`, `Items` o `Trainers`.
4. Pega un bloque PBS o usa `Leer archivo PBS`.
5. Pulsa `Convertir`, revisa los avisos y usa `Copiar resultado` o `Guardar en PBS`.

El mod trabaja con los archivos `PBS/moves.txt`, `PBS/abilities.txt`, `PBS/pokemon.txt`, `PBS/items.txt` y `PBS/trainers.txt`.

## Alcance

- Conserva comentarios, encabezados, orden, campos repetidos y claves desconocidas.
- Convierte alias históricos inequívocos, como `PP` a `TotalPP`, `MoveType` a `Type`, `Function` a `FunctionCode`, `Ability` a `Abilities` y `Plural` a `NamePlural`.
- Muestra advertencias para parties de entrenadores y listas de habilidades que necesitan revisión manual.
- No compila PBS ni modifica datos automáticamente hasta que pulses `Guardar en PBS`.

Siempre compila el PBS en Essentials v21 y corrige los avisos del compilador antes de probar el juego. Los datos de entrenadores antiguos son el caso que más suele necesitar revisión manual porque v16/v17 aceptaban variantes de party distintas.
