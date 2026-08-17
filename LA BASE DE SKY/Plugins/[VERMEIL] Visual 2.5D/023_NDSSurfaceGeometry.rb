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

    def initialize(map_id, width, height, height_step, source = :legacy, path = nil)
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

    # V5.10 override: todos los consumidores leen la misma rejilla.
    def nds_surface_height_at(x, y)
      geo = current_surface_geometry
      return geo.height_at(x, y) if geo
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
      return 0.0 if !geo
      renderer = $scene.instance_variable_get(:@map_renderer)
      # Las ramps legacy se construyen despues del height grid y conservan su
      # interpolacion continua. Un JSON con ramps explicitas tiene prioridad.
      if geo.instance_variable_get(:@ramps) && !geo.instance_variable_get(:@ramps).empty?
        return geo.real_height_at(world_x, world_y,
                                  Game_Map::TILE_WIDTH.to_f,
                                  Game_Map::TILE_HEIGHT.to_f)
      end
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
      geo.real_height_at(world_x, world_y,
                         Game_Map::TILE_WIDTH.to_f,
                         Game_Map::TILE_HEIGHT.to_f)
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

    # Read the explicit file first. A fully-authored Geometry map can opt out of
    # legacy Terrain Tags; in that common case there is no reason to scan the
    # complete map and calculate legacy elevation before throwing it away.
    overlay = Mode7::SurfaceGeometry.from_file(@map_id, @map.width, @map.height)
    if overlay && !overlay.inherit_legacy
      @nds_surface_geometry = overlay
      Mode7.register_geometry_collision_source(@nds_surface_geometry, @map_id) if Mode7.respond_to?(:register_geometry_collision_source)
      Console.echo_li("[VERMEIL] Runtime Geometry: #{overlay.path}") if defined?(Console) rescue nil
      return
    end

    legacy = Mode7::SurfaceGeometry.new(
      @map_id, @map.width, @map.height,
      Mode7::Config::SURFACE_GEOMETRY_HEIGHT_STEP, :legacy, nil
    )
    (@entry_cache || {}).each do |pos, entries|
      next if !entries || entries.empty?
      tx, ty = pos
      h = nds_legacy_surface_height_at(tx, ty)
      legacy.set_height(tx, ty, h) if h.abs >= 0.001
    end

    geo = if overlay && overlay.inherit_legacy
            legacy.overlay_from!(overlay)
          elsif overlay
            overlay
          else
            legacy
          end
    @nds_surface_geometry = geo
    Mode7.register_geometry_collision_source(@nds_surface_geometry, @map_id) if Mode7.respond_to?(:register_geometry_collision_source)
    if defined?(Console)
      label = geo.explicit? ? geo.path : "Terrain Tags legacy"
      Console.echo_li("[VERMEIL] Surface Geometry: #{label}") rescue nil
    end
  rescue Exception => e
    @nds_surface_geometry = nil
    Mode7.register_geometry_collision_source(nil, @map_id) if Mode7.respond_to?(:register_geometry_collision_source)
    Console.echo_error("VERMEIL surface geometry build: #{e.message}") if defined?(Console)
  end

  # Conversion legacy. IMPORTANTE: MountainWall/MountainWallPlane nunca tienen
  # altura horizontal; solo MountainTop/Volume definen la superficie caminable.
  def nds_legacy_surface_height_at(tx, ty)
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
    h = @nds_surface_geometry ? @nds_surface_geometry.height_at(tx, ty).to_f : nds_legacy_surface_height_at(tx, ty).to_f
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
    nds_legacy_surface_height_at(tx, ty)
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
    nds_legacy_surface_height_at(tx, ty)
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
