# Generador de la wiki para jugadores

El generador crea un sitio estático para que los jugadores consulten Pokémon,
movimientos, habilidades, objetos, entrenadores, encuentros, ubicaciones y
cambios respecto a los datos oficiales. La wiki puede personalizarse desde una
interfaz visual, sin editar Ruby ni PBS.

## Empezar

Ejecuta los comandos desde la raíz del repositorio, donde está `wiki/generate.rb`.
El generador localiza el juego por `mkxp.json`, `PBS/` y `Data/Scripts/`, aunque esté
en una subcarpeta o tenga otro nombre. Si el repositorio contiene varios juegos,
define `WIKI_GAME_DIR` con la ruta de la carpeta elegida. Por ejemplo, en macOS/Linux:

```bash
WIKI_GAME_DIR="ruta/al/juego" ruby wiki/generate.rb
```

En PowerShell:

```powershell
$env:WIKI_GAME_DIR = "C:\ruta\al\juego"
ruby wiki/generate.rb
```

Necesitas Ruby 3.1 o superior; no hace falta instalar gems ni abrir el juego.

```bash
ruby wiki/generate.rb
```

En una terminal interactiva verás un menú. Elige **Configurar la wiki en el
navegador** para abrir el configurador visual. También puedes abrirlo directamente:

```bash
ruby wiki/generate.rb --configure
```

En el configurador, revisa las pestañas, pulsa **Guardar y generar wiki** y
espera a que termine la compilación. La configuración se guarda en
`wiki/config.json`; la wiki resultante queda en `wiki/site/`.

## Previsualizar en VS Code

La forma recomendada es usar la extensión [Live Server de Ritwick Dey](https://marketplace.visualstudio.com/items?itemName=ritwickdey.LiveServer):

1. Abre en VS Code la carpeta del repositorio.
2. Instala **Live Server** desde la vista de Extensiones.
3. En el Explorador, abre `wiki/site/index.html` con el botón derecho y selecciona **Open with Live Server**. También puedes abrir el archivo y pulsar **Go Live** en la barra inferior.
4. El navegador abre la wiki en una dirección local y recarga la página cuando cambian los archivos.

Pulsa **Port: …** o **Go Live** de nuevo para detener el servidor. No abras el HTML con `file://`: servir el sitio localmente permite que funcionen todas las funciones de búsqueda.

Al volver a ejecutar `ruby wiki/generate.rb`, se conservan las opciones guardadas.
Añade `wiki/config.json` al control de versiones de tu proyecto para compartir la
configuración con el resto del equipo.

## Configurar los combates

En la pestaña **Entrenadores** puedes configurar las variantes de equipo:

1. Define los modos disponibles para tu juego, por ejemplo «Historia» y
   «Difícil». Los nombres son libres; puede haber uno o varios.
2. Indica qué tipo corresponde a cada inicial del juego.
3. Asigna modos a las versiones de entrenador del PBS. Puedes asignar una misma
   versión a varios modos. La asignación masiva por versión ahorra trabajo cuando
   los PBS siguen una convención, por ejemplo versión 0 para clásico y versión 1
   para completo.
4. Si un modo no tiene una versión propia, configura que herede los equipos de
   otro modo. Las excepciones se pueden ajustar por entrenador.
5. Personaliza el nombre visible de cada combate cuando lo necesites, por
   ejemplo «Primer combate» o «Revancha».

La versión PBS es el número interno del equipo del entrenador; los jugadores no
verán ese número. Si un entrenador tiene equipos adicionales para una revancha,
puedes mantenerlos en versiones aparte aunque usen el mismo modo.

En la wiki generada, el jugador puede elegir una vez el tipo de su inicial desde
la lista de entrenadores. La elección se guarda en el navegador y filtra las
variantes correspondientes; también puede cambiarla desde una ficha individual.

## Elegir qué información publicar

La pestaña **Contenido** permite ocultar secciones completas, como ubicaciones,
objetos encontrados en mapas, encuentros salvajes o equipos de entrenadores.
Esto sirve, por ejemplo, para no revelar dónde se encuentran los objetos y dejar
que el jugador los descubra.

En **Apariencia** puedes elegir acentos distintos para los temas claro y oscuro.
Las opciones generales incluyen la carpeta de salida, recompilar PBS y copiar o
omitir imágenes.

## Generar por terminal

El asistente permite cambiar la carpeta de salida, incluir imágenes, recompilar
PBS y configurar ambos colores. También puedes usar opciones de línea de comandos:

| Opción | Efecto |
| --- | --- |
| `--configure` | Abre el configurador visual local. |
| `--out CARPETA` | Elige otra carpeta para el sitio generado. |
| `--no-sprites` | Omite imágenes para reducir el tamaño de la wiki. |
| `--accent-light COLOR` | Cambia el acento del tema claro. |
| `--accent-dark COLOR` | Cambia el acento del tema oscuro. |
| `--accent COLOR` | Usa el mismo acento en ambos temas. |
| `--baseline none` | Genera sin destacar diferencias. |
| `--baseline RUTA` | Usa otro archivo de referencia. |
| `--snapshot RUTA` | Exporta los datos actuales como snapshot. |
| `--no-recompile` | Usa los datos compilados existentes en `Data/`. |

Por defecto, la generación compila los PBS actuales antes de extraer los datos.
El juego no se inicia: el soporte headless compila los datos y restaura los
archivos `Data/*.dat` originales al terminar. Usa `--no-recompile` solo cuando
quieras reutilizar una compilación existente.

## Baseline y diferencias

`wiki/baseline.json` contiene la referencia versionada contra la que se comparan
los PBS del proyecto. En juegos basados en La Base de Sky, conserva el baseline
de la base para que la wiki muestre qué cambió respecto a los juegos oficiales.
No lo regeneres desde el juego derivado: pasaría a tratar sus cambios como parte
de la referencia.

En el repositorio canónico, el job `wiki-baseline` de GitLab actualiza el snapshot
automáticamente cuando hay un push a una rama que modifica PBS, el extractor o el
generador. Si los datos cambiaron, el job confirma `wiki/baseline.json` en esa misma
rama. En forks no se ejecuta esta actualización automática.

El snapshot manual se usa para mantener o actualizar el baseline canónico, no
para crear el baseline de un juego derivado:

```bash
ruby wiki/generate.rb --snapshot /tmp/wiki-baseline-preview.json
```

Los archivos de `wiki/overrides/` permiten corregir o ampliar textos de fichas a
mano. Se conservan al regenerar la wiki.

## Publicar

`wiki/site/` es un sitio estático. El repositorio incluye plantillas para publicar
con CI:

- **GitHub Pages:** copia `deploy/github-pages.yml` a `.github/workflows/pages.yml`.
  En *Settings → Pages*, selecciona *GitHub Actions*. Ajusta las rutas PBS/Data y
  ramas del workflow a la estructura de tu repo.
- **GitLab Pages:** incorpora el job de `deploy/gitlab-pages.yml` en
  `.gitlab-ci.yml` y ajusta la etapa, la rama y las rutas del juego si hace falta.
- **Otro hosting:** sube el contenido de `wiki/site/` como sitio estático.
