#===============================================================================
# Suncorona / Eclipsora - Custom Abilities
#===============================================================================

module Battle::AbilityEffects
  module VermeilLightMoves
    FALLBACK_LIGHT_MOVES = [
      :FLASH, :FLASHCANNON, :LUMINACRASH, :MORNINGSUN, :MOONLIGHT, :SYNTHESIS,
      :SWIFT, :REFLECT, :LIGHTSCREEN, :AURORAVEIL, :AURORABEAM, :MIRRORCOAT,
      :SPOTLIGHT, :PHOTONGEYSER, :PRISMATICLASER, :LIGHTOFRUIN, :DAZZLINGGLEAM,
      :LUSTERPURGE, :FLASHSTRIKE, :MAGICSPARK, :MAGICPHOTON, :POWERGEM,
      :SOLARBEAM, :SOLARBLADE, :MINDBLOWN, :SIGNALBEAM, :CONFUSERAY,
      :SUNSTEELSTRIKE, :MOONGEISTBEAM, :FLEURCANNON, :FLAMEBURST
    ]

    def self.light_move_id?(move_or_id)
      id = move_or_id
      id = move_or_id.id if move_or_id.respond_to?(:id)
      return false if id.nil?
      if defined?(VermeilAbilityReworks) && VermeilAbilityReworks.const_defined?(:LIGHT_MOVES)
        return VermeilAbilityReworks::LIGHT_MOVES.include?(id)
      end
      return FALLBACK_LIGHT_MOVES.include?(id)
    end
  end

  #---------------------------------------------------------------------------
  # Helpers
  #---------------------------------------------------------------------------
  def self.exec_shadow_bearer_for_target(target)
    return nil if !target || !target.battle
    return target if target.battle.pbExecutionerShadowProtectsSide?(target.idxOwnSide)
    return nil
  end

  def self.exec_shadow_against?(battler)
    return false if !battler || !battler.battle
    return battler.battle.pbExecutionerShadowOpposes?(battler)
  end

  def self.exec_shadow_active?(battle)
    return false if !battle
    return battle.pbExecutionerShadowActive?
  end

  #===========================================================================
  # Blessed Corona
  #===========================================================================
  # 1) End of turn: 1/16 chip damage to all enemies.
  EndOfRoundEffect.add(:BLESSEDCORONA,
    proc { |ability, battler, battle|
      foes = battle.allOtherSideBattlers(battler.index).select do |b|
        b.near?(battler) && b.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
      end
      next if foes.empty?
      battle.pbShowAbilitySplash(battler)
      foes.each do |b|
        b.pbTakeEffectDamage([(b.totalhp / 16.0).floor, 1].max) do
          if Battle::Scene::USE_ABILITY_SPLASH
            battle.pbDisplay(_INTL("{1} is scorched by Blessed Corona!", b.pbThis))
          else
            battle.pbDisplay(_INTL("{1} is scorched by {2}'s {3}!",
              b.pbThis, battler.pbThis(true), battler.abilityName))
          end
        end
      end
      battle.pbHideAbilitySplash(battler)
    }
  )

  # 2) Allies are immune to freeze.
  StatusImmunityFromAlly.add(:BLESSEDCORONA,
    proc { |ability, battler, status|
      next true if status == :FROZEN
    }
  )

  # 3) Allies' Fire moves +20%.
  DamageCalcFromAlly.add(:BLESSEDCORONA,
    proc { |ability, user, target, move, mults, power, type|
      next if type != :FIRE
      mults[:power_multiplier] *= 1.2
    }
  )

  # 4) Self is immune to Water (evaporation).
  DamageCalcFromTarget.add(:BLESSEDCORONA,
    proc { |ability, user, target, move, mults, power, type|
      next if type != :WATER
      mults[:final_damage_multiplier] = 0
    }
  )

  # 5) Allies take 25% less damage from Water moves.
  DamageCalcFromTargetAlly.add(:BLESSEDCORONA,
    proc { |ability, user, target, move, mults, power, type|
      next if type != :WATER
      mults[:final_damage_multiplier] *= 0.75
    }
  )

  #===========================================================================
  # Executioner's Shadow (terrain-like aura)
  #===========================================================================
  # 1) Entry control pulse.
  OnSwitchIn.add(:UMBRAVEIL,
    proc { |ability, battler, battle, switch_in|
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("An Umbral Veil spreads across the field!"))
      battle.pbHideAbilitySplash(battler)
      battle.pbStartExecutionerShadow(battler) if battle.respond_to?(:pbStartExecutionerShadow)
    }
  )

  # 2) Ally support: immunity to stat drops.
  StatLossImmunityFromAlly.add(:UMBRAVEIL,
    proc { |ability, bearer, battler, stat, battle, showMessages|
      if showMessages
        battle.pbShowAbilitySplash(bearer)
        if Battle::Scene::USE_ABILITY_SPLASH
          battle.pbDisplay(_INTL("{1} is protected by the shadows!", battler.pbThis))
        else
          battle.pbDisplay(_INTL("{1}'s {2} protects {3}'s stats!",
            bearer.pbThis, bearer.abilityName, battler.pbThis(true)))
        end
        battle.pbHideAbilitySplash(bearer)
      end
      next true
    }
  )

  # 3) Ally support: no critical hits against allies (and bearer).
  CriticalCalcFromTarget.add(:UMBRAVEIL,
    proc { |ability, user, target, c|
      next -1
    }
  )
end

#===============================================================================
# Executioner's Shadow pseudo-terrain state (5 turns, independent from terrain/weather)
#===============================================================================
class Battle
  def pbExecutionerShadowActive?
    return @exec_shadow_turns && @exec_shadow_turns > 0
  end

  def pbExecutionerShadowProtectsSide?(side)
    return false if !pbExecutionerShadowActive? || @exec_shadow_side.nil?
    return side == @exec_shadow_side
  end

  def pbExecutionerShadowOpposes?(battler)
    return false if !battler || !pbExecutionerShadowActive? || @exec_shadow_side.nil?
    return battler.idxOwnSide != @exec_shadow_side
  end

  def pbExecutionerShadowInvokerSide?(battler)
    return false if !battler || !pbExecutionerShadowActive?
    return false if @exec_shadow_side.nil?
    return battler.idxOwnSide == @exec_shadow_side
  end

  def pbStartExecutionerShadow(battler)
    return if !battler
    if pbExecutionerShadowActive?
      if @exec_shadow_side != battler.idxOwnSide
        pbDisplay(_INTL("{1} seized control of the Eclipse!", battler.pbThis))
      else
        pbDisplay(_INTL("{1} reinforced the Eclipse!", battler.pbThis))
      end
    end
    @exec_shadow_turns = 5
    @exec_shadow_side = battler.idxOwnSide
    @scene.pbSetExecutionerShadowFog(true) if @scene && @scene.respond_to?(:pbSetExecutionerShadowFog)
  end

  def pbExecutionerShadowFavoredType?(battler)
    return false if !battler
    return battler.pbHasType?(:DARK) || battler.pbHasType?(:GHOST)
  end

  def pbClearExecutionerShadow(silent = false)
    was_active = pbExecutionerShadowActive?
    @exec_shadow_turns = 0
    @exec_shadow_side = nil
    @scene.pbSetExecutionerShadowFog(false) if @scene && @scene.respond_to?(:pbSetExecutionerShadowFog)
    pbDisplay(_INTL("The eclipse veil faded away!")) if was_active && !silent
  end

  if !method_defined?(:exec_shadow_visual_pbStartBattleCore_original)
    alias exec_shadow_visual_pbStartBattleCore_original pbStartBattleCore
  end

  def pbStartBattleCore(battle_loop = true)
    @exec_shadow_turns = 0
    @exec_shadow_side  = nil
    result = exec_shadow_visual_pbStartBattleCore_original(battle_loop)
    @scene.pbSetExecutionerShadowFog(false) if @scene && @scene.respond_to?(:pbSetExecutionerShadowFog)
    return result
  end

  if !method_defined?(:exec_shadow_visual_pbEndOfRoundPhase_original)
    alias exec_shadow_visual_pbEndOfRoundPhase_original pbEndOfRoundPhase
  end

  def pbEndOfRoundPhase
    exec_shadow_visual_pbEndOfRoundPhase_original
    if pbExecutionerShadowActive?
      allBattlers.each do |b|
        next if !b || b.fainted?
        amount = [(b.totalhp / 16.0).floor, 1].max
        if pbExecutionerShadowFavoredType?(b)
          next if !b.canHeal?
          b.pbRecoverHP(amount)
          pbDisplay(_INTL("{1} draws strength from the Eclipse!", b.pbThis))
        else
          next if !b.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
          b.pbTakeEffectDamage(amount) do
            pbDisplay(_INTL("{1} is worn down by the Eclipse fog!", b.pbThis))
          end
        end
      end
      @exec_shadow_turns -= 1
      if @exec_shadow_turns <= 0
        pbDisplay(_INTL("The Eclipse faded away!"))
        pbClearExecutionerShadow(true)
      else
        @scene.pbSetExecutionerShadowFog(true) if @scene && @scene.respond_to?(:pbSetExecutionerShadowFog)
      end
    end
  end

  if !method_defined?(:exec_shadow_visual_pbEndOfBattle_original)
    alias exec_shadow_visual_pbEndOfBattle_original pbEndOfBattle
  end

  def pbEndOfBattle(*args)
    pbClearExecutionerShadow(true)
    return exec_shadow_visual_pbEndOfBattle_original(*args)
  end
end

#===============================================================================
# Executioner's Shadow visual layer (fog persists independently of terrain/bg)
#===============================================================================
class Battle::Scene
  if !method_defined?(:exec_shadow_fog_pbInitSprites_original)
    alias exec_shadow_fog_pbInitSprites_original pbInitSprites
  end
  if !method_defined?(:exec_shadow_fog_pbFrameUpdate_original)
    alias exec_shadow_fog_pbFrameUpdate_original pbFrameUpdate
  end
  if !method_defined?(:exec_shadow_fog_pbDisposeSprites_original)
    alias exec_shadow_fog_pbDisposeSprites_original pbDisposeSprites
  end

  def pbInitSprites
    exec_shadow_fog_pbInitSprites_original
    pbInitExecutionerShadowFog
  end

  def pbFrameUpdate(cw = nil)
    exec_shadow_fog_pbFrameUpdate_original(cw)
    pbUpdateExecutionerShadowFog
  end

  def pbDisposeSprites
    pbDisposeExecutionerShadowFog
    exec_shadow_fog_pbDisposeSprites_original
  end

  def pbInitExecutionerShadowFog
    @exec_shadow_fog_target = false
    @exec_shadow_fog_alpha = 0
    @exec_shadow_fog_tiles = []
    @exec_shadow_fog_shift_x = 0.0
    @exec_shadow_fog_shift_y = 0.0
    @exec_shadow_fog_tile_w = 0
    @exec_shadow_fog_tile_h = 0
    @exec_shadow_fog_wide = 0
    @exec_shadow_fog_tall = 0
    begin
      @exec_shadow_fog_bitmap = RPG::Cache.load_bitmap("Graphics/Weather/", "fog_tile_3")
    rescue
      @exec_shadow_fog_bitmap = nil
    end
  end

  def pbSetExecutionerShadowFog(active)
    @exec_shadow_fog_target = active
  end

  def pbEnsureExecutionerShadowFogTiles
    return if !@exec_shadow_fog_bitmap
    return if @exec_shadow_fog_tiles.length > 0
    @exec_shadow_fog_tile_w = [@exec_shadow_fog_bitmap.width, 1].max
    @exec_shadow_fog_tile_h = [@exec_shadow_fog_bitmap.height, 1].max
    @exec_shadow_fog_wide = (Graphics.width.to_f / @exec_shadow_fog_tile_w).ceil + 2
    @exec_shadow_fog_tall = (Graphics.height.to_f / @exec_shadow_fog_tile_h).ceil + 2
    (@exec_shadow_fog_wide * @exec_shadow_fog_tall).times do
      s = Sprite.new(@viewport)
      s.bitmap = @exec_shadow_fog_bitmap
      s.visible = false
      s.opacity = 0
      s.z = 90
      @exec_shadow_fog_tiles << s
    end
  end

  def pbUpdateExecutionerShadowFog
    pbEnsureExecutionerShadowFogTiles
    return if @exec_shadow_fog_tiles.empty?
    target_alpha = @exec_shadow_fog_target ? 104 : 0
    if @exec_shadow_fog_alpha < target_alpha
      @exec_shadow_fog_alpha = [@exec_shadow_fog_alpha + 4, target_alpha].min
    elsif @exec_shadow_fog_alpha > target_alpha
      @exec_shadow_fog_alpha = [@exec_shadow_fog_alpha - 6, target_alpha].max
    end
    visible = @exec_shadow_fog_alpha > 0
    @exec_shadow_fog_shift_x += -10 * Graphics.delta
    @exec_shadow_fog_shift_y += 4 * Graphics.delta
    while @exec_shadow_fog_shift_x <= -@exec_shadow_fog_tile_w
      @exec_shadow_fog_shift_x += @exec_shadow_fog_tile_w
    end
    while @exec_shadow_fog_shift_x > 0
      @exec_shadow_fog_shift_x -= @exec_shadow_fog_tile_w
    end
    while @exec_shadow_fog_shift_y <= -@exec_shadow_fog_tile_h
      @exec_shadow_fog_shift_y += @exec_shadow_fog_tile_h
    end
    while @exec_shadow_fog_shift_y > 0
      @exec_shadow_fog_shift_y -= @exec_shadow_fog_tile_h
    end
    @exec_shadow_fog_tiles.each_with_index do |s, i|
      s.visible = visible
      next if !visible
      col = i % @exec_shadow_fog_wide
      row = i / @exec_shadow_fog_wide
      s.x = @exec_shadow_fog_shift_x.round + (col * @exec_shadow_fog_tile_w)
      s.y = @exec_shadow_fog_shift_y.round + (row * @exec_shadow_fog_tile_h)
      s.opacity = @exec_shadow_fog_alpha
    end
  end

  def pbDisposeExecutionerShadowFog
    @exec_shadow_fog_tiles.each { |s| s.dispose if s && !s.disposed? } if @exec_shadow_fog_tiles
    @exec_shadow_fog_tiles = []
  end
end

#===============================================================================
# Executioner's Shadow field-aura behavior
#===============================================================================
class Battle::Move
  if !method_defined?(:exec_shadow_pbCalcAccuracyModifiers_original)
    alias exec_shadow_pbCalcAccuracyModifiers_original pbCalcAccuracyModifiers
  end

  # While Eclipse is active, non-favored attackers from the non-invoker side suffer -10% accuracy.
  def pbCalcAccuracyModifiers(user, target, modifiers)
    exec_shadow_pbCalcAccuracyModifiers_original(user, target, modifiers)
    return if !user || !target
    return if !Battle::AbilityEffects.exec_shadow_active?(user.battle)
    return if user.battle.pbExecutionerShadowInvokerSide?(user)
    return if user.pbHasType?(:DARK) || user.pbHasType?(:GHOST)
    return if user.hasActiveAbility?(:ILLUMINATE)
    modifiers[:accuracy_multiplier] *= 0.9
  end

  if !method_defined?(:exec_shadow_light_pbMoveFailed_original)
    alias exec_shadow_light_pbMoveFailed_original pbMoveFailed?
  end

  # Under Umbral Veil, Light Moves from the opposing side are smothered.
  def pbMoveFailed?(user, targets)
    if user && user.battle &&
       Battle::AbilityEffects.exec_shadow_active?(user.battle) &&
       Battle::AbilityEffects::VermeilLightMoves.light_move_id?(@id)
      @battle.pbDisplay(_INTL("The eclipse fog smothered the light!"))
      return true
    end
    return exec_shadow_light_pbMoveFailed_original(user, targets)
  end

  if !method_defined?(:exec_shadow_pbAccuracyCheck_original)
    alias exec_shadow_pbAccuracyCheck_original pbAccuracyCheck
  end

  # If an ally misses under the aura, Eclipsora retaliates immediately.
  def pbAccuracyCheck(user, target)
    hit = exec_shadow_pbAccuracyCheck_original(user, target)
    return hit if hit
    return hit if !user || !target || !user.battle
    battle = user.battle
    return hit if !battle.pbExecutionerShadowInvokerSide?(user)
    return hit if !target.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
    source = battle.allSameSideBattlers(user.index).find { |b| b && !b.fainted? && b.hasActiveAbility?(:UMBRAVEIL) }
    if source
      battle.pbShowAbilitySplash(source)
      target.pbTakeEffectDamage([(target.totalhp / 16.0).floor, 1].max) do
        battle.pbDisplay(_INTL("{1} strikes from the shadows!", source.pbThis))
      end
      battle.pbHideAbilitySplash(source)
    else
      target.pbTakeEffectDamage([(target.totalhp / 16.0).floor, 1].max) do
        battle.pbDisplay(_INTL("The eclipse veil strikes from the shadows!"))
      end
    end
    return hit
  end
end

# Defog can clear the eclipse fog before its natural duration.
class Battle::Move::LowerTargetEvasion1RemoveSideEffects < Battle::Move::TargetStatDownMove
  if !method_defined?(:exec_shadow_defog_pbEffectAgainstTarget_original)
    alias exec_shadow_defog_pbEffectAgainstTarget_original pbEffectAgainstTarget
  end

  def pbEffectAgainstTarget(user, target)
    exec_shadow_defog_pbEffectAgainstTarget_original(user, target)
    if @battle.pbExecutionerShadowActive?
      @battle.pbClearExecutionerShadow(true)
      @battle.pbDisplay(_INTL("{1} blew away the eclipse fog!", user.pbThis))
    end
  end
end

#===============================================================================
# Light-based healing denial under Executioner's Shadow aura
#===============================================================================
class Battle::Move::HealUserDependingOnWeather < Battle::Move::HealingMove
  if !method_defined?(:exec_shadow_heal_pbMoveFailed_original)
    alias exec_shadow_heal_pbMoveFailed_original pbMoveFailed?
  end

  def pbMoveFailed?(user, targets)
    if Battle::AbilityEffects.exec_shadow_against?(user)
      @battle.pbDisplay(_INTL("The eclipse veil blocks the healing light!"))
      return true
    end
    return exec_shadow_heal_pbMoveFailed_original(user, targets)
  end
end

# Also deny Solar Beam's sunlight benefit by blocking its use while aura opposes.
class Battle::Move::TwoTurnAttackOneTurnInSun < Battle::Move::TwoTurnMove
  if !method_defined?(:exec_shadow_solar_pbMoveFailed_original)
    alias exec_shadow_solar_pbMoveFailed_original pbMoveFailed?
  end

  def pbMoveFailed?(user, targets)
    if @id == :SOLARBEAM && Battle::AbilityEffects.exec_shadow_against?(user)
      @battle.pbDisplay(_INTL("The eclipse veil smothers the solar charge!"))
      return true
    end
    return exec_shadow_solar_pbMoveFailed_original(user, targets)
  end
end
