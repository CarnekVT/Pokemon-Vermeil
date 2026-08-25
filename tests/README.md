# Tests de La Base de Sky

Pruebas automatizadas que corren **sin abrir el juego**. Un proceso `ruby` normal
carga los scripts del motor y los plugins contra un RGSS falso, lee los `.dat`
compilados y puede jugar batallas completas sin gráficos.

```bash
ruby tests/run.rb                 # todo
ruby tests/run.rb -n /battle/     # sólo los tests que coincidan
ruby tests/run.rb -n TestBoot     # sólo una clase
ruby tests/run.rb -v              # una línea por test
```

Sin dependencias: no hace falta instalar ninguna gema.

## Qué cubre y qué no

| Cubierto | No cubierto |
|---|---|
| Que todos los scripts y plugins evalúen sin error | Pantallas, menús, HUD |
| Que `GameData` cargue | Overworld, eventos de mapa, cutscenes |
| Integridad de los datos PBS (referencias colgadas) | Gráficos, audio, input |
| Mecánicas de combate (daño, estados, habilidades, prioridad) | Guardado/carga real |

Lo no cubierto se sigue probando a mano. Correr mkxp-z headless no es viable:
necesita un contexto OpenGL.

## Archivos

| Archivo | Qué hace |
|---|---|
| `rgss_shim.rb` | Clases falsas de RGSS/MKXP (`Graphics`, `Bitmap`, `Sprite`, `RPG::*`…) y la guardia de escritura |
| `harness.rb` | Localiza la carpeta del juego por `mkxp.json`, carga scripts y plugins, monta el estado de partida |
| `battle_helper.rb` | `TestScene` (batalla guionizada) y los helpers `mon` / `run_battle` |
| `framework.rb` | El runner: `TestCase`, aserciones, filtro por nombre, código de salida |
| `run.rb` | Punto de entrada |
| `cases/` | Los tests |

## Escribir un test

```ruby
class TestMiCosa < BattleTestCase
  def test_rayo_es_supereficaz_contra_agua
    pikachu  = mon(:PIKACHU, moves: [:THUNDERBOLT])
    squirtle = mon(:SQUIRTLE, moves: [:SPLASH])   # Splash: no cambia nada

    battle = run_battle(player: [pikachu], foe: [squirtle],
                        moves: { 0 => [:THUNDERBOLT] }, rounds: 1, seed: 42)

    assert_operator damage_taken(squirtle), :>, 0
    assert_message_matching(/supereficaz/i, battle)
  end
end
```

- `mon(...)` fija IVs, EVs, naturaleza, habilidad y género, así que el daño es
  reproducible. `moves:` deja el moveset exactamente en lo que le pases.
- `moves:` en `run_battle` es `{ índice_de_battler => [movimiento por ronda] }`.
  El índice 0 es el titular del jugador, el 1 el del rival. Al rival lo lleva la
  IA salvo que lo guiones.
- `rounds: 1` corta al empezar la ronda 2. `rounds: nil` juega hasta el final.
- El daño varía entre el 85% y el 100%: asserta rangos, no números exactos.

Los tests que no tocan combate heredan de `EngineTest`.

## Notas

- Las escrituras están bloqueadas durante los tests: si algo intenta escribir en
  el repo (`errorlog.txt`, un `.dat` recompilado, un save) el test falla con
  `WriteGuard::Violation` en vez de ensuciar el árbol de trabajo.
- Las excepciones de dentro del combate se relanzan en vez de registrarse, para
  que el test enseñe la traza real.
- `tests/` vive fuera de `LA BASE DE SKY/`, así que no entra en el zip de release.
