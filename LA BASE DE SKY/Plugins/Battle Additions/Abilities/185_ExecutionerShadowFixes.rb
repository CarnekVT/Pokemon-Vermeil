#===============================================================================
# Executioner's Shadow - ally critical-hit protection
# Essentials' CriticalCalcFromTarget handler only checks the target's own
# Ability. Umbral Veil explicitly protects allies too, so cover that part here.
#===============================================================================
class Battle::Move
  if !method_defined?(:vermeil_umbral_veil_pbIsCritical_original)
    alias vermeil_umbral_veil_pbIsCritical_original pbIsCritical?
  end

  def pbIsCritical?(user, target)
    if user && target && !user.hasMoldBreaker?
      protected_by_ally = false
      if target.respond_to?(:allAllies)
        protected_by_ally = target.allAllies.any? do |ally|
          ally && !ally.fainted? && ally.hasActiveAbility?(:UMBRAVEIL)
        end
      end
      return false if protected_by_ally
    end
    return vermeil_umbral_veil_pbIsCritical_original(user, target)
  end
end
