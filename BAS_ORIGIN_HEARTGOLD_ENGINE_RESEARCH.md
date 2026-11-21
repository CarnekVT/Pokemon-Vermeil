# Ingeniería de animaciones de Origin HeartGold y aplicación comprobable al BAS
**Revisión:** 2026-11-21 · **Fuente fijada:** `5e1c9dead781b13cc057bfb50117995261163fa0` · **Destino:** Pokémon Vermeil / Pokémon Essentials 21.1 / MakerStudio.

## 0. Alcance y prueba de procedencia
Se inspeccionaron **archivos técnicos reales** del repositorio `originheartgold/origin-heart-gold-EN-translation`, no una galería web. Este proyecto es la traducción y capa de parches sobre la **ROM ya compilada** de 起源心金 v4.0.3. No es el proyecto fuente de las animaciones DS; las secuencias de batalla del hack están en sus archivos ROM. El árbol público no proporciona un exportador de secuencias de ataque con sprites, transformaciones, emisores y audio ya reconstruidos para Essentials.

**No se afirman ni se fabrican** 920 animaciones, conversiones Nitro → BAS, fotogramas o rutas de assets de ataque. Las 920 fichas `moves/` del sitio son datos de movimientos, no 920 archivos de animación. No se redistribuyen gráficos propietarios ni una ROM.

## 1. Cadena funcional verificada de animación DS

| Nivel | Evidencia precisa en el fuente | Comportamiento | Equivalente / decisión BAS |
|---|---|---|---|
| Despacho de inicio | [`animcheck.py`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/advanced-ai/testbench/dev/animcheck.py) `ANIM_START = 0x02200E4A` (overlay 14) | Un hook registra el **inicio real** de una animación de movimiento mediante el ID en r2 | En BAS el inicio debe identificarse por la animación seleccionada, su contexto, FPS y frame 0; no se puede copiar esa dirección ARM |
| Interpretación de secuencias | [`animcheck.py`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/advanced-ai/testbench/dev/animcheck.py) señala overlay 8 `0x021E895E / 0x021E5EFC` | El intérprete ejecuta comandos del flujo ROM y puede disparar asserts | BAS necesita validar claves de escena, referencias y ciclo de vida del emisor; no comparte opcodes/VM |
| Carga de recursos | `ANIM_LOAD_CMD = 0x021E5ED8`, comando DS **0x33** | Carga de partícula/recurso a slot DS; la herramienta puede inyectar deliberadamente un slot incorrecto | BAS resuelve rutas `Graphics/...` y mantiene cachés por clip; se optimiza el preview sin emular slots DS |
| Emisión | `ANIM_EMITTER_CMD = 0x021E5B44`, comando DS **0x2E** | Comandos de emisión; el test muestra fallos si se altera el slot | BAS usa `pbs.emitter`, `pbs.emitterCommands.emitting`, frecuencia, intensidad, intervalo activo y vida |
| Fuga de heap | [`animcheck.py`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/advanced-ai/testbench/dev/animcheck.py) `heap_state`, heap 5, umbral 1024 B/uso | Repite la misma animación y compara bytes libres/asignaciones *después del primer turno*, para excluir calentamiento | No inventar mediciones de memoria: nuevo analizador BAS **estima carga** según cadencia, indica límites del preview; medir memoria requiere prueba con Essentials |
| Prueba por lado | [`emu_move_sweep.py`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/tools/emu_move_sweep.py) | Diseñado para barrer IDs de movimientos en lado **player/foe** y registrar `menu / field / hang / timeout / abort` con melonDS | Plan de regresión BAS: Player→Foe, Foe→Player, 1v1/2v2/3v3, finalizar, repetir, cancelar y comprobar sprites/SFX |
| SFX de golpe | [`battle-hit-sound/fix.toml`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/patches/battle-hit-sound/fix.toml), [ensamblador](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/patches/battle-hit-sound/battle-hit-sound.asm) | El hack carecía de SFX de daño. Command 8 del cliente: clase normal=**1790**, super=**1788**, resistido=**1789**; SFX separado del sonido del movimiento | En BAS los eventos de SFX pertenecen a la timeline, pero el **SFX universal de impacto** debe asociarse al evento efectivo de daño del motor, no inyectarse a ciegas en cada animación |
| Cry de debilitamiento | [`battle-faint-cry/fix.toml`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/patches/battle-faint-cry/fix.toml) | El grito de KO ocurre al completar fase 0; el audio de caída 1795 espera al fin del grito en fase 1 | El cry de KO debe estar gobernado por la secuencia de faint del juego, NO por el timeline de movimientos |
| Modelo fuera de límites | [`lugia-animation-state-bounds/fix.toml`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/patches/lugia-animation-state-bounds/fix.toml) | Callback de modelo especial fuera de rango: estado 3 con tabla de 2 entradas provocaba crash. **Escena overworld, no ataque de combate** | La lección aplicable es comprobar rangos de índice; no se clasifica como un efecto BAS |
| Archivos gráficos | [`gfx.py`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/tools/gfx.py) | Helpers para NCGR, NCLR, NSCR, NARC, LZ10/LZ11 y modificación de tiles | Son herramientas para material ROM; no entregan automáticamente una hoja PNG con frames + geometría + duración |
| Evidencia en emulador | [`emu_fixes.py`](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/5e1c9dead781b13cc057bfb50117995261163fa0/work/tools/emu_fixes.py) | Prueba con ROM parcheada **y control sin fix**; si no se distingue el resultado no cuenta como prueba | Comparar BAS antes/después en el mismo proyecto y runtime, y reportar diferencias visuales o funcionales |

### 1.1 Casos de fallo documentados en la herramienta DS
Estas son **observaciones del proyecto Origin HeartGold sobre su ROM**, no defectos atribuidos a Vermeil:
- **Fugas documentadas (23–28 KB/uso en el entorno del script):** Leaf Tornado, Leafage, Lunge, Psychic Fangs, Liquidation, Zing Zap y Jet Punch. Defecto descrito como `ANIM_RESLOT` en la base española de investigación; no está reparado por este repositorio de traducción.
- **Parámetros de secuencia ausentes / asserts:** Fire Pledge, Searing Shot, Freeze Shock, Throat Chop y Psychic Noise (esta última también congela).
- **Dobles:** Hyper Voice puede provocar assert desde la segunda posición del equipo, según el mismo test.
- La inyección artificial sobre los comandos 0x33 y 0x2E es una comprobación **de regresión**: si se reintroduce el bug, debe volver a fallar. No es código que deba ejecutarse en Ruby.

## 2. Anatomía BAS examinada antes de modificarlo
- `model.js`: animación `fps/duration`; clip `startFrame/endFrame`, `positionKeys`, `valueKeys`, `visibleKeys`, `graphicSwitches`, `fxOps`; SFX/cry/temblor en `events`.
- `preview.js`:
  - `emitterEmissionFrames`: reinicia cadencia por cada `SetEmitting=true` y respeta `SetEmitting=false`; tasa muestreada durante emisión.
  - `emitterValue`: comandos de emitter (duración/easing) con posibilidad de overrides de contexto.
  - `emitterParticleCommandFrame`: resuelve los comandos de partícula en espacio de animación o vida local, con compatibilidad para claves antiguas.
  - `drawEmitter`: límite **240 partículas reproduciendo** y **500 en pausa**; emisión, rutas, gravedad, formas, rotación y apariencia son computadas en el preview.
- `runtime_game/001_Runtime.rb`: ejecutor Ruby independiente del preview, con cachés propias de partículas, gráficos, frames y comandos. El informe estático **no valida paridad runtime**.

### 2.1 Implementación realizada en esta rama
1. `animation_forensics.js`: audita **todas las animaciones reales guardadas**, preservando JSON. Lista intervalos, eventos, cambios de gráficos, ON/OFF de emisión, SFX, cry, cámara y avisos. Advierte duraciones inconsistentes y claves fuera de orden. Calcula un pico **aproximado** de partículas basado en tasa/intensidad/vida y compara con el límite de preview.
2. `animation_forensics_ui.js`: panel con selector por animación, barras de duración reales, eventos cronológicos e hipervínculos a fuentes técnicas; acceso al frame/clip desde cada cue.
3. `index.js`: menú Herramientas → **Desglose técnico de animaciones**, tanto en Biblioteca como Editor. Saltos al timeline del editor sin modificar assets.
4. `preview.js`: elimina las copias/ordenaciones **repetidas** en los dos puntos calientes de commands de emitter si las claves ya están ordenadas; si no lo están, usa ordenación estable en una copia, sin tocar arrays del usuario.

**No se editó** `PBS/AnimationStudio/animations.json`, `compiled_animations.json` ni el runtime Ruby. No hay efectos de Origin HeartGold recreados sin evidencias visuales auténticas.

## 3. Diagnóstico real de los datos de Pokémon Vermeil
Sobre el JSON existente se analizaron **22 animaciones / 114 clips**. El analizador nuevo emitió **40 avisos estructurales y 4 notas informativas**; un aviso no equivale a fallo visual demostrado.

| Animación | Duración declarada | Último frame de algún clip | Criterio |
|---|---:|---:|---|
| Ala Mortífera | 200 | 415 | Inspeccionar clip muy extendido; puede ser cola de efecto guardada fuera de duración |
| Tajo Umbrío | 40 | 44 | Verificar cola del FOG |
| Essentials (Growl) | 24 | 36 | 15 elementos/aros visibles con extremos fuera de la duración |
| SOS Call | 22 | 36 | 15 elementos con cola potencialmente truncada |
| Acupresión copia | 83 | 84 | Desfase de 1 frame |
| Lanzallamas | 50 | 62 | Tres clips finales exceden duración |
| Ascuas | 26 | 52 | Dos clips exceden duración |

Otros casos que el módulo detecta:
- `Explosion2`: emisor declarado sin `SetEmitting=true` en su lista de claves; se marca como candidato a comprobar, no se elimina.
- `VoltTackle(Player)`: emisión queda activa al final (según claves existentes), requiere comprobación visual.
- `Pistola Agua`: existen cambios de emisión fuera del intervalo propio de ciertos clips; se muestran como datos informativos, no correcciones forzadas.

## 4. Validación realizada y pendiente
**Ejecutado (estático):** lectura de fuente pública, inventario del proyecto, análisis de 22 animaciones y 114 clips, parseo JavaScript de módulos afectados y **12.000 comparaciones** con el ordenado anterior (secuencias de claves ordenadas, desordenadas y repetidas), sin divergencias.

**Pendiente de comprobar en entorno real:** arranque UI de Maker Studio, reproducción visual de emisores, pérdida de frame, recorrido de SFX y comparativa con Ruby/Essentials v21.1. Ninguna cifra de memoria DS se presenta como medición de Vermeil.

Para descomponer y recrear el movimiento *visual exacto* de un ataque de Origin HeartGold se necesitan sus secuencias y recursos extraídos legalmente de una ROM propia, o capturas completas verificables por frame, con fuente/autorización. Un HTML de movimientos o una tabla de tipos no los sustituye.
