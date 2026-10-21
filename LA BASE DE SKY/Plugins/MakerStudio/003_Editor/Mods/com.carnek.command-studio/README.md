# Command Studio 0.3.0 — Maker Studio / Pokémon Vermeil

Versión ampliada para atender el problema de cobertura de Command Studio 0.2.0.

## Cómo abrir

1. Actualizar la rama **new-MK-for-2.5D-Testeo**.
2. Cerrar y volver a abrir Maker Studio.
3. Menú **Mods → Command Studio** (también **Tools → Command Studio**).
4. Al abrirse, se indexan automáticamente todos los archivos `.rb` accesibles en `Data/Scripts` y `Plugins`. El botón **Reindexar scripts** fuerza una nueva lectura.

## Fuentes y cobertura

- **Wiki LBDS:** 67 plantillas configurables de funciones y patrones documentados, con enlaces a los artículos originales de https://la-base-de-sky-wiki-1070f3.gitlab.io/.
- **Eventos RMXP:** 106 códigos, incluidos los auxiliares, con formularios para los más comunes y editor de parámetros JSON para los que aún no tienen un serializador visual especializado.
- **Código real del proyecto:** se enumeran recursivamente todos los `.rb` bajo `Data/Scripts` y `Plugins`, se extraen las declaraciones `def` y se infieren parámetros, valores por defecto y ámbitos.
- **PBS:** autocompletado de símbolos al abrir los archivos correspondientes de `PBS` (especies, objetos, movimientos, habilidades y tipos de entrenador).

**Importante: indexación no significa que todos los métodos Ruby sean comandos de evento.** Muchos son privados, internos, de instancia o requieren un receptor y estado concretos. El parser de Ruby es de propósito editorial, no un AST completo, y su interpretación de firmas complejas puede ser parcial. La pestaña Documentación enumera archivos no leídos, errores y estado de cobertura. No se promete el «100 %» sin comparar el índice con todas las fuentes compiladas.

## Editor

- Buscar sinónimos, funciones, categorías y nombres de archivos.
- Cambiar todos los parámetros de las 67 plantillas, incluidos símbolos, enteros, booleanos y expresiones.
- Configurar argumentos de métodos indexados, seleccionar tipos y alternar parámetros opcionales.
- Modificar manualmente el código generado antes de copiarlo.
- Comandos RMXP: construir parámetros mediante formularios o editor avanzado JSON.
- Inserciones de códigos de texto (nombre de jugador, variables, color, etc.).
- Leer la wiki oficial desde la propia ficha.

## Limitaciones actuales

- No modifica automáticamente eventos ni mapas de Maker Studio ni RPG Maker XP. Copiar texto/script pega en el editor de eventos; los objetos JSON necesitan importador, no deben pegarse en la caja de código Ruby.
- No interpreta el `Data/Scripts.rxdata` binario ni otras fuentes que no estén extraídas como Ruby legible. Si es el único repositorio de cierto script, debe extraerse antes de indexarlo.
- No extrae ni valida dinámicamente todas las funciones registradas mediante handlers, metaprogramación, alias o código generado.
- No comprueba a nivel de ejecución si una función/documentación es compatible con los cambios de LA BASE DE SKY o del juego; revisar la fuente Ruby real.
- Los errores de lectura en la indexación se muestran; una lectura completa de `.rb` no equivale a un catálogo semántico completo.
- El autocompletado PBS se basa en IDs de secciones y formatos simples; requiere revisar los identificadores según el proyecto.

## Archivos
- `index.js`: UI integrada.
- `catalog.js`: comandos nativos.
- `native-builder.js`: serialización RMXP de comandos habituales.
- `wiki-catalog.js`: plantillas con fuentes.
- `source-index.js`: indexador Ruby recursivo y constructor de argumentos.
- `pbs-index.js`: sugerencias desde PBS.
- `tests/smoke.cjs`: pruebas automatizadas sin depender de Maker Studio.

La app externa original se mantiene en `LA BASE DE SKY/DevTools/CommandStudio`.
