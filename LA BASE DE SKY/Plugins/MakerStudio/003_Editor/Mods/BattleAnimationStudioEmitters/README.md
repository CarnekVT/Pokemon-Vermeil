# Battle Animation Studio · Modern Emitters

Maker Studio mod for the Battle Animation Studio data used by Pokémon Vermeil.

- Opens from **Mods → Battle Animation Studio · Emitters**.
- Reads/writes `PBS/AnimationStudio/animations.json`.
- Separates emitter position, emitted spawn location, auto-movement and modifiers.
- Supports cartesian/polar emitter and spawn coordinates.
- Uses modern `InitialAngle` semantics.
- Migrates legacy BAS keys such as `emitX` → `spawnX` and `emitAngle` → `emitDirection`.
- Double-click a numeric property to edit its emitter keyframes.
- The BAS runtime keeps aliases for old animations, so existing animation JSON remains playable.
