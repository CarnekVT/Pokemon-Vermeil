#===============================================================================
# [VERMEIL] Visual 2.5D - 028_GeometryCollisionAuthority.rb
# V5.11.4 - Deterministic collision source + Maker Studio bridge support.
#
# Important performance rule:
#   Game_Map#passable? NEVER opens/stats/parses Geometry JSON.
# Geometry is loaded by the renderer once, then registered here as an in-memory
# collision source. During the short window before the renderer exists, normal
# map passability is used and no disk lookup is attempted.
#===============================================================================
module Mode7
  class << self
    # Called by Mode7Renderer after it has built the authoritative geometry.
    def register_geometry_collision_source(geo, map_id = nil)
      map_id ||= (defined?($game_map) && $game_map ? $game_map.map_id : 0)
      @geometry_collision_authority_map_id = map_id.to_i
      @geometry_collision_authority_geo = geo
      @geometry_collision_authority_frame = nil
      @geometry_collision_authority_result = nil
      if defined?(Mode7::ModelPhysicsWorld)
        Mode7::ModelPhysicsWorld.register_surface_geometry(map_id, geo)
      end
      geo
    rescue Exception
      nil
    end

    # Lightweight collision preload. This is called once when Game_Map#setup
    # finishes (via MakerStudio/016 bridge), never from passable?. The editor
    # writes MapXXX_collision.json containing only the movement grid.
    def preload_geometry_collision_for_map(map_id, width = nil, height = nil)
      map_id = map_id.to_i
      @geometry_collision_sidecar_cache ||= {}
      cached = @geometry_collision_sidecar_cache[map_id]
      if cached
        @geometry_collision_authority_map_id = map_id
        @geometry_collision_authority_geo = cached
        return cached
      end
      return nil if !defined?(Mode7::SurfaceGeometry)
      dir = if defined?(Config::SURFACE_GEOMETRY_DIRECTORY)
              Config::SURFACE_GEOMETRY_DIRECTORY.to_s
            else
              "Data/VERMEIL2_5D"
            end
      path = File.join(dir, format("Map%03d_collision.json", map_id))
      return nil if !File.file?(path)
      raw = JSON.parse(File.binread(path))
      rows = raw["model_collision_cells"]
      compact_rows = raw["model_collision_cells_compact"]
      if !rows.is_a?(Array) && compact_rows.is_a?(Array)
        rows = compact_rows.map do |r|
          next nil if !r.is_a?(Array)
          collision = case r[2].to_i
                      when 1 then "climb"
                      when 2 then "one-way"
                      when 3 then "none"
                      else "solid"
                      end
          { "x" => r[0], "y" => r[1], "collision" => collision, "base" => r[3], "height" => r[4],
            "model_id" => r[5], "model_instance_id" => r[6], "part_id" => r[7] }
        end.compact
      end
      return nil if !rows.is_a?(Array)
      map = defined?($game_map) ? $game_map : nil
      w = width || (map && map.respond_to?(:width) ? map.width : raw["width"])
      h = height || (map && map.respond_to?(:height) ? map.height : raw["height"])
      step = raw["height_step"] || (defined?(Config::SURFACE_GEOMETRY_HEIGHT_STEP) ? Config::SURFACE_GEOMETRY_HEIGHT_STEP : 32)
      geo = Mode7::SurfaceGeometry.new(map_id, w.to_i, h.to_i, step.to_f, :collision_sidecar, path)
      geo.set_model_collision_cells(rows)
      @geometry_collision_sidecar_cache[map_id] = geo
      register_geometry_collision_source(geo, map_id)
      geo
    rescue Exception => e
      Console.echo_error("VERMEIL collision sidecar #{map_id}: #{e.message}") if defined?(Console)
      nil
    end

    # Hot path. Do NOT add File/JSON calls here.
    def geometry_collision_source
      map = defined?($game_map) ? $game_map : nil
      return nil if !map
      map_id = map.respond_to?(:map_id) ? map.map_id.to_i : 0

      # Prefer the current renderer copy. No file access is involved.
      begin
        if defined?($scene) && $scene && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
          renderer = $scene.instance_variable_get(:@map_renderer)
          if renderer && renderer.respond_to?(:nds_surface_geometry)
            geo = renderer.nds_surface_geometry
            if geo
              register_geometry_collision_source(geo, map_id) if @geometry_collision_authority_geo != geo
              return geo
            end
          end
        end
      rescue Exception
      end

      # Renderer may be temporarily unavailable during a transition/rebuild.
      # Reuse only an already-registered source for this same map.
      return @geometry_collision_authority_geo if @geometry_collision_authority_map_id == map_id
      nil
    rescue Exception
      nil
    end

    def clear_geometry_collision_authority_cache!
      @geometry_collision_authority_map_id = nil
      @geometry_collision_authority_geo = nil
      @geometry_collision_authority_frame = nil
      @geometry_collision_authority_result = nil
    end

    # Resolve the actual destination cell regardless of whether the caller is
    # testing the actor's current tile (RMXP style) or the destination tile
    # (some Maker Studio/native helper paths). This prevents the old off-by-one
    # collision behavior without trapping an actor that is already inside a box.
    def geometry_collision_target_for_call(x, y, dir, self_event = nil, player_hint = false)
      dx, dy = case dir.to_i
               when 2 then [0, 1]
               when 4 then [-1, 0]
               when 6 then [1, 0]
               when 8 then [0, -1]
               else [0, 0]
               end
      tx = x.to_i
      ty = y.to_i
      actor = self_event
      actor = $game_player if !actor && player_hint && defined?($game_player)
      if actor && actor.respond_to?(:x) && actor.respond_to?(:y)
        # When x/y equal the actor's current cell, this is the source-side test;
        # advance once. Otherwise x/y is already the tile being tested.
        if tx == actor.x.to_i && ty == actor.y.to_i
          return [tx + dx, ty + dy, tx, ty]
        end
        return [tx, ty, actor.x.to_i, actor.y.to_i]
      end
      [tx + dx, ty + dy, tx, ty]
    rescue Exception
      [x.to_i, y.to_i, x.to_i, y.to_i]
    end

    # Exact cell test used by the final Maker Studio bridge. It never performs
    # file I/O and never calls Game_Map#passable?, so it cannot recurse.
    def geometry_collision_cell_blocked?(tx, ty, dir = 0, from_x = nil, from_y = nil)
      return false if !defined?(Config::NDS_GEOMETRY_OBJECTS_ENABLED) || !Config::NDS_GEOMETRY_OBJECTS_ENABLED
      map = defined?($game_map) ? $game_map : nil
      return false if !map
      tx = tx.to_i
      ty = ty.to_i
      if map.respond_to?(:width) && map.respond_to?(:height)
        return false if tx < 0 || ty < 0 || tx >= map.width.to_i || ty >= map.height.to_i
      end
      geo = geometry_collision_source
      return false if !geo
      step = geo.respond_to?(:height_step) ? geo.height_step.to_f : 32.0
      max_climb = if defined?(Config::NDS_OBJECT_CLIMB_MAX_TILES)
                    Config::NDS_OBJECT_CLIMB_MAX_TILES.to_i * step
                  else
                    0.0
                  end
      fx = from_x.nil? ? tx : from_x.to_i
      fy = from_y.nil? ? ty : from_y.to_i
      from_south = (dir.to_i == 8 && fy > ty)
      from_north = (dir.to_i == 2 && fy < ty)

      if geo.respond_to?(:model_collision_covering)
        geo.model_collision_covering(tx, ty).each do |cell|
          collision = (cell[:collision] || "solid").to_s
          next if collision == "none"
          base = cell[:base].to_f * step
          top  = base + cell[:height].to_f * step
          case collision
          when "solid"
            return true
          when "climb"
            return true if !from_south || (top - base) > max_climb + 0.01
          when "one-way"
            return true if from_north
          else
            return true
          end
        end
      end

      if geo.respond_to?(:object_covering)
        geo.object_covering(tx, ty).each do |obj|
          cell_mode = geo.respond_to?(:object_footprint_mode) ? geo.object_footprint_mode(obj, tx, ty) : "inherit"
          next if cell_mode == "void"
          collision = cell_mode == "inherit" ? (obj[:collision] || "solid").to_s : cell_mode.to_s
          next if collision == "none"
          case collision
          when "solid"
            return true
          when "climb"
            h = obj[:height].to_f * step
            return true if !from_south || h > max_climb + 0.01
          when "one-way"
            return true if from_north
          else
            return true
          end
        end
      end
      false
    rescue Exception
      false
    end

    def geometry_collision_blocked_for_call?(x, y, dir, self_event = nil, player_hint = false)
      tx, ty, fx, fy = geometry_collision_target_for_call(x, y, dir, self_event, player_hint)
      geometry_collision_cell_blocked?(tx, ty, dir, fx, fy)
    rescue Exception
      false
    end

    def geometry_collision_authority_blocked?(x, y, dir)
      geometry_collision_blocked_for_call?(x, y, dir, nil, false)
    rescue Exception
      false
    end
  end
end

# IMPORTANT:
# Do not wrap/prepend Game_Map#passable? here. Maker Studio aliases passable? in
# 013_EventExtensions.rb; prepending another passability wrapper causes its alias
# to resolve back into the prepended module and can recurse forever.
#
# Geometry collision is consumed by 014_Passability.rb, which is already in the
# normal Maker Studio -> Visual 2.5D -> Essentials call chain. This file is only
# the in-memory collision source/cache.
