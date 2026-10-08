# evolution_line_debug.rb
# Plugin [ZBOX] EvolutionLineGiving — Debug commands for evolutionary lines
# Place in: Plugins/[ZBOX] EvolutionLineGiving/evolution_line_debug.rb

module CarnekDebugOptions
  # ── Evolution Lines ──────────────────────────────────────────────
  EVOLUTION_LINES = {
    :CHARIZARD  => [:CHARMANDER, :CHARMELEON, :CHARIZARD],
    :BLASTOISE  => [:SQUIRTLE, :WARTORTLE, :BLASTOISE],
    :VENUSAUR   => [:BULBASAUR, :IVYSAUR, :VENUSAUR],
    :LUCARIO    => [:RIOLU, :LUCARIO],
    :GARCHOMP   => [:GIBLE, :GABITE, :GARCHOMP],
    :TYRANITAR  => [:LARVITAR, :PUPITAR, :TYRANITAR],
    :METAGROSS  => [:BELDUM, :METANG, :METAGROSS],
    :GENGAR     => [:GASTLY, :HAUNTER, :GENGAR],
    :DRAGONITE  => [:DRATINI, :DRAGONAIR, :DRAGONITE],
    :EEVEELUTIONS => [:EEVEE, :VAPOREON, :JOLTEON, :FLAREON,
                      :ESPEON, :UMBREON, :LEAFEON, :GLACEON, :SYLVEON],
    :GOODRA     => [:GOOMY, :SLIGGOO, :GOODRA],
    :PSEUDOS    => [:DRATINI, :DRAGONAIR, :DRAGONITE,
                    :LARVITAR, :PUPITAR, :TYRANITAR,
                    :BELDUM, :METANG, :METAGROSS,
                    :GIBLE, :GABITE, :GARCHOMP,
                    :GOOMY, :SLIGGOO, :GOODRA]
  }

  # ── Evolution Items ──────────────────────────────────────────────
  EVO_ITEM_MAP = {
    :CHARIZARD  => [:FIRE_STONE],
    :PIKACHU    => [:THUNDER_STONE],
    :VAPOREON   => [:WATER_STONE],
    :JOLTEON    => [:THUNDER_STONE],
    :FLAREON    => [:FIRE_STONE],
    :LEAFEON    => [:LEAF_STONE],
    :GLACEON    => [:ICE_STONE],
    :SCIZOR     => [:METAL_COAT],
    :KINGDRA    => [:DRAGON_SCALE],
    :POLITOED   => [:KING_S_ROCK],
    :PORYGON_Z  => [:UP_GRADE, :DUBIOUS_DISC],
    :UMBREON    => [:DUSK_STONE],
    :ESPEON     => [:SUN_STONE],
    :SYLVEON    => [:SHINY_STONE],
    :ROSERADE   => [:SHINY_STONE],
    :TOGEKISS   => [:SHINY_STONE],
    :MISMAGIUS  => [:DUSK_STONE],
    :HONCHKROW  => [:DUSK_STONE],
    :FROSLASS   => [:DAWN_STONE],
    :GALLADE    => [:DAWN_STONE],
    :AEGISLASH  => [:DUSK_STONE]
  }

  # ═══════════════════════════════════════════════════════════════════
  # CATEGORÍA PADRE
  # ═══════════════════════════════════════════════════════════════════

  MenuHandlers.add(:debug_menu, :carnek_debug, {
    "name"        => _INTL("Opciones de Debug Carnek..."),
    "parent"      => :main,
    "description" => _INTL("Líneas evolutivas, ítems y utilidades de testeo"),
    "always_show" => false
  })

  # ═══════════════════════════════════════════════════════════════════
  # CATEGORÍA: Líneas Evolutivas
  # ═══════════════════════════════════════════════════════════════════

  MenuHandlers.add(:debug_menu, :carnek_evo_lines_menu, {
    "name"        => _INTL("Líneas evolutivas..."),
    "parent"      => :carnek_debug,
    "description" => _INTL("Entregar líneas evolutivas completas"),
    "always_show" => false
  })

  MenuHandlers.add(:debug_menu, :give_evolution_line, {
    "name"     => _INTL("Dar línea evolutiva"),
    "parent"   => :carnek_evo_lines_menu,
    "description" => _INTL("Entrega todos los Pokémon de una línea"),
    "effect" => proc {
      next CarnekDebugOptions.choose_line(false)
    }
  })

  MenuHandlers.add(:debug_menu, :give_evo_line_advanced, {
    "name"     => _INTL("Dar línea evolutiva (avanzado)"),
    "parent"   => :carnek_evo_lines_menu,
    "description" => _INTL("Línea + ítems + shiny + personalización"),
    "effect" => proc {
      next CarnekDebugOptions.choose_line(true)
    }
  })

  # ═══════════════════════════════════════════════════════════════════
  # CATEGORÍA: Ítems de Evolución
  # ═══════════════════════════════════════════════════════════════════

  MenuHandlers.add(:debug_menu, :carnek_evo_items_menu, {
    "name"        => _INTL("Ítems de evolución..."),
    "parent"      => :carnek_debug,
    "description" => _INTL("Recibir piedras y objetos evolutivos"),
    "always_show" => false
  })

  MenuHandlers.add(:debug_menu, :give_all_evo_stones, {
    "name"     => _INTL("Dar todas las piedras evo"),
    "parent"   => :carnek_evo_items_menu,
    "description" => _INTL("Recibir 1 de cada piedra evolutiva"),
    "effect" => proc {
      stones = [:FIRE_STONE, :WATER_STONE, :THUNDER_STONE, :LEAF_STONE,
                :ICE_STONE, :SUN_STONE, :MOON_STONE, :SHINY_STONE,
                :DUSK_STONE, :DAWN_STONE, :EVERSTONE]
      stones.each { |s| pbReceiveItem(s) }
      pbMessage(_INTL("Piedras evolutivas entregadas."))
    }
  })

  MenuHandlers.add(:debug_menu, :give_all_evo_items, {
    "name"     => _INTL("Dar todos los ítems evo"),
    "parent"   => :carnek_evo_items_menu,
    "description" => _INTL("Recibir 1 de cada objeto de intercambio/evo"),
    "effect" => proc {
      items = [:METAL_COAT, :DRAGON_SCALE, :UP_GRADE, :DUBIOUS_DISC,
               :KING_S_ROCK, :DEEP_SEA_TOOTH, :DEEP_SEA_SCALE,
               :ELECTIRIZER, :MAGMARIZER, :PROTECTOR, :RAZOR_CLAW,
               :RAZOR_FANG, :REAPER_CLOTH, :PRISM_SCALE,
               :WHIPPED_DREAM, :SATCHEL, :SWEET_HEART]
      items.each { |i| pbReceiveItem(i) }
      pbMessage(_INTL("Ítems evolutivos entregados."))
    }
  })

  # ═══════════════════════════════════════════════════════════════════
  # CATEGORÍA: Utilidades de Testeo
  # ═══════════════════════════════════════════════════════════════════

  MenuHandlers.add(:debug_menu, :carnek_test_utils, {
    "name"        => _INTL("Utilidades de testeo..."),
    "parent"      => :carnek_debug,
    "description" => _INTL("Pokémon custom, limpieza, utilidades rápidas"),
    "always_show" => false
  })

  MenuHandlers.add(:debug_menu, :give_shiny_team, {
    "name"     => _INTL("Dar equipo shiny variado"),
    "parent"   => :carnek_test_utils,
    "description" => _INTL("Entrega un team variado shiny para testeo visual"),
    "effect" => proc {
      team = [:CHARIZARD, :LUCARIO, :GARCHOMP, :SYLVEON, :METAGROSS, :DRAGONITE]
      team.each_with_index do |species, i|
        pkmn = Pokemon.new(species, 50 + i * 10)
        pkmn.shiny = true
        set_perfect_ivs(pkmn)
        pbAddPokemonSilent(pkmn)
      end
      pbMessage(_INTL("Equipo shiny variado entregado."))
    }
  })

  MenuHandlers.add(:debug_menu, :clear_party, {
    "name"     => _INTL("Limpiar equipo"),
    "parent"   => :carnek_test_utils,
    "description" => _INTL("Borra todo el equipo actual"),
    "effect" => proc {
      $player.party.clear
      pbMessage(_INTL("Equipo eliminado."))
    }
  })

  # ═══════════════════════════════════════════════════════════════════
  # LÓGICA DE SELECCIÓN Y ENTREGA
  # ═══════════════════════════════════════════════════════════════════

  def self.line_name(key)
    species_data = GameData::Species.try_get(key)
    return species_data.name if species_data
    key.to_s
  end

  def self.choose_line(advanced)
    keys = EVOLUTION_LINES.keys
    names = keys.map { |s| line_name(s) }
    cmd = pbShowCommands(nil, names, -1)
    return if cmd < 0

    species_key = keys[cmd]
    line = EVOLUTION_LINES[species_key]

    if advanced
      shiny = pbShowCommands(nil, [_INTL("No"), _INTL("Sí")], -1)
      return if shiny < 0
      shiny = (shiny == 1)

      give_line_advanced(line, species_key, shiny)
      pbMessage(_INTL("Línea de {1} entregada (shiny={2}, items incluidos).",
        line_name(species_key),
        shiny ? _INTL("Sí") : _INTL("No")))
    else
      give_line(line, false)
      pbMessage(_INTL("Línea evolutiva de {1} entregada.",
        line_name(species_key)))
    end
  end

  def self.set_perfect_ivs(pkmn)
    GameData::Stat.each_main { |s| pkmn.iv[s.id] = 31 }
    pkmn.calc_stats
  end

  def self.give_line(line, shiny)
    line.each_with_index do |species, i|
      pkmn = Pokemon.new(species, 5 + i * 5)
      pkmn.shiny = true if shiny
      set_perfect_ivs(pkmn)
      pbAddPokemonSilent(pkmn)
    end
  end

  def self.give_line_advanced(line, species_key, shiny)
    base_id = $player.party.length
    line.each_with_index do |species, i|
      pkmn = Pokemon.new(species, 5 + i * 5)
      pkmn.shiny = true if shiny
      set_perfect_ivs(pkmn)
      natures = [:HASTY, :ADAMANT, :JOLLY]
      pkmn.nature = natures[i] if natures[i]
      pkmn.trainer_id = base_id + i + 1000
      pbAddPokemonSilent(pkmn)
    end
    give_evolution_items(species_key)
  end

  def self.give_evolution_items(species_key)
    items = EVO_ITEM_MAP[species_key]
    return if items.nil?
    items.each { |item| pbReceiveItem(item) }
  end
end
