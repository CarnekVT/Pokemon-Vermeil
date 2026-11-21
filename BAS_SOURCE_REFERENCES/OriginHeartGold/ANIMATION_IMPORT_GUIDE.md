# Origin HeartGold — rutas reales de animación e integración BAS

Auditoría: **2026-11-21**. Destino: Battle Animation Studio / Pokémon Vermeil / Essentials v21.1.
Referencias técnicas:
- [Documentación HGSS `move_anim` y `move_sub_anim`](https://github.com/BluRosie/hg-engine/wiki/Move-Animation-Scripting-System-Documentation)
- [Documentación HGSS de scripts de combate](https://github.com/BluRosie/hg-engine/wiki/Move-Scripting-Systems-Documentation)
- [Origin HeartGold EN — intérprete, slots, asserts, memory leaks](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/work/advanced-ai/testbench/dev/animcheck.py)
- [Origin HeartGold EN — barrido de animaciones player/foe](https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/work/tools/emu_move_sweep.py)
- [Licencias y procedencia (Origin HG EN)](https://github.com/originheartgold/origin-heart-gold-EN-translation#license).

## Qué funciona en la ROM y dónde están sus archivos

| Familia DS | Nitro FS / formato | Función y correspondencia BAS |
|---|---|---|
| `move_anim` | `a/0/1/0`, miembros NARC con **bytecode** de animaciones | Ataques, wait, animación de usuario/objetivo, partículas, sonidos; BAS: Moves |
| `move_sub_anim` | `a/0/6/1`, miembros NARC | Animación auxiliar independiente (p. ej. objetos). BAS: **Subanimaciones** |
| `SPA`/SPL | `a/0/2/9`, miembros NARC | Emisores, texturas/paletas y sus parámetros; BAS: emisor de partículas/clip, **no** bitmap directo |
| `battle_move_seq`, `battle_eff_seq`, `battle_sub_seq` | otros archivos de scripts de combate | **Mecánicas y comandos de combate**, no fotogramas exportables. No convertirlos a movimientos de cámara falsos |

**Comandos documentados:** `loadparticlefromspa(slot, spaId)` carga recurso; `waitparticle` sincroniza carga/partículas; `addparticle(slot, emitterIndex, target)` dispara emisor; `playsepan(seq, pan)` dispara sonido con panorámica; `wait(n)` suma frames; `unloadparticle(slot)` libera; `waitstate` espera al estado del motor; `callfunction` ejecuta funciones nativas cuyo efecto no puede deducirse del texto genérico.

**No todo el tiempo se puede recuperar de texto**: la duración de `waitparticle` y `waitstate` depende de la ROM y los datos concretos de SPA. Tampoco un ID SFX de SDAT se convierte en un OGG reproducible por Essentials. El importer conserva referencias, no genera sonidos inexistentes.

## ¿Qué archivos realmente estaban públicos?
El repositorio `originheartgold/origin-heart-gold-EN-translation` contiene instrumentación y parches; **no contiene los NARC completos con animaciones ni los SPA originales de todos los ataques**. En `work/graphics/vendor/hg-engine/` hay materiales puntuales (entre ellos `battle_gfx_8_236.NCGR` y `weather_icons/`), relativos a gráficos de interfaz, no un pack de ataques exportables. La documentación aclara que las licencias Apache de las herramientas no cubren los gráficos Nintendo/ROM. Por ello **no se copiaron ni se redistribuyeron** texturas de una ROM de un tercero.

## Extracción local y privada

1. Usa una copia de ROM de Nintendo DS que hayas obtenido legítimamente y **no la subas al repositorio**.
2. Desde un terminal, ejecuta:

```bash
python BAS_SOURCE_REFERENCES/OriginHeartGold/tools/extract_nitro_animations.py --rom "ruta/a/tu/origin-hg.nds" --out "mi_extraccion_privada"
```

3. El programa busca los tres archivos Nitro, separa NARC, escribe miembros numerados `0000.bin` (scripts) y `0000.spa` (partículas), y un `manifest.json` con rutas, SHA-256 y conteos. Es **extracción raw**, no creación automática de PNG ni conversión de secuencias a BAS. La ausencia de un archivo se anota, sin inventarlo.
4. Los `.spa` deben pasar por un decodificador compatible, por ejemplo Nitro Effect Maker. Para asociar emisor/texture al timeline se necesita identificar cada slot e índice y validar el resultado en juego.

No guardar un archivo de ROM, el manifiesto privado ni sprites de copyright ajeno en el repositorio. El extractor escribe un `.gitignore` en su carpeta de salida.

## Importación desde BAS

**Biblioteca → Importar → Importar script Nitro (texto)** acepta un *desensamblado textual* estilo `a010_486:`, no un `.bin` directamente. Permite ID, nombre y dos rutas de registro (**Subanimaciones**, recomendado, o **Moves** cuando el ID coincide con un movimiento real).

La importación:
- Reconoce `loadparticlefromspa`, `addparticle`, `wait`, `playse`, `playsepan`, `unloadparticle`, `waitparticle`, `waitstate` y `callfunction`.
- Registra SPA requeridas por índice, slots y emitters, SFX con pan y posiciones de comandos. Advierte carga/descarga incorrecta.
- Opcionalmente crea pequeños **placeholders procedurales originales** para visualizar dónde hay emisión. **No afirma que tengan el aspecto original DS**.
- Mantiene `runtimeEnabled=false` hasta que se sustituyan/verifiquen los recursos y actives expresamente la animación en gameplay.
- No es un desensamblador de scripts binarios ni decodificador automático de SPA.

## 13 categorías con rutas de reproducción diferenciadas

Moves, Common y Custom continúan con su funcionamiento anterior. Se añadieron:

| Categoría BAS | Uso | Ejemplo de llamada desde Battle::Scene |
|---|---|---|
| Subanimaciones | Secuencia independiente / movimiento auxiliar | `pbPlayBattleAnimationStudioCategory(:subanimation, "THIEF_ITEM", user, target)` |
| Estados | Efecto de estado de un battler | `pbPlayBattleAnimationStudioCategory(:status, "POISON", battler)` |
| Clima | Inicio / cambio de clima | `pbPlayBattleAnimationStudioCategory(:weather, "RAIN_START")` |
| Terreno | Cambio de terreno | `pbPlayBattleAnimationStudioCategory(:terrain, "ELECTRIC_FIELD")` |
| Habilidades | Activación de habilidad | `pbPlayBattleAnimationStudioCategory(:ability, "INTIMIDATE", user)` |
| Objetos | Uso de objetos / curación | `pbPlayBattleAnimationStudioCategory(:item, "HEAL", user)` |
| Entradas | Entrada de battler | `pbPlayBattleAnimationStudioCategory(:entry, "SEND_OUT", user)` |
| Debilitamiento | Secuencia visual de faint | `pbPlayBattleAnimationStudioCategory(:faint, "FAINT", target)` |
| Campo | Efecto ambiental | `pbPlayBattleAnimationStudioCategory(:field, "FOG")` |
| Transiciones | Interfaz / transición de escena | `pbPlayBattleAnimationStudioCategory(:transition, "BATTLE_OPEN")` |

Estas llamadas **no se ejecutan automáticamente** por tener una categoría asignada. Deben invocarse donde corresponda en el motor. Esto evita reproducir una animación de faint dos veces o afectar a la cámara/intro del BSS sin probarlo.

Las diez familias adicionales admiten presets originales opcionales con gráficos procedurales y keyframes normales, editables igual que cualquier otro clip BAS.

## Auditoría de recursos ya existentes en Vermeil

Comparación contra el árbol GitHub de **26.088 entradas** de la rama en el momento de la auditoría (22 animaciones; 114 clips):
- 40 referencias gráficas distintas encontradas. **Una ruta era incorrecta**: `Graphics/Battle animations/Examples/punches.png`. Se corrigió a `Graphics/AnimationStudio/punches.png`, ya utilizada por `compiled_animations.json`. No se importó arte externo.
- 41 nombres de sonidos SE distintos; 41 tenían coincidencia en `Audio/SE` y sus subcarpetas mediante resolución de nombres/extensiones.
- No se identificó ausencia de recursos propios que pudieran suplirse legítimamente desde el repo de traducción.

## Comprobaciones y límites
Se probó mediante ejecución JavaScript la creación, normalización y clasificación de las 13 familias, el parser Nitro con un ejemplo de `loadparticlefromspa/addparticle/playsepan/wait/unloadparticle`, la preservación de los 22 registros viejos, y se efectuó análisis sintáctico de módulos modificados. Hay tests de Node y Python con fixtures en `tests/` y `tools/`. **Pendientes**: abrir Maker Studio real, ejecutar Ruby bajo Essentials, ejecutar el extractor sobre una ROM propia (no suministrada), decodificar los SPA a texturas PNG y comparar efectos visuales con hardware/emulador.
