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
    # El runtime original conserva las posiciones en casillas reales; este puente
    # solo transforma el dibujo, nunca los datos, la colision ni los placements.
    # El modelo es el de los PLANOS del TilemapRenderer, no una camara cilindrica.

    def lbds_props_view_bounds(mx, my, zx, zy)
      bounds = super
      return bounds unless Visual25D.enabled? && Visual25D::StudioOptions.props?
      [bounds[0] - 2, bounds[1] - 2, bounds[2] + 2, bounds[3] + 2]
    end

    def lbds_props_update_sprites
      active = Visual25D.enabled? && Visual25D::StudioOptions.props?
      if active != @v25_props_active
        @lbds_prop_geometry_stamp = nil
        @lbds_prop_active_bounds = nil
        @v25_props_camera = nil
        @v25_props_active = active
      end

      # Animated Props escribe coordenadas 2D y zoom cada vez que avanza un
      # fotograma de animacion (aunque la camara este quieta). Guardar el estado
      # ANTES de super permite saber si se han reseteado los sprites y volver
      # a proyectarlos sin exigir movimiento de camara.
      previous_slot = @lbds_prop_frame_slot
      previous_geometry = @lbds_prop_geometry_stamp
      previous_sprites = @lbds_prop_sprites ? @lbds_prop_sprites.object_id : nil
      super
      return unless active && @map && @lbds_prop_sprites && !@lbds_prop_sprites.empty?

      # Mismo sistema de filas/scroll que tiles nativos y MakerStudio.
      # Primero sincronizar el terreno; no reproyectar una imagen ya proyectada.
      Visual25D.sync_projection_from_map!(@map)
      camera = [@map.map_id, @map.display_x, @map.display_y,
                Visual25D.projection_stamp, Visual25D.tilt,
                Visual25D.camera_zoom, Graphics.width, Graphics.height,
                @lbds_prop_sprites.object_id]
      source_changed = (previous_slot != @lbds_prop_frame_slot ||
                        previous_geometry != @lbds_prop_geometry_stamp ||
                        previous_sprites != @lbds_prop_sprites.object_id)
      return if !source_changed && @v25_props_camera == camera
      @v25_props_camera = camera

      zx = TilemapRenderer::ZOOM_X
      zy = TilemapRenderer::ZOOM_Y
      tw = Game_Map::TILE_WIDTH
      th = Game_Map::TILE_HEIGHT
      src_h = TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
      pixel_offset_y = Visual25D.display_pixel_offset_y(@map)
      field = Visual25D.wall_field(@map)
      field = nil if field && field.flat

      @lbds_prop_sprites.each do |entry|
        spr, obj, cx, cy, span, pri, _frame, track = entry
        next unless spr && !spr.disposed? && spr.bitmap
        cell_x = obj[:x].to_i + cx
        cell_y = obj[:y].to_i + cy
        priority = pri.to_i
        priority = 0 if priority < 0
        priority = Visual25D::Config::MAX_PRIORITY if priority > Visual25D::Config::MAX_PRIORITY

        # Origen X de la MISMA casilla, antes de proyectarla. La Y de cada
        # franja viene de las aristas del tilemap, no de mover el sprite N
        # casillas hacia abajo cuando su prioridad es N.
        flat_x, _flat_y = Visual25D::StudioTransform.flat(
          cell_x * tw, cell_y * th, @map, zx, zy)
        row = Visual25D.grid_row_for_map_cell(@map, cell_y)

        if priority > 0
          # Comparte exactamente el plano vertical de los tiles con prioridad.
          # Dos franjas de la misma columna encajan en la misma arista.
          geom = Visual25D.column_stack_geom(
            field, cell_x, cell_y, row, priority, @map.map_id)
          scale = geom[2]
          edges = geom[4]
          top = edges[priority]
          bottom = edges[priority - 1]
          bottom += Visual25D::COLUMN_BAND_OVERLAP if priority >= 2
          taper = 1.0
          z_raw = ((row + priority + 1) * TilemapRenderer::DISPLAY_TILE_HEIGHT) -
                  pixel_offset_y + 1 + priority
          spr.z = Visual25D.raised_tile_z(z_raw.round) +
                  [obj[:layer].to_i, 5].min + (track == :parallel ? 1 : 0)
        else
          # El suelo sigue las aristas del plano, incluidos desniveles Cliff.
          # La anchura toma la arista inferior igual que Tile Depth.
          scale = Visual25D.row_width_scale_any(row)
          taper = 1.0
          if Visual25D::TAPER_SUPPORTED
            near_scale = Visual25D.row_width_scale_any(row + 1)
            if near_scale && near_scale > 0
              scale = near_scale
              taper = Visual25D.row_taper(row)
            end
          end
          top, bottom = Visual25D.wall_cell_bounds(field, cell_x, cell_y, row)
          spr.z = [obj[:layer].to_i, 5].min + (track == :parallel ? 1 : 0)
        end

        height = bottom - top
        height = 1 if height < 1
        sx = Visual25D.project_x(flat_x, scale)
        xzoom = zx * scale
        yzoom = height / src_h
        spr.x = sx.round
        spr.y = top.round
        spr.zoom_x = xzoom if (spr.zoom_x - xzoom).abs > 0.002
        spr.zoom_y = yzoom if (spr.zoom_y - yzoom).abs > 0.002
        # Algunos runtimes MK admiten taper en Sprite: mantener la misma
        # arista del suelo sin tocar los fotogramas ni generar bitmaps nuevos.
        spr.taper = taper if spr.respond_to?(:taper=)
        spr.visible = sx < Graphics.width && top < Graphics.height &&
                      sx + span * tw * xzoom > 0 && bottom > 0
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
