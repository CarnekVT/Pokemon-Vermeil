#===============================================================================
#
#===============================================================================
module GameData
  class SpeciesMetrics
    # origin_only is for displaying battler sprites in the canvas of the
    # Animation Editor, where sprite's position already accounts for the changes
    # to ox/oy/y.
    def apply_metrics_to_sprite(sprite, index, shadow = false, origin_only = false)
      if shadow
        sprite.x += @shadow_x * 2 if (index & 1) == 1   # Foe Pokémon
      elsif (index & 1) == 0   # Player's Pokémon
        sprite.ox -= @back_sprite[0] * 2
        sprite.oy -= @back_sprite[1] * 2
        if origin_only
          sprite.x -= @back_sprite[0] * 2
          sprite.y -= @back_sprite[1] * 2
        end
      else                     # Foe Pokémon
        sprite.ox -= @front_sprite[0] * 2
        sprite.oy -= @front_sprite[1] * 2
        if origin_only
          sprite.x -= @front_sprite[0] * 2
          sprite.y -= @front_sprite[1] * 2
        end
        sprite.y -= @front_sprite_altitude * 2 if !origin_only
      end
    end
  end
end
