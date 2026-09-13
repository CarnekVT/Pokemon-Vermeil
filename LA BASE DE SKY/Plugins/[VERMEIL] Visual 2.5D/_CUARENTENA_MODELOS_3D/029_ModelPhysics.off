#===============================================================================
# [VERMEIL] Visual 2.5D - 029_ModelPhysics.rb
# V5.12.1 - Independent player/model physics gate + compact sidecar.
#
# Model collision no longer depends on Game_Map#passable?. Maker Studio and
# Essentials may replace/short-circuit tile passability in different orders;
# player movement is gated one level earlier at Game_Player#can_move_in_direction?.
# The hot path is an O(1) Hash lookup and never touches disk while the player is moving.
#===============================================================================
module Mode7
  module ModelPhysicsWorld
    class << self
      def clear!
        @worlds = {}
        @active_map_id = nil
        @active_cells = nil
        @sidecar_authoritative = {}
        @surface_fallback_maps = {}
        @surface_geometry_ids = {}
      end

      def collision_path(map_id)
        dir = if defined?(Mode7::Config::SURFACE_GEOMETRY_DIRECTORY)
                Mode7::Config::SURFACE_GEOMETRY_DIRECTORY.to_s
              else
                "Data/VERMEIL_GEOMETRY_V4"
              end
        File.join(dir, format("Map%03d.v25c", map_id.to_i))
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

      # Called once from Game_Map#setup. V6.1 reads the compact V25C2 sidecar.
      # No JSON and no visual model/mesh data are part of this path.
      def preload(map_id)
        map_id = map_id.to_i
        @worlds ||= {}
        @sidecar_authoritative ||= {}
        @surface_fallback_maps ||= {}
        path = collision_path(map_id)
        has_sidecar = File.file?(path)
        @sidecar_authoritative[map_id] = has_sidecar

        if has_sidecar
          cells = if defined?(Mode7::GeometryV4Fast)
                    Mode7::GeometryV4Fast.load_collision(path)
                  else
                    {}
                  end
          @worlds[map_id] = cells || {}
          @surface_fallback_maps.delete(map_id)
          activate(map_id, @worlds[map_id])
          return @worlds[map_id]
        end

        # No .v25c: do not freeze an empty world as authoritative. The renderer
        # will register the already-loaded .v25r geometry a few lines later.
        @worlds[map_id] ||= {}
        activate(map_id, @worlds[map_id])
        @worlds[map_id]
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

      # Build an O(1) collision grid directly from runtime Geometry when the
      # project has no MapXXX.v25c. This keeps gameplay collision authoritative
      # even for imported models that only ship in .v25r/.v25m.
      def build_surface_fallback_cells(geo)
        cells = {}
        return cells if !geo
        step = geo.respond_to?(:height_step) ? geo.height_step.to_f : 32.0
        step = 32.0 if step <= 0.001

        model_object_keys = {}
        objects = geo.respond_to?(:objects) ? (geo.objects || []) : []
        objects.each do |obj|
          next if !obj.is_a?(Hash)
          model_key = [obj[:model_id].to_s, obj[:model_instance_id].to_i]
          model_object_keys[model_key] = true if !model_key[0].empty? || model_key[1] != 0
          ox = obj[:x].to_i
          oy = obj[:y].to_i
          ow = [obj[:w].to_i, 1].max
          oh = [obj[:h].to_i, 1].max
          oy.upto(oy + oh - 1) do |ty|
            ox.upto(ox + ow - 1) do |tx|
              mode = geo.respond_to?(:object_footprint_mode) ? geo.object_footprint_mode(obj, tx, ty) : "inherit"
              next if mode == "void"
              collision = mode == "inherit" ? (obj[:collision] || "solid").to_s : mode.to_s
              next if collision == "none"
              entry = {
                collision: collision,
                base: obj[:anchor_z].to_f,
                height: [obj[:height].to_f, 0.05].max,
                model_id: obj[:model_id].to_s,
                model_instance_id: obj[:model_instance_id].to_i,
                part_id: obj[:id].to_s
              }
              (cells[[tx, ty]] ||= []) << entry
            end
          end
        end

        # Mesh-only imported models: derive a conservative XY convex footprint.
        # Terrain/mountain faces have no model identity and are deliberately
        # ignored. If an O-record exists for this model, its authored collision
        # above remains authoritative (including collision=none).
        grouped = Hash.new { |h, k| h[k] = { pts: [], min_z: nil, max_z: nil } }
        faces = geo.respond_to?(:mesh_faces) ? (geo.mesh_faces || []) : []
        faces.each do |face|
          next if !face.is_a?(Hash)
          key = [face[:model_id].to_s, face[:model_instance_id].to_i]
          next if key[0].empty? && key[1] == 0
          next if model_object_keys[key]
          group = grouped[key]
          verts = face[:vertices]
          if verts.is_a?(Array) && !verts.empty?
            verts.each do |v|
              next if !v.is_a?(Array)
              x = v[0].to_f; y = v[1].to_f; z = v[2].to_f
              group[:pts] << [x, y]
              group[:min_z] = z if group[:min_z].nil? || z < group[:min_z]
              group[:max_z] = z if group[:max_z].nil? || z > group[:max_z]
            end
          else
            x0 = face[:x0].to_f; y0 = face[:y0].to_f
            x1 = face[:x1].to_f; y1 = face[:y1].to_f
            group[:pts].concat([[x0, y0], [x1, y0], [x1, y1], [x0, y1]])
            z0 = face[:z0].to_f; z1 = face[:z1].to_f
            group[:min_z] = [group[:min_z], z0, z1].compact.min
            group[:max_z] = [group[:max_z], z0, z1].compact.max
          end
        end

        grouped.each do |(model_id, instance_id), group|
          pts = group[:pts]
          next if pts.empty?
          xs = pts.map { |pt| pt[0] }
          ys = pts.map { |pt| pt[1] }
          min_tx = xs.min.floor
          max_tx = [xs.max.ceil - 1, min_tx].max
          min_ty = ys.min.floor
          max_ty = [ys.max.ceil - 1, min_ty].max
          base = group[:min_z].to_f
          height = [group[:max_z].to_f - base, 0.05].max
          min_ty.upto(max_ty) do |ty|
            min_tx.upto(max_tx) do |tx|
              entry = { collision: "solid", base: base, height: height,
                        model_id: model_id, model_instance_id: instance_id, part_id: "mesh" }
              (cells[[tx, ty]] ||= []) << entry
            end
          end
        end
        cells
      rescue Exception => e
        Console.echo_error("VERMEIL ModelPhysics runtime fallback: #{e.message}") if defined?(Console)
        {}
      end

      def register_surface_geometry(map_id, geo)
        return nil if !geo
        map_id = map_id.to_i
        @worlds ||= {}
        @sidecar_authoritative ||= {}
        @surface_fallback_maps ||= {}
        @surface_geometry_ids ||= {}

        # A real .v25c always wins, including an intentionally empty one.
        if @sidecar_authoritative[map_id]
          activate(map_id, @worlds[map_id] || {})
          return @worlds[map_id]
        end

        # SurfaceGeometry.from_file keeps a small per-map runtime cache. If the
        # exact same geometry object is revisited, its collision grid is already
        # valid; rebuilding every footprint/mesh cell only lengthened transfers.
        geo_id = geo.object_id
        if @surface_fallback_maps[map_id] && @surface_geometry_ids[map_id] == geo_id &&
           @worlds.key?(map_id)
          activate(map_id, @worlds[map_id] || {})
          return @worlds[map_id]
        end

        cells = build_surface_fallback_cells(geo)
        @worlds[map_id] = cells
        @surface_fallback_maps[map_id] = true
        @surface_geometry_ids[map_id] = geo_id
        activate(map_id, cells)
        cells
      rescue Exception => e
        Console.echo_error("VERMEIL ModelPhysics register surface #{map_id}: #{e.message}") if defined?(Console)
        nil
      end

      # Model streaming may append faces after initial map build. Refresh only
      # fallback worlds; sidecar-authored physics never changes.
      def refresh_surface_fallback(map_id, geo, force = false)
        map_id = map_id.to_i
        return @worlds && @worlds[map_id] if @sidecar_authoritative && @sidecar_authoritative[map_id]
        # Streaming mutates the same SurfaceGeometry object in place. The normal
        # object_id cache is correct for map revisits, but must be invalidated
        # when the completed .v25m appended new faces.
        if force && @surface_geometry_ids
          @surface_geometry_ids.delete(map_id)
        end
        register_surface_geometry(map_id, geo)
      end

      def sidecar_authoritative?(map_id)
        @sidecar_authoritative && !!@sidecar_authoritative[map_id.to_i]
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
