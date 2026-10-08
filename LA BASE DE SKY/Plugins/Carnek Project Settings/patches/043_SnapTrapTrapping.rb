#===============================================================================
# Snap Trap (Cepo) → FunctionCode = BindTarget.
# Trapping move that traps 4–5 turns and deals damage each end-of-round, like
# Wrap/Fire Spin/Whirlpool (the "torbellino" traps). This gives Cepo the two
# things the other trapping moves already have, entirely within the plugin:
#   1) A common animation on EOR trapping damage.
#   2) A dedicated trap message instead of the generic "torbellino" one.
#===============================================================================

# 1) Common animation for Snap Trap's end-of-round trapping damage.
#    Used in Battle#pbEORTrappingDamage (TRAPPING_MOVE_COMMON_ANIMATIONS lookup).
#    If the common animation "Common:SnapTrap" is not defined, it is a no-op.
Battle::TRAPPING_MOVE_COMMON_ANIMATIONS[:SNAPTRAP] = "SnapTrap"

# 2) Dedicated trap message for Snap Trap, alongside the torbellino (Whirlpool)
#    message in Battle::Move::BindTarget#pbEffectAgainstTarget. Every other
#    BindTarget move keeps using the original method unchanged.
class Battle::Move::BindTarget
  alias _carnek_snaptrap_orig_pbEffectAgainstTarget pbEffectAgainstTarget

  def pbEffectAgainstTarget(user, target)
    if @id == :SNAPTRAP
      return if target.fainted? || target.damageState.substitute
      return if target.effects[PBEffects::Trapping] > 0
      if user.hasActiveItem?(:GRIPCLAW)
        target.effects[PBEffects::Trapping] = 8
      else
        target.effects[PBEffects::Trapping] = 5 + @battle.pbRandom(2)
      end
      target.effects[PBEffects::TrappingMove] = @id
      target.effects[PBEffects::TrappingUser] = user.index
      @battle.pbDisplay(_INTL("¡{1} quedó atrapado en un cepo!", target.pbThis, user.pbThis(true)))
    else
      _carnek_snaptrap_orig_pbEffectAgainstTarget(user, target)
    end
  end
end
