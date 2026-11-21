# Auditoría de Origin HeartGold para Battle Animation Studio (21-11-2026)

## Rectificación y alcance

El análisis inicial se centró incorrectamente en `originheartgold.github.io`, que es **la compilación de la web**, e ignoró el proyecto fuente `origin-heart-gold-EN-translation` (desarrollado por el mismo equipo). Esta revisión cubre ambos, la web realmente publicada, su catálogo de gráficos, el motor DS documentado y la posible transferencia de ideas a **BAS / Essentials 21.1**. No se atribuyen animaciones que no están alojadas ni se equiparan gráficos estáticos con secuencias de combate.

Repositorios:
- Web compilada: https://github.com/originheartgold/originheartgold.github.io (main, árbol `63e8ae6b737a13c287965440a8b1c1de46f04fc2`)
- Proyecto fuente: https://github.com/originheartgold/origin-heart-gold-EN-translation
- Web pública: https://originheartgold.github.io/
- Licencias de la fuente: https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/LICENSE-GUIDE

## 1. Contenido visual de la web publicado

El árbol compilado contiene 32.395 entradas (incluido `preview/` y búsqueda `pagefind/`), pero **no son 32.395 imágenes o animaciones distintas**. En la compilación principal excluyendo `preview/` hay **294 medios de imagen locales**: 280 WebP, 12 PNG, 2 SVG. No aparecen archivos con extensión GIF, APNG, MP4 o WebM; no se verificaron internamente los frames de cada WebP, así que no se infiere que todos sean monofotograma. Los medios proceden en su mayoría de capturas/ilustraciones para guías y objetos ocultos; `_astro/` además contiene recursos optimizados para el sitio. El listado exhaustivo de rutas con tamaños y enlaces directos está en `BAS_SOURCE_REFERENCES/OriginHeartGold/public_visual_manifest.json`.

La página usa también **imágenes remotas**, NO incluidas en esos 294: `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/...`, HOME y arte oficial. El componente `site/src/components/PokemonImage.astro` y `site/src/lib/pokemon-art.ts` implementan progresión sprite de 96px → HOME → official-artwork → placeholder. `ohg.js` agrega mini-sprites desde PokéAPI a las menciones de Pokémon y objetos cuando se visualiza el sitio en teléfono; carga `sprites.json` y usa lazy loading.

Rutas públicas verificadas:
- Inicio: https://originheartgold.github.io/ (hero, arte HOME, entradas a las secciones).
- Movimientos: https://originheartgold.github.io/moves/ (búsqueda por nombre, tipo, categoría, método y cambios).
- Pokédex: https://originheartgold.github.io/pokemon/ (1.440 especies y formas en el índice publicado).
- Entrenadores: https://originheartgold.github.io/trainers/ (equipo y batalla contextual).
- Guía: https://originheartgold.github.io/guide/ y capturas https://originheartgold.github.io/guide/hidden-items/
- Cámara: https://originheartgold.github.io/camera-codes/ (generador interactivo de códigos de cámara del **overworld**).
- FAQ: https://originheartgold.github.io/faq/ (problemas conocidos de audio/animaciones).

Diseño de frontend: Astro 7.3.5, Starlight 0.42.5; estilos en `site/src/styles/custom.css`, `site/src/styles/phone-shell.css`; barras de búsqueda y filtros, tarjetas de navegación, tema claro/oscuro con acento dorado, enlaces de procedencia y gráficos diferidos. Estas técnicas de navegación/organización pueden inspirar la **biblioteca BAS**, pero no representan un renderer de ataques de Origin HeartGold.

## 2. Movimientos y diferencias entre metadatos y animaciones

`site/src/data/moves.json` contiene **920 registros** (IDs 1–920; 902 nombrados): nombre, tipo, categoría, poder, exactitud, prioridad, objetivo, banderas, condiciones/estadísticas y evidencia. **No existe un campo con script de animación, fotogramas, spritesheet de ataques o efectos emitidos.** `site/src/pages/moves/[slug].astro` solo los presenta con componentes de stats y tabla de Pokémon que aprenden el ataque.

Distribución según `target`: 653 «Selected target», 63 «All opponents», 100 «User», 104 sin etiqueta. Puede servir para **contexto de prueba** del editor, con especial atención a ataques multiobjetivo, NO para reconstruir el aspecto visual. El índice de consulta sin descripciones protegidas figura en `BAS_SOURCE_REFERENCES/OriginHeartGold/move_reference_catalog.json`, con enlace directo a cada ficha.

La FAQ oficial documenta que **Terrain Pulse no tiene animación** en el hack original. También señala 15 ataques sin SFX propios: Electro Ball, Soak, Flame Charge, Coil, Low Sweep, Acid Spray, Foul Play, Simple Beam, After You, Round, Echoed Voice, Chip Away, Clear Smog, Synchronoise y Venom Drench. Esto caracteriza el juego DS, no implica que falten en BAS/Vermeil.

## 3. Dónde está el material auténtico del juego

La web pública distribuye un **parche xdelta**, no el ROM completo. `README.md` aclara que `work/rom/`, `work/extract/` y buena parte de `work/graphics/generated/` no están en GitHub: se generan usando copias propias de ROM. No es posible extraer automáticamente secuencias de combate completas del parche aislado como si fuera una biblioteca de PNG.

Archivos comprobados:
- `work/tools/gfx.py`: lector/rasterizador Nitro 2D: NCGR (tiles 4/8bpp), NCLR (paletas), NSCR (mapas de pantalla), NCER (celdas) y NARC comprimidos con LZ10/LZ11. Modos `scan` y `audit` para obtener PNG/sheets desde un ROM proporcionado. **No se ha identificado un exportador directo a la timeline JSON de BAS**, ni un parser completo de tiempo de animación para ataques.
- `work/notes/graphics_inventory.md`: identifica archivos de sprites Pokémon, entrenador y overworld: `a/0/0/4`, `a/0/0/6`, `a/0/5/8`, `a/0/1/8`, `a/0/2/0`, `data/pokepic_*`, `data/pokeicon.narc`; `extra/new_battle_bg.narc` contiene fondos; los miembros **14+ de `a/2/6/4`** son fotogramas animados de intro/título, observados pero no distribuidos como atlas PNG.
- `work/graphics/vendor/hg-engine/`: algunos gráficos puntuales (icono tipo Hada, iconos clima), **no** pack entero de animaciones. Créditos y condiciones en `work/graphics/CREDITS.md`.
- `work/patches/lugia-animation-state-bounds/`: corrección de una cinemática de Lugia que llamaba un callback fuera de los límites de una tabla de estados. Relevancia para BAS: verificar estados/tipos antes de ejecutar y mantener el último estado válido. No trasplantar direcciones de memoria de DS a RGSS.

## 4. Animaciones de combate: comprobaciones reales de su motor

El archivo `work/advanced-ai/testbench/dev/animcheck.py` es el hallazgo técnico más importante. Instrumenta el emulador del juego DS y reproduce movimientos repetidamente en singles/doubles; vigila asserts, bloqueos, heap 5 y tiempo de cada uso. Detalles:
- El código documenta comandos de **carga de partículas 0x33** y **emitter 0x2E** en el intérprete de la animación DS.
- Cita fugas de **23 a 28 KB por uso** para Leaf Tornado, Leafage, Lunge, Psychic Fangs, Liquidation, Zing Zap y Jet Punch en la ROM china.
- Enumera errores/asserts de Fire Pledge, Searing Shot, Freeze Shock, Throat Chop y Psychic Noise (este último también se congela); Hyper Voice provoca assert en dobles.
- Dispone de pruebas repetidas `--uses N` y modo `--single`; diferencia memoria de inicialización y pérdidas persistentes. Nota: algunos fixes de la build española que compara no están incorporados al proyecto inglés.

**Transferible como metodología, no como código Ruby:** probar 50–100 usos consecutivos de emitters, aumento/disminución de objetos del preview, residuos en escena al salir, exactitud del objetivo en 2v2/3v3, bloqueo de la timeline y SFX ausente. No inferir un problema de BAS simplemente por un bug de NDS.

## 5. Propuesta técnica concreta para BAS

**P0 — Diagnóstico y paridad Preview/Runtime**
1. Instrumentación de número de partículas vivas, emisores activos, mapas de recursos en caché, fin de animación, coste por frame y reutilización.
2. Escenarios de repetición de animaciones y prueba 1v1, 2v2, 3v3, objetivos de varios enemigos y efectos propios.
3. Validación de la salida: emisores detenidos, sonidos existentes, propiedades sin NaN, número finito de partículas, restauración de estados de battler/cámara/sombras, no interpolación residual.
4. Logging reproducible de casos de error sin detener toda la interfaz por un recurso faltante.

**P1 — Referencias externas (sin introducir assets protegidos al juego)**
1. Pestaña de referencias separada de `Acciones` y de animaciones compilables, con búsqueda por nombre/tipo/categoría/objetivo y enlace a la ficha de Origin HeartGold.
2. Etiquetas explícitas: `Datos de movimiento`, `Visual estático de guía`, `Animación verificada`, `Sin referencia`; el índice suministrado NO marca ningún movimiento como «animación verificada».
3. Galería de referencia a las 294 imágenes públicas: lazy load, fuente, ruta, visualización previa y «abrir origen», sin copiarlas a `Graphics/Animations`.
4. Desvincular ubicación/fuentes de imagen de keys temporales del usuario; no crear clips, proyectos ni audio automáticamente desde esas referencias.

**P2 — Importador Nintendo DS opcional, condicionado a datos reales**
1. Elegir carpeta de recursos Nitro/NARC exportados desde copia propia del juego y seleccionar paleta NCGR/NCLR y mapas NCER/NSCR correspondientes.
2. Previsualizar y exportar PNG transparentes/spritesheets compatibles con BAS, con reporte de dimensiones, origen, número de tiles, mapa de celdas, nombre y checksum.
3. La composición temporal (secuencia y comportamiento de ataque) solo se podría traducir tras estudiar el formato de comandos/animaciones de la ROM, **no** tras extraer una imagen aislada.
4. Mantener separados los tipos `sprite estático`, `frames de intro`, `emitter script DS` y `animación BAS` y pedir validación antes de materializar gráficos del juego.

**P3 — Ideas de UX tomadas de la web**
1. Filtros rápidos y contador real de resultados para Library/Acciones, inspirados en `moves/`.
2. Fuente y estado de procedencia siempre visibles; placeholder robusto si falla la imagen, como `PokemonImage.astro`.
3. Tarjetas compactas y paneles visuales que no tapen el lienzo; secciones colapsables y ayuda contextual sin texto excesivo.
4. Controles de cámara bien separados por parámetro y presets con valores visibles, inspirados en la página interactiva de cámara (que es del **overworld**, no del motor BAS).

## 6. Licencias y límites

`LICENSE-GUIDE`: el texto nuevo del sitio desde 2026-10-18 tiene derechos reservados; se pueden enlazar páginas y citar fragmentos breves. Los scripts propios están publicados bajo Apache 2.0. Las imágenes de Pokémon, contenido del ROM y recursos de hg-engine mantienen derechos/condiciones de sus propietarios. No copiar masivamente imágenes ni incrustar assets NDS de terceros en un pack redistribuible de BAS sin evaluar condiciones.

## 7. Material producido y cambios ya aplicados

- `BAS_SOURCE_REFERENCES/OriginHeartGold/public_visual_manifest.json`: 294 URLs/rutas de imágenes del sitio, sin ficheros binarios ajenos.
- `BAS_SOURCE_REFERENCES/OriginHeartGold/move_reference_catalog.json`: 920 fichas con metadatos/URLs; 1 ausencia de animación y 15 casos de audio conocidos **del juego DS**.
- El PR actual optimiza `model.js` (ordenamiento y visibilidad) y `preview.js` (caché LRU). Es trabajo **independiente** de la extracción; no implementa todavía la galería, comprobador ni importador DS.
- Pruebas lógica: 12.000 casos de muestreo de visibilidad y 500 de ordenación sin diferencias. **Sin prueba real de rendimiento, UI Maker Studio ni reproducción dentro de Essentials 21.1**.
- Ningún `animations.json`, preset, runtime Ruby ni imagen del juego de terceros ha sido sobrescrito.

## Enlaces de evidencia para revisión

- https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/work/advanced-ai/testbench/dev/animcheck.py
- https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/work/tools/gfx.py
- https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/work/notes/graphics_inventory.md
- https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/work/graphics/CREDITS.md
- https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/site/src/pages/moves/%5Bslug%5D.astro
- https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/site/src/components/PokemonImage.astro
- https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/site/src/styles/custom.css
- https://originheartgold.github.io/faq/
