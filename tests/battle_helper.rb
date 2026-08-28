# Scripted headless battles.
#
# Battle::DebugSceneNoVisuals already runs a fight with no graphics, but it picks
# its moves at random — fine for the Battle Frontier's team generator, useless
# for a test. TestScene follows a script instead, records every message the
# battle displays, and can stop the fight after a fixed number of rounds.

require_relative "harness"

# Battle and Battle::DebugSceneNoVisuals are defined by the engine scripts, so
# the engine has to be up before this file can subclass anything.
TestGame.boot

module BattleTest
  # Thrown to leave pbStartBattle once the requested rounds have been played.
  TURN_LIMIT = :battle_turn_limit

  #=============================================================================
  # A battle scene that plays the moves it is told to play.
  #=============================================================================
  class TestScene < Battle::DebugSceneNoVisuals
    # @return [Array<String>] every message the battle displayed, in order
    attr_reader :messages

    # @return [Integer] rounds begun so far
    attr_reader :round

    # @param moves [Hash{Integer => Array<Symbol>}] move to use per battler index
    #   and round, e.g. { 0 => [:THUNDERBOLT, :TACKLE] }. The last entry repeats
    #   once the list runs out. Battlers with no script fall back to their first
    #   usable move.
    # @param max_rounds [Integer, nil] stop the battle when this many rounds have
    #   been played; nil runs it to its natural end.
    # @param confirm [Boolean] answer to every yes/no prompt the battle raises
    def initialize(moves: {}, max_rounds: nil, confirm: false)
      super(false)
      @moves      = moves
      @max_rounds = max_rounds
      @confirm    = confirm
      @messages   = []
      @round      = 0
    end

    def pbBeginCommandPhase
      throw(TURN_LIMIT) if @max_rounds && @round >= @max_rounds
      @round += 1
    end

    def pbDisplayMessage(msg, brief = false)
      @messages << msg
    end
    alias pbDisplay pbDisplayMessage

    def pbDisplayPausedMessage(msg)
      @messages << msg
    end

    def pbDisplayConfirmMessage(msg)
      @messages << msg
      return @confirm
    end

    def pbShowCommands(msg, commands, defaultValue)
      @messages << msg
      return 0
    end

    # Always Fight; scripted battles never use the bag or run.
    def pbCommandMenu(idxBattler, firstAction)
      return 0
    end

    # The block vets the chosen index (PP, Disable, Torment...) and answers false
    # when the move cannot be used, so the scripted move is tried first and the
    # rest serve as fallback.
    def pbFightMenu(idxBattler, megaEvoPossible = false)
      battler = @battle.battlers[idxBattler]
      preferred = scripted_move_index(battler)
      order = ([preferred] + (0...battler.moves.length).to_a).compact.uniq
      order.each { |index| return if yield index }
    end

    # Deterministic, unlike the parent's random pick.
    def pbChooseTarget(idxBattler, target_data, visibleSprites = nil)
      targets = @battle.allOtherSideBattlers(idxBattler).map { |b| b.index }
      return -1 if targets.empty?
      return targets.first
    end

    def pbPartyScreen(idxBattler, canCancel = false)
      replacements = []
      @battle.eachInTeamFromBattlerIndex(idxBattler) do |_battler, idxParty|
        replacements.push(idxParty) if !@battle.pbFindBattler(idxParty, idxBattler)
      end
      return if replacements.empty?
      replacements.each { |idxParty| return if yield idxParty, self }
    end

    private

    def scripted_move_index(battler)
      script = @moves[battler.index]
      return nil if script.nil? || script.empty?
      wanted = script[[@round - 1, script.length - 1].min]
      index = battler.moves.index { |move| move&.id == wanted }
      if index.nil?
        raise ArgumentError, "#{battler.pbThis} no conoce #{wanted}; " \
                             "conoce #{battler.moves.map { |m| m&.id }.compact.inspect}"
      end
      return index
    end
  end

  #=============================================================================
  # Helpers available inside test cases
  #=============================================================================

  # Builds a Pokémon with every random attribute pinned down, so damage numbers
  # are reproducible. Anything left at its default is deliberate: max IVs, no
  # EVs, neutral nature, first ability, male.
  #
  # @return [Pokemon]
  def mon(species, level: 50, moves: nil, ability: nil, item: nil,
          nature: :HARDY, ivs: Pokemon::IV_STAT_LIMIT, evs: 0, gender: 0,
          happiness: 70, hp: nil, status: nil)
    pkmn = Pokemon.new(species, level, $player, moves.nil?)
    GameData::Stat.each_main do |stat|
      pkmn.iv[stat.id] = ivs
      pkmn.ev[stat.id] = evs
    end
    pkmn.nature    = nature
    pkmn.gender    = gender
    pkmn.shiny     = false
    pkmn.happiness = happiness
    pkmn.item      = item
    # Pokemon.new was told to skip its level-up moveset, so the list starts empty.
    moves&.each { |move| pkmn.learn_move(move) }
    set_ability(pkmn, ability) if ability
    pkmn.calc_stats
    pkmn.heal
    pkmn.hp = hp if hp
    pkmn.status = status if status
    return pkmn
  end

  # Runs a battle and hands back the Battle object for inspection.
  #
  # @param player [Array<Pokemon>] the player's party
  # @param foe [Array<Pokemon>] the opponent's party
  # @param moves [Hash{Integer => Array<Symbol>}] see TestScene#initialize
  # @param rounds [Integer, nil] stop after this many rounds (nil = fight it out)
  # @return [Battle]
  def run_battle(player:, foe:, moves: {}, rounds: 1, seed: nil, confirm: false,
                 doubles: false, internal: false)
    srand(seed) if seed
    $player.party = player
    opponent = NPCTrainer.new("Rival", :BUGCATCHER)
    opponent.party = foe

    scene  = TestScene.new(moves: moves, max_rounds: rounds, confirm: confirm)
    battle = Battle.new(scene, player, foe, $player, opponent)
    battle.debug         = true
    battle.controlPlayer = false   # so TestScene, not the AI, picks the player's moves
    battle.internalBattle = internal
    battle.setBattleMode("double") if doubles

    catch(BattleTest::TURN_LIMIT) { battle.pbStartBattle }
    return battle
  end

  # The battler currently in the given slot (0 = player's lead, 1 = foe's lead).
  def battler(battle, index) = battle.battlers[index]

  def damage_taken(pkmn) = pkmn.totalhp - pkmn.hp

  def assert_damage_between(low, high, pkmn, msg = nil)
    taken = damage_taken(pkmn)
    assert taken.between?(low, high),
           msg || "#{pkmn.name} recibió #{taken} de daño, se esperaba entre #{low} y #{high}"
  end

  def assert_message_matching(pattern, scene_or_battle, msg = nil)
    messages = messages_of(scene_or_battle)
    assert messages.any? { |m| m.match?(pattern) },
           msg || "ningún mensaje coincide con #{pattern.inspect}. Mensajes: #{messages.inspect}"
  end

  def refute_message_matching(pattern, scene_or_battle, msg = nil)
    messages = messages_of(scene_or_battle)
    refute messages.any? { |m| m.match?(pattern) },
           msg || "un mensaje coincidió con #{pattern.inspect} y no debía"
  end

  private

  def messages_of(subject)
    subject.is_a?(TestScene) ? subject.messages : subject.scene.messages
  end

  # Abilities are stored as an index into the species' ability list, so the
  # wanted one has to be found there first.
  def set_ability(pkmn, ability)
    ability = GameData::Ability.get(ability).id
    index = pkmn.getAbilityList.find { |entry| entry[0] == ability }
    raise ArgumentError, "#{pkmn.speciesName} no puede tener #{ability}" if index.nil?
    pkmn.ability_index = index[1]
  end
end

#===============================================================================
# Base class for battle test cases.
#===============================================================================
class BattleTestCase < EngineTest
  include BattleTest
end
