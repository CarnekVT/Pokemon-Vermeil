# [VERMEIL] Gender Name Command

Plugin sencillo para **Pokémon Essentials v21.1** que agrega el código de diálogo `\AN`. No sustituye ni modifica el nombre real del jugador.

## Uso en eventos

En el comando **Mostrar texto**, escribe:

```text
\AN se comió la baya.
```

- Protagonista masculino: **Dorian se comió la baya.**
- Protagonista femenino: **Gilia se comió la baya.**

También funciona en scripts:

```ruby
pbMessage("\\AN se comió la baya.")
```

Los nombres se cambian en `001_GenderNameCommand.rb`, dentro de `VermeilGenderName`:

```ruby
MALE_NAME   = "Dorian"
FEMALE_NAME = "Gilia"
```

## Comportamiento

- Detecta el género actual mediante `$player.male?` / `$player.female?`.
- Respeta mayúsculas/minúsculas: `\AN` y `\an` funcionan.
- `\PN` sigue mostrando el nombre real del jugador.
- No modifica los datos del jugador, ni los textos fuente o traducciones.
- El reemplazo se realiza en `pbMessageDisplay` y cubre los diálogos normales, incluidos los eventos y `pbMessage`.
- Si todavía no existe un jugador válido, `\AN` se deja sin sustituir.
- `\\AN` (barra invertida escapada) se conserva como texto literal.
- No añade reemplazos a las etiquetas de opciones del menú ni a los nombres de mapas.

El plugin está aislado en su propia carpeta. Solo requiere añadirla a `Plugins` y compilar los plugins de Essentials cuando corresponda.
