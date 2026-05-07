#===============================================================================
# EBDX Port Functions (subset not covered by DBK)
# - Randomizer
# - Nuzlocke
# - Boss battle helpers (wild generation + special battle start)
#===============================================================================

$nonStaticEncounter = false if !defined?($nonStaticEncounter)

module EliteBattle
  @cache = {} if !defined?(@cache)
  @data  = {} if !defined?(@data)
  @randomizer = false if !defined?(@randomizer)
  @nuzlocke = false if !defined?(@nuzlocke)

  #-------------------------------------------------------------------------
  # Lightweight cache/data helpers (EBDX-compatible minimal API)
  #-------------------------------------------------------------------------
  def self.set(key, value)
    @cache[key] = value
  end

  def self.get(key)
    return @cache[key]
  end

  def self.reset(key = nil)
    key ? @cache.delete(key) : @cache.clear
  end

  def self.add_data(section, key, value)
    @data[section] ||= {}
    @data[section][key] = value
  end

  def self.get_data(section, type = nil, key = nil, index = nil)
    data = @data[section]
    return nil if data.nil?
    data = data[type] if type && data.is_a?(Hash) && data.key?(type)
    data = data[key] if key && data.is_a?(Hash) && data.key?(key)
    if !index.nil? && data
      data = data[index] if data.is_a?(Hash) && data.key?(index)
      data = data[index] if data.is_a?(Array) && index.is_a?(Integer)
    end
    return data
  end

  def self.log
    @log ||= begin
      logger = Object.new
      def logger.error(msg)
        raise msg if $DEBUG
      end
      logger
    end
  end

  def self.all_species
    @all_species ||= GameData::Species.keys
  end

  def self.InitializeSpecies
    @all_species = GameData::Species.keys
  end

  def self.InitializeItems
    @all_items = GameData::Item.keys
  end

  #-------------------------------------------------------------------------
  # Simple command window shim used by Randomizer/Nuzlocke selection
  #-------------------------------------------------------------------------
  def self.commandWindow(commands, index = 0, msgwindow = nil)
    msg = ""
    msg = msgwindow.text if msgwindow && msgwindow.respond_to?(:text)
    return pbMessage(msg.to_s, commands, index)
  end

  #-------------------------------------------------------------------------
  # Randomizer
  #-------------------------------------------------------------------------
  def self.randomizer?
    return $PokemonGlobal && $PokemonGlobal.isRandomizer
  end

  def self.randomizerOn?
    return self.randomizer? && self.get(:randomizer)
  end

  def self.toggle_randomizer(force = nil)
    @randomizer = force.nil? ? !@randomizer : force
    self.set(:randomizer, @randomizer)
    $PokemonEncounters.setup($game_map.map_id) if $PokemonEncounters
  end

  def self.randomizeTrainers
    data = load_data("Data/trainers.dat")
    trainer_exclusions = EliteBattle.get_data(:RANDOMIZER, :Metrics, :EXCLUSIONS_TRAINERS)
    species_exclusions = EliteBattle.get_data(:RANDOMIZER, :Metrics, :EXCLUSIONS_SPECIES)
    return if !data.is_a?(Hash)
    data.keys.each do |key|
      next if trainer_exclusions&.include?(data[key].id)
      data[key].pokemon.each_with_index do |poke, i|
        next if species_exclusions&.include?(poke[:species])
        data[key].pokemon[i][:species] = EliteBattle.all_species.sample
      end
    end
    return data
  end

  def self.randomizeEncounters
    data = load_data("Data/encounters.dat")
    species_exclusions = EliteBattle.get_data(:RANDOMIZER, :Metrics, :EXCLUSIONS_SPECIES)
    return if !data.is_a?(Hash)
    data.keys.each do |key|
      data[key].types.keys.each do |type|
        data[key].types[type].each_with_index do |arr, i|
          next if species_exclusions&.include?(arr[1])
          data[key].types[type][i][1] = EliteBattle.all_species.sample
        end
      end
    end
    return data
  end

  def self.randomizeStatic
    new = {}
    array = EliteBattle.all_species.clone
    EliteBattle.all_species.each do |org|
      i = rand(array.length)
      new[org] = array[i]
      array.delete_at(i)
    end
    return new
  end

  def self.randomizeItems
    new = {}
    item = :POTION
    GameData::Item.keys.each do |org|
      loop do
        item = GameData::Item.keys.sample
        break if !GameData::Item.get(item).is_key_item?
      end
      new[org] = item
    end
    return new
  end

  def self.randomizeData
    data = {}
    randomized = {
      :TRAINERS   => proc { EliteBattle.randomizeTrainers },
      :ENCOUNTERS => proc { EliteBattle.randomizeEncounters },
      :STATIC     => proc { EliteBattle.randomizeStatic },
      :GIFTS      => proc { EliteBattle.randomizeStatic },
      :ITEMS      => proc { EliteBattle.randomizeItems }
    }
    rules = EliteBattle.get_data(:RANDOMIZER, :Metrics, :RULES) || []
    rules.each do |key|
      data[key] = randomized[key].call if randomized.key?(key)
    end
    return data
  end

  def self.getRandomizedData(data, symbol, index = nil)
    return data if !self.randomizerOn?
    if $PokemonGlobal && $PokemonGlobal.randomizedData && $PokemonGlobal.randomizedData.key?(symbol)
      return $PokemonGlobal.randomizedData[symbol][index] if !index.nil?
      return $PokemonGlobal.randomizedData[symbol]
    end
    return data
  end

  def self.startRandomizer(skip = false)
    ret = $PokemonGlobal && $PokemonGlobal.isRandomizer
    ret, cmd = self.randomizerSelection unless skip
    @randomizer = true
    self.set(:randomizer, true)
    $PokemonGlobal.randomizedData = self.randomizeData if $PokemonGlobal && $PokemonGlobal.randomizedData.nil?
    $PokemonGlobal.isRandomizer = ret if $PokemonGlobal
    $PokemonEncounters.setup($game_map.map_id) if $PokemonEncounters
    return if skip
    added = EliteBattle.get_data(:RANDOMIZER, :Metrics, :RULES) || []
    msg = _INTL("Your selected Randomizer rules have been applied.")
    msg = _INTL("No Randomizer rules have been applied.") if added.length < 1
    msg = _INTL("Your selection has been cancelled.") if cmd && cmd < 0
    pbMessage(msg)
  end

  def self.randomizerSelection
    modifiers = [:TRAINERS, :ENCOUNTERS, :STATIC, :GIFTS, :ITEMS]
    desc = [
      _INTL("Randomize Trainer parties"),
      _INTL("Randomize Wild encounters"),
      _INTL("Randomize Static encounters"),
      _INTL("Randomize Gifted Pokemon"),
      _INTL("Randomize Items")
    ]
    added = []
    cmd = 0
    msgwindow = pbCreateMessageWindow(nil, "choice 1")
    msgwindow.text = _INTL("Select the Randomizer Modes you wish to apply.")
    loop do
      commands = []
      modifiers.length.times do |i|
        mark = (added.include?(modifiers[i])) ? "[X]" : "[  ]"
        commands.push(_INTL("{1} {2}", mark, desc[i]))
      end
      commands.push(_INTL("Done"))
      cmd = self.commandWindow(commands, cmd, msgwindow)
      if cmd < 0
        clear = pbConfirmMessage("Do you wish to cancel the Randomizer selection?")
        added.clear if clear
        next unless clear
      end
      break if cmd < 0 || cmd >= (commands.length - 1)
      if added.include?(modifiers[cmd])
        added.delete(modifiers[cmd])
      else
        added.push(modifiers[cmd])
      end
    end
    pbDisposeMessageWindow(msgwindow)
    $PokemonGlobal.randomizerRules = added if $PokemonGlobal
    EliteBattle.add_data(:RANDOMIZER, :RULES, added)
    Input.update
    return (added.length > 0), cmd
  end

  def self.resetRandomizer
    EliteBattle.reset(:randomizer)
    if $PokemonGlobal
      $PokemonGlobal.randomizedData = nil
      $PokemonGlobal.isRandomizer = nil
      $PokemonGlobal.randomizerRules = nil
    end
    $PokemonEncounters.setup($game_map.map_id) if $PokemonEncounters
  end

  #-------------------------------------------------------------------------
  # Nuzlocke
  #-------------------------------------------------------------------------
  def self.nuzlocke?
    return $PokemonGlobal && $PokemonGlobal.isNuzlocke
  end

  def self.nuzlockeOn?
    return self.nuzlocke? && self.get(:nuzlocke)
  end

  def self.toggle_nuzlocke(force = nil)
    @nuzlocke = force.nil? ? !@nuzlocke : force
    self.set(:nuzlocke, @nuzlocke)
  end

  def self.getFirstEvo(species)
    return nil if species.nil?
    prev = GameData::Species.get(species).get_previous_species
    return species if prev == species
    return self.getFirstEvo(prev)
  end

  def self.getNextEvos(species)
    return [] if species.nil?
    evo = GameData::Species.get(species).get_evolutions
    all = []
    return [species] if evo.length < 1
    evo.each do |arr|
      all += [arr[0]]
      all += self.getNextEvos(arr[0])
    end
    return all.uniq
  end

  def self.getEvolutionaryLine(species)
    species = self.getFirstEvo(species)
    return [species] + self.getNextEvos(species)
  end

  def self.checkEvoNuzlocke?(species)
    return false if !$PokemonGlobal || !$PokemonGlobal.nuzlockeData
    self.getEvolutionaryLine(species).each do |poke|
      return true if $player.owned?(poke)
    end
    return false
  end

  def self.startNuzlocke(skip = false)
    ret = $PokemonGlobal && $PokemonGlobal.isNuzlocke
    ret = self.nuzlockeSelection unless skip
    $PokemonGlobal.qNuzlocke = ret if $PokemonGlobal
    GameData::Item.values.each do |i|
      break if !$bag
      if GameData::Item.get(i).is_poke_ball? && $bag.has?(i)
        @nuzlocke = ret
        self.set(:nuzlocke, ret)
        $PokemonGlobal.isNuzlocke = ret if $PokemonGlobal
        break
      end
    end
    $PokemonGlobal.nuzlockeData = {} if $PokemonGlobal && $PokemonGlobal.nuzlockeData.nil?
  end

  def self.nuzlockeSelection
    modifiers = [:NOREVIVE, :PERMADEATH, :ONEROUTE, :DUPSCLAUSE, :STATIC, :SHINY]
    desc = [
      _INTL("Cannot revive fainted battlers"),
      _INTL("Auto-delete fainted battlers"),
      _INTL("One encounter per map"),
      _INTL("Disregard duplicate species (line)"),
      _INTL("Exclude static from encounter limit"),
      _INTL("Exclude shiny from encounter limit")
    ]
    added = [:NOREVIVE, :DUPSCLAUSE, :ONEROUTE, :STATIC, :SHINY]
    cmd = 0
    msgwindow = pbCreateMessageWindow(nil, "choice 1")
    msgwindow.text = _INTL("Select the Nuzlocke Rules you wish to apply.")
    loop do
      commands = []
      modifiers.length.times do |i|
        mark = (added.include?(modifiers[i])) ? "[X]" : "[  ]"
        commands.push(_INTL("{1} {2}", mark, desc[i]))
      end
      commands.push(_INTL("Done"))
      cmd = self.commandWindow(commands, cmd, msgwindow)
      if cmd < 0
        clear = pbConfirmMessage("Do you wish to cancel the Nuzlocke selection?")
        added.clear if clear
        next unless clear
      end
      break if cmd < 0 || cmd >= (commands.length - 1)
      if added.include?(modifiers[cmd])
        added.delete(modifiers[cmd])
      else
        added.push(modifiers[cmd])
      end
    end
    pbDisposeMessageWindow(msgwindow)
    $PokemonGlobal.nuzlockeRules = added if $PokemonGlobal
    EliteBattle.add_data(:NUZLOCKE, :RULES, added)
    msg = _INTL("Your selected Nuzlocke rules have been applied.")
    msg = _INTL("No Nuzlocke rules have been applied.") if added.length < 1
    msg = _INTL("Your selection has been cancelled.") if cmd < 0
    pbMessage(msg)
    Input.update
    return added.length > 0
  end

  def self.resetNuzlocke
    EliteBattle.reset(:nuzlocke)
    if $PokemonGlobal
      $PokemonGlobal.qNuzlocke = nil
      $PokemonGlobal.nuzlockeData = nil
      $PokemonGlobal.isNuzlocke = nil
      $PokemonGlobal.nuzlockeRules = nil
    end
  end

  #-------------------------------------------------------------------------
  # Boss battle helpers
  #-------------------------------------------------------------------------
  def self.generateWild(data)
    species = hash_get(data, :species)
    level   = hash_get(data, :level)
    boss    = hash_get(data, :bossboost)
    EliteBattle.log.error("No species defined for Pokemon!") if !species
    EliteBattle.log.error("No level defined for Pokemon!") if !level
    EliteBattle.log.error("Invalid species constant!") if species.nil?
    species = randomizeSpecies(species, true)
    genwildpoke = pbGenerateWildPokemon(species, level)

    genwildpoke.shiny = true if hash_get(data, :shiny) || hash_get(data, :super_shiny) || hash_get(data, :superShiny)
    if genwildpoke.respond_to?(:super_shiny=) && (hash_get(data, :super_shiny) || hash_get(data, :superShiny))
      genwildpoke.super_shiny = true
    end
    if hash_get(data, :ev).is_a?(Array) || hash_get(data, :ev).is_a?(Hash) || hash_get(data, :ev).is_a?(Integer)
      genwildpoke.ev = hash_get(data, :ev) if genwildpoke.respond_to?(:ev=)
    end
    if hash_get(data, :iv).is_a?(Array) || hash_get(data, :iv).is_a?(Hash) || hash_get(data, :iv).is_a?(Integer)
      genwildpoke.iv = hash_get(data, :iv) if genwildpoke.respond_to?(:iv=)
    end
    genwildpoke.ability = hash_get(data, :ability) if hash_get(data, :ability)
    genwildpoke.calc_stats
    apply_boss_boost(genwildpoke, boss) if boss
    genwildpoke.gender = hash_get(data, :gender) if hash_get(data, :gender)
    genwildpoke.nature = hash_get(data, :nature) if hash_get(data, :nature)
    genwildpoke.givePokerus if hash_get(data, :pokerus)
    genwildpoke.item = hash_get(data, :item) if hash_get(data, :item)
    genwildpoke.forced_form = hash_get(data, :form) if hash_get(data, :form)
    genwildpoke.reset_moves

    if hash_get(data, :moves).is_a?(Array)
      genwildpoke.moves.clear
      hash_get(data, :moves).each do |move|
        genwildpoke.learn_move(move)
      end
    end
    if hash_get(data, :ribbons).is_a?(Array)
      hash_get(data, :ribbons).each do |ribbon|
        genwildpoke.giveRibbon(ribbon)
      end
    end
    return genwildpoke
  end

  def self.wildBattle(data, partysize = 1, canEscape = true, canLose = false, playersize = 1)
    outcomeVar = $game_temp.battle_rules["outcomeVar"] || 1
    outcomeVar = data[:variable] if data.is_a?(Hash) && data.key?(:variable)
    canLose    = $game_temp.battle_rules["canLose"] || canLose
    genwildpoke = data.is_a?(Pokemon) ? data : self.generateWild(data)
    handled = [nil]
    EventHandlers.trigger(:on_calling_wild_battle, genwildpoke.species, genwildpoke.level, handled)
    return handled[0] if handled[0] != nil
    if $player.able_pokemon_count == 0 || ($DEBUG && Input.press?(Input::CTRL))
      pbMessage(_INTL("SKIPPING BATTLE...")) if $player.pokemon_count > 0
      pbSet(outcomeVar, 1)
      $game_temp.clear_battle_rules
      $PokemonGlobal.nextBattleBGM       = nil
      $PokemonGlobal.nextBattleVictoryBGM       = nil
      $PokemonGlobal.nextBattleCaptureME = nil
      $PokemonGlobal.nextBattleBack      = nil
      return true
    end
    EventHandlers.trigger(:on_start_battle)
    foeParty = [genwildpoke]
    playerTrainers    = [$player]
    playerParty       = $player.party
    playerPartyStarts = [0]
    room_for_partner = (foeParty.length > 1)
    if !room_for_partner && $game_temp.battle_rules["size"] && !["single", "1v1", "1v2", "1v3"].include?($game_temp.battle_rules["size"])
      room_for_partner = true
    end
    if $PokemonGlobal.partner && !$game_temp.battle_rules["noPartner"] && room_for_partner
      ally = NPCTrainer.new($PokemonGlobal.partner[1], $PokemonGlobal.partner[0])
      ally.id    = $PokemonGlobal.partner[2]
      ally.party = $PokemonGlobal.partner[3]
      playerTrainers.push(ally)
      playerParty = []
      $player.party.each { |pkmn| playerParty.push(pkmn) }
      playerPartyStarts.push(playerParty.length)
      ally.party.each { |pkmn| playerParty.push(pkmn) }
      setBattleRule("double") if !$game_temp.battle_rules["size"]
    end
    EliteBattle.set(:wildSpecies, genwildpoke.species)
    EliteBattle.set(:wildLevel, genwildpoke.level)
    EliteBattle.set(:wildForm, genwildpoke.form)
    EliteBattle.set(:setBoss, true) if data.is_a?(Hash) && data[:setBoss]

    speech = EliteBattle.get_data(genwildpoke.species, :Species, :BATTLESCRIPT, (genwildpoke.form rescue 0))
    EliteBattle.set(:nextBattleScript, (speech.is_a?(Hash) ? speech : speech.to_sym)) if !speech.nil?

    if $game_temp.battle_rules
      setBattleRule(sprintf("%dv%d", partysize, playersize)) if !$game_temp.battle_rules["size"]
      setBattleRule(canLose ? "canLose" : "cannotLose") if !$game_temp.battle_rules.has_key?("canLose", "cannotLose")
      setBattleRule(canEscape ? "canRun" : "cannotRun") if !$game_temp.battle_rules.has_key?("canRun", "cannotRun")
    end
    scene = pbNewBattleScene
    battle = Battle.new(scene, playerParty, foeParty, playerTrainers, nil)
    battle.party1starts = playerPartyStarts
    pbPrepareBattle(battle)
    $game_temp.clear_battle_rules
    decision = 0
    pbBattleAnimation(pbGetWildBattleBGM(foeParty), (foeParty.length == 1) ? 0 : 2, foeParty) {
      pbSceneStandby {
        decision = battle.pbStartBattle
      }
      BattleCreationHelperMethods.after_battle(decision, canLose)
    }
    Input.update
    pbSet(outcomeVar, decision)
    EventHandlers.trigger(:on_wild_battle_end, genwildpoke.species, genwildpoke.level, decision)
    return (decision != 2 && decision != 5)
  end

  def self.bossBattle(species, level, partysize = 2, cancatch = false, options = {})
    data = {
      :species   => randomizeSpecies(species, true),
      :level     => level,
      :iv        => { :HP => 31, :ATTACK => 31, :DEFENSE => 31, :SPECIAL_ATTACK => 31, :SPECIAL_DEFENSE => 31, :SPEED => 31 },
      :bossboost => { :HP => 1.75, :ATTACK => 1.25, :DEFENSE => 1.25, :SPECIAL_ATTACK => 1.25, :SPECIAL_DEFENSE => 1.25, :SPEED => 1.25 },
      :setBoss   => true
    }
    options.each { |key, val| data[key] = val.clone rescue val }
    setBattleRule("nevercapture") if !cancatch && defined?(setBattleRule)
    partysize = 3 if partysize > 3
    partysize = 1 if partysize < 1
    return self.wildBattle(data, partysize, false, false)
  end

  #-------------------------------------------------------------------------
  # Internal helpers
  #-------------------------------------------------------------------------
  def self.hash_get(hash, key)
    return nil if !hash.is_a?(Hash)
    return hash[key] if hash.key?(key)
    k = key.to_s
    return hash[k] if hash.key?(k)
    return hash[k.to_sym] if hash.key?(k.to_sym)
    return nil
  end

  def self.apply_boss_boost(pkmn, bossboost)
    return if !pkmn || bossboost.nil?
    return if !bossboost.is_a?(Hash)
    stats = {
      :HP => pkmn.totalhp,
      :ATTACK => pkmn.attack,
      :DEFENSE => pkmn.defense,
      :SPECIAL_ATTACK => pkmn.spatk,
      :SPECIAL_DEFENSE => pkmn.spdef,
      :SPEED => pkmn.speed
    }
    stats.each do |stat, base|
      mult = bossboost[stat] || bossboost[stat.to_s] || 1.0
      stats[stat] = (base * mult).round
    end
    pkmn.instance_variable_set(:@totalhp, stats[:HP])
    pkmn.instance_variable_set(:@attack, stats[:ATTACK])
    pkmn.instance_variable_set(:@defense, stats[:DEFENSE])
    pkmn.instance_variable_set(:@spatk, stats[:SPECIAL_ATTACK])
    pkmn.instance_variable_set(:@spdef, stats[:SPECIAL_DEFENSE])
    pkmn.instance_variable_set(:@speed, stats[:SPEED])
    pkmn.hp = [pkmn.hp, pkmn.totalhp].min
  end
end

#===============================================================================
# Randomizer helpers and hooks
#===============================================================================
def randomizeSpecies(species, static = false, gift = false)
  return species if !EliteBattle.get(:randomizer)
  pokemon = nil
  if species.is_a?(Pokemon)
    pokemon = species.clone
    species = pokemon.species
  end
  excl = EliteBattle.get_data(:RANDOMIZER, :Metrics, :EXCLUSIONS_SPECIES)
  if excl.is_a?(Array)
    excl.each { |ent| return (pokemon.nil? ? species : pokemon) if species == ent }
  end
  species = EliteBattle.getRandomizedData(species, :STATIC, species) if static
  species = EliteBattle.getRandomizedData(species, :GIFTS, species) if gift
  if !pokemon.nil?
    pokemon.species = species
    pokemon.calc_stats
    if pokemon.respond_to?(:reset_moves)
      pokemon.reset_moves
    else
      pokemon.resetMoves if pokemon.respond_to?(:resetMoves)
    end
  end
  return pokemon.nil? ? species : pokemon
end

def randomizeItem(item)
  return item if !EliteBattle.get(:randomizer)
  return item if GameData::Item.get(item).is_key_item?
  excl = EliteBattle.get_data(:RANDOMIZER, :Metrics, :EXCLUSIONS_ITEMS)
  if excl.is_a?(Array)
    excl.each { |ent| return item if item == ent }
  end
  return EliteBattle.getRandomizedData(item, :ITEMS, item)
end

alias pbBattleOnStepTaken_ebdx_port pbBattleOnStepTaken unless defined?(pbBattleOnStepTaken_ebdx_port)
def pbBattleOnStepTaken(*args)
  $nonStaticEncounter = true
  pbBattleOnStepTaken_ebdx_port(*args)
  $nonStaticEncounter = false
end

class WildBattle
  class << self
    alias pbWildBattle_ebdx_port start unless defined?(pbWildBattle_ebdx_port)
  end

  def self.start(*args, can_override: false)
    if args.length <= 2
      [0].each { |i| args[i] = randomizeSpecies(args[i], !$nonStaticEncounter) }
    elsif args.length <= 4
      [0, 2].each { |i| args[i] = randomizeSpecies(args[i], !$nonStaticEncounter) }
    else
      [0, 2, 4].each { |i| args[i] = randomizeSpecies(args[i], !$nonStaticEncounter) }
    end
    return pbWildBattle_ebdx_port(*args, can_override: can_override)
  end
end

alias pbAddPokemon_ebdx_port pbAddPokemon unless defined?(pbAddPokemon_ebdx_port)
def pbAddPokemon(*args)
  args[0] = randomizeSpecies(args[0], false, true)
  return pbAddPokemon_ebdx_port(*args)
end

alias pbAddPokemonSilent_ebdx_port pbAddPokemonSilent unless defined?(pbAddPokemonSilent_ebdx_port)
def pbAddPokemonSilent(*args)
  args[0] = randomizeSpecies(args[0], false, true)
  return pbAddPokemonSilent_ebdx_port(*args)
end

alias pbItemBall_ebdx_port pbItemBall unless defined?(pbItemBall_ebdx_port)
def pbItemBall(*args)
  args[0] = randomizeItem(args[0])
  return pbItemBall_ebdx_port(*args)
end

alias pbReceiveItem_ebdx_port pbReceiveItem unless defined?(pbReceiveItem_ebdx_port)
def pbReceiveItem(*args)
  args[0] = randomizeItem(args[0])
  return pbReceiveItem_ebdx_port(*args)
end

class PokemonGlobalMetadata
  attr_accessor :randomizedData unless method_defined?(:randomizedData)
  attr_accessor :isRandomizer unless method_defined?(:isRandomizer)
  attr_accessor :randomizerRules unless method_defined?(:randomizerRules)
  attr_accessor :qNuzlocke unless method_defined?(:qNuzlocke)
  attr_accessor :nuzlockeData unless method_defined?(:nuzlockeData)
  attr_accessor :isNuzlocke unless method_defined?(:isNuzlocke)
  attr_accessor :nuzlockeRules unless method_defined?(:nuzlockeRules)
end

class PokemonLoadScreen
  alias pbStartLoadScreen_ebdx_port pbStartLoadScreen unless method_defined?(:pbStartLoadScreen_ebdx_port)
  def pbStartLoadScreen
    ret = pbStartLoadScreen_ebdx_port
    if $PokemonGlobal && $PokemonGlobal.isRandomizer
      EliteBattle.startRandomizer(true)
      EliteBattle.add_data(:RANDOMIZER, :RULES, $PokemonGlobal.randomizerRules) if !$PokemonGlobal.randomizerRules.nil?
    end
    if $PokemonGlobal && $PokemonGlobal.isNuzlocke
      EliteBattle.set(:nuzlocke, true)
      EliteBattle.add_data(:NUZLOCKE, :RULES, $PokemonGlobal.nuzlockeRules) if !$PokemonGlobal.nuzlockeRules.nil?
    end
    return ret
  end
end

alias pbLoadTrainer_ebdx_port pbLoadTrainer unless defined?(pbLoadTrainer_ebdx_port)
def pbLoadTrainer(tr_type, tr_name, tr_version = 0)
  trainer = pbLoadTrainer_ebdx_port(tr_type, tr_name, tr_version)
  return trainer if !trainer || !EliteBattle.randomizerOn?
  rules = EliteBattle.get_data(:RANDOMIZER, :Metrics, :RULES) || []
  return trainer if !rules.include?(:TRAINERS)
  tr_excl = EliteBattle.get_data(:RANDOMIZER, :Metrics, :EXCLUSIONS_TRAINERS)
  sp_excl = EliteBattle.get_data(:RANDOMIZER, :Metrics, :EXCLUSIONS_SPECIES)
  if tr_excl && trainer.respond_to?(:trainer_type)
    return trainer if tr_excl.include?(trainer.trainer_type)
  end
  trainer.party.each do |pkmn|
    next if sp_excl&.include?(pkmn.species)
    pkmn.species = EliteBattle.all_species.sample
    pkmn.calc_stats
    pkmn.reset_moves if pkmn.respond_to?(:reset_moves)
  end
  return trainer
end

module GameData
  class Encounter
    class << self
      alias get_ebdx_port get unless method_defined?(:get_ebdx_port)
    end
    def self.get(map_id, map_version = 0)
      validate map_id => Integer
      validate map_version => Integer
      trial_key = sprintf("%s_%d", map_id, map_version).to_sym
      key = (self::DATA.key?(trial_key)) ? trial_key : sprintf("%s_0", map_id).to_sym
      data = get_ebdx_port(map_id, map_version)
      return EliteBattle.getRandomizedData(data, :ENCOUNTERS, key)
    end
  end
end

#===============================================================================
# Nuzlocke hooks
#===============================================================================
class Pokemon
  attr_accessor :permaFaint unless method_defined?(:permaFaint)
  alias hpget_ebdx_port_nuzlocke hp unless method_defined?(:hpget_ebdx_port_nuzlocke)
  def hp
    return (self.permaFaint && EliteBattle.get(:nuzlocke)) ? 0 : hpget_ebdx_port_nuzlocke
  end

  alias hpset_ebdx_port_nuzlocke hp= unless method_defined?(:hpset_ebdx_port_nuzlocke)
  def hp=(val)
    data = EliteBattle.get_data(:NUZLOCKE, :Metrics, :RULES) || []
    perma = data.include?(:PERMADEATH) || data.include?(:PEMADEATH)
    self.permaFaint = true if EliteBattle.get(:nuzlocke) && (data.include?(:NOREVIVE) || perma) && val <= 0
    hpset_ebdx_port_nuzlocke((self.permaFaint && EliteBattle.get(:nuzlocke)) ? 0 : val)
  end
end

class Battle::Battler
  alias hpget_ebdx_port_nuzlocke hp unless method_defined?(:hpget_ebdx_port_nuzlocke)
  def hp
    return (@pokemon && @pokemon.permaFaint && EliteBattle.get(:nuzlocke)) ? 0 : hpget_ebdx_port_nuzlocke
  end

  alias hpset_ebdx_port_nuzlocke hp= unless method_defined?(:hpset_ebdx_port_nuzlocke)
  def hp=(val)
    data = EliteBattle.get_data(:NUZLOCKE, :Metrics, :RULES) || []
    perma = data.include?(:PERMADEATH) || data.include?(:PEMADEATH)
    @pokemon.permaFaint = true if EliteBattle.get(:nuzlocke) && (data.include?(:NOREVIVE) || perma) && val <= 0
    hpset_ebdx_port_nuzlocke((@pokemon.permaFaint && EliteBattle.get(:nuzlocke)) ? 0 : val)
  end
end

class Battle::Scene
  attr_accessor :firstFainted unless method_defined?(:firstFainted)
  alias pbFaintBattler_ebdx_port_nuzlocke pbFaintBattler unless method_defined?(:pbFaintBattler_ebdx_port_nuzlocke)
  def pbFaintBattler(battler)
    if !@battle.opponent && battler.opposes?
      data = EliteBattle.get_data(:NUZLOCKE, :Metrics, :RULES) || []
      unless (@battle.pbParty(1).length == 2 && !self.firstFainted)
        if EliteBattle.get(:nuzlocke) && data.include?(:ONEROUTE) && battler.index % 2 == 1
          evo = EliteBattle.checkEvoNuzlocke?(battler.pokemon.species) && data.include?(:DUPSCLAUSE)
          static = data.include?(:STATIC) && !$nonStaticEncounter
          shiny = data.include?(:SHINY) && battler.shiny?
          map = $PokemonGlobal.nuzlockeData[$game_map.map_id]
          $PokemonGlobal.nuzlockeData[$game_map.map_id] = true if map.nil? && !static && !evo && !shiny
        end
      end
      self.firstFainted = true
    end
    return pbFaintBattler_ebdx_port_nuzlocke(battler)
  end
end

class Battle
  alias pbEndOfBattle_ebdx_port_nuzlocke pbEndOfBattle unless method_defined?(:pbEndOfBattle_ebdx_port_nuzlocke)
  def pbEndOfBattle
    ret = pbEndOfBattle_ebdx_port_nuzlocke
    data = EliteBattle.get_data(:NUZLOCKE, :Metrics, :RULES) || []
    if EliteBattle.get(:nuzlocke) && data.include?(:PERMADEATH)
      (0...$player.party.length).each do |i|
        k = $player.party.length - 1 - i
        if $player.party[k].hp <= 0
          $bag.add($player.party[k].item, 1) if $player.party[k].item
          $player.party.delete_at(k)
          $game_temp.evolutionLevels.delete_at(k)
        end
      end
    end
    return ret
  end

  alias pbThrowPokeBall_ebdx_port_nuzlocke pbThrowPokeBall unless method_defined?(:pbThrowPokeBall_ebdx_port_nuzlocke)
  def pbThrowPokeBall(*args)
    data = EliteBattle.get_data(:NUZLOCKE, :Metrics, :RULES) || []
    if EliteBattle.get(:nuzlocke) && data.include?(:ONEROUTE)
      static = data.include?(:STATIC) && !$nonStaticEncounter
      shiny = data.include?(:SHINY) && @battlers[args[0]].shiny?
      map = $PokemonGlobal.nuzlockeData[$game_map.map_id]
      return pbDisplay(_INTL("Nuzlocke rules prevent you from catching a wild Pokemon on a map you already had an encounter on!")) if !map.nil? && !static && !shiny
    end
    pbThrowPokeBall_ebdx_port_nuzlocke(*args)
    if EliteBattle.get(:nuzlocke) && data.include?(:ONEROUTE) && @decision == 4
      $PokemonGlobal.nuzlockeData[$game_map.map_id] = true unless static || shiny
    end
  end

  alias pbRun_ebdx_port_nuzlocke pbRun unless method_defined?(:pbRun_ebdx_port_nuzlocke)
  def pbRun(*args)
    data = EliteBattle.get_data(:NUZLOCKE, :Metrics, :RULES) || []
    battler = nil
    (0...self.pbSideSize(1)).each do |i|
      if @battlers[i + 1] && @battlers[i + 1].hp > 0
        battler = @battlers[i + 1]
        break
      end
    end
    if EliteBattle.get(:nuzlocke) && data.include?(:ONEROUTE) && !self.opponent
      evo = battler.nil? ? false : EliteBattle.checkEvoNuzlocke?(battler.displaySpecies) && data.include?(:DUPSCLAUSE)
      static = data.include?(:STATIC) && !$nonStaticEncounter
      shiny = false
      eachOtherSideBattler(args[0]) { |b| shiny = true if data.include?(:SHINY) && b.shiny? }
      map = $PokemonGlobal.nuzlockeData[$game_map.map_id]
      $PokemonGlobal.nuzlockeData[$game_map.map_id] = true if map.nil? && !static && !evo && !shiny
    end
    return pbRun_ebdx_port_nuzlocke(*args)
  end
end

alias pbStartOver_ebdx_port_nuzlocke pbStartOver unless defined?(pbStartOver_ebdx_port_nuzlocke)
def pbStartOver(*args)
  if EliteBattle.get(:nuzlocke)
    pbMessage(_INTL("\\w[]\\wm\\c[8]\\l[3]All your Pokemon have fainted. You have lost the Nuzlocke challenge! The challenge will now be turned off."))
    EliteBattle.set(:nuzlocke, false)
    $PokemonGlobal.isNuzlocke = false if $PokemonGlobal
  end
  return pbStartOver_ebdx_port_nuzlocke(*args)
end

class PokemonBag
  alias add_ebdx_port_nuzlocke add unless method_defined?(:add_ebdx_port_nuzlocke)
  def add(*args)
    ret = add_ebdx_port_nuzlocke(*args)
    item = args[0]
    if $PokemonGlobal && $PokemonGlobal.qNuzlocke && GameData::Item.get(item).is_poke_ball?
      EliteBattle.set(:nuzlocke, true)
      EliteBattle.add_data(:NUZLOCKE, :RULES, $PokemonGlobal.nuzlockeRules) if !$PokemonGlobal.nuzlockeRules.nil?
      $PokemonGlobal.isNuzlocke = true
    end
    return ret
  end
end
