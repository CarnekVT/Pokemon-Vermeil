#===============================================================================
# Visual 2.5D HD — adaptadores opcionales. Todo el soporte vive AQUÍ.
# No modifica LBDS Animated Props ni Lighting Studio.
# Coordenadas absolutas: nunca proyectar un sprite ya proyectado.
#===============================================================================
module Visual25D
  module StudioOptions
    @props_enabled = true
    @lights_enabled = true
    class << self
      attr_accessor :props_enabled, :lights_enabled
      def props?
        @props_enabled != false
      end
      def lights?
        @lights_enabled != false
      end
    end
  end

  module StudioTransform
    def self.flat(wx, wy, map, zx, zy)
      mx = (map.display_x.to_f / Game_Map::X_SUBPIXELS).round
      my = (map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
      x = wx - mx
      y = wy - my
      x = (x - Graphics.width / 2.0) * zx + Graphics.width / 2.0 if zx != 1
      y = (y - Graphics.height / 2.0) * zy + Graphics.height / 2.0 if zy != 1
      [x, y]
    end

    def self.project(x, y)
      [Visual25D.project_x(x, Visual25D.width_scale_at(y)), Visual25D.project_y(y)]
    end
  end

  module Props
    def lbds_props_view_bounds(mx, my, zx, zy)
      result = super
      return result unless Visual25D.enabled? && Visual25D::StudioOptions.props?
      # Amplía un poco el culling 2D para objetos visibles tras proyectar.
      [result[0] - 2, result[1] - 2, result[2] + 2, result[3] + 2]
    end

    def lbds_props_update_sprites
      active = Visual25D.enabled? && Visual25D::StudioOptions.props?
      if active != @v25_props_active
        @lbds_prop_geometry_stamp = nil
        @lbds_prop_active_bounds = nil
        @v25_props_camera = nil
        @v25_props_active = active
      end
      super
      return unless active && @map && @lbds_prop_sprites
      camera = [@map.map_id, @map.display_x, @map.display_y, Visual25D.projection_stamp,
                Visual25D.tilt, Visual25D.camera_zoom, Graphics.width, Graphics.height,
                @lbds_prop_sprites.object_id]
      return if @v25_props_camera == camera
      @v25_props_camera = camera
      # Coordinar el mismo frame de proyeccion y desplazamiento de tiles.
      Visual25D.sync_projection_from_map!(@map)
      zx = TilemapRenderer::ZOOM_X
      zy = TilemapRenderer::ZOOM_Y
      pixel_offset_y = Visual25D.display_pixel_offset_y(@map)
      tw = Game_Map::TILE_WIDTH
      th = Game_Map::TILE_HEIGHT
      @lbds_prop_sprites.each do |entry|
        spr, obj, cx, cy, span, pri, _frame, track = entry
        next if !spr || spr.disposed? || !spr.bitmap
        x, y = Visual25D::StudioTransform.flat((obj[:x] + cx) * tw,
                                                (obj[:y] + cy) * th, @map, zx, zy)
        priority = pri.to_i
        if priority > 0
          feet_y = y + priority * th * zy
          scale = Visual25D.width_scale_at(feet_y)
          unit = [Visual25D.vertical_unit_at(feet_y), 1.0].max
          top = Visual25D.project_y(feet_y) - priority * unit
          height = unit
          # Igual que Tile Depth#project_tile_z: fila de rejilla + prioridad
          # pintada por cada celda, sin perder capas de Animated Props.
          cell_y = obj[:y].to_i + cy
          row = Visual25D.grid_row_for_map_cell_id(@map.map_id, cell_y)
          if row
            original_z = ((row + priority + 1) *
                           TilemapRenderer::DISPLAY_TILE_HEIGHT) -
                         pixel_offset_y + 1 + priority
          else
            original_z = (y + (priority + 1) * th * zy).round + 1 + priority
          end
          spr.z = Visual25D.raised_tile_z(original_z.round) +
                  [obj[:layer].to_i, 5].min + (track == :parallel ? 1 : 0)
        else
          scale = Visual25D.width_scale_at(y + th * zy / 2.0)
          top = Visual25D.project_y(y)
          height = [Visual25D.project_y(y + th * zy) - top, 1].max
          # Los props del suelo retienen su propia banda y capa, sin Z_LIFT.
        end
        # Los valores provienen de p[:cells][cy*width+cx] y se conservan
        # también entre cambios de frame. No reutilizar la Z de otro sprite.
        if priority <= 0
          spr.z = [obj[:layer].to_i, 5].min + (track == :parallel ? 1 : 0)
        end
        sx = Visual25D.project_x(x, scale)
        xzoom = zx * scale
        yzoom = height / 32.0
        spr.x = sx.round
        spr.y = top.round
        spr.zoom_x = xzoom if (spr.zoom_x - xzoom).abs > 0.002
        spr.zoom_y = yzoom if (spr.zoom_y - yzoom).abs > 0.002
        spr.visible = sx < Graphics.width && top < Graphics.height &&
                      sx + span * tw * xzoom > 0 && top + height > 0
      end
    end
  end

  module Lighting
    def ls_world_screen(wx, wy, mx, my, zx, zy)
      return super unless Visual25D.enabled? && Visual25D::StudioOptions.lights?
      x = wx - mx
      y = wy - my
      x = (x - Graphics.width / 2.0) * zx + Graphics.width / 2.0 if zx != 1
      y = (y - Graphics.height / 2.0) * zy + Graphics.height / 2.0 if zy != 1
      Visual25D::StudioTransform.project(x, y)
    end

    def ls_update_chunks(mx, my, zx, zy)
      active = Visual25D.enabled? && Visual25D::StudioOptions.lights?
      sig = [@map&.map_id, mx, my, zx, zy, Visual25D.projection_stamp,
             @ls_chunks&.object_id, Graphics.width, Graphics.height]
      # Los chunks no tienen pulsación: mantener los ya proyectados mientras
      # cámara/luces estáticas no cambien. No repetir miles de asignaciones.
      return if active && @v25_chunks_complete && @v25_chunk_sig == sig
      super
      if !active
        @v25_chunk_sig = nil
        @v25_chunks_complete = false
        return
      end
      return if !@ls_chunks || !defined?(LightingStudio::CHUNK_WORLD)
      @v25_chunk_sig = sig
      size = LightingStudio::CHUNK_WORLD.to_f
      @ls_chunks.each do |key, entry|
        spr, bmp = entry[:sprite], entry[:bitmap]
        next if !spr || spr.disposed? || !spr.visible || !bmp
        y = key[1] * size - my
        y = (y - Graphics.height / 2.0) * zy + Graphics.height / 2.0 if zy != 1
        h = size * zy
        next if h <= 0
        scale = Visual25D.width_scale_at(y + h / 2.0)
        ph = [Visual25D.project_y(y + h) - Visual25D.project_y(y), 1].max
        sx = zx * scale * size / bmp.width.to_f
        sy = ph.to_f / bmp.height.to_f
        spr.zoom_x = sx if (spr.zoom_x - sx).abs > 0.002
        spr.zoom_y = sy if (spr.zoom_y - sy).abs > 0.002
      end
      # No marcar completo mientras queden bloques por construir.
      visible = ls_visible_keys(mx, my, zx, zy)
      @v25_chunks_complete = visible.all? { |key| @ls_chunks.key?(key) }
    end

    def ls_update
      active = Visual25D.enabled? && Visual25D::StudioOptions.lights?
      if active != @v25_lights_active
        @v25_lights_active = active
        @v25_chunks_complete = false
        @v25_chunk_sig = nil
      end
      super
      return if !active || !@map || !@ls_sprites
      my = (@map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
      zy = TilemapRenderer::ZOOM_Y
      # Las luces individuales sí pueden pulsar: el Studio calcula primero el
      # tamaño 2D de este frame. Aplicar la proyección SOLO UNA VEZ después.
      @ls_sprites.each do |spr, entry|
        next if !spr || spr.disposed? || !spr.bitmap
        y = entry[:cy].to_f - my
        y = (y - Graphics.height / 2.0) * zy + Graphics.height / 2.0 if zy != 1
        scale_x = Visual25D.width_scale_at(y)
        scale_y = Visual25D.scale_at(y)
        base_x = spr.zoom_x
        base_y = spr.zoom_y
        target_x = base_x * scale_x
        target_y = base_y * scale_y
        spr.zoom_x = target_x if (base_x - target_x).abs > 0.002
        spr.zoom_y = target_y if (base_y - target_y).abs > 0.002
      end
    end
  end
end

# Solo enganchar si los plugins existen. Orden original/carga independiente.
if defined?(Spriteset_Map)
  if defined?(LBDSAnimatedProps) && Spriteset_Map.method_defined?(:lbds_props_update_sprites) &&
     !Spriteset_Map.ancestors.include?(Visual25D::Props)
    Spriteset_Map.prepend(Visual25D::Props)
  end
  if defined?(LightingStudio) && Spriteset_Map.method_defined?(:ls_update) &&
     Spriteset_Map.method_defined?(:ls_update_chunks) &&
     Spriteset_Map.method_defined?(:ls_world_screen) &&
     !Spriteset_Map.ancestors.include?(Visual25D::Lighting)
    Spriteset_Map.prepend(Visual25D::Lighting)
  end
end

# Perfilado de integraciones sin alterar configuraciones internas de Studio.
def pbVisual25DStudioBridgeTest
  loop do
    props = Visual25D::StudioOptions.props? ? _INTL("Sí") : _INTL("No")
    lights = Visual25D::StudioOptions.lights? ? _INTL("Sí") : _INTL("No")
    ch = pbMessage(_INTL("Adaptadores de Visual 2.5D"),
      [_INTL("Animated Props: {1}", props),
       _INTL("Lighting Studio: {1}", lights), _INTL("Salir")], 3)
    case ch
    when 0
      Visual25D::StudioOptions.props_enabled = !Visual25D::StudioOptions.props?
      Visual25D.redraw_map
    when 1
      Visual25D::StudioOptions.lights_enabled = !Visual25D::StudioOptions.lights?
      Visual25D.redraw_map
    else
      break
    end
  end
end

MenuHandlers.add(:debug_menu, :visual25d_bridges_test, {
  "name" => _INTL("2.5D: adaptadores externos"),
  "parent" => :field_menu,
  "description" => _INTL("Compara FPS y posición con adaptadores activados o desactivados."),
  "effect" => proc { pbVisual25DStudioBridgeTest }
})
