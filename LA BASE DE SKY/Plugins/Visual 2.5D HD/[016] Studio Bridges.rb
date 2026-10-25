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
    # Generation V-like representation:
    # - upright Animated Props form ONE camera-facing visual plane per placement
    # - ground-only animated placements follow the tilemap's terrain plane
    # - priority changes depth ordering, never the authored X/Y coordinates
    # All placement data/collision remains owned by LBDS Animated Props.

    def lbds_props_view_bounds(mx, my, zx, zy)
      bounds = super
      return bounds unless Visual25D.enabled? && Visual25D::StudioOptions.props?
      # LBDS already keeps 3 tile margins. Adding 4x6 MORE tiles in both
      # directions kept hundreds of invisible sprites alive during movement.
      # Upright sprites need only a small extra SOUTH margin for tall tops.
      [bounds[0] - 1, bounds[1], bounds[2] + 1, bounds[3] + 2]
    end

    def v25_prop_surface?(obj)
      # Overrides may be supplied by a future authoring/editor bridge without
      # modifying LBDS Animated Props' data schema.
      modes = (@v25_prop_modes ||= {})
      id = obj.object_id
      return modes[id] if modes.key?(id)
      specified = (obj[:visual25d_mode] || obj[:projection_mode]).to_s.downcase
      mode = case specified
             when "surface", "ground", "floor" then true
             when "billboard", "upright", "vertical" then false
             else
               # Una animacion de varias filas es normalmente un objeto
               # vertical, aunque el usuario no haya asignado prioridades.
               # Solo las tiras de una fila sin prioridad son suelo por defecto.
               cells = obj[:cells] || []
               obj[:height].to_i <= 1 &&
                 !cells.any? { |cell| cell && cell.fetch("priority", 0).to_i > 0 }
             end
      modes[id] = mode
      return mode
    end

    # Invocado desde LBDS Animated Props solo cuando cambia la camara o
    # cuando se crean sprites visibles. El runtime base muestrea fotogramas y
    # NO toca sus posiciones en el modo 2.5D: solo existe una ruta geometrica.
    def v25_props_apply_geometry(mx, my, zx, zy)
      return unless @map && @lbds_prop_sprites && !@lbds_prop_sprites.empty?
      return unless Visual25D.enabled? && Visual25D::StudioOptions.props?

      if @v25_prop_mode_list != @lbds_prop_placements.object_id
        @v25_prop_modes = {}
        @v25_prop_mode_list = @lbds_prop_placements.object_id
      end

      tw = Game_Map::TILE_WIDTH
      th = Game_Map::TILE_HEIGHT
      zx = TilemapRenderer::ZOOM_X
      zy = TilemapRenderer::ZOOM_Y
      src_width = LBDSAnimatedProps::CELL_SIZE.to_f
      src_height = LBDSAnimatedProps::CELL_SIZE.to_f
      pixel_offset_y = Visual25D.display_pixel_offset_y(@map)
      # Los billboards verticales no necesitan escanear WallField.
      # Leer el terreno solo si hay una superficie animada.
      field = nil
      field_ready = false
      # One projected anchor per placement. Fragments with different priorities
      # MUST share this anchor and the same scaling to prevent visible tears.
      anchors = {}

      @lbds_prop_sprites.each do |entry|
        spr, obj, cx, cy, span, pri, _frame, track = entry
        next if !spr || spr.disposed? || !spr.bitmap
        priority = pri.to_i
        priority = 0 if priority < 0
        priority = Visual25D::Config::MAX_PRIORITY if priority > Visual25D::Config::MAX_PRIORITY
        cell_x = obj[:x].to_i + cx
        cell_y = obj[:y].to_i + cy
        row = Visual25D.grid_row_for_map_cell(@map, cell_y)

        if v25_prop_surface?(obj)
          if !field_ready
            field = Visual25D.wall_field(@map)
            field = nil if field && field.flat
            field_ready = true
          end
          # Terrain planes: same Y edges, row width and taper as native tiles.
          flat_x, _flat_y = Visual25D::StudioTransform.flat(
            cell_x * tw, cell_y * th, @map, zx, zy)
          scale = Visual25D.row_width_scale_any(row)
          taper = 1.0
          if Visual25D::TAPER_SUPPORTED
            near_scale = Visual25D.row_width_scale_any(row + 1)
            if near_scale && near_scale > 0
              scale = near_scale
              taper = Visual25D.row_taper(row)
            end
          end
          left = Visual25D.project_x(flat_x, scale)
          right = Visual25D.project_x(flat_x + span * tw * zx, scale)
          top, bottom = Visual25D.wall_cell_bounds(field, cell_x, cell_y, row)
        else
          anchor = anchors[obj.object_id]
          if !anchor
            # World-space contact point at the SOUTH edge of the placement,
            # not at y+priority (a priority is not a world-space coordinate).
            flat_x, foot_y = Visual25D::StudioTransform.flat(
              obj[:x].to_i * tw,
              (obj[:y].to_i + obj[:height].to_i) * th,
              @map, zx, zy)
            scale = Visual25D.width_scale_at(foot_y)
            px = Visual25D.project_x(flat_x, scale)
            py = Visual25D.project_y(foot_y)
            # vertical_unit_at ya esta expresado en pixeles de DISPLAY tile;
            # multiplicar por ZOOM_Y otra vez duplicaba la escala al moverse.
            unit = Visual25D.vertical_unit_at(foot_y)
            anchor = [px, py, scale, unit]
            anchors[obj.object_id] = anchor
          end
          px, py, scale, unit = anchor
          left = px + (cx * tw * zx * scale).round
          right = px + ((cx + span) * tw * zx * scale).round
          # Compute both edges from ONE unrounded baseline. Independently
          # rounded per-band positions created gaps while scrolling vertically.
          top = (py - ((obj[:height] - cy) * unit)).round
          bottom = (py - ((obj[:height] - cy - 1) * unit)).round
          taper = 1.0
        end

        right = left + 1 if right <= left
        bottom = top + 1 if bottom <= top
        target_x = left.round
        target_y = top.round
        spr.x = target_x if spr.x != target_x
        spr.y = target_y if spr.y != target_y
        new_zx = (right - left).to_f / (span * src_width)
        new_zy = (bottom - top).to_f / src_height
        spr.zoom_x = new_zx if (spr.zoom_x - new_zx).abs > 0.002
        spr.zoom_y = new_zy if (spr.zoom_y - new_zy).abs > 0.002
        spr.taper = taper if spr.respond_to?(:taper=) && spr.taper != taper

        if priority > 0
          depth = ((row + priority + 1) * TilemapRenderer::DISPLAY_TILE_HEIGHT) -
                  pixel_offset_y + 1 + priority
          target_z = Visual25D.raised_tile_z(depth.round) +
                     [obj[:layer].to_i, 5].min + (track == :parallel ? 1 : 0)
        else
          target_z = [obj[:layer].to_i, 5].min + (track == :parallel ? 1 : 0)
        end
        spr.z = target_z if spr.z != target_z
        shown = left < Graphics.width && right > 0 &&
                top < Graphics.height && bottom > 0
        spr.visible = shown if spr.visible != shown
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
