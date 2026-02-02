#===============================================================================
# Reactive Pollen - Custom Ability
#===============================================================================
module Battle::AbilityEffects
  #=============================================================================
  # When hit by a Physical move, lower opponent's Attack and Speed by 1 stage.
  # When hit by a Special move, lower opponent's Special Attack and Speed by 1 stage.
  #=============================================================================
  OnBeingHit.add(:REACTIVEPOLLEN,
    proc { |ability, user, target, move, battle|
      PBDebug.log("[Reactive Pollen] OnBeingHit - Move: #{move ? move.name : 'nil'}, Category: #{move ? (move.physicalMove? ? 'Physical' : move.specialMove? ? 'Special' : 'Other') : 'nil'}")
      
      next if !move || !move.damagingMove?
      next if target.fainted?
      
      battle.pbShowAbilitySplash(target)
      
      showAnim = true
      if move.physicalMove?
        # Lower Attack
        if user.pbCanLowerStatStage?(:ATTACK, target)
          if user.pbLowerStatStage(:ATTACK, 1, target, showAnim)
            showAnim = false
          end
        end
        # Lower Speed
        if user.pbCanLowerStatStage?(:SPEED, target)
          user.pbLowerStatStage(:SPEED, 1, target, showAnim)
        end
      elsif move.specialMove?
        # Lower Special Attack
        if user.pbCanLowerStatStage?(:SPECIAL_ATTACK, target)
          if user.pbLowerStatStage(:SPECIAL_ATTACK, 1, target, showAnim)
            showAnim = false
          end
        end
        # Lower Speed
        if user.pbCanLowerStatStage?(:SPEED, target)
          user.pbLowerStatStage(:SPEED, 1, target, showAnim)
        end
      end
      
      battle.pbHideAbilitySplash(target)
    }
  )
end
