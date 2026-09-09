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

Genera el sitio en `wiki/site/`. Abre `wiki/site/index.html` en el navegador.

No hace falta instalar nada: usa el mismo arranque headless del motor que la
suite de tests (`tests/harness.rb`). La primera vez tarda un poco porque compila
los PBS.

### Opciones

| Opción | Efecto |
| --- | --- |
| `--out CARPETA` | Carpeta de salida (por defecto `wiki/site/`). |
| `--no-sprites` | No copia imágenes (wiki mucho más ligera). |
| `--baseline none` | No marca los cambios; genera la wiki completa a secas. |
| `--baseline RUTA` | Usa otro archivo de referencia en vez de `wiki/baseline.json`. |
| `--snapshot RUTA` | No genera la wiki: vuelca el estado actual como archivo de referencia. |
| `--no-recompile` | No recompila los PBS; usa los `Data/*.dat` que haya. |

> `generate.rb` recompila los PBS antes de leerlos (como hace el juego al
> arrancar en modo debug), así que la wiki siempre refleja tus `.txt`, incluidos
> los archivos divididos tipo `pokemon_custom.txt` y las secciones parciales.

## Cómo se marcan los cambios

`wiki/baseline.json` es una foto de datos de referencia (por defecto, los de La
Base de Sky). El generador compara el estado de tu juego contra esa foto y marca
cada Pokémon / movimiento / etc. como **Nuevo** o **Modificado** directamente en
su ficha, con el detalle de qué campos cambiaron y sus valores antes/después.

El texto de esas anotaciones ("Cambios respecto a los juegos oficiales") se ajusta
en la constante `BASELINE_LABEL` de `wiki/lib/render.rb`.

Cuando actualices tu copia de La Base de Sky, `wiki/baseline.json` se actualizará
con ella y el diff se recalcula solo.

Si mantienes tú La Base de Sky, regenera la referencia en cada versión:

```bash
ruby wiki/generate.rb --snapshot wiki/baseline.json
git add wiki/baseline.json && git commit -m "Actualiza baseline de la wiki"
```

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
