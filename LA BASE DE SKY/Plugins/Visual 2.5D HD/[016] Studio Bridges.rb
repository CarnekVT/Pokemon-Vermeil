#===============================================================================
# Visual 2.5D HD - Puentes opcionales, encapsulados en ESTE plugin.
# LBDS Animated Props y Lighting Studio quedan totalmente independientes.
# Sin 2.5D activo, los metodos originales funcionan normalmente.
#===============================================================================
module Visual25D
  module StudioOptions
    ANIMATED_PROPS_BRIDGE = true
    LIGHTING_STUDIO_BRIDGE = true
  end

  module AnimatedPropsBridge
    def lbds_props_update_sprites
      mode = Visual25D.enabled? ? :projected : :normal
      if @v25d_props_mode != mode
        @lbds_prop_geometry_stamp = nil
        @v25d_props_stamp = nil
        @v25d_props_mode = mode
      end
      super
      return unless Visual25D::StudioOptions::ANIMATED_PROPS_BRIDGE
      return unless Visual25D.enabled? && @map && @lbds_prop_sprites
      stamp = [@map.display_x, @map.display_y, Visual25D.projection_stamp,
               Visual25D.tilt, Visual25D.camera_zoom]
      return if @v25d_props_stamp == stamp
      @v25d_props_stamp = stamp
      mx = (@map.display_x.to_f / Game_Map::X_SUBPIXELS).round
      my = (@map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
      zx = TilemapRenderer::ZOOM_X
      zy = TilemapRenderer::ZOOM_Y
      hw = Graphics.width / 2.0
      hh = Graphics.height / 2.0
      tw = Game_Map::TILE_WIDTH
      th = Game_Map::TILE_HEIGHT
      @lbds_prop_sprites.each do |entry|
        sprite, obj, cx, cy, span, pri = entry
        next if !sprite || sprite.disposed? || !sprite.bitmap
        x = ((obj[:x] + cx) * tw) - mx
        y = ((obj[:y] + cy) * th) - my
        x = (x - hw) * zx + hw if zx != 1
        y = (y - hh) * zy + hh if zy != 1
        priority = pri.to_i
        if priority > 0
          feet = y + (priority * th * zy)
          scale = Visual25D.width_scale_at(feet)
          unit = Visual25D.vertical_unit_at(feet)
          unit = th * zy if unit <= 0
          pos_y = Visual25D.project_y(feet) - (priority * unit)
          sy = unit / 32.0
        else
          scale = Visual25D.width_scale_at(y + th * zy / 2.0)
          pos_y = Visual25D.project_y(y)
          sy = [Visual25D.project_y(y + th * zy) - pos_y, 1].max / 32.0
        end
        sprite.x = Visual25D.project_x(x, scale)
        sprite.y = pos_y.round
        sprite.zoom_x = zx * scale
        sprite.zoom_y = sy
        if priority > 0
          raw_z = y + th * (priority + 1) + 1
          sprite.z = Visual25D.raised_tile_z(raw_z.round) +
                     [obj[:layer].to_i, 5].min + (entry[7] == :parallel ? 1 : 0)
        end
        sprite.visible = sprite.x + (span * tw * sprite.zoom_x) > 0 &&
                         sprite.y + (th * sprite.zoom_y) > 0 &&
                         sprite.x < Graphics.width && sprite.y < Graphics.height
      end
    end
  end

  module LightingBridge
    def ls_world_screen(wx, wy, mx, my, zx, zy)
      original = super
      return original unless Visual25D::StudioOptions::LIGHTING_STUDIO_BRIDGE && Visual25D.enabled?
      x, y = original
      return [Visual25D.project_x(x, Visual25D.width_scale_at(y)), Visual25D.project_y(y)]
    end

    def ls_update
      super
      return unless Visual25D::StudioOptions::LIGHTING_STUDIO_BRIDGE && Visual25D.enabled? && @map
      return unless @ls_sprites || @ls_chunks
      my = (@map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
      zy = TilemapRenderer::ZOOM_Y
      if @ls_sprites
        @ls_sprites.each do |sprite, entry|
          next unless sprite && !sprite.disposed? && sprite.bitmap
          y = entry[:cy].to_f - my
          y = (y - Graphics.height / 2.0) * zy + Graphics.height / 2.0 if zy != 1
          sprite.zoom_x *= Visual25D.width_scale_at(y)
          sprite.zoom_y *= Visual25D.scale_at(y)
        end
      end
      if @ls_chunks && defined?(LightingStudio::CHUNK_WORLD)
        @ls_chunks.each do |key, entry|
          sprite = entry[:sprite]
          next unless sprite && !sprite.disposed? && sprite.visible && sprite.bitmap
          y = key[1] * LightingStudio::CHUNK_WORLD - my
          y = (y - Graphics.height / 2.0) * zy + Graphics.height / 2.0 if zy != 1
          h = LightingStudio::CHUNK_WORLD * zy
          next if h <= 0
          height = Visual25D.project_y(y + h) - Visual25D.project_y(y)
          sprite.zoom_x *= Visual25D.width_scale_at(y + h / 2.0)
          sprite.zoom_y *= [height, 1].max / h.to_f
        end
      end
    end
  end
end

if defined?(Spriteset_Map)
  if defined?(LBDSAnimatedProps) && Spriteset_Map.method_defined?(:lbds_props_update_sprites) &&
     !Spriteset_Map.ancestors.include?(Visual25D::AnimatedPropsBridge)
    Spriteset_Map.prepend(Visual25D::AnimatedPropsBridge)
  end
  if defined?(LightingStudio) && Spriteset_Map.method_defined?(:ls_update) &&
     Spriteset_Map.method_defined?(:ls_world_screen) &&
     !Spriteset_Map.ancestors.include?(Visual25D::LightingBridge)
    Spriteset_Map.prepend(Visual25D::LightingBridge)
  end
end
