#===============================================================================
# [VERMEIL] Visual 2.5D - 006_Atmosphere.rb
# Clima al frente en la camara 2.5D: fuerza el viewport de lluvia/nieve a la
# maxima profundidad para que se dibuje por delante del mapa proyectado.
#===============================================================================
class RPG::Weather
  MODE7_WEATHER_Z = 999_999 unless const_defined?(:MODE7_WEATHER_Z)

  alias_method :_VERMEIL_25D_weather_update_orig, :update unless method_defined?(:_VERMEIL_25D_weather_update_orig)
  alias_method :_VERMEIL_25D_weather_pos_orig, :update_sprite_position unless method_defined?(:_VERMEIL_25D_weather_pos_orig)

  def update
    _VERMEIL_25D_weather_update_orig
    force_weather_in_front
  end

  def update_sprite_position(sprite, index, is_new_sprite = false)
    _VERMEIL_25D_weather_pos_orig(sprite, index, is_new_sprite)
    if $scene.is_a?(Scene_Map) && Mode7.active_now?
      if sprite && !sprite.disposed?
        sprite.z = MODE7_WEATHER_Z
      end
    end
  end

  private

  def force_weather_in_front
    return unless $scene.is_a?(Scene_Map) && Mode7.rendering_now?

    # Aseguramos que el viewport del clima este por encima de cualquier capa del mapa
    if @viewport && !@viewport.disposed?
      @viewport.z = MODE7_WEATHER_Z
    end

    # Forzamos todas las colecciones de particulas internas del clima a la maxima profundidad
    [@sprites, @new_sprites, @tiles].each do |collection|
      next unless collection
      collection.each do |particle|
        if particle && !particle.disposed?
          particle.z = MODE7_WEATHER_Z
        end
      end
    end
  end
end

# --- Sombra de OW sobre superficies elevadas (antes 015_OWShadowDepth.rb) ---
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