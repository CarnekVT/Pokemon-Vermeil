#===============================================================================
# Warlord's Gaze - Custom Ability
#===============================================================================
module Battle::AbilityEffects
  #=============================================================================
  # On switch-in, intimidate opponent(s) lowering their Attack (like Intimidate)
  #=============================================================================
  OnSwitchIn.add(:WARLORDSGAZE,
    proc { |ability, battler, battle, switch_in|
      PBDebug.log("[Warlord's Gaze] OnSwitchIn triggered")
      
      battle.pbShowAbilitySplash(battler)
      battle.allOtherSideBattlers(battler.index).each do |b|
        next if !b.near?(battler)
        check_item = true
        if b.hasActiveAbility?(:CONTRARY)
          check_item = false if b.statStageAtMax?(:ATTACK)
        elsif b.statStageAtMin?(:ATTACK)
          check_item = false
        end
        check_ability = b.pbLowerAttackStatStageIntimidate(battler)
        b.pbAbilitiesOnIntimidated if check_ability
        b.pbItemOnIntimidatedCheck if check_item
      end
      battle.pbHideAbilitySplash(battler)
    }
  )
end

#===============================================================================
# Override switch-out move classes to add Warlord's Gaze effect
#===============================================================================

# Override SwitchOutUserDamagingMove (U-turn, Volt Switch, Flip Turn)
class Battle::Move::SwitchOutUserDamagingMove
  alias_method :dbk_original_pbEndOfMoveUsageEffect, :pbEndOfMoveUsageEffect
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    PBDebug.log("[Warlord's Gaze] SwitchOutUserDamagingMove - User: #{user.pbThis}, Fainted: #{user.fainted?}")
    return if user.fainted? || numHits == 0 || @battle.pbAllFainted?(user.idxOpposingSide)
    targetSwitched = true
    targets.each do |b|
      targetSwitched = false if !switchedBattlers.include?(b.index)
    end
    return if targetSwitched
    return if !@battle.pbCanChooseNonActive?(user.index)
    @battle.pbDisplay(_INTL("{1} went back to {2}!", user.pbThis,
                            @battle.pbGetOwnerName(user.index)))
    
    # Apply Warlord's Gaze effect
    @battle.allOtherSideBattlers(user.index).each do |b|
      if b.hasActiveAbility?(:WARLORDSGAZE)
        @battle.pbShowAbilitySplash(b)
        damage = (user.totalhp / 8).ceil
        PBDebug.log("[Warlord's Gaze] Dealing #{damage} damage to #{user.pbThis}, current HP: #{user.hp}")
        if user.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
          user.pbTakeEffectDamage(damage) do
            @battle.pbDisplay(_INTL("{1} took damage from {2}'s {3}!", user.pbThis, b.pbThis(true), b.abilityName))
          end
        end
        @battle.pbHideAbilitySplash(b)
        return if user.fainted?
        break
      end
    end
    return if user.fainted?
    
    @battle.pbPursuit(user.index)
    return if user.fainted?
    newPkmn = @battle.pbGetReplacementPokemonIndex(user.index)   # Owner chooses
    return if newPkmn < 0
    @battle.pbRecallAndReplace(user.index, newPkmn)
    @battle.pbClearChoice(user.index)   # Replacement Pokémon does nothing this round
    @battle.moldBreaker = false
    @battle.pbOnBattlerEnteringBattle(user.index)
    switchedBattlers.push(user.index)
  end
end

# Override SwitchOutUserStatusMove (Teleport)
class Battle::Move::SwitchOutUserStatusMove
  alias_method :dbk_original_pbEndOfMoveUsageEffect, :pbEndOfMoveUsageEffect
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.wild?
    @battle.pbDisplay(_INTL("{1} went back to {2}!", user.pbThis,
                            @battle.pbGetOwnerName(user.index)))
    
    # Apply Warlord's Gaze effect
    @battle.allOtherSideBattlers(user.index).each do |b|
      if b.hasActiveAbility?(:WARLORDSGAZE)
        @battle.pbShowAbilitySplash(b)
        damage = (user.totalhp / 8).ceil
        if user.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
          user.pbTakeEffectDamage(damage) do
            @battle.pbDisplay(_INTL("{1} took damage from {2}'s {3}!", user.pbThis, b.pbThis(true), b.abilityName))
          end
        end
        @battle.pbHideAbilitySplash(b)
        return if user.fainted?
        break
      end
    end
    return if user.fainted?
    
    @battle.pbPursuit(user.index)
    return if user.fainted?
    newPkmn = @battle.pbGetReplacementPokemonIndex(user.index)   # Owner chooses
    return if newPkmn < 0
    @battle.pbRecallAndReplace(user.index, newPkmn)
    @battle.pbClearChoice(user.index)   # Replacement Pokémon does nothing this round
    @battle.moldBreaker = false
    @battle.pbOnBattlerEnteringBattle(user.index)
    switchedBattlers.push(user.index)
  end
end

# Override LowerTargetAtkSpAtk1SwitchOutUser (Parting Shot)
class Battle::Move::LowerTargetAtkSpAtk1SwitchOutUser
  alias_method :dbk_original_pbEndOfMoveUsageEffect, :pbEndOfMoveUsageEffect
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    switcher = user
    targets.each do |b|
      next if switchedBattlers.include?(b.index)
      switcher = b if b.effects[PBEffects::MagicCoat] || b.effects[PBEffects::MagicBounce]
    end
    return if switcher.fainted? || numHits == 0
    return if !@battle.pbCanChooseNonActive?(switcher.index)
    @battle.pbDisplay(_INTL("{1} went back to {2}!", switcher.pbThis,
                            @battle.pbGetOwnerName(switcher.index)))
    
    # Apply Warlord's Gaze effect
    @battle.allOtherSideBattlers(switcher.index).each do |b|
      if b.hasActiveAbility?(:WARLORDSGAZE)
        @battle.pbShowAbilitySplash(b)
        damage = (switcher.totalhp / 8).ceil
        if switcher.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
          switcher.pbTakeEffectDamage(damage) do
            @battle.pbDisplay(_INTL("{1} took damage from {2}'s {3}!", switcher.pbThis, b.pbThis(true), b.abilityName))
          end
        end
        @battle.pbHideAbilitySplash(b)
        return if switcher.fainted?
        break
      end
    end
    return if switcher.fainted?
    
    @battle.pbPursuit(switcher.index)
    return if switcher.fainted?
    newPkmn = @battle.pbGetReplacementPokemonIndex(switcher.index)   # Owner chooses
    return if newPkmn < 0
    @battle.pbRecallAndReplace(switcher.index, newPkmn)
    @battle.pbClearChoice(switcher.index)   # Replacement Pokémon does nothing this round
    @battle.moldBreaker = false if switcher.index == user.index
    @battle.pbOnBattlerEnteringBattle(switcher.index)
    switchedBattlers.push(switcher.index)
  end
end

# Override SwitchOutUserPassOnEffects (Baton Pass)
class Battle::Move::SwitchOutUserPassOnEffects
  alias_method :dbk_original_pbEndOfMoveUsageEffect, :pbEndOfMoveUsageEffect
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.fainted? || numHits == 0
    return if !@battle.pbCanChooseNonActive?(user.index)
    
    # Apply Warlord's Gaze effect
    @battle.allOtherSideBattlers(user.index).each do |b|
      if b.hasActiveAbility?(:WARLORDSGAZE)
        @battle.pbShowAbilitySplash(b)
        damage = (user.totalhp / 8).ceil
        if user.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
          user.pbTakeEffectDamage(damage) do
            @battle.pbDisplay(_INTL("{1} took damage from {2}'s {3}!", user.pbThis, b.pbThis(true), b.abilityName))
          end
        end
        @battle.pbHideAbilitySplash(b)
        return if user.fainted?
        break
      end
    end
    return if user.fainted?
    
    @battle.pbPursuit(user.index)
    return if user.fainted?
    newPkmn = @battle.pbGetReplacementPokemonIndex(user.index)   # Owner chooses
    return if newPkmn < 0
    @battle.pbRecallAndReplace(user.index, newPkmn, false, true)
    @battle.pbClearChoice(user.index)   # Replacement Pokémon does nothing this round
    @battle.moldBreaker = false
    @battle.pbOnBattlerEnteringBattle(user.index)
    switchedBattlers.push(user.index)
  end
end

# Override Battle class to handle normal switch-outs in pbAttackPhaseSwitch
class Battle
  alias_method :dbk_original_pbAttackPhaseSwitch, :pbAttackPhaseSwitch
  def pbAttackPhaseSwitch
    pbPriority.each do |b|
      next unless @choices[b.index][0] == :SwitchOut && !b.fainted?
      idxNewPkmn = @choices[b.index][1]   # Party index of Pokémon to switch to
      b.lastMoveFailed = false   # Counts as a successful move for Stomping Tantrum
      @lastMoveUser = b.index
      # Switching message
      pbMessageOnRecall(b)
      
      # Apply Warlord's Gaze effect before Pursuit
      allOtherSideBattlers(b.index).each do |opp|
        if opp.hasActiveAbility?(:WARLORDSGAZE)
          pbShowAbilitySplash(opp)
          damage = (b.totalhp / 8).ceil
          if b.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
            b.pbTakeEffectDamage(damage) do
              pbDisplay(_INTL("{1} took damage from {2}'s {3}!", b.pbThis, opp.pbThis(true), opp.abilityName))
            end
          end
          pbHideAbilitySplash(opp)
          return if b.fainted?
          break
        end
      end
      return if b.fainted?
      
      # Pursuit interrupts switching
      pbPursuit(b.index)
      return if @decision > 0
      # Switch Pokémon
      allBattlers.each do |b2|
        b2.droppedBelowHalfHP = false
        b2.statsDropped = false
      end
      pbRecallAndReplace(b.index, idxNewPkmn)
      pbOnBattlerEnteringBattle(b.index, true)
    end
  end
end

