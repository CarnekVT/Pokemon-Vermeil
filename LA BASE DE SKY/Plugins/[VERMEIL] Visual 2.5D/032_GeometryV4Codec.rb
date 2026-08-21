#===============================================================================
# [VERMEIL] Visual 2.5D - 032_GeometryV4Codec.rb
# V6.1.0 - Fast Geometry v4 runtime. No authoring JSON in gameplay.
#
# Runtime files:
#   MapXXX.v25r  V25R2 line records (terrain/first-frame only)
#   MapXXX.v25c  V25C2 line records (collision only)
#   MapXXX.v25m  lazy model-face stream
#
# MapXXX.v25d is editor-only and is NEVER opened by gameplay.
#===============================================================================
require "uri"

module Mode7
  module V25Codec
    class Parser
      def initialize(text)
        @s = text.to_s
        @i = 0
      end
      def read_len
        j = @i
        @i += 1 while @i < @s.bytesize && @s.getbyte(@i) != 58
        raise "V25 malformed length" if @i >= @s.bytesize
        n = @s.byteslice(j, @i - j).to_i
        @i += 1
        raise "V25 invalid length" if n < 0
        n
      end
      def read
        raise "V25 unexpected EOF" if @i >= @s.bytesize
        t = @s.getbyte(@i).chr
        @i += 1
        case t
        when "Z" then nil
        when "T" then true
        when "F" then false
        when "N"
          n = read_len
          raw = @s.byteslice(@i, n).to_s
          @i += n
          raw.include?(".") || raw.include?("e") || raw.include?("E") ? raw.to_f : raw.to_i
        when "S"
          n = read_len
          raw = @s.byteslice(@i, n).to_s
          @i += n
          URI.decode_www_form_component(raw)
        when "A"
          n = read_len
          Array.new(n) { read }
        when "O"
          n = read_len
          out = {}
          n.times do
            k = read.to_s
            out[k] = read
          end
          out
        else
          raise "V25 unknown token #{t.inspect}"
        end
      end
    end

    class << self
      def decode(text)
        Parser.new(text.to_s.strip).read
      end
      def read_file(path, header)
        raw = File.binread(path)
        first, payload = raw.split("\n", 2)
        raise "Expected #{header}" if first.to_s.strip != header.to_s
        decode(payload.to_s)
      end
    end
  end

  module GeometryV4Fast
    class << self
      def apply_cell(geo, key, value, step)
        xy = key.to_s.split(",", 2)
        return if xy.length != 2
        x = xy[0].to_i
        y = xy[1].to_i
        material = nil
        h = 0.0
        if value.is_a?(Numeric)
          h = value.to_f * step
        elsif value.is_a?(Hash)
          material = value["material"]
          h = value.key?("height") ? value["height"].to_f : value.fetch("level", 0).to_f * step
        end
        geo.set_height(x, y, h, material, true)
      end

      def normalize_object(o)
        return nil if !o.is_a?(Hash)
        {
          id: o["id"].to_i,
          name: o["name"].to_s.empty? ? "Object #{o["id"].to_i}" : o["name"].to_s,
          compiled: o["compiled"] == true,
          source_key: o["source_key"].to_s,
          instance_key: o["instance_key"].to_s,
          source: o["source"].is_a?(Hash) ? o["source"] : nil,
          components: o["components"].is_a?(Hash) ? o["components"] : {},
          type: o["type"] == "plane" ? "plane" : "cube",
          x: o["x"].to_i, y: o["y"].to_i,
          w: [o["w"].to_i, 1].max, h: [o["h"].to_i, 1].max,
          height: [o["height"].to_f, 0.0].max,
          anchor_z: [o["anchor_z"].to_f, 0.0].max,
          anchor_row: o["anchor_row"].to_i,
          rotation: o["rotation"].to_i % 360,
          collision: o["collision"].to_s.empty? ? "solid" : o["collision"].to_s,
          category: o["category"].to_s.empty? ? "prop" : o["category"].to_s,
          characters_in_front: o["characters_in_front"] == true,
          footprint: {},
          material: o["material"].is_a?(Hash) ? o["material"] : nil,
          face_materials: o["face_materials"].is_a?(Hash) ? o["face_materials"] : {},
          model_id: o["model_id"].to_s,
          model_instance_id: o["model_instance_id"].to_i,
          render: o["render"] == false ? false : true
        }
      end

      def setup_stream(geo, path, header)
        stream = header.is_a?(Hash) ? header["model_stream"].to_s : ""
        return if stream.empty?
        geo.set_model_stream(File.join(File.dirname(path), stream), header["model_face_count"].to_i)
      end

      def load_surface_v2(path, map_id, width, height, io = nil)
        own = io.nil?
        io ||= File.open(path, "rb")
        io.rewind if io.respond_to?(:rewind)
        magic = io.gets.to_s.strip
        raise "Expected V25R2" if magic != "V25R2"
        hline = io.gets.to_s.strip
        raise "Missing V25R2 header" if hline.empty? || hline.getbyte(0) != 72
        header = Mode7::V25Codec.decode(hline.byteslice(1, hline.bytesize - 1))
        step = ((header.is_a?(Hash) ? header["height_step"] : nil) || Mode7::Config::SURFACE_GEOMETRY_HEIGHT_STEP).to_f
        geo = Mode7::SurfaceGeometry.new(map_id, width, height, step, :file, path)
        geo.instance_variable_set(:@inherit_legacy, false)
        setup_stream(geo, path, header || {})
        mats = []
        io.each_line do |line|
          line = line.strip
          next if line.empty?
          tag = line.getbyte(0)
          payload = line.byteslice(1, line.bytesize - 1)
          case tag
          when 67 # C
            pair = Mode7::V25Codec.decode(payload)
            apply_cell(geo, pair[0], pair[1], step) if pair.is_a?(Array) && pair.length >= 2
          when 82 # R
            row = Mode7::V25Codec.decode(payload)
            geo.add_ramp(row) if row.is_a?(Hash)
          when 80 # P
            row = Mode7::V25Codec.decode(payload)
            geo.add_plane(row) if row.is_a?(Hash)
          when 77 # M
            mat = Mode7::V25Codec.decode(payload)
            mats << mat
          when 70 # F
            row = Mode7::V25Codec.decode(payload)
            face = Mode7::SurfaceGeometry.normalize_compact_mesh_face(row, mats)
            geo.mesh_faces << face if face
          when 79 # O
            obj = normalize_object(Mode7::V25Codec.decode(payload))
            geo.objects << obj if obj
          end
        end
        geo
      ensure
        io.close if own && io && !io.closed?
      end

      def load_surface_v1(path, map_id, width, height)
        raw = Mode7::V25Codec.read_file(path, "V25R1")
        return nil if !raw.is_a?(Hash)
        step = (raw["height_step"] || Mode7::Config::SURFACE_GEOMETRY_HEIGHT_STEP).to_f
        geo = Mode7::SurfaceGeometry.new(map_id, width, height, step, :file, path)
        geo.instance_variable_set(:@inherit_legacy, false)
        setup_stream(geo, path, raw)
        cells = raw["cells"]
        cells.each { |k, v| apply_cell(geo, k, v, step) } if cells.is_a?(Hash)
        Array(raw["ramps"]).each { |r| geo.add_ramp(r) }
        Array(raw["terrain_planes"]).each { |pl| geo.add_plane(pl) }
        objects = []
        objects.concat(raw["objects"]) if raw["objects"].is_a?(Array)
        objects.concat(raw["compiled_objects"]) if raw["compiled_objects"].is_a?(Array)
        objects.each do |o|
          obj = normalize_object(o)
          geo.objects << obj if obj
        end
        mats = raw["materials"].is_a?(Array) ? raw["materials"] : []
        Array(raw["mesh_faces_compact"]).each do |row|
          face = Mode7::SurfaceGeometry.normalize_compact_mesh_face(row, mats)
          geo.mesh_faces << face if face
        end
        geo
      end

      def load_surface(path, map_id, width, height)
        return nil if !File.file?(path)
        File.open(path, "rb") do |io|
          magic = io.gets.to_s.strip
          if magic == "V25R2"
            io.rewind
            return load_surface_v2(path, map_id, width, height, io)
          elsif magic == "V25R1"
            return load_surface_v1(path, map_id, width, height)
          end
          raise "Unsupported Geometry runtime #{magic.inspect}"
        end
      end

      def load_collision(path)
        return {} if !File.file?(path)
        File.open(path, "rb") do |io|
          magic = io.gets.to_s.strip
          if magic == "V25C2"
            hline = io.gets
            rows = []
            io.each_line do |line|
              line = line.strip
              next if line.empty? || line.getbyte(0) != 67
              row = Mode7::V25Codec.decode(line.byteslice(1, line.bytesize - 1))
              rows << row if row.is_a?(Array)
            end
            return Mode7::ModelPhysicsWorld.build_index_compact(rows)
          elsif magic == "V25C1"
            raw = Mode7::V25Codec.read_file(path, "V25C1")
            return {} if !raw.is_a?(Hash)
            if raw["model_collision_cells_compact"].is_a?(Array)
              return Mode7::ModelPhysicsWorld.build_index_compact(raw["model_collision_cells_compact"])
            end
            return Mode7::ModelPhysicsWorld.build_index(raw["model_collision_cells"])
          end
          {}
        end
      end
    end
  end
end

module Mode7
  class << self
    def preload_geometry_collision_for_map(map_id, width = nil, height = nil)
      return nil if !defined?(Mode7::ModelPhysicsWorld)
      Mode7::ModelPhysicsWorld.preload(map_id)
    rescue Exception
      nil
    end
  end
end

module Mode7
  class SurfaceGeometry
    class << self
      def file_path(map_id)
        File.join(Mode7::Config::SURFACE_GEOMETRY_DIRECTORY.to_s, format("Map%03d.v25d", map_id.to_i))
      end

      def runtime_file_path(map_id)
        File.join(Mode7::Config::SURFACE_GEOMETRY_DIRECTORY.to_s, format("Map%03d.v25r", map_id.to_i))
      end

      def clear_file_cache!(map_id = nil)
        @file_geometry_cache ||= {}
        if map_id.nil?
          @file_geometry_cache.clear
        else
          paths = [file_path(map_id), runtime_file_path(map_id)]
          @file_geometry_cache.delete_if { |key, _| paths.include?(key[0]) }
        end
      rescue Exception
      end

      def from_file(map_id, width, height)
        path = runtime_file_path(map_id)
        cache_key = [path, width.to_i, height.to_i]
        @file_geometry_cache ||= {}
        return @file_geometry_cache[cache_key] if @file_geometry_cache.key?(cache_key)
        geo = Mode7::GeometryV4Fast.load_surface(path, map_id, width, height)
        @file_geometry_cache[cache_key] = geo
        if @file_geometry_cache.length > 6
          oldest = @file_geometry_cache.keys.find { |k| k != cache_key }
          @file_geometry_cache.delete(oldest) if oldest
        end
        geo
      rescue Exception => e
        @file_geometry_cache[cache_key] = nil if defined?(cache_key) && cache_key
        Console.echo_error("VERMEIL Geometry v4 fast #{path}: #{e.message}") if defined?(Console)
        nil
      end
    end
  end
end

module Mode7
  module ModelPhysicsWorld
    class << self
      def collision_path(map_id)
        dir = defined?(Mode7::Config::SURFACE_GEOMETRY_DIRECTORY) ? Mode7::Config::SURFACE_GEOMETRY_DIRECTORY.to_s : "Data/VERMEIL_GEOMETRY_V4"
        File.join(dir, format("Map%03d.v25c", map_id.to_i))
      end

      def preload(map_id)
        map_id = map_id.to_i
        @worlds ||= {}
        if @worlds.key?(map_id)
          activate(map_id, @worlds[map_id])
          return @worlds[map_id]
        end
        cells = Mode7::GeometryV4Fast.load_collision(collision_path(map_id))
        @worlds[map_id] = cells
        activate(map_id, cells)
        cells
      rescue Exception => e
        Console.echo_error("VERMEIL ModelPhysics v4 fast preload #{map_id}: #{e.message}") if defined?(Console)
        @worlds ||= {}
        @worlds[map_id] = {}
        activate(map_id, {})
        {}
      end
    end
  end
end

class Mode7Renderer
  private
  def nds_prepare_model_stream
    geo = @nds_surface_geometry
    path = geo && geo.respond_to?(:model_stream_path) ? geo.model_stream_path : nil
    return false if !path || path.to_s.empty?
    return false if @nds_model_stream_done && @nds_model_stream_map_id == @map_id
    return true if @nds_model_stream_io && !@nds_model_stream_io.closed? && @nds_model_stream_map_id == @map_id
    nds_close_model_stream if @nds_model_stream_io
    @nds_model_stream_done = false
    @nds_model_stream_map_id = @map_id
    unless File.file?(path)
      @nds_model_stream_done = true
      return false
    end
    @nds_model_stream_io = File.open(path, "rb")
    magic = @nds_model_stream_io.gets.to_s.strip
    raise "Expected V25M1" if magic != "V25M1"
    header_line = @nds_model_stream_io.gets.to_s.strip
    raise "Missing V25M header" if header_line.empty? || header_line.getbyte(0) != 72 # H
    header = Mode7::V25Codec.decode(header_line.byteslice(1, header_line.bytesize - 1))
    @nds_model_stream_materials = header.is_a?(Hash) && header["materials"].is_a?(Array) ? header["materials"] : []
    @nds_model_stream_total = header.is_a?(Hash) ? header["count"].to_i : 0
    @nds_model_stream_loaded = 0
    true
  rescue Exception => e
    Console.echo_error("2.5D v4 model stream open: #{e.message}") if defined?(Console)
    nds_close_model_stream
    false
  end

  def nds_model_stream_step
    geo = @nds_surface_geometry
    return if !geo || !geo.respond_to?(:model_stream_path) || !geo.model_stream_path
    return if @nds_model_stream_done && @nds_model_stream_map_id == @map_id
    @nds_model_stream_age = @nds_model_stream_age.to_i + 1
    delay = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_START_DELAY_FRAMES) ? Mode7::Config::NDS_MODEL_STREAM_START_DELAY_FRAMES.to_i : 8
    return if @nds_model_stream_age <= [delay, 0].max
    interval = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_INTERVAL_FRAMES) ? Mode7::Config::NDS_MODEL_STREAM_INTERVAL_FRAMES.to_i : 1
    interval = 1 if interval < 1
    return if (@nds_model_stream_age % interval) != 0
    idle_only = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_IDLE_ONLY) ? Mode7::Config::NDS_MODEL_STREAM_IDLE_ONLY : true
    return if idle_only && defined?($game_player) && $game_player && $game_player.respond_to?(:moving?) && $game_player.moving?
    return if !nds_prepare_model_stream
    io = @nds_model_stream_io
    return if !io || io.closed?
    budget = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_FACE_BUDGET) ? Mode7::Config::NDS_MODEL_STREAM_FACE_BUDGET.to_i : 32
    budget = 1 if budget < 1
    time_ms = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_TIME_MS) ? Mode7::Config::NDS_MODEL_STREAM_TIME_MS.to_f : 0.75
    time_ms = 0.5 if time_ms <= 0.0
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue nil
    tw = Game_Map::TILE_WIDTH.to_f; th = Game_Map::TILE_HEIGHT.to_f
    step = geo.height_step.to_f; step = 32.0 if step <= 0.0
    loaded = 0
    while loaded < budget
      line = io.gets
      if !line
        nds_close_model_stream
        break
      end
      line = line.strip
      next if line.empty?
      next if line.getbyte(0) != 70 # F
      row = Mode7::V25Codec.decode(line.byteslice(1, line.bytesize - 1))
      mf = Mode7::SurfaceGeometry.normalize_compact_mesh_face(row, @nds_model_stream_materials || [])
      next if !mf
      geo.mesh_faces << mf
      nds_object_build_region_mesh_faces(tw, th, step, [mf]) if respond_to?(:nds_object_build_region_mesh_faces, true)
      @nds_model_stream_loaded = @nds_model_stream_loaded.to_i + 1
      loaded += 1
      if t0
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0 rescue 0.0
        break if elapsed >= time_ms
      end
    end
    if loaded > 0 && defined?(Mode7::ModelPhysicsWorld) &&
       Mode7::ModelPhysicsWorld.respond_to?(:refresh_surface_fallback)
      Mode7::ModelPhysicsWorld.refresh_surface_fallback(@map_id, geo)
    end
    @nds_object_projection_key = nil
    @nds_object_visibility_key = nil
  rescue Exception => e
    Console.echo_error("2.5D v4 model stream: #{e.message}") if defined?(Console)
    nds_close_model_stream
  end
end
