#===============================================================================
# [VERMEIL] Visual 2.5D - 029_ModelPhysics.rb
# V5.12.1 - Independent player/model physics gate + compact sidecar.
#
# Model collision no longer depends on Game_Map#passable?. Maker Studio and
# Essentials may replace/short-circuit tile passability in different orders;
# player movement is gated one level earlier at Game_Player#can_move_in_direction?.
# The hot path is an O(1) Hash lookup and never touches disk or JSON.
#===============================================================================
module Mode7
  module ModelPhysicsWorld
    class << self
      def clear!
        @worlds = {}
        @active_map_id = nil
        @active_cells = nil
      end

      def collision_path(map_id)
        dir = if defined?(Mode7::Config::SURFACE_GEOMETRY_DIRECTORY)
                Mode7::Config::SURFACE_GEOMETRY_DIRECTORY.to_s
              else
                "Data/VERMEIL2_5D"
              end
        File.join(dir, format("Map%03d_collision.json", map_id.to_i))
      end

      def build_index(rows)
        cells = {}
        Array(rows).each do |row|
          next if !row.is_a?(Hash)
          collision = (row["collision"] || row[:collision] || "solid").to_s
          next if collision == "none"
          x = (row["x"] || row[:x]).to_i
          y = (row["y"] || row[:y]).to_i
          entry = {
            collision: collision,
            base: (row["base"] || row[:base] || 0).to_f,
            height: (row["height"] || row[:height] || 0.05).to_f,
            model_id: (row["model_id"] || row[:model_id]).to_s,
            model_instance_id: (row["model_instance_id"] || row[:model_instance_id]).to_i,
            part_id: (row["part_id"] || row[:part_id]).to_s
          }
          (cells[[x, y]] ||= []) << entry
        end
        cells
      end

      # Compact sidecar rows: [x,y,collisionCode,base,height,modelId,instanceId,partId]
      # 0=solid, 1=climb, 2=one-way. This cuts JSON size/key allocation sharply.
      def build_index_compact(rows)
        cells = {}
        Array(rows).each do |row|
          next if !row.is_a?(Array) || row.length < 5
          collision = case row[2].to_i
                      when 1 then "climb"
                      when 2 then "one-way"
                      when 3 then "none"
                      else "solid"
                      end
          next if collision == "none"
          x = row[0].to_i
          y = row[1].to_i
          entry = { collision: collision, base: row[3].to_f, height: row[4].to_f,
                    model_id: row[5].to_s, model_instance_id: row[6].to_i, part_id: row[7].to_s }
          (cells[[x, y]] ||= []) << entry
        end
        cells
      end

      # Called once from Game_Map#setup. This is the only disk access needed by
      # model physics. Missing sidecars are negatively cached for the session.
      def preload(map_id)
        map_id = map_id.to_i
        @worlds ||= {}
        if @worlds.key?(map_id)
          activate(map_id, @worlds[map_id])
          return @worlds[map_id]
        end
        path = collision_path(map_id)
        cells = {}
        if File.file?(path) && defined?(JSON)
          raw = JSON.parse(File.binread(path))
          if raw.is_a?(Hash)
            if raw["model_collision_cells_compact"].is_a?(Array)
              cells = build_index_compact(raw["model_collision_cells_compact"])
            else
              cells = build_index(raw["model_collision_cells"])
            end
          end
        end
        @worlds[map_id] = cells
        activate(map_id, cells)
        cells
      rescue Exception => e
        Console.echo_error("VERMEIL ModelPhysics preload #{map_id}: #{e.message}") if defined?(Console)
        @worlds ||= {}
        @worlds[map_id] = {}
        activate(map_id, {})
        {}
      end

      # Renderer/editor geometry can refresh the active world without any file
      # access (useful after a transfer/rebuild or debug reload).
      def register_rows(map_id, rows)
        map_id = map_id.to_i
        @worlds ||= {}
        cells = build_index(rows)
        @worlds[map_id] = cells
        activate(map_id, cells)
        cells
      rescue Exception
        nil
      end

      def register_surface_geometry(map_id, geo)
        return nil if !geo
        rows_hash = geo.instance_variable_get(:@model_collision_cells) rescue nil
        rows = []
        if rows_hash.is_a?(Hash)
          rows_hash.each_value { |arr| rows.concat(Array(arr)) }
        end
        # Runtime visual sidecars intentionally omit model collision in v5.12.1;
        # keep the already-preloaded compact physics world instead of replacing it
        # with an empty hash when the renderer registers its geometry.
        return (@worlds && @worlds[map_id.to_i]) if rows.empty? && @worlds && @worlds.key?(map_id.to_i)
        register_rows(map_id, rows)
      rescue Exception
        nil
      end

      def activate(map_id, cells)
        @active_map_id = map_id.to_i
        @active_cells = cells || {}
      end

      def cells
        map_id = if defined?($game_map) && $game_map && $game_map.respond_to?(:map_id)
                   $game_map.map_id.to_i
                 else
                   @active_map_id.to_i
                 end
        return @active_cells if @active_map_id == map_id && @active_cells
        @worlds ||= {}
        activate(map_id, @worlds[map_id] || {})
        @active_cells
      end

      def delta(dir)
        case dir.to_i
        when 1 then [-1, 1]
        when 2 then [0, 1]
        when 3 then [1, 1]
        when 4 then [-1, 0]
        when 6 then [1, 0]
        when 7 then [-1, -1]
        when 8 then [0, -1]
        when 9 then [1, -1]
        else [0, 0]
        end
      end

      def blocked_cell?(tx, ty, dir = 0, fx = nil, fy = nil)
        list = cells[[tx.to_i, ty.to_i]]
        return false if !list || list.empty?
        fx = tx.to_i if fx.nil?
        fy = ty.to_i if fy.nil?
        list.each do |cell|
          case cell[:collision].to_s
          when "none"
            next
          when "solid", ""
            return true
          when "one-way"
            # Same convention as Geometry: blocks entry from north/downward.
            return true if dir.to_i == 2 && fy.to_i < ty.to_i
          when "climb"
            # Model physics deliberately treats climb as a wall except for the
            # established south->north climb direction and configured height.
            from_south = dir.to_i == 8 && fy.to_i > ty.to_i
            return true if !from_south
            max_tiles = defined?(Mode7::Config::NDS_OBJECT_CLIMB_MAX_TILES) ? Mode7::Config::NDS_OBJECT_CLIMB_MAX_TILES.to_f : 0.0
            return true if cell[:height].to_f > max_tiles + 0.001
          else
            return true
          end
        end
        false
      rescue Exception
        false
      end

      def blocked_move?(actor, dir)
        return false if !actor || !actor.respond_to?(:x) || !actor.respond_to?(:y)
        dx, dy = delta(dir)
        return false if dx == 0 && dy == 0
        fx = actor.x.to_i
        fy = actor.y.to_i
        tx = fx + dx
        ty = fy + dy
        map = defined?($game_map) ? $game_map : nil
        if map && map.respond_to?(:width) && map.respond_to?(:height)
          return false if tx < 0 || ty < 0 || tx >= map.width.to_i || ty >= map.height.to_i
        end
        # For diagonal movement, block if destination itself is occupied. The
        # engine's own corner/passability rules still run afterward via super.
        blocked_cell?(tx, ty, dir, fx, fy)
      rescue Exception
        false
      end
    end
  end
end

# This hook is intentionally on player movement, not Game_Map#passable?. It
# therefore cannot recurse with Maker Studio's passability aliases.
if defined?(Game_Player)
  module VermeilModelPhysicsPlayerGate
    def can_move_in_direction?(dir, strict = false)
      bypass = respond_to?(:through) && through
      if !bypass && defined?(Mode7::ModelPhysicsWorld) &&
         Mode7::ModelPhysicsWorld.blocked_move?(self, dir)
        return false
      end
      super
    end
  end
  Game_Player.prepend(VermeilModelPhysicsPlayerGate) unless Game_Player.ancestors.include?(VermeilModelPhysicsPlayerGate)
end
