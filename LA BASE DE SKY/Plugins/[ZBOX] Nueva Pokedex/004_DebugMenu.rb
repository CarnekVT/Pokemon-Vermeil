#===============================================================================
# [ZBOX] Nueva Pokédex - Comandos de Menú F9 Debug (Vanilla marcado como Legacy)
#===============================================================================
MenuHandlers.add(:debug_menu, :new_pokedex_hub, {
  "name"        => _INTL("Nueva Pokédex (Comandos)"),
  "parent"      => :pokemon_menu,
  "description" => _INTL("Herramientas de depuración, recarga de JSONs y prueba de la Nueva Pokédex."),
  "effect"      => proc { |msgwindow|
    commands = [
      _INTL("Abrir Nueva Pokédex"),
      _INTL("Recargar Dex JSONs"),
      _INTL("Desbloquear todas las Dexes regionales"),
      _INTL("Marcar Dex activa como completada (Vistos/Atrapados)"),
      _INTL("Ver lista de especies habilitadas"),
      _INTL("Editor de formas y slots")
    ]
    loop do
      choice = pbShowCommands(msgwindow, commands, -1)
      break if choice < 0
      case choice
      when 0
        pbOpenNewPokedex(0)
      when 1
        NewPokedex.reload_data!
        pbMessage(_INTL("¡Datos de Dex JSONs recargados con éxito!"))
      when 2
        if $player && $player.pokedex
          num = defined?(Settings::DEXES_COUNT) ? Settings::DEXES_COUNT : 4
          (0...num).each { |i| $player.pokedex.unlock(i) rescue nil }
          pbMessage(_INTL("Todas las dexes regionales han sido desbloqueadas."))
        end
      when 3
        if $player && $player.pokedex
          species_list = NewPokedex.enabled_species_list
          species_list.each do |sp|
            $player.pokedex.set_seen(sp) rescue nil
            $player.pokedex.set_owned(sp) rescue nil
          end
          pbMessage(_INTL("¡Se han registrado {1} especies como vistas y atrapadas!", species_list.length))
        end
      when 4
        species_list = NewPokedex.enabled_species_list
        pbMessage(_INTL("Especies habilitadas actualmente: {1}", species_list.length))
      when 5
        pbFadeOutIn do
          NuevaPokedex.debug_edit_pokedex
        end
      end
    end
  }
})

# Marcar las opciones vanilla de Pokédex como Legacy para no confundir al desarrollador
EventHandlers.add(:on_start_game, :mark_vanilla_pokedex_debug_legacy, proc {
  if defined?(MenuHandlers)
    [:pokedex_cmds, :pokedex_lists].each do |key|
      item = MenuHandlers.get(:debug_menu, key) rescue nil
      if item && item.is_a?(Hash) && item["name"] && !item["name"].include?("[Legacy]")
        item["name"] = "[Legacy] " + item["name"]
      end
    end
  end
})
