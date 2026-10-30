# Bifröst Capture — Audio y referencias de gamefeel

La selección sonora es **inspiración para diseño original**, no una instrucción para copiar ni redistribuir archivos extraídos de videojuegos. El plugin **no incluye WAV/OGG comerciales**. Los usuarios deben proporcionar efectos originales o sonidos que estén autorizados a utilizar.

## Referencias verificadas

- **Tetris 99 — tema especial 21: Pokémon Legends: Arceus Edition**: https://sounds.spriters-resource.com/nintendo_switch/tetris99/asset/440995/ — referencia de señales UI muy cortas y capas de confirmación.
- **Pokémon Legends: Arceus — Effects Used**: https://soundeffects.fandom.com/wiki/Pok%C3%A9mon_Legends%3A_Arceus — referencia para el *throw*, *poof*, impacto y sonidos asociados a acciones del jugador.
- **Pokémon Legends: Z-A — Pokémon Cries**: https://sounds.spriters-resource.com/nintendo_switch/pokemonlegendsza/asset/498803/ — archivo listado con variantes *ANGER*, *ATK*, *ENV*, *GLAD*, *SAD*, etc. Es una referencia útil para la actuación vocal de criaturas neutras, miedosas o agresivas; no es un banco de sonidos de menú/captura.
- **Diseño sonoro de Legends: Arceus**: https://splice.com/blog/pokemon-legends-arceus-sound/ — análisis del enfoque sonoro y su relación con la exploración.

## Matriz de eventos de Bifröst

| Campo `config.ini` | Momento | Intención sonora |
|---|---|---|
| `sfx_aim` | Inicia apuntado | Textura breve y discreta |
| `sfx_switch` | Cambia Ball | Clic suave, inequívoco |
| `sfx_lock` | Cambia objetivo | Confirmación pequeña |
| `sfx_throw` | Sale la Ball | Golpe inicial + desplazamiento aéreo |
| `sfx_hit` | Impacta | Respuesta fuerte pero breve |
| `sfx_shake` | Cada sacudida | Ritmo reconocible y creciente |
| `sfx_caught` | Captura confirmada | Resolución ascendente y clara |
| `sfx_breakout` | Se libera | Nota descendente + ruptura |
| `sfx_flee` | Pokémon escapa | Movimiento corto y evasivo |
| `sfx_alert` | Agresivo detecta | Aviso seco y urgente |

## Uso

Añade archivos propios/autorizados en `Audio/SE/Bifrost/` con nombre alfanumérico o guion bajo, sin espacios, por ejemplo `captura_ok.ogg`.

```ini
[global]
audio_profile=original
feedback_sfx=1
sfx_aim=apuntar
sfx_switch=cambiar
sfx_lock=objetivo
sfx_throw=lanzar
sfx_hit=impactar
sfx_shake=sacudir
sfx_caught=captura_ok
sfx_breakout=liberacion
sfx_flee=escape
sfx_alert=alerta
```

- `audio_profile=vanilla`: usa los efectos que Essentials conozca para eventos comunes y, si se indican, los archivos propios.
- `audio_profile=original`: **solo** archivos que se hayan configurado; `none` deja en silencio ese evento.
- `audio_profile=muted` o `feedback_sfx=0`: desactiva estos eventos.
- Cada clave puede sobrescribirse por mapa, especie o evento desde Maker Studio. Una entrada ausente nunca debe bloquear un lanzamiento ni alterar la IA.

## Pendiente de verificar en juego

Mezcla, volumen relativo, reproducción espacial y superposición de efectos, sincronización con el shader 2.5D, tiempo de impacto y las transiciones entre exploración y combate. Las pruebas Ruby únicamente validan enrutamiento, no el sonido reproducido en mkxp.
