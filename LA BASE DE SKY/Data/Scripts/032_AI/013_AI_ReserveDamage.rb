#===============================================================================
# Immediate incoming damage for ordinary single-battle replacement candidates.
#===============================================================================
module AIReserveDamage
  FRAGILITY_MAX_PENALTY = 20
  FUNCTIONS = %w[None BurnTarget ParalyzeTarget PoisonTarget BadPoisonTarget
                 FreezeTarget FlinchTarget].freeze
  UNSAFE_ABILITIES = [:TERASHIFT, :TERASHELL, :ZENMODE, :FORECAST, :FLOWERGIFT,
                     :SCHOOLING, :SHIELDSDOWN, :STANCECHANGE, :DISGUISE, :ICEFACE,
                     :POWERCONSTRUCT, :ZEROTOHERO, :HUNGERSWITCH, :COMMANDER,
                     :PROTOSYNTHESIS, :QUARKDRIVE, :PRISMARMOR, :PIERCINGDRILL].freeze
  BATTLE_ARRAYS = [:abilitiesUsedPerSwitchIn, :abilitiesUsedOnce, :initialItems,
                  :recycleItems, :belch, :corrosiveGas, :usedInBattle,
                  :hitsTakenCounts, :sideFaintCounts, :sideSizes,
                  :party1starts, :party2starts, :party1order, :party2order].freeze

  def self.copy_data(value)
    Marshal.load(Marshal.dump(value))
  end

  def self.copy_pokemon(pkmn)
    return nil if !pkmn
    # Pokémon are save data: include owner, ribbons, fused Pokémon and shadow
    # move/state arrays, not just IVs/EVs and the currently visible moves.
    copy_data(pkmn)
  end

  def self.entry_ability?(ability)
    Battle::AbilityEffects::OnSwitchIn[ability] ||
      Battle::AbilityEffects::OnSwitchInDelayed[ability] ||
      Battle::AbilityEffects::OnSwitchInNeutralizingGas[ability] ||
      Battle::AbilityEffects::OnSwitchInUnnerve[ability] ||
      Battle::AbilityEffects::Trace[ability] || Battle::AbilityEffects::StatusCure[ability]
  end

  def self.exit_ability?(ability)
    [:PRIMORDIALSEA, :DESOLATELAND, :DELTASTREAM].include?(ability) ||
      Battle::AbilityEffects::OnSwitchOut[ability] ||
      Battle::AbilityEffects::OnSwitchInNeutralizingGas[ability] ||
      Battle::AbilityEffects::OnSwitchInUnnerve[ability]
  end

  def self.copy_effects(object)
    copy = object.dup
    copy.instance_variable_set(:@effects, copy_data(object.effects))
    copy
  end

  def self.copy_battler(battler, battle)
    return nil if !battler
    copy = copy_effects(battler)
    copy.instance_variable_set(:@battle, battle)
    copy.instance_variable_set(:@pokemon, battle.pbParty(battler.index)[battler.pokemonIndex])
    copy.instance_variable_set(:@stages, battler.stages.dup)
    copy.instance_variable_set(:@damageState, battler.damageState.dup)
    copy.instance_variable_set(:@stagesChangeRecord, copy_data(battler.stagesChangeRecord))
    copy.instance_variable_set(:@baseMoves, [])
    copy.instance_variable_set(:@moves, battler.moves.map do |move|
      next nil if !move
      cloned = move.dup
      cloned.instance_variable_set(:@battle, battle)
      cloned.instance_variable_set(:@realMove, move.realMove&.dup)
      cloned
    end)
    copy
  end
end

class Battle::AI
  def ai_improvements_pokemon_item_active?(side, pkmn)
    active = @battle.allBattlers.find { |b| b.pokemon.equal?(pkmn) }
    return active.itemActive? if active
    return false if @battle.field.effects[PBEffects::MagicRoom] > 0
    party_index = @battle.pbParty(side).index { |member| member.equal?(pkmn) }
    return false if party_index && @battle.corrosiveGas[side & 1][party_index]
    return false if pkmn.hasAbility?(:KLUTZ) && !@battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)
    return true
  end

  # nil means unsupported, not zero damage. Raw damage and reliability belong
  # to the maximum expected-damage candidate (ties prefer raw damage).
  def ai_improvements_reserve_threat(idxBattler, pkmn, entry_hazard_damage)
    return nil if !@trainer || !@trainer.high_skill? || !@trainer.has_skill_flag?("HPAware")
    return nil if !@battle.singleBattle? || !idxBattler.is_a?(Integer) || !idxBattler.between?(0, 1)
    return nil if !$game_temp || !$game_temp.in_battle || !pkmn
    return nil unless entry_hazard_damage.is_a?(Integer) || entry_hazard_damage.is_a?(Float)
    return nil if !entry_hazard_damage.finite? || entry_hazard_damage < 0
    # pbReduceHP rounds damage; no hazard callbacks are run here.
    entry_hazard_damage = [entry_hazard_damage.round, 1].max if entry_hazard_damage > 0
    active = @battle.battlers[idxBattler]
    foe = @battle.battlers[idxBattler ^ 1]
    return nil if !active || !foe || foe.fainted? || !active.pokemon
    party_index = @battle.pbParty(idxBattler).index { |member| member.equal?(pkmn) }
    return nil if !party_index
    staying = active.pokemon.equal?(pkmn)
    return nil if staying && entry_hazard_damage != 0
    candidate = staying ? pkmn : AIReserveDamage.copy_pokemon(pkmn)
    return nil if candidate.egg? || candidate.hp <= entry_hazard_damage
    return nil if [active, foe].any? do |b|
      b.usingMultiTurnAttack? || b.effects[PBEffects::SkyDrop] >= 0 ||
        b.effects[PBEffects::CommandedBy] >= 0 || b.effects[PBEffects::Commanding] >= 0 ||
        AIReserveDamage::UNSAFE_ABILITIES.include?(b.ability_id)
    end
    return nil if foe.hasActiveItem?(:ZOOMLENS)
    return nil if foe.hasActiveAbility?(:RIVALRY) &&
                  [foe.pokemon, pkmn].any? { |p| p.instance_variable_get(:@gender).nil? }
    if !staying
      # Reject registered entry/exit effects even if currently suppressed. This
      # lookup checks presence; it does not trigger the ability's handler.
      return nil if AIReserveDamage.entry_ability?(candidate.ability_id) ||
                    AIReserveDamage.exit_ability?(active.ability_id)
      return nil if MultipleForms.hasFunction?(active.pokemon, "getFormOnLeavingBattle") ||
                    MultipleForms.hasFunction?(active.pokemon, "changePokemonOnLeavingBattle")
      return nil if AIReserveDamage::UNSAFE_ABILITIES.include?(candidate.ability_id)
      return nil if MultipleForms.hasFunction?(candidate, "getFormOnEnteringBattle")
      effects = @battle.sides[idxBattler & 1].effects
      # ponytail: no entry effects or Baton Pass prediction; add an explicit entry
      # model before supporting poison/web, Healing Wish or entry-dependent forms.
      boots_active = candidate.hasItem?(:HEAVYDUTYBOOTS) && ai_improvements_pokemon_item_active?(idxBattler, pkmn)
      return nil if !boots_active &&
                    (effects[PBEffects::ToxicSpikes] > 0 || effects[PBEffects::StickyWeb])
      position = @battle.positions[idxBattler].effects
      return nil if position[PBEffects::HealingWish] || position[PBEffects::LunarDance]
    end
    evaluation_ai = staying ? self : ai_reserve_damage_context(idxBattler, party_index, entry_hazard_damage)
    return nil if !evaluation_ai.battlers
    attacker, defender = evaluation_ai.battlers[idxBattler ^ 1], evaluation_ai.battlers[idxBattler]
    return nil if !attacker || !defender
    return nil if staying && (!attacker.battler.equal?(foe) || !defender.battler.equal?(active))
    # Native rough_damage skips resistance berries; do not turn that into a KO.
    return nil if defender.item_active? && defender.item&.is_berry?
    return nil if attacker.has_active_item?(:ZOOMLENS)
    if !staying && defender.item_active?
      return nil if Battle::ItemEffects::OnTerrainChange[defender.battler.item_id] ||
                    Battle::ItemEffects::OnSwitchInDelayed[defender.battler.item_id] ||
                    Battle::ItemEffects::OnTrickRoomStarted[defender.battler.item_id]
    end
    return nil if defender.effects[PBEffects::Protect] || defender.effects[PBEffects::KingsShield] ||
                  defender.effects[PBEffects::BanefulBunker] || defender.effects[PBEffects::Obstruct] ||
                  defender.effects[PBEffects::SpikyShield] || defender.effects[PBEffects::SilkTrap] ||
                  defender.effects[PBEffects::BurningBulwark]
    side_effects = defender.pbOwnSide.effects
    return nil if side_effects[PBEffects::MatBlock] || side_effects[PBEffects::WideGuard] ||
                  side_effects[PBEffects::QuickGuard]
    selectable = evaluation_ai.ai_reserve_damage_selectable_moves(attacker)
    return nil if selectable.any? do |move|
      move.callsAnotherMove? || (move.damagingMove? &&
        (!AIReserveDamage::FUNCTIONS.include?(move.function_code) || move.power <= 1 ||
         !GameData::Move.try_get(move.id)))
    end
    result = { :damage => 0, :expected => 0.0, :move => nil, :reliable_ko => false }
    return result if !attacker.can_attack?
    if staying
      # pbCanChooseMove? clears stale ChoiceBand even with showMessages=false.
      choice_lock = attacker.effects[PBEffects::ChoiceBand]
      begin
        if selectable.empty?
          ai_improvements_with_move_context(attacker, defender) do
            @battle.moldBreaker = attacker.has_mold_breaker?
            @move.set_up(Battle::Move::Struggle.new(@battle, nil))
            ai_reserve_damage_record(result, @move, attacker, defender)
          end
        else
          ai_improvements_best_damage(attacker, defender) do |move|
            ai_reserve_damage_record(result, move, attacker, defender)
            next false
          end
        end
      ensure
        attacker.effects[PBEffects::ChoiceBand] = choice_lock
      end
    else
      selectable = [Battle::Move::Struggle.new(evaluation_ai.battle, nil)] if selectable.empty?
      evaluation_ai.ai_improvements_with_move_context(attacker, defender) do
        selectable.each do |move|
          next if !move.damagingMove?
          evaluation_ai.battle.moldBreaker = attacker.has_mold_breaker?
          evaluation_ai.move.set_up(move.dup)
          evaluation_ai.ai_reserve_damage_record(result, evaluation_ai.move, attacker, defender)
        end
      end
    end
    result
  end

  def ai_reserve_damage_selectable_moves(attacker)
    choice_lock = attacker.effects[PBEffects::ChoiceBand]
    begin
      # Same legality/PP/Encore checks as pbCanChooseAnyMove?: status options
      # count too. Only zero selectable options warrants native Struggle.
      attacker.moves.each_with_index.select do |move, index|
        move && @battle.pbCanChooseMove?(attacker.index, index, false)
      end.map(&:first)
    ensure
      attacker.effects[PBEffects::ChoiceBand] = choice_lock
    end
  end

  def ai_reserve_damage_context(index, party_index, hazard_damage)
    shadow = @battle.dup
    shadow.instance_variable_set(:@scene, nil)
    shadow.instance_variable_set(:@peer, nil)
    shadow.instance_variable_set(:@battlers, [])
    shadow.instance_variable_set(:@priority, [])
    shadow.choices = Array.new(@battle.battlers.length) { [:None, 0, nil, -1, 0] }
    AIReserveDamage::BATTLE_ARRAYS.each do |name|
      ivar = :"@#{name}"
      shadow.instance_variable_set(ivar, AIReserveDamage.copy_data(@battle.instance_variable_get(ivar)))
    end
    [:@party1, :@party2].each do |name|
      shadow.instance_variable_set(name, @battle.instance_variable_get(name).map { |p| AIReserveDamage.copy_pokemon(p) })
    end
    shadow.instance_variable_set(:@field, AIReserveDamage.copy_effects(@battle.field))
    shadow.instance_variable_set(:@sides, @battle.sides.map { |s| AIReserveDamage.copy_effects(s) })
    shadow.instance_variable_set(:@positions, @battle.positions.map { |p| p && AIReserveDamage.copy_effects(p) })
    shadow.instance_variable_set(:@rules, AIReserveDamage.copy_data(@battle.rules))
    shadow.instance_variable_set(:@struggle, Battle::Move::Struggle.new(shadow, nil))
    # The constructor can clear other battlers' effects: keep its battle empty.
    replacement = Battle::Battler.new(shadow, index)
    replacement.pbInitPokemon(shadow.pbParty(index)[party_index], party_index)
    replacement.hp -= hazard_damage
    copies = @battle.battlers.map { |b| AIReserveDamage.copy_battler(b, shadow) }
    copies[index] = replacement
    shadow.instance_variable_set(:@battlers, copies)
    # Clear the foe's Attract/LockOn/JawLock/etc. against the outgoing slot.
    # Only now can pbInitEffects clean those links on the isolated battlers.
    replacement.pbInitEffects(false)
    ai = dup
    ai.instance_variable_set(:@battle, shadow)
    ai.instance_variable_set(:@battlers, copies.each_index.map { |i| copies[i] && AIBattler.new(ai, i) })
    trainer = @trainer.dup
    trainer.instance_variable_set(:@ai, ai)
    ai.instance_variable_set(:@trainer, trainer)
    ai.instance_variable_set(:@user, ai.battlers[index ^ 1])
    ai.instance_variable_set(:@target, ai.battlers[index])
    ai.instance_variable_set(:@move, AIMove.new(ai))
    shadow.instance_variable_set(:@battleAI, ai)
    ai
  end

  def ai_reserve_damage_record(result, move, attacker, defender)
    return if !@battle.pbMoveCanTarget?(attacker.index, defender.index, move.pbTarget(attacker.battler))
    type = move.rough_type
    return if (@battle.pbWeather == :HeavyRain && type == :FIRE) ||
              (@battle.pbWeather == :HarshSun && type == :WATER)
    type_mod = move.move.pbCalcTypeMod(type, attacker.battler, defender.battler)
    return if Effectiveness.ineffective?(type_mod)
    if defender.ability_active? && !defender.being_mold_broken?
      if defender.has_active_ability?(:WONDERGUARD)
        return if type && !Effectiveness.super_effective?(type_mod)
      else
        return if move.id != :STRUGGLE && pokemon_can_absorb_move?(defender, move.move, type)
        return if move.move.pbImmunityByAbility(attacker.battler, defender.battler, false)
      end
    end
    return if type == :GROUND && defender.battler.airborne? && !move.move.hitsFlyingTargets?
    return if move.move.powderMove? && !defender.battler.affectedByPowder?
    priority = move.rough_priority(attacker)
    return if priority > 0 && (defender.has_active_ability?([:DAZZLING, :QUEENLYMAJESTY, :ARMORTAIL]) ||
              (@battle.field.terrain == :Psychic && defender.battler.affectedByTerrain?))
    accuracy = move.rough_accuracy.clamp(0, 100)
    return if accuracy <= 0
    damage = move.rough_damage
    expected = damage * accuracy / 100.0
    return if expected < result[:expected] || (expected == result[:expected] && damage <= result[:damage])
    crit = move.rough_critical_hit_stage
    ratios = Battle::Move::CRITICAL_HIT_RATIOS
    uncertain_crit = crit >= 0 && crit < ratios.length && ratios[crit] == 2
    reliable = accuracy >= AIImprovements::IMMEDIATE_KO_MIN_ACCURACY &&
               damage > defender.hp * AIImprovements::IMMEDIATE_KO_DAMAGE_MARGIN && !uncertain_crit
    reliable = false if attacker.status == :PARALYSIS || attacker.effects[PBEffects::Confusion] > 0 ||
                        attacker.effects[PBEffects::Attract] >= 0
    reliable = false if defender.effects[PBEffects::Substitute] > 0 && !move.move.ignoresSubstitute?(attacker.battler)
    if defender.hp == defender.totalhp
      reliable = false if defender.has_active_item?(:FOCUSSASH) ||
                          (defender.has_active_ability?(:STURDY) && !defender.being_mold_broken?)
    end
    result.replace(:damage => damage, :expected => expected, :move => move.id, :reliable_ko => reliable)
  end
end
