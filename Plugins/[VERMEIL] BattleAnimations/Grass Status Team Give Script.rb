#===============================================================================
# [VERMEIL] Grass Status Team - Pokemon Give Debug Script
# Gives a series of Pokemon that cover all grass status moves
# Usage: Call pbGiveGrassTeam in debug console or via event script
#===============================================================================

# The complete list of grass status moves to cover
VERMEIL_GRASS_MOVES = [
  :WORRYSEED, :STRENGTHSAP, :AROMATHERAPY, :INGRAIN, :SPIKYSHIELD,
  :FORESTSCURSE, :JUNGLEHEALING, :LEECHSEED, :SPORE, :COTTONSPORE,
  :STUNSPORE, :SPICYEXTRACT, :GRASSWHISTLE, :SYNTHESIS, :SLEEPPOWDER,
  :POISONPOWDER, :GROWTH
]

# Optimal distribution of moves across 5 Pokemon (4 + 4 + 4 + 4 + 1 = 17)
# Pokemon chosen to match move compatibility
VERMEIL_GRASS_TEAM = [
  # Pokemon 1: Sleep/Spore User (Bulbasaur line) - 4 moves
  { species: :VENUSAUR, moves: [:SPORE, :SLEEPPOWDER, :LEECHSEED, :GROWTH] },
  
  # Pokemon 2: Status Powder User (Breloom) - 4 moves
  { species: :BRELOOM, moves: [:STUNSPORE, :POISONPOWDER, :WORRYSEED, :STRENGTHSAP] },
  
  # Pokemon 3: Support/Healing (Amoonguss) - 4 moves
  { species: :AMOONGUSS, moves: [:AROMATHERAPY, :JUNGLEHEALING, :SPIKYSHIELD, :SYNTHESIS] },
  
  # Pokemon 4: Ingrain/Curse (Tangrowth) - 4 moves
  { species: :SCEPTILE, moves: [:INGRAIN, :FORESTSCURSE, :COTTONSPORE, :GRASSWHISTLE] },
  
  # Pokemon 5: Extra move - Bellossom with SPICYEXTRACT only
  { species: :BELLOSSOM, moves: [:SPICYEXTRACT] }
]

#===============================================================================
# Main function to give the grass status team
#===============================================================================
def pbGiveGrassTeam
  # Check if party exists
  if !$player
    pbMessage("Error: No player data found.")
    return
  end
  
  VERMEIL_GRASS_TEAM.each_with_index do |pokemon_data, index|
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
  
  pbMessage("\\me[BattleWin]All grass status team Pokemon received!")
  pbMessage("Use 'pbListGrassTeam' to see the team summary.")
end

#===============================================================================
# List the grass status team summary
#===============================================================================
def pbListGrassTeam
  return if VERMEIL_GRASS_TEAM.empty?
  
  summary = "=== GRASS STATUS TEAM ===\n\n"
  
  VERMEIL_GRASS_TEAM.each_with_index do |pokemon_data, index|
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
# Give just one specific grass status Pokemon (by index 0-4)
#===============================================================================
def pbGiveGrassPokemon(index)
  return if index < 0 || index >= VERMEIL_GRASS_TEAM.length
  
  pokemon_data = VERMEIL_GRASS_TEAM[index]
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
    pbMessage("\\me[BagGet]Got #{species_data.name} with #{moves.length} grass status moves!")
  else
    pbStorePokemon(pokemon)
    pbMessage("\\me[BagGet]Sent #{species_data.name} to PC!")
  end
end

#===============================================================================
# Alternative: Simple give command for testing individual moves
#===============================================================================
def pbGiveGrassMoveToPartyPokemon(pokemon_index, move_id)
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
  DebugMenuCommands.register(:vermeil_grass_team, {
    "name"        => "Vermeil: Give Grass Status Team",
    "description" => "Gives 5 Pokemon covering all grass status moves"
  }) { 
    pbGiveGrassTeam
  }
  
  DebugMenuCommands.register(:vermeil_list_grass_team, {
    "name"        => "Vermeil: List Grass Status Team",
    "description" => "Shows the grass status team composition"
  }) { 
    pbListGrassTeam
  }
end

#===============================================================================
# Instructions:
# Run in game console or event:
#   pbGiveGrassTeam          - Get all 5 grass status Pokemon
#   pbListGrassTeam          - See team composition  
#   pbGiveGrassPokemon(0-4)  - Get specific Pokemon from team
#===============================================================================
