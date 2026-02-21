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
      # Keep already-fainted battlers hidden while Toxic Debris-style splash/animation runs.
      if battle.scene.respond_to?(:vermeil_mark_force_hidden_if_fainted)
        battle.battlers.each do |b|
          next if !b || (b.hp > 0 && !b.fainted?)
          battle.scene.vermeil_mark_force_hidden_if_fainted(b.index, 360)
        end
      end
      battle.scene.vermeil_force_hide_fainted_now if battle.scene.respond_to?(:vermeil_force_hide_fainted_now)
      fainted_source = target.fainted? || target.hp <= 0
      battle.pbShowAbilitySplash(target) if !fainted_source
      anim_user = target
      if fainted_source
        alt = target.pbDirectOpposing
        anim_user = alt if alt && !(alt.fainted? || alt.hp <= 0)
      end
      battle.pbAnimation(:TOXICSPIKES, anim_user, target.pbDirectOpposing)
      battle.pbHideAbilitySplash(target) if !fainted_source
      target.pbOpposingSide.effects[PBEffects::ToxicSpikes] += 1
      battle.scene.vermeil_force_hide_fainted_now if battle.scene.respond_to?(:vermeil_force_hide_fainted_now)
      battle.pbDisplay(_INTL("Poison spikes were scattered on the ground all around {1}!", target.pbOpposingTeam(true)))
      battle.scene.update_hazard_sprites if battle.scene.respond_to?(:update_hazard_sprites)

      # Keep fainted battlers hidden after ability splash/animation refreshes.
      scene_sprites = battle.scene.instance_variable_get(:@sprites) rescue nil
      if scene_sprites
        battle.battlers.each do |b|
          next if !b || (b.hp > 0 && !b.fainted?)
          pkmn = scene_sprites["pokemon_#{b.index}"]
          shdw = scene_sprites["shadow_#{b.index}"]
          pkmn.visible = false if pkmn && pkmn.respond_to?(:visible=)
          shdw.visible = false if shdw && shdw.respond_to?(:visible=)
          battle.scene.vermeil_mark_force_hidden_if_fainted(b.index, 360) if battle.scene.respond_to?(:vermeil_mark_force_hidden_if_fainted)
        end
      end
    }
  )
end
