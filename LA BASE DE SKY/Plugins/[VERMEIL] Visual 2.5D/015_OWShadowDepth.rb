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
    return if !@event.is_a?(Game_Player) || !@sprite || @sprite.disposed?
    return if !@sprite.visible || @sprite.opacity <= 0
    # No usar ground_cap: cambia por celda durante movimiento vertical/diagonal
    # y hace alternar z contra Mountain. Mismo Z interpolado del player, -1.
    @sprite.z = @event.screen_z(@rsprite.src_rect.height) - 1
  rescue Exception
    # ponytail: sombra vanilla queda intacta si una API externa no esta lista.
  end
end
