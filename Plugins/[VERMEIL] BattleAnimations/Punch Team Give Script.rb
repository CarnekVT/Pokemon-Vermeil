#===============================================================================
# [VERMEIL] Punch Arsenal - Pokemon Give Debug Script
# Gives a series of Pokemon that cover all punch moves
# Usage: Call pbGivePunchTeam in debug console or via event script
#===============================================================================

# The complete list of punch moves to cover
VERMEIL_PUNCH_MOVES = [
  :COMETPUNCH, :DOUBLEHIT, :SURGINGSTRIKES,
  :MACHPUNCH, :BULLETPUNCH, :JETPUNCH, :SUCKERPUNCH, :WICKEDBLOW,
  :TREMORPUNCH, :FOCUSPUNCH, :DYNAMICPUNCH, :METEORMASH, :ICEHAMMER, :HAMMERARM, :RAGEFIST,
  :FIREPUNCH, :ICEPUNCH, :THUNDERPUNCH, :PLASMAFISTS, :SHADOWPUNCH, :DRAINPUNCH, :POWERUPPUNCH, :MEGAPUNCH, :SKYUPPERCUT, :DIZZYPUNCH
]

# Optimal distribution of moves across 7 Pokemon (4 moves each = 28 total)
# Pokemon chosen to match move compatibility
VERMEIL_PUNCH_TEAM = [
  # Pokemon 1: Fast Multi-Hit Punches
  { species: :HITMONLEE, moves: [:COMETPUNCH, :DOUBLEHIT, :SURGINGSTRIKES] },
  
  # Pokemon 2: Priority Punches
  { species: :HITMONCHAN, moves: [:MACHPUNCH, :BULLETPUNCH, :JETPUNCH, :SUCKERPUNCH] },
  
  # Pokemon 3: Heavy Power Punches
  { species: :PRIMEAPE, moves: [:WICKEDBLOW, :RAGEFIST, :FOCUSPUNCH, :DYNAMICPUNCH] },
  
  # Pokemon 4: Ground/Steel/Fighting Punches
  { species: :GOLEM, moves: [:TREMORPUNCH, :METEORMASH, :HAMMERARM, :ICEHAMMER] },
  
  # Pokemon 5: Elemental Punches 1
  { species: :MACHAMP, moves: [:FIREPUNCH, :ICEPUNCH, :THUNDERPUNCH, :MEGAPUNCH] },
  
  # Pokemon 6: Elemental Punches 2 + Special
  { species: :SCYTHER, moves: [:PLASMAFISTS, :SHADOWPUNCH, :DRAINPUNCH, :POWERUPPUNCH] },
  
  # Pokemon 7: Uppercut + Finisher
  { species: :HERACROSS, moves: [:SKYUPPERCUT, :DIZZYPUNCH, :MACHPUNCH, :FIREPUNCH] }
]

#===============================================================================
# Main function to give the punch team
#===============================================================================
def pbGivePunchTeam
  # Check if party exists
  if !$player
    pbMessage("Error: No player data found.")
    return
  end
  
  VERMEIL_PUNCH_TEAM.each_with_index do |pokemon_data, index|
    species_id = pokemon_data[:species]
    moves = pokemon_data[:moves]
    
    # Get species data
    species_data = GameData::Species.get(species_id)
    unless species_data
      pbMessage("Error: Species #{species_id} not found!")
      next
    end
    
    # Create Pokemon at level 100
    pokemon = Pokemon.new(species_id, 100)
    
    # Reset moves to clear default moves
    pokemon.reset_moves
    
    # Set our custom moves using the correct method
    moves.each_with_index do |move_id, move_index|
      move_data = GameData::Move.get(move_id)
      if move_data && move_index < 4
        # Create a new Pokemon::Move object and assign it
        pokemon.moves[move_index] = Pokemon::Move.new(move_data.id)
      end
    end
    
    # Add to party or PC
    if $player.party.length < 6
      $player.party.push(pokemon)
      pbMessage("\\me[BagGet]Got #{species_data.name}!")
    else
      # Use pbStorePokemon to store in PC when party is full
      pbStorePokemon(pokemon)
      pbMessage("\\me[BagGet]Sent #{species_data.name} to PC!")
    end
  end
  
  pbMessage("\\me[BattleWin]All punch team Pokemon received!")
  pbMessage("Use 'pbListPunchTeam' to see the team summary.")
end

#===============================================================================
# List the punch team summary
#===============================================================================
def pbListPunchTeam
  return if VERMEIL_PUNCH_TEAM.empty?
  
  summary = "=== PUNCH TEAM ===\n\n"
  
  VERMEIL_PUNCH_TEAM.each_with_index do |pokemon_data, index|
    species_data = GameData::Species.get(pokemon_data[:species])
    moves = pokemon_data[:moves].map { |m| 
      move_data = GameData::Move.get(m)
      move_data ? move_data.name : m.to_s
    }.join(", ")
    
    summary += "#{index + 1}. #{species_data.name}: #{moves}\n"
  end
  
  pbMessage(summary)
end

#===============================================================================
# Give just one specific punch Pokemon (by index 0-6)
#===============================================================================
def pbGivePunchPokemon(index)
  return if index < 0 || index >= VERMEIL_PUNCH_TEAM.length
  
  pokemon_data = VERMEIL_PUNCH_TEAM[index]
  species_id = pokemon_data[:species]
  moves = pokemon_data[:moves]
  
  species_data = GameData::Species.get(species_id)
  unless species_data
    pbMessage("Error: Species #{species_id} not found!")
    return
  end
  
  # Create Pokemon
  pokemon = Pokemon.new(species_id, 100)
  
  # Reset moves first
  pokemon.reset_moves
  
  # Set moves using the correct method
  moves.each_with_index do |move_id, move_index|
    move_data = GameData::Move.get(move_id)
    if move_data && move_index < 4
      pokemon.moves[move_index] = Pokemon::Move.new(move_data.id)
    end
  end
  
  # Add to party or PC
  if $player.party.length < 6
    $player.party.push(pokemon)
    pbMessage("\\me[BagGet]Got #{species_data.name} with #{moves.length} punch moves!")
  else
    pbStorePokemon(pokemon)
    pbMessage("\\me[BagGet]Sent #{species_data.name} to PC!")
  end
end

#===============================================================================
# Alternative: Simple give command for testing individual moves
#===============================================================================
def pbGiveMoveToPartyPokemon(pokemon_index, move_id)
  return if pokemon_index < 0 || pokemon_index >= $player.party.length
  
  pokemon = $player.party[pokemon_index]
  move_data = GameData::Move.get(move_id)
  
  unless move_data
    pbMessage("Error: Move #{move_id} not found!")
    return
  end
  
  # Find first empty move slot
  empty_slot = -1
  4.times { |i| empty_slot = i if !pokemon.moves[i] || pokemon.moves[i].id == :STRUGGLE }
  
  if empty_slot >= 0
    # Create new move and assign directly
    pokemon.moves[empty_slot] = Pokemon::Move.new(move_data.id)
    pbMessage("Added #{move_data.name} to #{$player.party[pokemon_index].name}!")
  else
    pbMessage("No empty move slot available!")
  end
end

#===============================================================================
# Console command registration (for debug menu)
#===============================================================================
if defined?(DebugMenuCommands)
  DebugMenuCommands.register(:vermeil_punch_team, {
    "name"        => "Vermeil: Give Punch Team",
    "description" => "Gives 7 Pokemon covering all 26 punch moves"
  }) { 
    pbGivePunchTeam
  }
  
  DebugMenuCommands.register(:vermeil_list_punch_team, {
    "name"        => "Vermeil: List Punch Team",
    "description" => "Shows the punch team composition"
  }) { 
    pbListPunchTeam
  }
end

#===============================================================================
# Instructions:
# Run in game console or event:
#   pbGivePunchTeam          - Get all 7 punch Pokemon
#   pbListPunchTeam          - See team composition  
#   pbGivePunchPokemon(0-6) - Get specific Pokemon from team
#===============================================================================
