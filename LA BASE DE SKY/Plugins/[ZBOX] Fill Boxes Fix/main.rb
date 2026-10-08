MenuHandlers.add(:debug_menu, :fill_boxes, {
  "name"        => _INTL("Llenar cajas del PC"),
  "parent"      => :pokemon_menu,
  "description" => _INTL("Llena el PC con un Pokémon de cada especie (al nivel 50)."),
  "effect"      => proc {
    added = 0
    box_qty = PokemonBox::BOX_SIZE
    completed = true
    GameData::Species.each do |sp|
      species = sp.species
      form = sp.form
      if sp.single_gendered?
        gender = (sp.gender_ratio == :AlwaysFemale) ? 1 : 0
        [false, true].each do |shiny|
          $player.pokedex.register(species, gender, form, shiny, false)
        end
      elsif form == 0 ||
            (sp.real_form_name && !sp.real_form_name.empty? && sp.pokedex_form == sp.form)
        2.times do |gender|
          [false, true].each do |shiny|
            $player.pokedex.register(species, gender, form, shiny, false)
          end
        end
      end
      $player.pokedex.set_owned(species, false)
      next if form != 0
      if added >= Settings::NUM_STORAGE_BOXES * box_qty
        completed = false
        next
      end
      added += 1
      $PokemonStorage[(added - 1) / box_qty, (added - 1) % box_qty] = Pokemon.new(species, 50)
    end
    $player.pokedex.refresh_accessible_dexes
    pbMessage(_INTL("Las cajas del PC se han llenado con un Pokémon de cada especie."))
    if !completed
      pbMessage(_INTL("Nota: El número de espacio en el PC ({1} cajas de {2}) es menor que el número de especies.",
                      Settings::NUM_STORAGE_BOXES, box_qty))
    end
  }
})
