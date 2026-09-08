#===============================================================================
# PRESA MORTAL - :DEADLYGRIP
#-------------------------------------------------------------------------------
# - Si el portador SOBREVIVE a un movimiento de contacto, el atacante pasa a
#   ser su presa.
# - El portador y la presa no pueden cambiar voluntariamente ni escapar.
# - U-turn/Volt Switch/Flip Turn, Baton Pass, Teleport y Parting Shot tampoco
#   permiten salir de la presa.
# - Los cambios forzados del rival (Roar, Whirlwind, Dragon Tail, etc.) SI
#   rompen la presa y se permiten.
# - Los Fantasma NO ignoran este atrapamiento personalizado.
# - Shed Shell/Run Away y equivalentes NO rompen la presa una vez formada.
# - El portador hace x1.3 de dano contra ESA presa concreta.
# - Solo puede existir una relacion 1 a 1 por battler.
# - Si cualquiera se debilita o abandona el campo, el vinculo deja de ser valido.
#===============================================================================

module GoldenAbilities
  module DeadlyGripBattlerState
    attr_accessor :golden_deadly_grip_prey
    attr_accessor :golden_deadly_grip_owner

    def golden_deadly_grip_valid_prey?
      prey = @golden_deadly_grip_prey
      return false if !prey
      if prey.fainted? || prey.golden_deadly_grip_owner != self
        @golden_deadly_grip_prey = nil
        return false
      end
      return true
    end

    def golden_deadly_grip_valid_owner?
      owner = @golden_deadly_grip_owner
      return false if !owner
      if owner.fainted? || owner.golden_deadly_grip_prey != self
        @golden_deadly_grip_owner = nil
        return false
      end
      return true
    end

    def golden_deadly_grip_linked?
      return golden_deadly_grip_valid_prey? || golden_deadly_grip_valid_owner?
    end

    def golden_deadly_grip_target?(other)
      return false if !golden_deadly_grip_valid_prey?
      return @golden_deadly_grip_prey.equal?(other)
    end

    def golden_bind_deadly_grip(other)
      return false if !other || other.equal?(self)
      return false if fainted? || other.fainted?
      return false if golden_deadly_grip_linked? || other.golden_deadly_grip_linked?
      @golden_deadly_grip_prey = other
      other.golden_deadly_grip_owner = self
      return true
    end

    def golden_clear_deadly_grip_link
      prey  = @golden_deadly_grip_prey
      owner = @golden_deadly_grip_owner
      @golden_deadly_grip_prey  = nil
      @golden_deadly_grip_owner = nil
      if prey && prey.respond_to?(:golden_deadly_grip_owner) && prey.golden_deadly_grip_owner.equal?(self)
        prey.golden_deadly_grip_owner = nil
      end
      if owner && owner.respond_to?(:golden_deadly_grip_prey) && owner.golden_deadly_grip_prey.equal?(self)
        owner.golden_deadly_grip_prey = nil
      end
    end
  end
end

Battle::Battler.prepend(GoldenAbilities::DeadlyGripBattlerState) unless Battle::Battler.ancestors.include?(GoldenAbilities::DeadlyGripBattlerState)

# Activacion por contacto. damageState.substitute evita activarla si el golpe se
# quedo en un Sustituto. pbContactMove? respeta la logica de contacto de
# Essentials (Long Reach, etc.).
Battle::AbilityEffects::OnBeingHit.add(
  GoldenAbilities::DEADLY_GRIP,
  proc { |ability, user, target, move, battle|
    next if user.fainted? || target.fainted?
    next if target.damageState.substitute
    next if !move.pbContactMove?(user)
    next if target.golden_deadly_grip_linked?
    next if user.golden_deadly_grip_linked?
    next if !target.golden_bind_deadly_grip(user)

    battle.pbShowAbilitySplash(target)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("¡{1} atrapo a {2} en una Presa Mortal!",
                             target.pbThis, user.pbThis(true)))
    else
      battle.pbDisplay(_INTL("¡{1} atrapo a {2} con {3}!",
                             target.pbThis, user.pbThis(true), target.abilityName))
    end
    battle.pbHideAbilitySplash(target)
  }
)

# Bonus de dano: solo contra la presa concreta del portador.
Battle::AbilityEffects::DamageCalcFromUser.add(
  GoldenAbilities::DEADLY_GRIP,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.golden_deadly_grip_target?(target)
    mults[:final_damage_multiplier] *= GoldenAbilities::DEADLY_GRIP_MULTIPLIER
  }
)

# Bloquea el cambio manual ANTES de las excepciones vanilla (Fantasma, Shed
# Shell, habilidades que permiten cambiar, etc.). Los cambios forzados no pasan
# por este chequeo y por eso siguen funcionando.
module GoldenAbilities
  module DeadlyGripSwitchBlock
    def pbCanSwitchOut?(idxBattler, partyScene = nil)
      battler = @battlers[idxBattler]
      if battler && !battler.fainted? && battler.golden_deadly_grip_linked?
        partyScene&.pbDisplay(_INTL("¡{1} no puede abandonar la Presa Mortal!", battler.pbThis))
        return false
      end
      return super
    end

    def pbCanRun?(idxBattler)
      battler = @battlers[idxBattler]
      return false if battler && !battler.fainted? && battler.golden_deadly_grip_linked?
      return super
    end

    def pbRun(idxBattler, duringBattle = false)
      battler = @battlers[idxBattler]
      if !duringBattle && battler && !battler.fainted? && battler.golden_deadly_grip_linked?
        # Mantener disponible la salida Debug de Essentials.
        return super if $DEBUG && Input.press?(Input::CTRL)
        pbDisplayPaused(_INTL("¡{1} no puede escapar de la Presa Mortal!", battler.pbThis))
        return 0
      end
      return super
    end
  end
end

Battle.prepend(GoldenAbilities::DeadlyGripSwitchBlock) unless Battle.ancestors.include?(GoldenAbilities::DeadlyGripSwitchBlock)

#-------------------------------------------------------------------------------
# Movimientos de auto-cambio que por defecto IGNORAN trapping en Essentials.
# Presa Mortal debe bloquearlos porque son una salida voluntaria.
#-------------------------------------------------------------------------------
module GoldenAbilities
  module DeadlyGripDamagingPivot
    def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
      if !user.fainted? && numHits > 0 && user.golden_deadly_grip_linked?
        @battle.pbDisplay(_INTL("¡{1} no puede abandonar la Presa Mortal!", user.pbThis))
        return
      end
      super
    end
  end

  module DeadlyGripStatusPivot
    def pbMoveFailed?(user, targets)
      if user.golden_deadly_grip_linked?
        @battle.pbDisplay(_INTL("¡{1} no puede abandonar la Presa Mortal!", user.pbThis))
        return true
      end
      return super
    end
  end

  module DeadlyGripPartingShot
    def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
      switcher = user
      targets.each do |b|
        next if switchedBattlers.include?(b.index)
        switcher = b if b.effects[PBEffects::MagicCoat] || b.effects[PBEffects::MagicBounce]
      end
      if !switcher.fainted? && numHits > 0 && switcher.golden_deadly_grip_linked?
        @battle.pbDisplay(_INTL("¡{1} no puede abandonar la Presa Mortal!", switcher.pbThis))
        return
      end
      super
    end
  end
end

if defined?(Battle::Move::SwitchOutUserDamagingMove)
  Battle::Move::SwitchOutUserDamagingMove.prepend(GoldenAbilities::DeadlyGripDamagingPivot) unless Battle::Move::SwitchOutUserDamagingMove.ancestors.include?(GoldenAbilities::DeadlyGripDamagingPivot)
end
if defined?(Battle::Move::SwitchOutUserStatusMove)
  Battle::Move::SwitchOutUserStatusMove.prepend(GoldenAbilities::DeadlyGripStatusPivot) unless Battle::Move::SwitchOutUserStatusMove.ancestors.include?(GoldenAbilities::DeadlyGripStatusPivot)
end
if defined?(Battle::Move::SwitchOutUserPassOnEffects)
  Battle::Move::SwitchOutUserPassOnEffects.prepend(GoldenAbilities::DeadlyGripStatusPivot) unless Battle::Move::SwitchOutUserPassOnEffects.ancestors.include?(GoldenAbilities::DeadlyGripStatusPivot)
end
if defined?(Battle::Move::FleeFromBattle)
  Battle::Move::FleeFromBattle.prepend(GoldenAbilities::DeadlyGripStatusPivot) unless Battle::Move::FleeFromBattle.ancestors.include?(GoldenAbilities::DeadlyGripStatusPivot)
end
if defined?(Battle::Move::LowerTargetAtkSpAtk1SwitchOutUser)
  Battle::Move::LowerTargetAtkSpAtk1SwitchOutUser.prepend(GoldenAbilities::DeadlyGripPartingShot) unless Battle::Move::LowerTargetAtkSpAtk1SwitchOutUser.ancestors.include?(GoldenAbilities::DeadlyGripPartingShot)
end
