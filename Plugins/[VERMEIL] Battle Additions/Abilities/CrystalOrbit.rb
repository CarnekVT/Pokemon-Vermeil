module Battle::AbilityEffects
  if const_defined?(:MoveImmunity) && MoveImmunity.respond_to?(:copy)
    MoveImmunity.copy(:MAGICBOUNCE, :CRYSTALORBIT)
  end

  # Explicit Toxic Debris behavior for Crystal Orbit to avoid load-order issues.
  OnBeingHit.add(:CRYSTALORBIT,
    proc { |ability, user, target, move, battle|
      next if !move.physicalMove?
      next if target.damageState.substitute
      next if target.pbOpposingSide.effects[PBEffects::ToxicSpikes] >= 2
      battle.pbShowAbilitySplash(target)
      target.pbOpposingSide.effects[PBEffects::ToxicSpikes] += 1
      battle.pbAnimation(:TOXICSPIKES, target, target.pbDirectOpposing)
      battle.pbDisplay(_INTL("Poison spikes were scattered on the ground all around {1}!", target.pbOpposingTeam(true)))
      battle.pbHideAbilitySplash(target)
    }
  )
end
