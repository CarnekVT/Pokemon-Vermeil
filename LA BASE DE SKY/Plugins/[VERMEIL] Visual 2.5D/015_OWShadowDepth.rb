#===============================================================================
# [VERMEIL] Visual 2.5D - 015_OWShadowDepth.rb
# Sombra de OW sobre superficies wall transitables.
#===============================================================================

class Game_Player
  alias_method :_VERMEIL_25D_orig_shows_shadow?, :shows_shadow? unless method_defined?(:_VERMEIL_25D_orig_shows_shadow?)

  def shows_shadow?(recalc = false)
    result = _VERMEIL_25D_orig_shows_shadow?(recalc)
    return result if result || !$scene.is_a?(Scene_Map) || !Mode7.rendering_now?
    tag = $game_map.terrain_tag(x, y)
    return result if !tag || tag.id == :None
    walls = Mode7.indoor_map? ? Mode7::Config::INDOOR_WALL_TERRAIN_TAG_HEIGHT :
                                Mode7::Config::OUTDOOR_WALL_TERRAIN_TAG_HEIGHT
    walls.key?(tag.id)
  end
end

class Sprite_OWShadow
  alias_method :_VERMEIL_25D_orig_update_depth, :update unless method_defined?(:_VERMEIL_25D_orig_update_depth)

  def update
    _VERMEIL_25D_orig_update_depth
    return if disposed? || !$scene.is_a?(Scene_Map) || !Mode7.rendering_now?
    return if !@event.is_a?(Game_Player) || !@sprite || @sprite.disposed? ||
              !@rsprite || @rsprite.disposed?
    if Mode7::Config::OW_SHADOW_HIDE_IN_BUSH && @event.bush_depth > 0
      @sprite.visible = false
      return
    end
    return if !@sprite.visible || @sprite.opacity <= 0
    if Mode7::Config::OW_SHADOW_GROUND_ALIGNMENT && Mode7.perspective_mode?
      # Sprite_OWShadow hereda el zoom uniforme del personaje. Una sombra es
      # plana, así que Y debe usar la derivada vertical del plano proyectado.
      # Conservamos el factor temporal de salto/flotación del script original.
      original_scale = @rsprite.zoom_x.to_f
      factor = original_scale.abs > 0.001 ? @sprite.zoom_x.to_f / original_scale : 1.0
      wy = @event.real_y.to_f / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT
      elevation = if Mode7.respond_to?(:nds_surface_height_at_real)
                    wx = @event.real_x.to_f / Game_Map::X_SUBPIXELS + Game_Map::TILE_WIDTH / 2.0
                    Mode7.nds_surface_height_at_real(wx, wy)
                  else
                    Mode7.nds_surface_height_at(@event.x, @event.y)
                  end
      @sprite.zoom_x = Mode7.object_scale_for_world_y(wy, elevation) * factor
      @sprite.zoom_y = Mode7.perspective_vertical_scale_for_world_y(wy, elevation) * factor
    end
    # No usar ground_cap: cambia por celda durante movimiento vertical/diagonal
    # y hace alternar z contra Mountain. Mismo Z interpolado del player, -1.
    @sprite.z = @event.screen_z(@rsprite.src_rect.height) - 1
  rescue Exception
    # ponytail: sombra vanilla queda intacta si una API externa no esta lista.
  end
end
