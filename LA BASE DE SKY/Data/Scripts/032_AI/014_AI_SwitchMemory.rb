#===============================================================================
# Battle-local memory of completed replacements, not commands or predictions.
#===============================================================================
module AISwitchMemory
  WINDOW_TURNS          = 4
  MAX_EVENTS_PER_SIDE   = 4
  HAZARD_SCORE_BONUS    = 4
  MIN_RECENT_EXITS      = 2
  SPIKES_MAX_LAYERS     = 3
  TOXIC_SPIKES_MAX_LAYERS = 2
end

class Battle
  def ai_switch_memory_snapshot(idxBattler, idxParty, randomReplacement)
    return nil if pbSideSize(0) != 1 || pbSideSize(1) != 1
    battler = @battlers[idxBattler]
    return nil if !battler || !battler.pokemon || idxParty < 0
    return nil if !pbParty(idxBattler)[idxParty] || battler.pokemonIndex == idxParty
    return {
      :turn => @turnCount, :side => idxBattler & 1,
      :outgoing_party => battler.pokemonIndex, :incoming_party => idxParty,
      :outgoing_fainted => battler.fainted?, :random_replacement => randomReplacement
    }
  end

  def ai_switch_memory_record(event, idxBattler)
    return if !event || pbSideSize(0) != 1 || pbSideSize(1) != 1
    battler = @battlers[idxBattler]
    return if !battler || !battler.pokemon || battler.pokemonIndex != event[:incoming_party]
    @ai_switch_memory ||= [[], []]
    history = @ai_switch_memory[event[:side]]
    history.reject! { |entry| @turnCount - entry[:turn] >= AISwitchMemory::WINDOW_TURNS }
    history.push(event)
    history.shift while history.length > AISwitchMemory::MAX_EVENTS_PER_SIDE
  end

  def ai_switch_memory_recent_events(side)
    return [] if !@ai_switch_memory
    return @ai_switch_memory[side].select do |event|
      age = @turnCount - event[:turn]
      age >= 0 && age < AISwitchMemory::WINDOW_TURNS
    end
  end
end

class Battle::AI
  def switch_memory_hazard_score(score, move, user)
    return score if score <= MOVE_USELESS_SCORE
    return score if !@trainer || !@trainer.high_skill? || !@trainer.has_skill_flag?("HPAware")
    return score if @battle.pbSideSize(0) != 1 || @battle.pbSideSize(1) != 1
    return score if !user || user.fainted?
    effects = user.pbOpposingSide.effects
    return score if !switch_memory_hazard_has_room?(move.function_code, effects)
    events = @battle.ai_switch_memory_recent_events(user.idxOpposingSide)
    # ponytail: observed traffic includes automatic non-random exits, not intent;
    # explicit execution provenance would be needed to distinguish voluntary pivots.
    exits = events.count { |event| !event[:outgoing_fainted] && !event[:random_replacement] }
    return score if exits < AISwitchMemory::MIN_RECENT_EXITS
    observed_indices = events.flat_map { |event| [event[:outgoing_party], event[:incoming_party]] }.uniq
    party = @battle.pbParty(user.idxOpposingSide)
    if move.function_code == "AddToxicSpikesToFoeSide"
      # A grounded Poison type absorbs Toxic Spikes even when it has Boots.
      return score if observed_indices.any? do |idxParty|
        pkmn = party[idxParty]
        pkmn && pkmn.able? && pkmn.hasType?(:POISON) && !pokemon_airborne?(pkmn)
      end
    end
    affected_reserve = observed_indices.any? do |idxParty|
      next false if !@battle.pbCanSwitchIn?(user.idxOpposingSide, idxParty)
      next switch_memory_hazard_affects?(move.function_code, party[idxParty], effects)
    end
    return score unless affected_reserve
    PBDebug.log_ai_decision("Memoria de cambios: salidas recientes #{exits}, hazard #{move.id}, ajuste +#{AISwitchMemory::HAZARD_SCORE_BONUS}.")
    return score + AISwitchMemory::HAZARD_SCORE_BONUS
  end

  def switch_memory_hazard_has_room?(function_code, effects)
    case function_code
    when "AddSpikesToFoeSide"
      return effects[PBEffects::Spikes] < AISwitchMemory::SPIKES_MAX_LAYERS
    when "AddToxicSpikesToFoeSide"
      return effects[PBEffects::ToxicSpikes] < AISwitchMemory::TOXIC_SPIKES_MAX_LAYERS
    when "AddStealthRocksToFoeSide"
      return !effects[PBEffects::StealthRock] && GameData::Type.exists?(:ROCK)
    when "AddStickyWebToFoeSide"
      return !effects[PBEffects::StickyWeb]
    end
    return false
  end

  def switch_memory_hazard_affects?(function_code, pkmn, effects)
    return false if !pkmn || !pkmn.able?
    side = @battle.pbParty(0).any? { |member| member.equal?(pkmn) } ? 0 : 1
    return false if pkmn.hasItem?(:HEAVYDUTYBOOTS) && ai_improvements_pokemon_item_active?(side, pkmn)
    case function_code
    when "AddStealthRocksToFoeSide"
      return false if pkmn.hasAbility?(:MAGICGUARD)
      return !Effectiveness.ineffective?(Effectiveness.calculate(:ROCK, *pkmn.types))
    when "AddSpikesToFoeSide"
      return !pkmn.hasAbility?(:MAGICGUARD) && !pokemon_airborne?(pkmn)
    when "AddToxicSpikesToFoeSide"
      return pkmn.status == :NONE && !pokemon_airborne?(pkmn) && pokemon_can_be_poisoned?(pkmn)
    when "AddStickyWebToFoeSide"
      return false if pokemon_airborne?(pkmn) || effects[PBEffects::Mist] > 0
      return false if pkmn.hasAbility?(:CONTRARY) || pkmn.hasAbility?(:CLEARBODY) ||
                      pkmn.hasAbility?(:WHITESMOKE) || pkmn.hasAbility?(:FULLMETALBODY)
      return false if pkmn.hasAbility?(:FLOWERVEIL) && pkmn.hasType?(:GRASS)
      return true
    end
    return false
  end
end

Battle::AI::Handlers::GeneralMoveScore.add(:hazards_vs_observed_switch_traffic,
  proc { |score, move, user, ai, battle|
    next ai.switch_memory_hazard_score(score, move, user)
  }
)
