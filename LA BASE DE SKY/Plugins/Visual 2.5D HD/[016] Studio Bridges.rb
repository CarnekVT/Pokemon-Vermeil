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
    def self.flat(wx, wy, map, zx, zy, mx = nil, my = nil)
      # Prefer caller's unshifted camera position; it is shared by ALL props
      # for this frame, so no redundant map->pixel conversions per fragment.
      mx = (map.display_x.to_f / Game_Map::X_SUBPIXELS).round if mx.nil?
      my = (map.display_y.to_f / Game_Map::Y_SUBPIXELS).round if my.nil?
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
    # Skyflyer 3.3.0 is the source of truth for the 2.5D tile geometry.
    # LBDS owns animation frames and persistent world coordinates.
    # This optional adapter positions the existing LBDS sprites using Sky's
    # OWN row and column edges. It never creates another camera model.

    def lbds_props_view_bounds(mx, my, zx, zy)
      bounds = super
      return bounds unless Visual25D.enabled? && Visual25D::StudioOptions.props?
      # Keep LBDS spatial buckets; just enough padding for raised bands.
      [bounds[0] - 1, bounds[1] - 2, bounds[2] + 1, bounds[3] + 1]
    end

    # All-zero multirow images are upright sprites unless the author marks
    # them surface/ground/floor. Mixed priorities are native Sky tile bands.
    def v25_props_mode(obj)
      @v25_props_modes ||= {}
      key = obj.object_id
      return @v25_props_modes[key] if @v25_props_modes.key?(key)
      label = (obj[:projection_mode] || obj[:visual25d_mode]).to_s.downcase
      mode = case label
             when "surface", "ground", "floor" then :surface
             when "billboard", "upright", "vertical" then :billboard
             else
               cells = obj[:cells] || []
               has_height = obj[:height].to_i > 1
               priorities = cells.map { |c| c.fetch("priority", 0).to_i }
               has_height && priorities.uniq.length == 1 ? :billboard : :native
             end
      @v25_props_modes[key] = mode
    end

    # Called only by LBDSAnimatedPropsSpriteset when camera geometry changes.
    # Do NOT prepend/wrap lbds_props_update_sprites: doing so writes each
    # sprite in 2D and then again in 2.5D, causing FPS loss and jumps.
    def v25_props_apply_geometry(mx, my, zx, zy)
      return unless @map && @lbds_prop_sprites && !@lbds_prop_sprites.empty?
      return unless Visual25D.enabled? && Visual25D::StudioOptions.props?
      profile = Visual25D.perf_enabled? if Visual25D.respond_to?(:perf_enabled?)
      started = Visual25D.perf_now if profile

      if @v25_props_placements != @lbds_prop_placements.object_id
        @v25_props_placements = @lbds_prop_placements.object_id
        @v25_props_modes = {}
      end
      tw = Game_Map::TILE_WIDTH
      th = Game_Map::TILE_HEIGHT
      sw = LBDSAnimatedProps::CELL_SIZE.to_f
      sh = sw
      offset_y = Visual25D.display_pixel_offset_y(@map)
      field = nil
      field_ready = false
      upright = {}
      map_id = @map.map_id
      @lbds_prop_sprites.each do |entry|
        spr, obj, cx, cy, span, priority, _frame, track, row_span = entry
        row_span ||= 1
        next if !spr || spr.disposed? || !spr.bitmap
        mode = v25_props_mode(obj)
        cell_x = obj[:x].to_i + cx
        cell_y = obj[:y].to_i + cy
        row = Visual25D.grid_row_for_map_cell(@map, cell_y)
        next if row.nil?
        pri = priority.to_i.clamp(0, Visual25D::Config::MAX_PRIORITY)

        if !field_ready && (mode == :surface || mode == :native ||
                            (mode == :billboard && pri > 0))
          field = Visual25D.wall_field(@map)
          field = nil if field && field.flat
          field_ready = true
        end

        # 2D source, calculated from MAP coordinates once: NEVER a value
        # read back from an already projected Sprite.
        flat_x, _flat_y = Visual25D::StudioTransform.flat(
          cell_x * tw, cell_y * th, @map, zx, zy, mx, my)
        taper = 1.0
        if mode == :billboard
          info = upright[obj.object_id]
          if !info
            last_y = obj[:y].to_i + obj[:height].to_i - 1
            base_row = Visual25D.grid_row_for_map_cell(@map, last_y)
            if pri > 0
              # Raised billboards use the exact supporting band of Sky's
              # native priority tile, including Cliff terrain displacement.
              column = Visual25D.column_stack_geom(
                field, cell_x, last_y, base_row, pri, map_id)
              base_y = column[4][pri - 1]
              unit = column[1]
              scale = column[2]
            else
              base_y = Visual25D.row_top_any(base_row + 1)
              unit = Visual25D.row_unit(base_row)
              unit = Visual25D.vertical_unit_at(base_y) if !unit || unit <= 0
              scale = Visual25D.row_width_scale_any(base_row)
            end
            info = [base_y, unit, scale, base_row + pri]
            upright[obj.object_id] = info
          end
          feet, unit, scale, foot_row = info
          remaining = obj[:height].to_i - cy
          top = (feet - remaining * unit).round
          bottom = (feet - (remaining - row_span) * unit).round
          # When an entire billboard is one sprite there is no internal seam.
          # Multi-part billboards use the shared Sky seam at row boundaries.
          bottom += Visual25D.column_band_overlap if row_span == 1 && remaining > 1
          z_row = foot_row
          use_raised_z = true
        elsif mode == :native && pri > 0
          # Exact same shared column stack as Sky native tiles:
          # p1/p2/p3 meet at edges[] even with nonuniform perspective.
          geom = Visual25D.column_stack_geom(field, cell_x, cell_y,
                                               row, pri, map_id)
          scale = geom[2]
          edges = geom[4]
          top = edges[pri]
          bottom = edges[pri - 1]
          bottom += Visual25D.column_band_overlap if pri >= 2
          z_row = row + pri
          use_raised_z = true
        else
          # Ground: project the SAME near/far edges and taper as Tile Depth.
          scale = Visual25D.row_width_scale_any(row)
          if Sprite.method_defined?(:taper=)
            near = Visual25D.row_width_scale_any(row + 1)
            if near && near > 0
              scale = near
              taper = Visual25D.row_taper(row)
            end
          end
          top, bottom = Visual25D.wall_cell_bounds(field, cell_x, cell_y, row)
          z_row = row
          use_raised_z = false
        end

        start_x = Visual25D.project_x(flat_x, scale)
        finish_x = Visual25D.project_x(flat_x + span * tw * zx, scale)
        bottom = top + 1 if bottom <= top
        finish_x = start_x + 1 if finish_x <= start_x
        dest_zoom_x = (finish_x - start_x).to_f / (span * sw)
        dest_zoom_y = (bottom - top).to_f / (sh * row_span)
        spr.x = start_x if spr.x != start_x
        spr.y = top if spr.y != top
        spr.zoom_x = dest_zoom_x if (spr.zoom_x - dest_zoom_x).abs > 0.002
        spr.zoom_y = dest_zoom_y if (spr.zoom_y - dest_zoom_y).abs > 0.002
        if spr.respond_to?(:taper=) && spr.taper != taper
          spr.taper = taper
        end
        depth = ((z_row + 1) * TilemapRenderer::DISPLAY_TILE_HEIGHT) -
                offset_y + 1
        depth_z = Visual25D.raised_tile_z(depth.round) if use_raised_z
        target_z = (use_raised_z ? depth_z : 0) +
                   [obj[:layer].to_i, 5].min + (track == :parallel ? 1 : 0)
        spr.z = target_z if spr.z != target_z
        visible = start_x < Graphics.width && finish_x > 0 &&
                  top < Graphics.height && bottom > 0
        spr.visible = visible if spr.visible != visible
      end
      if profile
        Visual25D.perf_record_props!(@lbds_prop_sprites.length,
          (Visual25D.perf_now - started) * 1000.0) if Visual25D.respond_to?(:perf_record_props!)
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
  # Load-order independent: Sky can compile before LBDS Animated Props.
  # No update hook is installed by this module, so an absent LBDS adds
  # NO runtime work. LBDS itself tests respond_to?(:v25_props_apply_geometry).
  unless Spriteset_Map.ancestors.any? { |ancestor| ancestor.equal?(Visual25D::Props) ||
                                              ancestor.name == "Visual25D::Props" }
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
