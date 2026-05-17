#===============================================================================
# Restructures the trainer Pokemon editor so that plugins may add new properties.
#===============================================================================
module TrainerPokemonProperty
  #-----------------------------------------------------------------------------
  # Returns initial settings and associated keys for a trainer's Pokemon.
  #-----------------------------------------------------------------------------
  def self.editor_settings(initsetting)
    initsetting = {:species => nil, :level => 10} if !initsetting
    oldsetting = [
      initsetting[:species],
      initsetting[:level],
      initsetting[:real_name],
      initsetting[:form],
      initsetting[:gender],
      initsetting[:shininess],
      initsetting[:super_shininess],
      initsetting[:shadowness]
    ]
    keys = [
      :species, :level, :real_name, :form, :gender, 
      :shininess, :super_shininess, :shadowness
    ]
    Pokemon::MAX_MOVES.times do |i|
      oldsetting.push((initsetting[:moves]) ? initsetting[:moves][i] : nil)
      keys.push(:moves)
    end
    oldsetting.concat([
      initsetting[:ability],
      initsetting[:ability_index],
      initsetting[:item],
      initsetting[:nature],
      initsetting[:iv],
      initsetting[:ev],
      initsetting[:happiness],
      initsetting[:poke_ball]
    ])
    keys.push(
      :ability, :ability_index, :item, :nature,
      :iv, :ev, :happiness, :poke_ball
    )
    return oldsetting, keys
  end
  
  #-----------------------------------------------------------------------------
  # Returns all of the editor properties for a trainer's Pokemon.
  #-----------------------------------------------------------------------------
  def self.editor_properties(oldsetting)
    max_level = GameData::GrowthRate.max_level
    properties = [
      [_INTL("Species"),    SpeciesProperty,                     _INTL("Especie del Pokémon.")],
      [_INTL("Level"),      NonzeroLimitProperty.new(max_level), _INTL("Nivel del Pokémon (1-{1}).", max_level)],
      [_INTL("Name"),       StringProperty,                      _INTL("Mote del Pokémon.")],
      [_INTL("Form"),       LimitProperty2.new(999),             _INTL("Forma del Pokémon.")],
      [_INTL("Gender"),     GenderProperty,                      _INTL("énero del Pokémon.")],
      [_INTL("Shiny"),      BooleanProperty2,                    _INTL("Si está activado, el Pokémon es variocolor.")],
      [_INTL("SuperShiny"), BooleanProperty2,                    _INTL("Si está activado, el Pokémon es super variocolor (variocolor con un color diferente y una animación especial de brillo).")],
      [_INTL("Shadow"),     BooleanProperty2,                    _INTL("Si está activado, el Pokémon es un Pokémon Oscuro.")]
    ]
    Pokemon::MAX_MOVES.times do |i|
      properties.push([_INTL("Move {1}", i + 1),
                       MovePropertyForSpecies.new(oldsetting), _INTL("Movimiento conocido por el Pokémon. Deja todos los movimientos en blanco (usa la tecla Z para borrar) para un conjunto de movimientos salvaje.")])
    end
    properties.concat([
      [_INTL("Ability"),       AbilityProperty,                         _INTL("Habilidad del Pokémon. Sobrescribe el índice de habilidad.")],
      [_INTL("Ability index"), LimitProperty2.new(99),                  _INTL("Índice de habilidad. 0=primera habilidad, 1=segunda habilidad, 2+=habilidad oculta.")],
      [_INTL("Held item"),     ItemProperty,                            _INTL("Objeto que lleva el Pokémon.")],
      [_INTL("Nature"),        GameDataProperty.new(:Nature),           _INTL("Naturaleza del Pokémon.")],
      [_INTL("IVs"),           IVsProperty.new(Pokemon::IV_STAT_LIMIT), _INTL("Valores individuales para cada una de las estadísticas del Pokémon.")],
      [_INTL("EVs"),           EVsProperty.new(Pokemon::EV_STAT_LIMIT), _INTL("Valores de esfuerzo para cada una de las estadísticas del Pokémon.")],
      [_INTL("Happiness"),     LimitProperty2.new(255),                 _INTL("Felicidad del Pokémon (0-255).")],
      [_INTL("Poké Ball"),     BallProperty.new(oldsetting),            _INTL("El tipo de Poké Ball en la que se guarda el Pokémon.")]
    ])
    return properties
  end
  
  #-----------------------------------------------------------------------------
  # Rewritten editor for trainer's Pokemon.
  #-----------------------------------------------------------------------------
  def self.set(settingname, initsetting)
    oldsetting, keys = self.editor_settings(initsetting)
    pkmn_properties = self.editor_properties(oldsetting)
    pbPropertyList(settingname, oldsetting, pkmn_properties, false)
    return nil if !oldsetting[0]
    ret = {}
    keys.each_with_index do |key, i|
      case key
      when :moves
        ret[key] = [] if !ret[key]
        ret[key].push(oldsetting[i])
      else
        ret[key] = oldsetting[i]
      end
    end
    ret[:moves].uniq!
    ret[:moves].compact!
    return ret
  end
end

#===============================================================================
# Fix for partner trainers not inheriting inventories set in PBS data.
#===============================================================================
module BattleCreationHelperMethods
  module_function
  
  def set_up_player_trainers(foe_party)
    trainer_array = [$player]
    ally_items    = []
    pokemon_array = $player.party
    party_starts  = [0]
    if partner_can_participate?(foe_party)
      ally = NPCTrainer.new($PokemonGlobal.partner[1], $PokemonGlobal.partner[0])
      ally.id    = $PokemonGlobal.partner[2]
      ally.party = $PokemonGlobal.partner[3]
      ally_items[1] = $PokemonGlobal.partner[4].clone
      trainer_array.push(ally)
      pokemon_array = []
      $player.party.each { |pkmn| pokemon_array.push(pkmn) }
      party_starts.push(pokemon_array.length)
      ally.party.each { |pkmn| pokemon_array.push(pkmn) }
      setBattleRule("double") if $game_temp.battle_rules[:side_sizes].nil?
    end
    return trainer_array, ally_items, pokemon_array, party_starts
  end
end

def pbRegisterPartner(tr_type, tr_name, tr_id = 0)
  tr_type = GameData::TrainerType.get(tr_type).id
  pbCancelVehicles
  trainer = pbLoadTrainer(tr_type, tr_name, tr_id)
  EventHandlers.trigger(:on_trainer_load, trainer)
  trainer.party.each do |i|
    i.owner = Pokemon::Owner.new_from_trainer(trainer)
    i.calc_stats
  end
  $PokemonGlobal.partner = [tr_type, tr_name, trainer.id, trainer.party, trainer.items]
end