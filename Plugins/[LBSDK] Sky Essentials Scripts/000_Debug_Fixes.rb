#===============================================================================
# Fix for move forgetting when Pokemon has no moves
#===============================================================================
MenuHandlers.remove(:battle_pokemon_debug_menu, :forget_move)
MenuHandlers.add(:battle_pokemon_debug_menu, :forget_move, {
  "name"   => _INTL("Forget move"),
  "parent" => :moves,
  "usage"  => :both,
  "effect" => proc { |pkmn, battler, battle|
    move_names = []
    move_indices = []
    pkmn.moves.each_with_index do |move, index|
      next if !move || !move.id
      if move.total_pp <= 0
        move_names.push(_INTL("{1} (PP: ---)", move.name))
      else
        move_names.push(_INTL("{1} (PP: {2}/{3})", move.name, move.pp, move.total_pp))
      end
      move_indices.push(index)
    end
    if move_indices.empty?
      pbMessage("\\ts[]" + _INTL("{1} doesn't know any moves to forget.", pkmn.name))
      next
    end
    cmd = pbMessage("\\ts[]" + _INTL("Forget which move?"), move_names, -1)
    next if cmd < 0
    old_move_name = pkmn.moves[move_indices[cmd]].name
    pkmn.forget_move_at_index(move_indices[cmd])
    battler&.moves&.delete_at(move_indices[cmd])
    pbMessage("\\ts[]" + _INTL("{1} forgot {2}.", pkmn.name, old_move_name))
  }
})
