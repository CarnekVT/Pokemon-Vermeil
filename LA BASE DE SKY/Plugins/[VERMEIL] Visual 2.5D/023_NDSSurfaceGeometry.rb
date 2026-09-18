#===============================================================================
# [VERMEIL] Visual 2.5D - 023_NDSSurfaceGeometry.rb
# V5.10 - Geometria fisica unificada por mapa.
#
# Una sola rejilla controla:
#   * altura del jugador/eventos/props
#   * elevacion de camara
#   * paredes generadas por diferencia de altura
#   * colision de desniveles
#   * superficie de MountainTop/Volume/Stair
#
# Runtime limpio: Data/VERMEIL_GEOMETRY_V4/MapXXX.v25r (sin JSON de autoría)
# Si no existe, se compila un fallback desde los Terrain Tags actuales.
#===============================================================================

begin
  require "json"
rescue LoadError
end

module Mode7
  class SurfaceGeometry
    attr_reader :map_id, :width, :height, :height_step, :source, :path, :inherit_legacy, :objects, :mesh_faces, :model_collision_cells, :model_stream_path, :model_face_count, :planes

    def initialize(map_id, width, height, height_step, source = :nds_tags, path = nil)
      @map_id = map_id.to_i
      @width = width.to_i
      @height = height.to_i
      @height_step = height_step.to_f
      @height_step = 32.0 if @height_step.abs < 0.001
      @source = source
      @path = path
      @cells = {}
      @ramps = []
      # DS-style authored terrain is stored as a few merged rectangular planes.
      # @plane_index makes gameplay height queries O(1) without generating a 3D
      # object/collider per tile.
      @planes = []
      @plane_index = {}
      @objects = []
      @mesh_faces = []
      @model_collision_cells = {}
      @model_stream_path = nil
      @model_face_count = 0
      @inherit_legacy = false
    end

    def explicit?
      @source == :file
    end

    def set_model_stream(path, count = 0)
      @model_stream_path = path
      @model_face_count = count.to_i
    end

    def self.normalize_compact_mesh_face(a, mats)
      return nil if !a.is_a?(Array)
      raw_kind = a[1].to_s
      kind = raw_kind == "top" ? "top" : (raw_kind == "quad" ? "quad" : "side")
      edge = a[3].to_s
      edge = nil if !["north", "south", "east", "west"].include?(edge)
      vertices = nil
      if a[4].is_a?(Array) && a[4].length == 4
        vertices = a[4].map do |v|
          next [0.0, 0.0, 0.0] if !v.is_a?(Array)
          [v[0].to_f, v[1].to_f, [v[2].to_f, 0.0].max]
        end
      end
      uv = a[5]
      uv_rect = uv.is_a?(Array) && uv.length == 4 ? uv.map { |v| [[v.to_f, 0.0].max, 1.0].min } : nil
      puv = a[6]
      pattern_uv = puv.is_a?(Array) && puv.length == 4 ? puv.map { |v| v.to_f } : nil
      mi = a[7].to_i
      {
        id: a[0].to_i, kind: kind, surface: a[2].to_s, edge: edge,
        vertices: vertices, uv_rect: uv_rect, pattern_uv: pattern_uv,
        x0: a[14].to_f, y0: a[15].to_f, x1: a[16].to_f, y1: a[17].to_f,
        z0: [a[18].to_f, 0.0].max, z1: [a[19].to_f, 0.0].max,
        material: (mi >= 0 && mats[mi].is_a?(Hash)) ? mats[mi] : nil,
        material_repeat: a[8].to_i != 0,
        category: a[9].to_s.empty? ? "mountain" : a[9].to_s,
        model_id: a[10].to_s, model_instance_id: a[11].to_i, part_id: a[12].to_s
      }
    end

    def inside?(x, y)
      x >= 0 && y >= 0 && x < @width && y < @height
    end

    def set_height(x, y, value, material = nil, keep_zero = false)
      x = x.to_i
      y = y.to_i
      return if !inside?(x, y)
      h = value.to_f
      key = [x, y]
      if h.abs < 0.001 && (material.nil? || material.to_s.empty?) && !keep_zero
        @cells.delete(key)
      else
        @cells[key] = { height: h, material: material }
      end
    end

    def add_plane(hash)
      return if !hash.is_a?(Hash)
      x = (hash["x"] || hash[:x]).to_i
      y = (hash["y"] || hash[:y]).to_i
      w = [(hash["width"] || hash[:width] || 1).to_i, 1].max
      h = [(hash["height"] || hash[:height] || 1).to_i, 1].max
      raw = hash["corners"] || hash[:corners]
      return if !raw.is_a?(Array) || raw.length != 4
      # Runtime JSON stores height-step units; SurfaceGeometry always exposes px.
      corners = raw.map { |v| [v.to_f * @height_step, 0.0].max }
      plane = { x: x, y: y, width: w, height: h, corners: corners }
      idx = @planes.length
      @planes << plane
      y.upto(y + h - 1) do |ty|
        x.upto(x + w - 1) do |tx|
          next if !inside?(tx, ty)
          @plane_index[[tx, ty]] = idx
        end
      end
      plane
    rescue Exception
      nil
    end

    def plane_at(x, y)
      idx = @plane_index[[x.to_i, y.to_i]]
      idx.nil? ? nil : @planes[idx]
    rescue Exception
      nil
    end

    def plane_cell?(x, y)
      @plane_index.key?([x.to_i, y.to_i])
    rescue Exception
      false
    end

    def plane_height(plane, u, v)
      return 0.0 if !plane
      z00, z10, z11, z01 = plane[:corners]
      u = [[u.to_f, 0.0].max, 1.0].min
      v = [[v.to_f, 0.0].max, 1.0].min
      north = z00 + (z10 - z00) * u
      south = z01 + (z11 - z01) * u
      north + (south - north) * v
    rescue Exception
      0.0
    end

    def plane_center_height_at(x, y)
      plane = plane_at(x, y)
      return nil if !plane
      u = ((x.to_f + 0.5) - plane[:x].to_f) / plane[:width].to_f
      v = ((y.to_f + 0.5) - plane[:y].to_f) / plane[:height].to_f
      plane_height(plane, u, v)
    rescue Exception
      nil
    end

    def height_at(x, y)
      x = x.to_i
      y = y.to_i
      return 0.0 if !inside?(x, y)
      ph = plane_center_height_at(x, y)
      return ph.to_f if !ph.nil?
      cell = @cells[[x, y]]
      cell ? cell[:height].to_f : 0.0
    end

    def material_at(x, y)
      cell = @cells[[x.to_i, y.to_i]]
      cell && cell[:material]
    end

    def explicit_cell?(x, y)
      @cells.key?([x.to_i, y.to_i]) || plane_cell?(x, y)
    end

    def ramp_cell?(x, y)
      tx = x.to_i
      ty = y.to_i
      @ramps.any? do |ramp|
        tx >= ramp[:x] && tx < ramp[:x] + ramp[:width] &&
          ty >= ramp[:y] && ty < ramp[:y] + ramp[:height]
      end
    rescue Exception
      false
    end

    def each_cell(&block)
      @cells.each(&block)
    end

    # Objetos Geometry (cubos/planos) del editor. Cada objeto es un Hash con
    # tipo, footprint, altura, material y colision. Los consumidores preguntan
    # con object_at?/object_covering para no depender del formato exacto.
    def object_footprint_mode(obj, x, y)
      ox = obj[:x].to_i
      oy = obj[:y].to_i
      dx = x.to_i - ox
      dy = y.to_i - oy
      return "void" if dx < 0 || dy < 0 || dx >= obj[:w].to_i || dy >= obj[:h].to_i
      fp = obj[:footprint]
      return "inherit" if !fp.is_a?(Hash)
      (fp[[dx, dy]] || fp["#{dx},#{dy}"] || "inherit").to_s
    rescue Exception
      "inherit"
    end

    def object_at?(x, y)
      @objects.any? { |obj| object_footprint_mode(obj, x, y) != "void" }
    rescue Exception
      false
    end

    def object_covering(x, y)
      @objects.select { |obj| object_footprint_mode(obj, x, y) != "void" }
    rescue Exception
      []
    end

    def set_model_collision_cells(rows)
      @model_collision_cells = {}
      return if !rows.is_a?(Array)
      rows.each do |row|
        next if !row.is_a?(Hash)
        x = (row[:x] || row["x"]).to_i
        y = (row[:y] || row["y"]).to_i
        next if !inside?(x, y)
        collision = (row[:collision] || row["collision"] || "solid").to_s
        next if collision == "none"
        entry = {
          x: x, y: y,
          base: [(row[:base] || row["base"]).to_f, 0.0].max,
          height: [(row[:height] || row["height"]).to_f, 0.05].max,
          collision: collision,
          model_id: (row[:model_id] || row["model_id"]).to_s,
          model_instance_id: (row[:model_instance_id] || row["model_instance_id"]).to_i,
          part_id: (row[:part_id] || row["part_id"]).to_s
        }
        (@model_collision_cells[[x, y]] ||= []) << entry
      end
    rescue Exception
      @model_collision_cells = {}
    end

    def model_collision_covering(x, y)
      rows = @model_collision_cells[[x.to_i, y.to_i]]
      rows ? rows : []
    rescue Exception
      []
    end

    def object_top_z(obj)
      step = @height_step
      base = obj[:anchor_z].to_f * step
      obj[:type].to_s == "cube" ? base + obj[:height].to_f * step : base
    end

    def overlay_from!(other)
      other.each_cell do |key, cell|
        @cells[key] = cell.dup
      end
      @height_step = other.height_step.to_f
      @source = :file
      @path = other.path
      @inherit_legacy = true
      ramps = other.instance_variable_get(:@ramps)
      @ramps = ramps ? ramps.map(&:dup) : []
      @planes = []
      @plane_index = {}
      planes = other.respond_to?(:planes) ? other.planes : []
      (planes || []).each do |pl|
        # other planes are already in pixels; convert back to step units for add_plane.
        raw = { x: pl[:x], y: pl[:y], width: pl[:width], height: pl[:height],
                corners: (pl[:corners] || []).map { |z| z.to_f / @height_step } }
        add_plane(raw)
      end
      objects = other.objects
      @objects = objects ? objects.map { |obj| Marshal.load(Marshal.dump(obj)) } : []
      faces = other.mesh_faces
      @mesh_faces = faces ? faces.map { |face| Marshal.load(Marshal.dump(face)) } : []
      @model_stream_path = other.respond_to?(:model_stream_path) ? other.model_stream_path : nil
      @model_face_count = other.respond_to?(:model_face_count) ? other.model_face_count.to_i : 0
      # Keep compiled model collision when explicit Geometry is overlaid on
      # legacy terrain. Older builds copied the visible mesh but dropped this
      # grid, which made placed models walk-through on inherit_legacy maps.
      collision = other.instance_variable_get(:@model_collision_cells)
      @model_collision_cells = {}
      if collision.is_a?(Hash)
        collision.each do |key, rows|
          @model_collision_cells[key] = rows.map { |row| Marshal.load(Marshal.dump(row)) }
        end
      end
      self
    end

    def add_ramp(hash)
      return if !hash.is_a?(Hash)
      x = (hash["x"] || hash[:x]).to_i
      y = (hash["y"] || hash[:y]).to_i
      w = (hash["width"] || hash[:width] || 1).to_i
      h = (hash["height"] || hash[:height] || 1).to_i
      south = hash.key?("south_z") ? hash["south_z"] : hash[:south_z]
      north = hash.key?("north_z") ? hash["north_z"] : hash[:north_z]
      south = height_at(x, y + h) if south.nil?
      north = height_at(x, y - 1) if north.nil?
      @ramps << {
        x: x, y: y, width: [w, 1].max, height: [h, 1].max,
        south_z: south.to_f, north_z: north.to_f
      }
    rescue Exception
    end

    def real_height_at(world_x, world_y, tile_w, tile_h)
      wx = world_x.to_f
      wy = world_y.to_f
      tx0 = (wx / tile_w).floor
      ty0 = (wy / tile_h).floor
      plane = plane_at(tx0, ty0)
      if plane
        west = plane[:x].to_f * tile_w
        north = plane[:y].to_f * tile_h
        span_x = [plane[:width].to_f * tile_w, 0.001].max
        span_y = [plane[:height].to_f * tile_h, 0.001].max
        return plane_height(plane, (wx - west) / span_x, (wy - north) / span_y)
      end
      @ramps.each do |ramp|
        west = ramp[:x] * tile_w
        east = (ramp[:x] + ramp[:width]) * tile_w
        north_y = ramp[:y] * tile_h
        south_y = (ramp[:y] + ramp[:height]) * tile_h
        next if wx < west - 0.001 || wx > east + 0.001
        next if wy < north_y - 0.001 || wy > south_y + 0.001
        span = south_y - north_y
        next if span.abs < 0.001
        t = ((south_y - wy) / span).clamp(0.0, 1.0)
        return ramp[:south_z] + (ramp[:north_z] - ramp[:south_z]) * t
      end
      tx = (wx / tile_w).floor
      ty = ((wy - 0.001) / tile_h).floor
      height_at(tx, ty)
    rescue Exception
      0.0
    end

    # Geometry v4 runtime methods are implemented by 032_GeometryV4Codec.rb.
    # Keep these delegating definitions here so this file never touches the old
    # legacy Geometry JSON path, regardless of plugin load order.
    def self.file_path(map_id)
      File.join(Mode7::Config::SURFACE_GEOMETRY_DIRECTORY.to_s, format("Map%03d.v25d", map_id.to_i))
    end

    def self.runtime_file_path(map_id)
      File.join(Mode7::Config::SURFACE_GEOMETRY_DIRECTORY.to_s, format("Map%03d.v25r", map_id.to_i))
    end

    def self.clear_file_cache!(map_id = nil)
      @file_geometry_cache ||= {}
      if map_id.nil?
        @file_geometry_cache.clear
      else
        paths = [file_path(map_id), runtime_file_path(map_id)]
        @file_geometry_cache.delete_if { |key, _| paths.include?(key[0]) }
      end
    rescue Exception
    end

    def self.from_file(map_id, width, height)
      path = runtime_file_path(map_id)
      cache_key = [path, width.to_i, height.to_i]
      @file_geometry_cache ||= {}
      return @file_geometry_cache[cache_key] if @file_geometry_cache.key?(cache_key)
      geo = if defined?(Mode7::GeometryV4Fast)
              Mode7::GeometryV4Fast.load_surface(path, map_id, width, height)
            else
              nil
            end
      @file_geometry_cache[cache_key] = geo
      geo
    rescue Exception => e
      @file_geometry_cache[cache_key] = nil if defined?(cache_key) && cache_key
      Console.echo_error("VERMEIL Geometry v4 #{path}: #{e.message}") if defined?(Console)
      nil
    end
  end

  class << self
    def current_surface_geometry
      return nil if !$scene.is_a?(Scene_Map)
      renderer = $scene.instance_variable_get(:@map_renderer)
      return nil if !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      renderer.nds_surface_geometry
    rescue Exception
      nil
    end

    def surface_geometry_source
      geo = current_surface_geometry
      geo ? geo.source : nil
    end

    # V5.12 override: todos los consumidores leen la misma rejilla unificada.
    def nds_surface_height_at(x, y)
      # Prioridad: Geometry explícita > HeightCache unificado > fallback 0
      geo = current_surface_geometry
      if geo
        h = geo.height_at(x, y).to_f
        return h if h.abs >= 0.001
      end
      return Mode7.height_cache.height_at(x, y) if Mode7.respond_to?(:height_cache) && Mode7.height_cache.built
      0.0
    rescue Exception
      0.0
    end

    def nds_surface_material_at(x, y)
      geo = current_surface_geometry
      geo ? geo.material_at(x, y) : nil
    rescue Exception
      nil
    end

    def nds_surface_height_at_real(world_x, world_y)
      geo = current_surface_geometry
      if geo
        # Ramps explícitas del Geometry file tienen prioridad
        ramps = geo.instance_variable_get(:@ramps)
        if ramps && !ramps.empty?
          return geo.real_height_at(world_x, world_y,
                                    Game_Map::TILE_WIDTH.to_f,
                                    Game_Map::TILE_HEIGHT.to_f)
        end
      end
      # Usar el caché unificado (incluye stair ramps por grid espacial)
      return Mode7.height_cache.height_at_real(world_x, world_y) if Mode7.respond_to?(:height_cache) && Mode7.height_cache.built
      # Fallback: ramps del renderer
      renderer = $scene.instance_variable_get(:@map_renderer)
      if renderer
        ramps = renderer.instance_variable_get(:@nds_stair_ramps)
        if ramps
          wx = world_x.to_f
          wy = world_y.to_f
          ramps.each do |ramp|
            next if wx < ramp[:west_wx] - 0.001 || wx > ramp[:east_wx] + 0.001
            next if wy < ramp[:north_wy] - 0.001 || wy > ramp[:south_wy] + 0.001
            span = ramp[:south_wy] - ramp[:north_wy]
            next if span.abs <= 0.001
            t = ((ramp[:south_wy] - wy) / span).clamp(0.0, 1.0)
            return ramp[:south_z] + (ramp[:north_z] - ramp[:south_z]) * t
          end
        end
      end
      geo ? geo.real_height_at(world_x, world_y,
                               Game_Map::TILE_WIDTH.to_f,
                               Game_Map::TILE_HEIGHT.to_f) : 0.0
    rescue Exception
      0.0
    end
  end
end

class Mode7Renderer
  attr_reader :nds_surface_geometry

  private

  def build_nds_surface_geometry
    @nds_surface_geometry = nil
    return if !Mode7::Config::SURFACE_GEOMETRY_ENABLED

    # V7 / single-source Terrain Tags: con SURFACE_GEOMETRY_RUNTIME_FILES=false
    # el archivo .v25r no se lee (cuarentena de modelos 3D). La superficie se
    # deriva siempre de los Terrain Tags NDS asignados en el tileset.
    overlay = nil
    if Mode7::Config::SURFACE_GEOMETRY_RUNTIME_FILES
      # Read the explicit Geometry V4 file first. If it is fully authored, it is
      # authoritative. Otherwise its compatibility inherit flag overlays the
      # NDS Terrain Tag surface generated below.
      overlay = Mode7::SurfaceGeometry.from_file(@map_id, @map.width, @map.height)
      if overlay && !overlay.inherit_legacy
        @nds_surface_geometry = overlay
        Mode7.register_geometry_collision_source(@nds_surface_geometry, @map_id) if Mode7.respond_to?(:register_geometry_collision_source)
        Console.echo_li("[VERMEIL] Runtime Geometry: #{overlay.path}") if defined?(Console) rescue nil
        return
      end
    end

    nds_tags = Mode7::SurfaceGeometry.new(
      @map_id, @map.width, @map.height,
      Mode7::Config::SURFACE_GEOMETRY_HEIGHT_STEP, :nds_tags, nil
    )
    (@entry_cache || {}).each do |pos, entries|
      next if !entries || entries.empty?
      tx, ty = pos
      h = nds_tag_surface_height_at(tx, ty)
      nds_tags.set_height(tx, ty, h) if h.abs >= 0.001
    end

    geo = if overlay && overlay.inherit_legacy
            # inherit_legacy is retained only as an on-disk compatibility field.
            # Its runtime meaning is now "inherit NDS Terrain Tags".
            nds_tags.overlay_from!(overlay)
          elsif overlay
            overlay
          else
            nds_tags
          end
    @nds_surface_geometry = geo
    Mode7.register_geometry_collision_source(@nds_surface_geometry, @map_id) if Mode7.respond_to?(:register_geometry_collision_source)
    if defined?(Console)
      label = geo.explicit? ? geo.path : "NDS Terrain Tags"
      Console.echo_li("[VERMEIL] Surface Geometry: #{label}") rescue nil
    end
  rescue Exception => e
    @nds_surface_geometry = nil
    Mode7.register_geometry_collision_source(nil, @map_id) if Mode7.respond_to?(:register_geometry_collision_source)
    Console.echo_error("VERMEIL surface geometry build: #{e.message}") if defined?(Console)
  end

  # Superficie derivada de Terrain Tags NDS. MountainWall/MountainWallPlane
  # nunca tienen altura horizontal; MountainTop/Volume definen superficie.
  def nds_tag_surface_height_at(tx, ty)
    return 0.0 if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    entries = @entry_cache[[tx, ty]] || []
    max_h = 0.0
    entries.each do |entry|
      id = nds_category_id(entry)
      next if id == Mode7::Config::NDS_STAIR_TERRAIN_TAG
      next if id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG ||
              id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
      h = if id == Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
            nds_mountain_height_at(tx, ty).to_f
          else
            Mode7.nds_volume_height_for_tag(id).to_f
          end
      max_h = h if h > max_h
    end
    max_h
  rescue Exception
    0.0
  end

  # Alias de compatibilidad: ya no representa un backend legacy; delega a NDS.
  def nds_legacy_surface_height_at(tx, ty)
    nds_tag_surface_height_at(tx, ty)
  end

  # V5.10.1: una celda pintada en el Geometry Editor puede elevar cualquier
  # tile horizontal, no solo NDSMountainTop/NDSVolume. La base P0 se retira del
  # gran bitmap Z=0 y se reconstruye luego como surface strip en su Z fisica.
  if private_method_defined?(:ground_entries_for_cell) &&
     !private_method_defined?(:_VERMEIL_V5101_ground_entries_for_cell)
    alias_method :_VERMEIL_V5101_ground_entries_for_cell, :ground_entries_for_cell
  end

  def ground_entries_for_cell(tx, ty, entries)
    base = _VERMEIL_V5101_ground_entries_for_cell(tx, ty, entries)
    return base if !@nds_surface_geometry
    return base if respond_to?(:nds_stair_cell?, true) && nds_stair_cell?(tx, ty)
    h = @nds_surface_geometry.height_at(tx, ty).to_f
    if @nds_surface_geometry.respond_to?(:plane_cell?) && @nds_surface_geometry.plane_cell?(tx, ty)
      pl = @nds_surface_geometry.plane_at(tx, ty) rescue nil
      if pl && (pl[:corners] || []).any? { |z| z.to_f > 0.001 }
        return []
      end
    end
    return base if h <= 0.001
    # Todo lo que sobrevivio al filtro original ya es arte horizontal P0.
    # Debe abandonar @ground para que no exista simultaneamente en Z=0 y Z=h.
    []
  rescue Exception
    base || []
  end

  if private_method_defined?(:paint_nds_underlay) &&
     !private_method_defined?(:_VERMEIL_V5101_paint_nds_underlay)
    alias_method :_VERMEIL_V5101_paint_nds_underlay, :paint_nds_underlay
  end

  def paint_nds_underlay(tx, ty, entries, ground_entries, target = @ground)
    _VERMEIL_V5101_paint_nds_underlay(tx, ty, entries, ground_entries, target)
    return if !@nds_surface_geometry
    return if @nds_surface_geometry.height_at(tx, ty).to_f <= 0.001
    return if nds_underlay_required?(entries)
    return if nds_base_ground_present?(ground_entries)
    underlay = nds_underlay_entries_for(tx, ty)
    return if !underlay || underlay.empty?
    blt_ground_cell(tx, ty, underlay, target)
  rescue Exception
  end

  # V5.10.1: cualquier consumidor legacy que pregunte la altura de MountainTop
  # recibe primero el height grid fisico. Esto evita que un level:0 explicito
  # vuelva a elevarse por la pila MountainWall del mapa 2D.
  if private_method_defined?(:nds_mountain_height_at) &&
     !private_method_defined?(:_VERMEIL_V5101_legacy_mountain_height_at)
    alias_method :_VERMEIL_V5101_legacy_mountain_height_at, :nds_mountain_height_at
  end

  def nds_mountain_height_at(tx, ty)
    # Solo las mesetas de NDS_REAL_MOUNTAIN_MAP_IDS tienen altura de
    # superficie; no arrastra vecinos en el resto.
    return 0.0 if Mode7.nds_mountain_billboard?(@map_id)
    if @nds_surface_geometry
      h = @nds_surface_geometry.height_at(tx, ty).to_f
      return h if @nds_surface_geometry.explicit_cell?(tx, ty) || h.abs >= 0.001
    end
    return _VERMEIL_V5101_legacy_mountain_height_at(tx, ty) if respond_to?(:_VERMEIL_V5101_legacy_mountain_height_at, true)
    Mode7::Config::NDS_MOUNTAIN_HEIGHT.to_f
  rescue Exception
    Mode7::Config::NDS_MOUNTAIN_HEIGHT.to_f
  end

  # El top visible debe ser exactamente la misma superficie que usan colision
  # y camara. La implementacion V5.7 seguia consultando el solver de montana
  # legacy y podia separarse del JSON/height brush.
  def nds_volume_surface_elevation(entries, tx = nil, ty = nil)
    return nil if tx.nil? || ty.nil?
    return nil if entries.any? { |entry| nds_mountain_face_plane_entry?(entry) }
    # Una escalera es una superficie inclinada unica. No dibujar tambien un
    # MountainTop horizontal debajo/encima de la rampa.
    return nil if entries.any? { |entry| nds_stair_entry?(entry) }
    h = @nds_surface_geometry ? @nds_surface_geometry.height_at(tx, ty).to_f : nds_tag_surface_height_at(tx, ty).to_f
    return nil if h <= 0.001
    # La geometria explicita es independiente del Terrain Tag: un tile normal
    # pintado L1/L2 en Maker Studio tambien se convierte en superficie 3D real.
    h
  rescue Exception
    nil
  end

  # Base para stairs, props y soportes. Desde V5.10 ya no vuelve a deducir Z
  # desde una categoria distinta: consulta la misma geometria central.
  def nds_base_surface_height_at(tx, ty)
    return @nds_surface_geometry.height_at(tx, ty) if @nds_surface_geometry
    nds_tag_surface_height_at(tx, ty)
  rescue Exception
    0.0
  end

  # 019_NDSVolumePerformance llama dinamicamente a este metodo para construir
  # caras. Por tanto los vertices visibles nacen del MISMO height grid usado por
  # colision/camara/actores.
  def nds_volume_cell_height(tx, ty)
    if @nds_surface_geometry
      # Ramps are not rectangular columns. For face generation use the lower
      # adjacent support; the inclined quad itself is built by NDSStair.
      if respond_to?(:nds_stair_cell?, true) && nds_stair_cell?(tx, ty)
        south = ty + 1 < @map.height ? @nds_surface_geometry.height_at(tx, ty + 1).to_f : 0.0
        north = ty - 1 >= 0 ? @nds_surface_geometry.height_at(tx, ty - 1).to_f : south
        return [south, north].min
      end
      return @nds_surface_geometry.height_at(tx, ty)
    end
    nds_tag_surface_height_at(tx, ty)
  rescue Exception
    0.0
  end

  def nds_mountain_art_cell?(tx, ty)
    entries = @entry_cache && @entry_cache[[tx.to_i, ty.to_i]]
    return false if !entries || entries.empty?
    entries.any? do |entry|
      id = nds_category_id(entry)
      id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG ||
        id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
    end
  rescue Exception
    false
  end
end
# >>> [VERMEIL] Visual 2.5D - 028_NDSUnifiedHeight.rb
#===============================================================================
# [VERMEIL] Visual 2.5D - 028_NDSUnifiedHeight.rb
# Sistema centralizado de alturas con caché plano O(1).
#
# Reemplaza las múltiples rutas de lookup distribuidas en 020/023 por una
# sola fuente de verdad. Cada celda tiene exactamente un valor de altura
# cacheado; las consultas en coordenadas de mundo interpolan entre celdas
# vecinas sin recorrer arrays.
#
# Jerarquía de resolución (la primera que devuelve > 0 gana):
#   1. SurfaceGeometry explícita (Geometry v4 / .v25r)
#   2. Terrain Tags NDS (Volume/MountainTop/Stair)
#   3. Stair ramp interpolation (continua entre celdas)
#===============================================================================

# --- Supresión de spam de consola ---
# Evita que el mismo mensaje de error se imprima repetidamente.
module Mode7
  @@_console_error_last = nil
  @@_console_error_count = 0

  def self._console_suppress(msg)
    if msg == @@_console_error_last
      @@_console_error_count += 1
      return
    end
    @@_console_error_last = msg
    @@_console_error_count = 0
    Console.echo_error(msg) if defined?(Console)
  end

  def self._console_suppress_reset
    @@_console_error_last = nil
    @@_console_error_count = 0
  end
end

module Mode7
  # ---------------------------------------------------------------------------
  # HeightCache — caché plano de alturas por celda
  # ---------------------------------------------------------------------------
  class HeightCache
    attr_reader :width, :height, :built

    def initialize
      @cells = {}         # [tx,ty] => Float (altura discreta)
      @ramps = []         # rampas de escalera (rango de world coordinates)
      @ramp_grid = nil    # Hash [grid_x,grid_y] => ramp index (búsqueda espacial)
      @width = 0
      @height = 0
      @built = false
    end

    def clear
      @cells.clear
      @ramps.clear
      @ramp_grid = nil
      @width = 0
      @height = 0
      @built = false
    end

    # ---------------------------------------------------------------------------
    # Construcción desde el renderer
    # ---------------------------------------------------------------------------
    def build(renderer)
      clear
      Mode7._console_suppress_reset
      map = renderer.instance_variable_get(:@map)
      return if !map
      @width = map.width.to_i
      @height = map.height.to_i
      entry_cache = renderer.instance_variable_get(:@entry_cache)
      return if !entry_cache

      build_cells_from_entries(renderer, entry_cache)
      build_ramps_from_renderer(renderer)
      build_ramp_grid
      @built = true
    rescue Exception => e
      clear
      Mode7._console_suppress("2.5D HeightCache build: #{e.message}")
    end

    # ---------------------------------------------------------------------------
    # Consulta discreta (tile coordinates) — O(1)
    # ---------------------------------------------------------------------------
    def height_at(tx, ty)
      @cells[[tx.to_i, ty.to_i]] || 0.0
    end

    # ---------------------------------------------------------------------------
    # Consulta continua (world coordinates) — O(1) amortizado
    # Interpola bilinealmente entre las 4 celdas vecinas.
    # ---------------------------------------------------------------------------
    def height_at_real(wx, wy, tile_w = 32.0, tile_h = 32.0)
      # 1) Buscar rampa de escalera (O(1) con grid espacial)
      ramp = find_ramp_at(wx, wy)
      return interpolate_ramp(ramp, wx, wy) if ramp

      # 2) Interpolación bilineal entre celdas vecinas
      tx0 = (wx / tile_w).floor
      ty0 = (wy / tile_h).floor
      tx1 = tx0 + 1
      ty1 = ty0 + 1

      frac_x = (wx / tile_w) - tx0.to_f
      frac_y = (wy / tile_h) - ty0.to_f
      frac_x = frac_x.clamp(0.0, 1.0)
      frac_y = frac_y.clamp(0.0, 1.0)

      h00 = height_at(tx0, ty0)
      h10 = height_at(tx1, ty0)
      h01 = height_at(tx0, ty1)
      h11 = height_at(tx1, ty1)

      top = h00 + (h10 - h00) * frac_x
      bot = h01 + (h11 - h01) * frac_x
      top + (bot - top) * frac_y
    end

    # Retorna la rampa en (wx,wy) o nil.
    def find_ramp_at(wx, wy)
      return nil if !@ramp_grid || @ramps.empty?
      tw = Game_Map::TILE_WIDTH.to_f
      th = Game_Map::TILE_HEIGHT.to_f
      gx = (wx / tw / Mode7::Config::NDS_RUNTIME_BUCKET_SIZE).floor
      gy = (wy / th / Mode7::Config::NDS_RUNTIME_BUCKET_SIZE).floor
      (-1..1).each do |dy|
        (-1..1).each do |dx|
          key = [gx + dx, gy + dy]
          indices = @ramp_grid[key]
          next if !indices
          indices.each do |i|
            r = @ramps[i]
            next if wx < r[:west_wx] - 0.001 || wx > r[:east_wx] + 0.001
            next if wy < r[:north_wy] - 0.001 || wy > r[:south_wy] + 0.001
            return r
          end
        end
      end
      nil
    end

    private

    # ---------------------------------------------------------------------------
    # Construcción de celdas desde entry_cache
    # ---------------------------------------------------------------------------
    def build_cells_from_entries(renderer, entry_cache)
      entry_cache.each do |(tx, ty), entries|
        next if !entries || entries.empty?
        h = compute_cell_height(renderer, entries, tx, ty)
        @cells[[tx, ty]] = h if h.abs >= 0.001
      end
    end

    def compute_cell_height(renderer, entries, tx, ty)
      mountain_h = 0.0

      entries.each do |entry|
        id = renderer.send(:nds_category_id, entry) rescue nil
        next if id.nil?

        case id
        when Mode7::Config::NDS_STAIR_TERRAIN_TAG
          next
        when Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG,
             Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
          next
        when Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
          mh = renderer.send(:nds_mountain_height_at, tx, ty).to_f rescue 0.0
          mountain_h = mh if mh > mountain_h
        else
          mid = renderer.instance_variable_get(:@map_id)
          h = Mode7.nds_volume_height_for_tag(id, mid).to_f
          roof_h = Mode7.nds_roof_height_for_tag(id).to_f
          h = roof_h if roof_h > h
          mountain_h = h if h > mountain_h
        end
      end

      mountain_h
    end

    # ---------------------------------------------------------------------------
    # Construcción de rampas de escalera
    # ---------------------------------------------------------------------------
    def build_ramps_from_renderer(renderer)
      raw_ramps = renderer.instance_variable_get(:@nds_stair_ramps)
      return if !raw_ramps
      @ramps = raw_ramps.dup
    end

    def build_ramp_grid
      @ramp_grid = {}
      bucket = Mode7::Config::NDS_RUNTIME_BUCKET_SIZE.to_i
      bucket = 8 if bucket <= 0
      tw = Game_Map::TILE_WIDTH.to_f
      th = Game_Map::TILE_HEIGHT.to_f

      @ramps.each_with_index do |ramp, idx|
        min_gx = (ramp[:west_wx] / tw / bucket).floor
        max_gx = (ramp[:east_wx] / tw / bucket).floor
        min_gy = (ramp[:north_wy] / th / bucket).floor
        max_gy = (ramp[:south_wy] / th / bucket).floor

        min_gx.upto(max_gx) do |gx|
          min_gy.upto(max_gy) do |gy|
            key = [gx, gy]
            @ramp_grid[key] ||= []
            @ramp_grid[key] << idx
          end
        end
      end
    end

    def interpolate_ramp(ramp, wx, wy)
      span = ramp[:south_wy] - ramp[:north_wy]
      return ramp[:south_z].to_f if span.abs <= 0.001
      t = ((ramp[:south_wy] - wy) / span).clamp(0.0, 1.0)
      ramp[:south_z] + (ramp[:north_z] - ramp[:south_z]) * t
    end
  end

  # ---------------------------------------------------------------------------
  # Integración con Mode7 module — delegación unificada
  # ---------------------------------------------------------------------------
  class << self
    def height_cache
      @@height_cache ||= HeightCache.new
    end

    def rebuild_height_cache(renderer)
      height_cache.build(renderer)
    end

  end
end

#===============================================================================
# Integración con Mode7Renderer — rebuild del caché al cargar mapa
#===============================================================================
class Mode7Renderer
  private

  if private_method_defined?(:build_nds_surface_geometry)
    alias_method :_VERMEIL_UH_orig_build_surface, :build_nds_surface_geometry
  end

  def build_nds_surface_geometry
    _VERMEIL_UH_orig_build_surface if respond_to?(:_VERMEIL_UH_orig_build_surface, true)
    Mode7.rebuild_height_cache(self)
  end
end
# >>> [VERMEIL] Visual 2.5D - 022_NDSNativeGround.rb
#===============================================================================
# [VERMEIL] Visual 2.5D - 022_NDSNativeGround.rb
# V5.5 - Plano de suelo persistente proyectado en GPU para mkxp-z-ext.
#
# Reemplaza las bandas Sprite#corners por un unico quad con perspectiva exacta.
# Ruby solo actualiza cinco uniforms cuando cambia la camara; el bitmap del mapa
# permanece en GPU y no se vuelve a rasterizar durante el movimiento.
#===============================================================================

class Mode7Renderer
  NDS_NATIVE_GROUND_SHADER_PATH =
    "Plugins/[VERMEIL] Visual 2.5D/Shaders/nds_ground.frag"

  if private_method_defined?(:update_nds_ground) &&
     !private_method_defined?(:_VERMEIL_V55_band_update_nds_ground)
    alias_method :_VERMEIL_V55_band_update_nds_ground, :update_nds_ground
  end
  if private_method_defined?(:dispose_nds_ground) &&
     !private_method_defined?(:_VERMEIL_V55_band_dispose_nds_ground)
    alias_method :_VERMEIL_V55_band_dispose_nds_ground, :dispose_nds_ground
  end
  if private_method_defined?(:apply_tone_color) &&
     !private_method_defined?(:_VERMEIL_V55_orig_apply_tone_color)
    alias_method :_VERMEIL_V55_orig_apply_tone_color, :apply_tone_color
  end

  private

  def nds_native_ground_enabled?
    return false if @nds_native_ground_failed
    return false if !Mode7::Config::NDS_NATIVE_GROUND_SHADER
    Mode7::MKXPZExt.shader? && Mode7.perspective_mode?
  rescue Exception
    false
  end

  def ensure_nds_native_ground
    return false if !nds_native_ground_enabled?
    if @nds_native_ground_sprite && !@nds_native_ground_sprite.disposed? &&
       @nds_native_ground_shader && !@nds_native_ground_shader.disposed?
      if @nds_native_ground_sprite.bitmap != @ground
        @nds_native_ground_sprite.bitmap = @ground
      end
      return true
    end

    dispose_nds_native_ground
    @nds_native_ground_shader = Shader.new(NDS_NATIVE_GROUND_SHADER_PATH)
    @nds_native_ground_sprite = Sprite.new(@viewport)
    @nds_native_ground_sprite.bitmap = @ground
    @nds_native_ground_sprite.shader = @nds_native_ground_shader
    @nds_native_ground_sprite.x = 0
    @nds_native_ground_sprite.y = 0
    @nds_native_ground_sprite.ox = 0
    @nds_native_ground_sprite.oy = 0
    @nds_native_ground_sprite.z = -1000
    @nds_native_ground_sprite.visible = false
    true
  rescue Exception => e
    nds_disable_native_ground(e)
    false
  end

  def dispose_nds_native_ground
    spr = @nds_native_ground_sprite
    shader = @nds_native_ground_shader
    if spr && !spr.disposed?
      begin
        spr.shader = nil
      rescue Exception
      end
      spr.dispose
    end
    shader.dispose if shader && !shader.disposed?
    @nds_native_ground_sprite = nil
    @nds_native_ground_shader = nil
    @nds_native_ground_key = nil
  rescue Exception
    @nds_native_ground_sprite = nil
    @nds_native_ground_shader = nil
    @nds_native_ground_key = nil
  end

  def dispose_nds_ground
    dispose_nds_native_ground
    _VERMEIL_V55_band_dispose_nds_ground
  end

  def nds_disable_native_ground(error)
    @nds_native_ground_failed = true
    dispose_nds_native_ground
    return if @nds_native_ground_error_logged
    @nds_native_ground_error_logged = true
    if defined?(Console)
      Console.echo_error("2.5D GPU ground fallback: #{error.message}")
    end
  rescue Exception
  end

  def nds_native_ground_key
    [
      Mode7.cam_x.to_f.round(4),
      Mode7.projection_cam_y.to_f.round(4),
      Mode7.perspective_pivot_world_y.to_f.round(4),
      Mode7.projection_cam_elevation.to_f.round(4),
      Mode7.projection_revision
    ]
  end

  def update_nds_native_ground_uniforms
    math = Mode7.nds_camera_math
    shader = @nds_native_ground_shader
    shader.set_vec2("u_camera", Mode7.cam_x.to_f,
                    Mode7.perspective_pivot_world_y.to_f)
    shader.set_vec2("u_optics", math[:distance].to_f, math[:focal].to_f)
    shader.set_vec2("u_angle", math[:sin].to_f, math[:cos_raw].to_f)
    shader.set_vec2("u_screen", Mode7.center_x.to_f, Mode7.pivot_y.to_f)
    shader.set_float("u_camera_elevation", Mode7.projection_cam_elevation.to_f)
    near = Mode7::Config::PERSPECTIVE_NEAR_CLIP.to_f
    near = 8.0 if near <= 0.0
    shader.set_float("u_near", near)
  end

  def update_nds_ground(force = false)
    return _VERMEIL_V55_band_update_nds_ground(force) if !nds_native_ground_enabled?
    return if !nds_ground_active?
    build_nds_ground if !@nds_ground_pool ||
                        @nds_ground_bitmap_id != @ground.object_id
    return _VERMEIL_V55_band_update_nds_ground(force) if !ensure_nds_native_ground

    key = nds_native_ground_key
    return if !force && @nds_native_ground_key == key
    @nds_native_ground_key = key

    min_y, max_y = nds_visible_world_y_range
    x0, x1 = nds_visible_world_x_range(min_y, max_y)
    sx0 = x0.floor.clamp(0, @ground.width)
    sx1 = x1.ceil.clamp(0, @ground.width)
    sy0 = min_y.floor.clamp(0, @ground.height)
    sy1 = max_y.ceil.clamp(0, @ground.height)

    spr = @nds_native_ground_sprite
    if sx1 <= sx0 || sy1 <= sy0
      spr.visible = false
      hide_unused_nds_ground(0)
      return
    end

    spr.bitmap = @ground if spr.bitmap != @ground
    spr.src_rect.set(sx0, sy0, sx1 - sx0, sy1 - sy0)
    spr.z = -1000
    spr.tone = @tone
    spr.color = @color
    update_nds_native_ground_uniforms
    spr.visible = true
    hide_unused_nds_ground(0)
  rescue Exception => e
    nds_disable_native_ground(e)
    _VERMEIL_V55_band_update_nds_ground(force)
  end

  def apply_tone_color
    _VERMEIL_V55_orig_apply_tone_color
    spr = @nds_native_ground_sprite
    return if !spr || spr.disposed?
    spr.tone = @tone
    spr.color = @color
  end
end
# >>> [VERMEIL] Visual 2.5D - 013_Heightmap.rb
#===============================================================================
# [VERMEIL] Visual 2.5D - 013_Heightmap.rb
# CAMARA 3D / RELIEVE REAL DEL TERRENO (nuevo, distinto al render plano previo)
# Referencia: H-Mode7.update_camera (V.1.4.2) y Neo Mode 7 cam altitude.
#
# Un PNG de relieve (Graphics/Heightmaps/Heightmap_XXX.png, XXX = id del mapa)
# guarda la altura del terreno por pixel (0=negro, 255=blanco). Este modulo:
#   1) Carga y cachea el heightmap por mapa.
#   2) Eleva el suelo: las filas de pantalla se desplazan en Y segun el relieve
#      que atraviesan (proyeccion en picada mas alta si el terreno sube).
#   3) Mueve la camara (altura del ojo) siguiendo la elevacion bajo el jugador,
#      interpolada con Config::ALTITUDE_SMOOTH.
#
# Es OPT-IN: solo actua en mapas que tengan un heightmap. Sin PNG, no cambia
# nada del render anterior.
#===============================================================================
module Mode7
  module Heightmap
    module_function

    # Obtiene (o carga y cachea) la tabla de alturas del mapa actual.
    # Devuelve un Array[Array[Float]] [x][y] con la altura en px de mundo,
    # o nil si no hay heightmap para el mapa.
    def data
      return @data if @data && @map_id == $game_map.map_id
      load_current
    end

    def dispose
      @bitmap&.dispose
      @bitmap = nil
      @data = nil
      @map_id = nil
    end

    # Altura (px de mundo) en el tile (tx, ty) del mapa actual.
    def altitude_at(x, y)
      d = data
      return 0 if !d
      d[[x, 0].max, [y, 0].max]
    end

    # Altura bajo el jugador (px de mundo).
    def player_altitude
      return 0 if !$game_player
      tx = $game_player.x
      ty = $game_player.y
      return altitude_at(tx, ty)
    end

    # La altura actual aplicada a la camara (px de mundo), suavizado.
    def camera_altitude
      return @camera_altitude || 0
    end

    # Avanza el seguimiento suave de la camara hacia la altura del jugador.
    # Llamar cada frame desde Scene_Map cuando el heightmap este activo.
    def update_camera
      d = data
      return if !d
      target = player_altitude
      return if @camera_altitude.nil?
      @camera_altitude += (target - @camera_altitude) * Config::ALTITUDE_SMOOTH
      @camera_altitude = target if (target - @camera_altitude).abs < 0.5
    end

    # ------- carga y cache -------
    def load_current
      @bitmap&.dispose
      @data = nil
      @map_id = $game_map.map_id
      @camera_altitude = 0
      filename = sprintf("Graphics/%s/Heightmap_%03d.png",
        Config::HEIGHTMAP_FOLDER, @map_id)
      return nil if !safe_exist?(filename)
      bmp = Bitmap.new(filename)
      @bitmap = bmp
      build_data(bmp)
      @data
    rescue
      @data = nil
      nil
    end

    def safe_exist?(path)
      return FileTest.exist?(path)
    end

    # Reduce el PNG a una tabla de tierra. Re-muestrea a px por tile (nueva
    # altura en horizonte por pixel de mapa => altura por tile).
    def build_data(bmp)
      w = $game_map.width
      h = $game_map.height
      max = Config::HEIGHT_RANGE_PX
      scale = Config::HEIGHT_SCALE
      @data = Array.new(w) { Array.new(h, 0) }
      w.times do |tx|
        h.times do |ty|
          sx = ((tx + 0.5) * bmp.width / w.to_f).floor.clamp(0, bmp.width - 1)
          sy = ((ty + 0.5) * bmp.height / h.to_f).floor.clamp(0, bmp.height - 1)
          c = bmp.get_pixel(sx, sy)
          lum = (c.red + c.green + c.blue) / 3.0
          @data[tx][ty] = (lum / 255.0 * max * scale).round
        end
      end
    end
  end
end
