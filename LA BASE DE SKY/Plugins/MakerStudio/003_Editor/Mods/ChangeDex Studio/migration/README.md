# ChangeDex migrations

## First Branch vs PBS Base

`First Branch vs PBS Base.json` fue generado comparando los dos PBS adjuntos en esta tanda. La comparación resuelve primero la herencia de formas y después calcula sólo diferencias semánticas de campos compatibles con ChangeDex.

- 1479 entradas oficiales comunes.
- 1168 especies/formas con diferencias.
- 2673 campos diferentes.
- 33 entradas sólo en PBS Base y 6 sólo en First Branch se reportan pero no se fuerzan como overrides.
- Las entradas procedentes de archivos específicos de Vermeil se excluyen para que el preset se concentre en Pokémon oficiales.
- Reordenar sin cambiar contenido no cuenta como cambio para Moves, TutorMoves, EggMoves, Flags y Evolutions.

El flujo limpio es **PBS Base → JSON First Branch → runtime**.

## Legacy

`Vermeil First Branch - legacy pokemon changes.json` conserva la migración pequeña generada desde el antiguo `PBS Changes/pokemon.txt`.
