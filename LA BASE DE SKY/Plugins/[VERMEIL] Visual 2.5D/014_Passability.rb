#===============================================================================
# [VERMEIL] Visual 2.5D - 014_Passability.rb
# V4.3.2 - Pasabilidad limpia del sistema NDS.
#
# El plugin ya NO altera Mountains, Ladders ni ningun Terrain Tag ajeno.
# Bloquea paredes explicitas y el cuerpo superior de estructuras/billboards.
# El borde inferior conserva la pasabilidad configurada en el tileset para no
# cerrar puertas, sombras ni puntos de entrada.
#===============================================================================
class Mode7Renderer
  def solid_cell_at?(x, y)
    return false if disposed? || !@walls_known
    tx = x.to_i
    ty = y.to_i
    return true if wall_cell_at?(tx, ty)
    entries = @entry_cache && @entry_cache[[tx, ty]]
    return false if !entries || entries.empty?

    rigid_ids = [
      Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG,
      Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG
    ]
    cell_ids = entries.filter_map do |entry|
      id = nds_category_id(entry)
      rigid_ids.include?(id) ? id : nil
    end
    return false if cell_ids.empty?

    below = @entry_cache[[tx, ty + 1]]
    return false if !below || below.empty?
    # ponytail: continuidad vertical basta; matriz manual solo si un asset
    # necesita huecos internos distintos de su pasabilidad del tileset.
    below.any? { |entry| cell_ids.include?(nds_category_id(entry)) }
  rescue Exception
    false
  end
end

module Mode7
  class << self
    def surface_transition_blocked?(x, y, dir)
      return false if !Config::NDS_MOUNTAIN_HEIGHT_COLLISION
      return false if !rendering_now? || !$scene.is_a?(Scene_Map)
      dx, dy = case dir.to_i
               when 2 then [0, 1]
               when 4 then [-1, 0]
               when 6 then [1, 0]
               when 8 then [0, -1]
               else return false
               end
      x0 = x.to_i
      y0 = y.to_i
      x1 = x0 + dx
      y1 = y0 + dy
      return false if x1 < 0 || y1 < 0 || x1 >= $game_map.width || y1 >= $game_map.height

      renderer = $scene.instance_variable_get(:@map_renderer)
      return false if !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      # Una rampa explicita es el unico puente visual entre dos niveles.
      if renderer.respond_to?(:nds_stair_cell?, true)
        return false if renderer.send(:nds_stair_cell?, x0, y0) ||
                        renderer.send(:nds_stair_cell?, x1, y1)
      end
      h0 = nds_surface_height_at(x0, y0).to_f
      h1 = nds_surface_height_at(x1, y1).to_f
      (h0 - h1).abs > Config::NDS_MOUNTAIN_COLLISION_EPSILON.to_f
    rescue Exception
      false
    end

    # -------------------------------------------------------------------------
    # Objetos Geometry (cubos/planos del editor). Cada objeto bloquea el paso
    # hacia su footprint segun su flag de colision:
    #   none     -> decoracion, nunca bloquea
    #   solid    -> bloquea desde cualquier direccion
    #   climb    -> bloquea salvo por la cara sur (dir 8) y solo si la altura
    #               del objeto no supera NDS_OBJECT_CLIMB_MAX_TILES
    #   one-way  -> bloquea SOLO desde el norte (dir 2); sur/este/oeste pasan
    # La evaluacion usa la celda destino (x+dx, y+dy) para no encerrar al actor
    # que ya esta dentro del footprint.
    # -------------------------------------------------------------------------
    def object_cell_blocked?(x, y, dir)
      return false if !Config::NDS_GEOMETRY_OBJECTS_ENABLED
      dx, dy = case dir.to_i
               when 2 then [0, 1]
               when 4 then [-1, 0]
               when 6 then [1, 0]
               when 8 then [0, -1]
               else return false
               end
      x0 = x.to_i
      y0 = y.to_i
      x1 = x0 + dx
      y1 = y0 + dy
      return false if x1 < 0 || y1 < 0 || x1 >= $game_map.width || y1 >= $game_map.height

      # V25 model collision authority. El sidecar .v25c se precarga al montar
      # el mapa y vive en un Hash O(1). Consultarlo aqui hace que la colision de
      # modelos use EXACTAMENTE la misma ruta que passable?/playerPassable?, sin
      # depender de Game_Player#can_move_in_direction? ni del renderer visual.
      if defined?(Mode7::ModelPhysicsWorld) &&
         Mode7::ModelPhysicsWorld.respond_to?(:blocked_cell?)
        return true if Mode7::ModelPhysicsWorld.blocked_cell?(x1, y1, dir, x0, y0)
      end

      # Collision must never depend on renderer visibility or perform file I/O.
      # 028_GeometryCollisionAuthority keeps the already-loaded Geometry object in
      # memory. During renderer rebuilds/transitions we continue using that source.
      geo = nil
      if Mode7.respond_to?(:geometry_collision_source)
        geo = Mode7.geometry_collision_source
      end
      if !geo && rendering_now? && $scene.is_a?(Scene_Map)
        renderer = $scene.instance_variable_get(:@map_renderer)
        if renderer.is_a?(Mode7Renderer) && !renderer.disposed?
          geo = renderer.nds_surface_geometry
        end
      end
      return false if !geo

      step = geo.height_step.to_f
      max_climb = Config::NDS_OBJECT_CLIMB_MAX_TILES.to_i * step

      # v2.9.5+: model collision is compiled independently from render meshes.
      # The editor rasterizes each custom/automatic collision volume onto the
      # RPG Maker movement grid, so a visible model cannot be walked through
      # merely because its render mesh and legacy object footprint disagree.
      if geo.respond_to?(:model_collision_covering)
        cells = geo.model_collision_covering(x1, y1)
        cells.each do |cell|
          collision = (cell[:collision] || "solid").to_s
          next if collision == "none"
          base = cell[:base].to_f * step
          top = base + cell[:height].to_f * step
          from_south = (dir.to_i == 8 && y0 == y1 + 1)
          from_north = (dir.to_i == 2 && y0 == y1 - 1)
          case collision
          when "solid"
            return true
          when "climb"
            return true if !from_south
            return true if (top - base) > max_climb + 0.01
          when "one-way"
            return true if from_north
          else
            return true
          end
        end
      end

      # Legacy/manual Geometry objects remain supported.
      return false if !geo.respond_to?(:object_covering)
      objs = geo.object_covering(x1, y1)
      return false if objs.empty?

      objs.each do |obj|
        cell_mode = geo.respond_to?(:object_footprint_mode) ? geo.object_footprint_mode(obj, x1, y1) : "inherit"
        next if cell_mode == "void"
        collision = cell_mode == "inherit" ? (obj[:collision] || "solid").to_s : cell_mode.to_s
        next if collision == "none"
        ox = obj[:x].to_i
        oy = obj[:y].to_i
        ow = obj[:w].to_i
        oh = obj[:h].to_i
        base = obj[:anchor_z].to_f * step
        top = obj[:type].to_s == "cube" ? base + obj[:height].to_f * step : base
        from_south = y0 == oy + oh && dir == 8
        from_north = y0 == oy - 1 && dir == 2
        case collision
        when "solid"
          return true
        when "climb"
          return true if !from_south
          return true if (top - base) > max_climb + 0.01
        when "one-way"
          return true if from_north
        end
      end
      false
    rescue Exception
      false
    end

    # passable?, passableStrict? and playerPassable? can ask the same 2.5D
    # question several times during a single movement frame. Cache the combined
    # static geometry result for that frame to remove duplicate Ruby lookups.
    def movement_blocked_cached?(x, y, dir)
      frame = Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : 0
      map_id = ($game_map && $game_map.respond_to?(:map_id)) ? $game_map.map_id.to_i : 0
      if @movement_block_cache_frame != frame || @movement_block_cache_map != map_id
        @movement_block_cache_frame = frame
        @movement_block_cache_map = map_id
        @movement_block_cache = {}
      end
      key = [x.to_i, y.to_i, dir.to_i]
      return @movement_block_cache[key] if @movement_block_cache.key?(key)
      value = solid_cell_at?(x, y) ||
              surface_transition_blocked?(x, y, dir) ||
              object_cell_blocked?(x, y, dir)
      @movement_block_cache[key] = value
      value
    rescue Exception
      false
    end

    # V5.10 transitional compatibility for maps authored in 2D:
    # MountainWall rows are artwork sampled by the vertical cliff renderer.
    # Their old tileset passability must not create a second collision wall in
    # front of the physical height edge. Other VERMEIL solids still win.
    def decorative_mountain_wall_transition?(x, y, dir)
      return false if !Config::SURFACE_GEOMETRY_ENABLED || !Config::NDS_MOUNTAIN_AUTO_FACES
      return false if !rendering_now? || !$scene.is_a?(Scene_Map)
      dx, dy = case dir.to_i
               when 2 then [0, 1]
               when 4 then [-1, 0]
               when 6 then [1, 0]
               when 8 then [0, -1]
               else return false
               end
      x0 = x.to_i
      y0 = y.to_i
      x1 = x0 + dx
      y1 = y0 + dy
      return false if x1 < 0 || y1 < 0 || x1 >= $game_map.width || y1 >= $game_map.height
      renderer = $scene.instance_variable_get(:@map_renderer)
      return false if !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      return false if !renderer.respond_to?(:nds_mountain_art_cell?, true)
      art = renderer.send(:nds_mountain_art_cell?, x0, y0) ||
            renderer.send(:nds_mountain_art_cell?, x1, y1)
      return false if !art
      return false if surface_transition_blocked?(x0, y0, dir)
      return false if renderer.solid_cell_at?(x0, y0) || renderer.solid_cell_at?(x1, y1)
      true
    rescue Exception
      false
    end

    def solid_cell_at?(x, y)
      return false if !Config::WALL_BLOCKS_MOVEMENT
      if indoor_map? && defined?(Config::INDOOR_WALL_BLOCKS_MOVEMENT) &&
         !Config::INDOOR_WALL_BLOCKS_MOVEMENT
        return false
      end
      return false if !rendering_now? || !$scene.is_a?(Scene_Map)
      renderer = $scene.instance_variable_get(:@map_renderer)
      return false if !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      renderer.solid_cell_at?(x, y)
    rescue Exception
      false
    end
  end
end

# Envuelve la pasabilidad final del mapa sin tocar mecanicas de otros tags.
module Passability_2p5D
  def self.patch_base!
    return if Game_Map.method_defined?(:_ZBOX_25D_orig_passable)
    Game_Map.class_eval do
      alias_method :_ZBOX_25D_orig_passable, :passable?
      def passable?(x, y, dir, self_event = nil)
        if Mode7.movement_blocked_cached?(x, y, dir)
          return false if !self_event || !self_event.through
        end
        result = _ZBOX_25D_orig_passable(x, y, dir, self_event)
        return true if !result && Mode7.decorative_mountain_wall_transition?(x, y, dir)
        result
      end

      alias_method :_ZBOX_25D_orig_passable_strict, :passableStrict?
      def passableStrict?(x, y, dir, self_event = nil)
        return false if Mode7.movement_blocked_cached?(x, y, dir)
        result = _ZBOX_25D_orig_passable_strict(x, y, dir, self_event)
        return true if !result && Mode7.decorative_mountain_wall_transition?(x, y, dir)
        result
      end

      alias_method :_ZBOX_25D_orig_player_passable, :playerPassable?
      def playerPassable?(x, y, dir, self_event = nil)
        return false if Mode7.movement_blocked_cached?(x, y, dir)
        result = _ZBOX_25D_orig_player_passable(x, y, dir, self_event)
        return true if !result && Mode7.decorative_mountain_wall_transition?(x, y, dir)
        result
      end
    end
  end
end

Passability_2p5D.patch_base!
