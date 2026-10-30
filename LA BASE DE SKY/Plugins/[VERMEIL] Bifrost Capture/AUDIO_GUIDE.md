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
| `sfx_mode` | Alterna Ball/Team | Cambio de equipo reconocible |
| `sfx_party` | Cambia Pokémon | Selección del icono de equipo |
| `sfx_throw` | Sale la Ball | Golpe inicial + desplazamiento aéreo |
| `sfx_hit` | Impacta | Respuesta fuerte pero breve |
| `sfx_shake` | Cada sacudida | Ritmo reconocible y creciente |
| `sfx_caught` | Captura confirmada | Resolución ascendente y clara |
| `sfx_breakout` | Se libera | Nota descendente + ruptura |
| `sfx_flee` | Pokémon escapa | Movimiento corto y evasivo |
| `sfx_alert` | Agresivo detecta | Aviso seco y urgente |

## Predeterminado en Vermeil: audio grabado real

`audio_profile=za_like` sigue siendo la configuración por defecto.
El motor da prioridad a los recursos `za_*.ogg/.wav/.mp3` que el autor
haya colocado explícitamente en `Audio/SE/Bifrost`. Si faltan, se
reproducen los 12 efectos reales `real_*.wav` incluidos en el proyecto,
bajo licencia CC0. **No son sonidos del juego Pokémon Legends: Z-A**;
son sustitutos de Kenney y no se deben promocionar como sonidos oficiales.

La antigua generación de WAV sintéticos fue retirada. El motor
reconoce e ignora sus WAV heredados por formato/duración. Para limpiar
tu copia de desarrollo, elimina `Audio/SE/Bifrost/za_*.wav` únicamente
si son los tonos generados por versiones previas, no archivos propios.

Para audios legítimos de procedencia verificada, puedes reemplazar los
`za_*` o configurar los `sfx_*` específicos. Consulta
[AUDIO_LICENSES.md](AUDIO_LICENSES.md) para una matriz exhaustiva.

## Presets tipo Legends (sin audio incluido)

`audio_profile=pla_like` busca efectos propios llamados `pla_aim.ogg`, `pla_switch.ogg`, `pla_mode.ogg`, `pla_party.ogg`, `pla_lock.ogg`, `pla_throw.ogg`, `pla_hit.ogg`, `pla_shake.ogg`, `pla_caught.ogg`, `pla_breakout.ogg`, `pla_flee.ogg` y `pla_alert.ogg`. Para `za_like` se cambia el prefijo por `za_`. Si no existen, el perfil ZA utiliza los 12 WAV reales CC0 instalados; PLA recurre a Essentials.

Son **nombres de archivos configurables**, no archivos comerciales incluidos. El audio que quieras usar debe estar autorizado para su inclusión en el proyecto.

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
