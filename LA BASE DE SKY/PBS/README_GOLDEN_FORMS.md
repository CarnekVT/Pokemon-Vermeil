# Pokémon Vermeil — PBS de formas y movimientos dorados

Los datos jugables de las formas doradas y sus movimientos especiales están separados de los PBS estándar de Essentials:

- `PBS/golden_forms.txt`: transformación de cada especie o forma de origen; número de la forma de destino, habilidad, tipos y estadísticas.
- `PBS/golden_moves.txt`: modificaciones exclusivas de movimientos cuando la Forma Dorada está activa.

**Prioridad de lectura:** PBS dedicado → JSON heredado (`Data/GoldenSystem/species.json`, `golden_moves.json`). El JSON se conserva íntegro: **goldenType** y **goldenTypeReplace** siguen allí, junto con configuración adicional no migrada. Los PBS no crean nuevos ID de movimientos ni reemplazan `PBS/moves.txt`; se aplican como variantes contextuales en combate.

Golden Systems Studio (Maker Studio) lee y escribe ambos formatos al guardar, utilizando estos PBS como fuente prioritaria para formas y movimientos. Se recomienda editar desde Golden Systems Studio o actualizar el PBS manualmente y recargar el editor. Al guardar desde el editor, el texto PBS se vuelve a serializar y pueden cambiar el orden y los comentarios; los campos reconocidos permanecen.

## Formatos

```ini
[HERACROSS]
Number = 2
Ability = UNSTOPPABLECHARGE
Types = BUG,FIGHTING
BaseStats = 80,160,65,30,75,115
```

**Orden de BaseStats:** HP, ATTACK, DEFENSE, SPECIAL_ATTACK, SPECIAL_DEFENSE, SPEED. Es distinto del orden de presentación del hash JSON, por lo que el lector usa nombres para garantizar una migración correcta.

```ini
[HERACROSS|MEGAHORN]
Form = 2
Name = Cuerno Astral
Type = DRAGON
Power = 120
Accuracy = 85
```

El campo `Form` es el destino dorado, y `[ESPECIE|MOVIMIENTO|FORMA_ORIGEN]` permite personalizar variantes dependientes de una forma de origen concreta.

## Datos incompletos conocidos

Las entradas `CHARIZARD,1`, `CHARIZARD,2` y `CHARIZARD,3` incluyen tipos y estadísticas, pero **no declaran Number** (forma de destino). Están preservadas como borradores, no como transformaciones activas. Completar `Number` requiere elegir un índice que no colisione con otras formas del Pokémon y preparar sus gráficos. No se inventa un índice automáticamente.

`HELIOLISK` declara Number=1, pero aún no se encontró el sprite específico `Graphics/Pokemon/Front/HELIOLISK_1.png` en la revisión. El juego puede usar el gráfico base hasta que añadas el sprite. Heracross y Pinsir tienen archivos de forma 2.

## Pruebas

En GitHub Actions, `Vermeil Pokedex Notebook Golden QA` verifica sintaxis Ruby y JavaScript, presencia de los perfiles y la equivalencia de datos esenciales de PBS con los JSON heredados. La prueba no reemplaza el testeo de combate dentro de mkxp/Essentials.
