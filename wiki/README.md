# Wiki web del juego

Genera un sitio web estático con todos los datos de tu juego (Pokémon,
movimientos, habilidades, objetos, entrenadores, ubicaciones y tabla de tipos) y
resalta lo que has cambiado respecto a La Base de Sky.

Está pensado para publicarse en **GitHub Pages**, **GitLab Pages**, Netlify o
cualquier hosting de archivos estáticos.

## Uso

Desde la raíz del repositorio:

```bash
ruby wiki/generate.rb
```

En una terminal, abre un asistente con opciones recomendadas y pregunta por separado los accents claro y oscuro. Enter conserva `#1a3d5c` y `#5ba0d6`. También acepta los argumentos de abajo. Genera el sitio en `wiki/site/`; abre `wiki/site/index.html` en el navegador.

No hace falta instalar nada: usa el mismo arranque headless del motor que la
suite de tests (`tests/harness.rb`). La primera vez tarda un poco porque compila
los PBS.

### Opciones

| Opción | Efecto |
| --- | --- |
| `--out CARPETA` | Carpeta de salida (por defecto `wiki/site/`). Las carpetas existentes deben ser una wiki marcada como generada. |
| `--no-sprites` | No copia imágenes (wiki mucho más ligera). |
| `--accent-light COLOR` | Accent del tema claro; por defecto `#1a3d5c`. |
| `--accent-dark COLOR` | Accent del tema oscuro; por defecto `#5ba0d6`. |
| `--accent COLOR` | Atajo para usar el mismo accent en ambos temas. |
| `--baseline none` | No marca los cambios; genera la wiki completa a secas. |
| `--baseline RUTA` | Usa otro archivo de referencia en vez de `wiki/baseline.json`. |
| `--snapshot RUTA` | No genera la wiki: vuelca el estado actual como archivo de referencia. |
| `--no-recompile` | No recompila los PBS; usa los `Data/*.dat` que haya. |

> `generate.rb` recompila los PBS antes de leerlos (como hace el juego al
> arrancar en modo debug), así que la wiki siempre refleja tus `.txt`, incluidos
> los archivos divididos tipo `pokemon_custom.txt` y las secciones parciales.

## Cómo se marcan los cambios

`wiki/baseline.json` es la referencia versionada en Git. Guarda datos de la
versión canónica de los PBS de La Base de Sky, incluida la tabla de tipos. El
campo `_meta` registra el juego fuente y su versión. El generador compara cada
ficha completa con esa referencia y resalta los campos distintos.

En el repo canónico, el job `wiki-baseline` actualiza el archivo si un push cambia
PBS. Se ejecuta aunque falle otra etapa del pipeline; compila los datos y, si la
compilación funciona, genera el snapshot y confirma el cambio en la misma rama.
También se ejecuta cuando cambia el extractor o el propio job, para migrar el
formato. Los forks no pasan la validación `CI_PROJECT_PATH` y conservan su baseline.

El job usa `CI_JOB_TOKEN`. En GitLab, habilita la escritura del repositorio con
job tokens para que pueda confirmar `wiki/baseline.json`. Los listados permiten
filtrar solo cambios; la página «Cambios» reúne las diferencias detectadas.

Para generar una referencia manual desde una copia canónica, revisa primero una
vista previa fuera del repo:

```bash
ruby wiki/generate.rb --snapshot /tmp/wiki-baseline-preview.json
```

Para regenerarlo directamente desde la raíz del repo canónico y sobrescribirlo:

```bash
ruby wiki/generate.rb --snapshot wiki/baseline.json
```

Este comando recompila los PBS actuales antes de crear el baseline.

## Corregir cosas a mano

Dos formas, de menos a más técnica:

1. **`wiki/overrides/`** — un archivo Markdown por entrada a corregir. No hay que
   saber programar. Ver `wiki/overrides/EXAMPLE.md`. Sirve para arreglar un texto
   que salió mal y para añadir notas propias a una ficha. Se conserva al
   regenerar.
2. **Editar el HTML de `wiki/site/`** directamente. El HTML es limpio y sin
   minificar. Ojo: al volver a generar la wiki se sobrescribe; para cambios
   permanentes usa `overrides/`.

## Publicar

### GitHub Pages

Copia `deploy/github-pages.yml` a `.github/workflows/pages.yml` en tu repo,
haz push, y en *Settings → Pages* elige *GitHub Actions* como origen.

### GitLab Pages

Añade el contenido de `deploy/gitlab-pages.yml` a tu `.gitlab-ci.yml`.

### A mano

Sube el contenido de `wiki/site/` a cualquier hosting estático.
