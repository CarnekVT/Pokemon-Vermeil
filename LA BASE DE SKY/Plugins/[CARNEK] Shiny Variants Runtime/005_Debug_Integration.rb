#===============================================================================
# [CARNEK] Shiny Variants Runtime - Integración con el Menú Debug
#===============================================================================

# Reemplazo en el menú Debug de Pokémon individual
# (Debug -> Pokémon -> Info visual... -> Definir variocolor)
MenuHandlers.add(:pokemon_debug_menu, :set_shininess, {
  "name"   => _INTL("Definir variocolor"),
  "parent" => :cosmetic,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    ShinyVariantRegistry.reload!
    cmd = 0
    loop do
      v = pkmn.shiny_variant
      v_info = ShinyVariantRegistry.get(v)
      v_name = v_info ? (v_info["name"] || v_info["id"]) : v.to_s
      
      msg = if v == :none
        _INTL("Estado actual: Normal (no variocolor).")
      elsif v == :shiny
        _INTL("Estado actual: Variocolor (Shiny estándar).")
      elsif v == :supershiny
        _INTL("Estado actual: Súper variocolor (Super Shiny).")
      else
        _INTL("Estado actual: Variante '{1}'.", v_name)
      end

      commands = []
      actions = []

      # Opciones básicas
      commands.push(_INTL("Hacer normal"))
      actions.push(:none)

      commands.push(_INTL("Hacer variocolor"))
      actions.push(:shiny)

      commands.push(_INTL("Hacer súper variocolor"))
      actions.push(:supershiny)

      # Variantes personalizadas registradas (ej. Ancient Shiny)
      ShinyVariantRegistry.all.each do |entry|
        id_sym = entry["id"].to_sym
        next if id_sym == :shiny || id_sym == :supershiny || id_sym == :none
        name = entry["name"] || entry["id"].capitalize
        commands.push(_INTL("Hacer {1}", name))
        actions.push(id_sym)
      end

      commands.push(_INTL("Resetear (aleatorio)"))
      actions.push(:reset)

      cmd = screen.pbShowCommands(msg, commands, cmd)
      break if cmd < 0
      action = actions[cmd]
      if action == :reset
        pkmn.shiny_variant = nil
        pkmn.shiny = nil
        pkmn.super_shiny = nil
      else
        pkmn.shiny_variant = action
      end
      $player.pokedex.register(pkmn) if !settingUpBattle && !pkmn.egg?
      screen.pbRefreshSingle(pkmnid)
    end
    next false
  }
})

# Reemplazo en el menú Debug de Combate
# (Debug en batalla -> Pokémon -> Definir variocolor)
MenuHandlers.add(:battle_pokemon_debug_menu, :set_shininess, {
  "name"   => _INTL("Definir variocolor"),
  "parent" => :main,
  "usage"  => :both,
  "effect" => proc { |pkmn, battler, battle|
    ShinyVariantRegistry.reload!
    cmd = 0
    loop do
      v = pkmn.shiny_variant
      v_info = ShinyVariantRegistry.get(v)
      v_name = v_info ? (v_info["name"] || v_info["id"]) : v.to_s
      
      msg = if v == :none
        _INTL("Estado actual: Normal.")
      elsif v == :shiny
        _INTL("Estado actual: Variocolor.")
      elsif v == :supershiny
        _INTL("Estado actual: Súper variocolor.")
      else
        _INTL("Estado actual: {1}.", v_name)
      end

      commands = []
      actions = []

      commands.push(_INTL("Hacer normal"))
      actions.push(:none)

      commands.push(_INTL("Hacer variocolor"))
      actions.push(:shiny)

      commands.push(_INTL("Hacer súper variocolor"))
      actions.push(:supershiny)

      ShinyVariantRegistry.all.each do |entry|
        id_sym = entry["id"].to_sym
        next if id_sym == :shiny || id_sym == :supershiny || id_sym == :none
        name = entry["name"] || entry["id"].capitalize
        commands.push(_INTL("Hacer {1}", name))
        actions.push(id_sym)
      end

      commands.push(_INTL("Resetear"))
      actions.push(:reset)

      cmd = pbMessage("\\ts[]" + msg, commands, -1, nil, cmd)
      break if cmd < 0
      action = actions[cmd]
      if action == :reset
        pkmn.shiny_variant = nil
        pkmn.shiny = nil
        pkmn.super_shiny = nil
      else
        pkmn.shiny_variant = action
      end
      if battler
        battler.pokemon.shiny_variant = pkmn.shiny_variant
        battler.pbUpdate(true) if battler.respond_to?(:pbUpdate)
      end
    end
  }
})
