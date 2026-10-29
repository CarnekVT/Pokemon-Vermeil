# Bifröst Capture — prototipo funcional 0.1.0

Compatible con la estructura de Pokémon Essentials 21.1 del repositorio. Integrado como plugin separado y editor de Maker Studio. **Requiere pruebas dentro de mkxp/Essentials.** No se modifican scripts de cámara BSS/BAS, 2.5D ni movimiento.

## Diseño oficial Bifröst

- Pokémon elegibles: Raikou, Suicune, Entei, Latias, Latios, Articuno, Zapdos, Moltres (incluidas formas de Galar), Mesprit, Uxie, Azelf, Cobalion, Virizion, Terrakion, Genesect, Landorus, Thundurus, Tornadus, Eternatus y Tapu Koko, Tapu Lele, Tapu Bulu, Tapu Fini.
- **Eventos elegibles solamente**: otros Pokémon visibles no se convierten accidentalmente en encuentros.
- El apuntado utiliza **7 columnas × 7 filas hacia delante** (3 columnas a cada lado), no un área centrada en el jugador. Distancia óptima: 4. Fila 8: fallo garantizado en perfil Bifröst.
- El jugador puede lanzar Poké Ball o enviar su Pokémon para iniciar un combate.
- Distancia ≤3 (Manhattan): reacción de huida o ataque. Efecto breve de impacto visual al acertar por espalda, bonus de captura y mayor probabilidad de captura crítica.
- La captura directa usa probabilidad propia del mod basada en el ratio de captura de la especie y modificadores simples de Ball, NO reproduce toda la fórmula de combate de Essentials. Sin presión de captura, estado alterado ni aturdimiento en la versión inicial.
- Los encuentros originales en hierba alta permanecen intactos.
- Las opciones para otras experiencias: perfiles **Classic**, **Adventure**, **Safari** o **Custom**, además de ajustes globales, por mapa, especie y evento.

## Preparar los eventos

En el nombre del evento, coloca:

- `[OWCAP:RAIKOU:50]` — Raikou salvaje, nivel 50, interactivo.
- `[OWCAP:ARTICUNO:70:1]` — Articuno de Galar, nivel 70, forma 1.
- `[OWDECOR]` — decorativo; no es capturable ni combatible con este sistema.

El evento debe contener su sprite de OW habitual. **No marca como objetivo a NPC, Pokémon de tejados, árboles ni decoración** salvo que se etiqueten expresamente con `OWCAP`. No uses esta etiqueta en los eventos decorativos.

Para abrir la interfaz desde un evento de mapa / controlador de captura, utiliza un comando de script:

```ruby
pbBifrostAim
```

Puedes enlazarlo a un objeto clave o comando de un menú mediante ese mismo método. La versión 0.1 no registra una tecla global predeterminada para evitar conflictos con Movimiento, Maker Studio y otros plugins. Para abrir las opciones en una zona de juego:

```ruby
pbBifrostRulesMenu
```

Para fijar o restaurar opciones por evento desde scripts:

```ruby
BifrostCapture.set_rule("capture_enabled", "0")
BifrostCapture.set_rule("capture_enabled", "1")
BifrostCapture.reset_event(12,4)
```

Las opciones ingame se guardan en `PokemonGlobalMetadata` del archivo de partida. Las opciones del editor modifican el archivo `config.ini`. Las opciones ingame prevalecen sobre el INI donde se apliquen.

## Maker Studio

Menú **Mods → Bifröst Capture Studio**. Tiene controles de reglas, previsualización de la parrilla, perfiles y ámbitos `global`, `map:12`, `species:RAIKOU`, `event:12:4`. Se guardan cambios exclusivamente al pulsar **Guardar**, con lectura de verificación. Ajustar parámetros y reglas NO reescribe otros plugins.

## Limitaciones y pruebas pendientes

1. Comprobar la carga del plugin y el editor en la versión exacta de Maker Studio de Vermeil.
2. Validar nombres de eventos, obtención/consumo de Balls, captura y almacenamiento en PC, registro de Pokédex, formularios regionales y reacción de huida.
3. Validar que el evento no reaparece tras salvar y recargar, y restauración por script.
4. Probar los cuatro sentidos, los límites laterales, obstáculos, casilla 8, distancia 3, Turbo y mapas 2.5D.
5. La trayectoria de proyectil, sprite de Ball, sonido, sacudidas, animación física de lanzador y efectos estéticos avanzados de los videos **no están implementados todavía**. El apuntado actual es una cuadrícula dibujada y el impacto es un flash corto.
6. Los errantes que usan la mecánica de Roaming de Essentials no se vinculan automáticamente al estado del evento `OWCAP`. La aparición y desaparición de OWs, la sincronización de su captura con el sistema de errantes y la persistencia de individuos requieren integración adicional.
7. `WildBattle.start` inicia el combate normal, pero la versión inicial no bloquea automáticamente el lanzamiento de Balls durante ese combate; si el diseño lo requiere se integrará una regla de batalla aparte.
8. Las opciones in-game son un menú opcional invocado por script, no una entrada añadida al menú de pausa por defecto.

## Archivos

- `001_Core.rb`: INI + perfiles + cálculos + eventos + persistencia.
- `002_Runtime.rb`: selección de bolas/Pokémon, apuntado y resolución.
- `003_RulesMenu.rb`: ajustes opcionales ingame.
- `config.ini`: reglas oficiales Bifröst.
- `Plugins/MakerStudio/003_Editor/Mods/com.vermeil.bifrost-capture`: editor gráfico.
