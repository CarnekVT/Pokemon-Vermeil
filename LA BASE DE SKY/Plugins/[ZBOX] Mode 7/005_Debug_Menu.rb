#===============================================================================
# Mode 7 (2.5D) - Comando de debug (F9)
#===============================================================================
MenuHandlers.add(:debug_menu, :mode7_toggle, {
  "name"        => _INTL("Alternar 2.5D (Mode 7)"),
  "parent"      => :main,
  "description" => _INTL("Activa o desactiva la proyección 2.5D (Modo 7) del mapa actual."),
  "effect"      => proc {
    Mode7.toggle_debug
    pbMessage(_INTL("2.5D ({1})", Mode7.override_state))
    next if !$scene.is_a?(Scene_Map)
    # createSpritesets del motor NO dispone los spritesets viejos (003_Scene_Map.rb:18-27);
    # si no se dispone antes, quedan sprites de eventos huérfanos duplicados.
    $scene.disposeSpritesets
    $scene.createSpritesets
  }
})
