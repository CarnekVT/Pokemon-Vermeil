#===============================================================================
# Golden Form - battle activation similar to Primal Reversion
#===============================================================================
class Battle
  def pbStartGoldenForm(idxBattler, assignment=nil)
    battler=@battlers[idxBattler]
    return false if !battler
    return true if battler.isOnGoldenForm?
    assignment ||= pbGoldenAssignmentFor(idxBattler,:FORM) if respond_to?(:pbGoldenAssignmentFor)
    return false if !pbCanUseGoldenMechanic?(idxBattler,:FORM,assignment)

    old_ability=battler.ability_id
    pbDisplay(_INTL("¡{1} supera sus límites hasta alcanzar su Forma Dorada!",battler.pbThis))
    pbCommonAnimation("MegaEvolution",battler)
    return false if !battler.pokemon.makeGolden

    pbConsumeGoldenUse(idxBattler,:FORM)
    battler.form=battler.pokemon.form
    battler.pbUpdate(true)
    # Refresh battle typing and contextual Golden Move names before the next
    # command is selected; some battle UIs cache both values.
    battler.pbSyncGoldenMoveDisplayNames if battler.respond_to?(:pbSyncGoldenMoveDisplayNames)
    @scene.pbChangePokemon(battler,battler.pokemon)
    @scene.pbRefreshOne(idxBattler)
    pbCommonAnimation("MegaEvolution2",battler)

    if old_ability!=battler.ability_id
      battler.pbOnLosingAbility(old_ability)
      battler.pbTriggerAbilityOnGainingIt
    end
    pbCalculatePriority(false,[idxBattler])
    return true
  end

  def pbApplyGoldenFormDrain(battler)
    return false if !battler || battler.fainted? || !battler.isOnGoldenForm?
    ratio=GoldenSystem.settings[:form_hp_drain]
    return false if ratio<=0
    loss=[(battler.totalhp*ratio).floor,1].max
    total_loss=battler.pbReduceHP(loss)
    pbDisplay(_INTL("¡{1} pierde {2} PS por mantener su Forma Dorada!",battler.pbThis,total_loss))
    return true
  end
end

Battle::ItemEffects::OnSwitchIn.add(
  GoldenSystem::GOLDEN_STONE_ITEM,
  proc do |item,battler,battle|
    # A transformed Pokémon switching back in keeps the transformation and does
    # not consume a second activation.
    if battler.pokemon.isOnGoldenForm?
      battler.form=battler.pokemon.form
      battler.pbUpdate(true)
      battler.pbSyncGoldenMoveDisplayNames if battler.respond_to?(:pbSyncGoldenMoveDisplayNames)
      battle.scene.pbChangePokemon(battler,battler.pokemon)
      battle.scene.pbRefreshOne(battler.index)
      next
    end
    battle.pbStartGoldenForm(battler.index)
  end
)

Battle::ItemEffects::EndOfRoundEffect.add(
  GoldenSystem::GOLDEN_STONE_ITEM,
  proc do |item,battler,battle|
    battle.pbApplyGoldenFormDrain(battler)
  end
)

# Golden activator items remain attached once their mechanic has been invoked.
module GoldenSystem
  module GoldenUnlosableItems
    def unlosableItem?(check_item)
      if @pokemon
        return true if @pokemon.isOnGoldenPower? && check_item==GoldenSystem::GOLDEN_FRAGMENT_ITEM
        return true if @pokemon.isOnGoldenForm? && check_item==GoldenSystem::GOLDEN_STONE_ITEM
      end
      return super
    end
  end
end
Battle::Battler.prepend(GoldenSystem::GoldenUnlosableItems)
