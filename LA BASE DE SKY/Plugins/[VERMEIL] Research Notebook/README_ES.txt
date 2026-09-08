[VERMEIL] RESEARCH NOTEBOOK v1.2.1
==================================
Pokémon Essentials v21.1
Créditos: CarnekVT

PROPÓSITO
=========
Libreta del protagonista dedicada a dos líneas de investigación:
- Habilidades Arcanas
- fenómenos Áureos

No sustituye a la Pokédex general.

NAVEGACIÓN
==========
- Pokémon focal a la izquierda y cuadrícula de especies a la derecha.
- Flechas: mover por la cuadrícula y cambiar de página automáticamente.
- Confirmar: abrir la ficha.
- Acción: cambiar de pestaña.
- Especial: ordenar por Número / Nombre / Estado.
- Atrás: volver o cerrar la Libreta.

APERTURA / CIERRE
=================
La transición representa una libreta cerrada que abre sus páginas desde el
centro. Ya no usa el fundido del menú de pausa ni una animación de dos puertas.
La duración es intencionalmente corta.

RENDIMIENTO
===========
- Abrir la Libreta solo revisa el equipo actual; no recorre las cajas.
- El escaneo completo de equipo+cajas queda en Debug > recargar y sincronizar.
- La cuadrícula se rasteriza en un solo bitmap en vez de mantener 25
  PokemonIconSprite activos.
- No hay pulsos de escala por frame en Pokémon ni iconos y el cursor tampoco
  pulsa por defecto.
- Cambiar de orden ya no añade frames de espera.

TIPOS
=====
Ruta principal:
  Graphics/UI/types

HABILIDADES ARCANAS
===================
La identidad de la Habilidad Arcana se guarda por especie y permanece oculta
hasta que se desbloquea de verdad.

Regla de familia evolutiva:
- si dos especies de la misma familia tienen exactamente el mismo ID de
  Habilidad Arcana, descubrirla en una revela esa misma habilidad en ambas;
- si una evolución tiene otro ID, su habilidad sigue oculta;
- al evolucionar un Pokémon que ya había despertado su habilidad, se registra
  la habilidad de la nueva especie;
- usar Té Arcano con éxito registra la habilidad de esa especie.

La mera existencia de ArcaneAbility en GameData/PBS NO cuenta como descubrimiento.
Los datos de v1.2.0 que pudieron haberse marcado solo por configuración se limpian
al migrar; una habilidad realmente usada se conserva.

APIs:
  pbResearchArcaneTriggered(battler, ability_id)
  pbResearchArcaneSeen(species, ability_id)
  pbResearchArcaneUsed(species, ability_id)

ÁUREO
=====
Fuente principal:
  Data/GoldenSystem/species.json

`goldenForm` acepta tanto índice numérico como Hash con datos anidados. Nunca se
convierte un Hash con `.to_i`.

APIs:
  pbResearchGoldenFormActivated(battler)
  pbResearchGoldenPowerActivated(battler)

DEBUG
=====
- Libreta de Investigación
- Libreta: desbloquear secciones
- Libreta: recargar y sincronizar

SUMMARY
=======
Este plugin no modifica PokemonSummaryScreen ni PokemonSummary_Scene.
