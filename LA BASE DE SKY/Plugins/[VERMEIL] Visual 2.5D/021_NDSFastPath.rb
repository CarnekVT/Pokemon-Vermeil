#===============================================================================
# [VERMEIL] Visual 2.5D - 021_NDSFastPath.rb
# V4.1 - Fast path para 100+ FPS y arranque mas corto.
#
# - Un solo update del ground por frame (elimina el doble pase legacy).
# - El fondo fullscreen no se rellena cada pixel de movimiento.
# - Walls/props/prioridades usan buckets espaciales; no se recorre el mapa entero.
# - Reproyeccion cuantizada configurable para evitar trabajo subpixel redundante.
# - Diagnostico del coste de build y numero de objetos activos.
#===============================================================================

class Mode7Renderer
  if private_method_defined?(:build) &&
     !private_method_defined?(:_VERMEIL_V41_fast_orig_build)
    alias_method :_VERMEIL_V41_fast_orig_build, :build
  end
  if private_method_defined?(:update_walls) &&
     !private_method_defined?(:_VERMEIL_V41_fast_orig_update_walls)
    alias_method :_VERMEIL_V41_fast_orig_update_walls, :update_walls
  end
  if private_method_defined?(:update_priority_surfaces) &&
     !private_method_defined?(:_VERMEIL_V41_fast_orig_update_priority_surfaces)
    alias_method :_VERMEIL_V41_fast_orig_update_priority_surfaces,
                 :update_priority_surfaces
  end

  attr_reader :nds_fast_last_build_ms

  # Reemplaza la cadena de aliases V3/V4 para que ground se reproyecte una sola
  # vez y volume se actualice una sola vez por frame.
  def update
    @tilesets.update
    @autotiles.update

    built = false
    if @need_build || @map_id != $game_map.map_id
      build
      built = true
    elsif @autotiles.changed && !@autotile_cells.empty?
      recomposite_autotiles
      @need_ground_redraw = true
    end

    cx = Mode7.cam_x
    cy = Mode7.cam_y
    ce = Mode7.respond_to?(:projection_cam_elevation) ? Mode7.projection_cam_elevation.to_f : 0.0

    if nds_ground_active?
      fast_refresh_nds_background(built)
      # El bitmap fuente se comparte: una animacion no necesita recalcular los
      # corners. La key interna decide si la camara realmente cambio suficiente.
      update_nds_ground(built)
      @last_cam_x = cx
      @last_cam_y = cy
      @last_cam_elevation = ce
      @need_ground_redraw = false
    else
      # La proyeccion anterior usaba quads separados. Ocultarlos antes del
      # suelo legacy evita que ambas copias del mapa sobrevivan al cambio.
      hide_unused_nds_ground(0) if @nds_ground_pool
      redraw_step = Mode7::Config::GROUND_REDRAW_WORLD_STEP.to_f
      redraw_step = 1.0 if redraw_step <= 0.0
      camera_moved = @need_ground_redraw || @last_cam_x.nil? || @last_cam_y.nil? ||
                     @last_cam_elevation.nil? ||
                     (@last_cam_x - cx).abs >= redraw_step ||
                     (@last_cam_y - cy).abs >= redraw_step ||
                     (@last_cam_elevation - ce).abs >= 0.01
      if camera_moved
        draw_ground
        @last_cam_x = cx
        @last_cam_y = cy
        @last_cam_elevation = ce
        @need_ground_redraw = false
      end
    end

    update_ms_fog
    update_walls
    update_priority_surfaces
    update_nds_volume_faces if Mode7::Config::NDS_VOLUME_ENABLED
    apply_tone_color
    @autotiles.changed = false
  end

  private

  def build
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue nil
    _VERMEIL_V41_fast_orig_build
    begin
      build_nds_runtime_buckets
    rescue Exception => e
      @nds_fast_wall_buckets = nil
      @nds_fast_strip_buckets = nil
      @nds_fast_object_buckets = nil
      Console.echo_error("2.5D V4.1 buckets: #{e.message}") if defined?(Console)
    end
    fast_refresh_nds_background(true) if nds_ground_active?
    if t0
      @nds_fast_last_build_ms =
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0
    end
  end

  def fast_refresh_nds_background(force = false)
    return if !@ground_sprite || @ground_sprite.disposed? ||
              !@ground_sprite.bitmap || @ground_sprite.bitmap.disposed?
    c = projection_fill_color
    key = [c.red, c.green, c.blue, c.alpha,
           Mode7.indoor_map?, Mode7.map_mode]
    return if !force && @nds_fast_background_key == key
    @ground_sprite.bitmap.fill_rect(0, 0, Mode7.screen_w, Mode7.screen_h, c)
    @ground_sprite.z = -1001
    @nds_fast_background_key = key
  end

  def nds_fast_bucket_size
    bs = Mode7::Config::NDS_RUNTIME_BUCKET_SIZE.to_i
    bs > 0 ? bs : 8
  end

  def nds_fast_bucket_add(hash, index, min_tx, min_ty, max_tx, max_ty)
    bs = nds_fast_bucket_size
    bx0 = min_tx.to_i / bs
    bx1 = max_tx.to_i / bs
    by0 = min_ty.to_i / bs
    by1 = max_ty.to_i / bs
    bx = bx0
    while bx <= bx1
      by = by0
      while by <= by1
        hash[[bx, by]] << index
        by += 1
      end
      bx += 1
    end
  end

  def build_nds_runtime_buckets
    @nds_fast_wall_buckets = Hash.new { |h, k| h[k] = [] }
    @nds_fast_strip_buckets = Hash.new { |h, k| h[k] = [] }
    @nds_fast_object_buckets = Hash.new { |h, k| h[k] = [] }

    (@wall_data || []).each_with_index do |data, i|
      sprite, wx, wyb, h = data[0], data[1], data[2], data[3]
      min_tx, min_ty, max_tx, max_ty = data[9], data[10], data[11], data[12]
      if min_tx.nil? || max_tx.nil?
        width = sprite && sprite.bitmap ? sprite.bitmap.width : Game_Map::TILE_WIDTH
        min_tx = ((wx.to_f - width / 2.0) / Game_Map::TILE_WIDTH).floor
        max_tx = ((wx.to_f + width / 2.0) / Game_Map::TILE_WIDTH).ceil
      end
      min_ty ||= ((wyb.to_f - h.to_f) / Game_Map::TILE_HEIGHT).floor
      max_ty ||= (wyb.to_f / Game_Map::TILE_HEIGHT).ceil
      nds_fast_bucket_add(@nds_fast_wall_buckets, i, min_tx, min_ty, max_tx, max_ty)
    end

    (@priority_strips || []).each_with_index do |data, i|
      source, min_tx, ty = data[1], data[2], data[3]
      next if !source
      max_tx = min_tx.to_i + (source.width.to_f / Game_Map::TILE_WIDTH).ceil - 1
      nds_fast_bucket_add(@nds_fast_strip_buckets, i, min_tx, ty, max_tx, ty)
    end

    (@priority_data || []).each_with_index do |data, i|
      tx, ty = data[7], data[8]
      next if tx.nil? || ty.nil?
      nds_fast_bucket_add(@nds_fast_object_buckets, i, tx, ty, tx, ty)
    end

    @nds_fast_wall_active = []
    @nds_fast_strip_active = []
    @nds_fast_object_active = []
    @nds_fast_wall_key = nil
    @nds_fast_priority_key = nil
    @nds_fast_wall_visibility_key = nil
    @nds_fast_priority_visibility_key = nil
    @nds_fast_wall_subset = []
    @nds_fast_strip_subset = []
    @nds_fast_object_subset = []
  end

  def nds_fast_visible_indices(buckets, radius_x, radius_y)
    return [] if !buckets
    bs = nds_fast_bucket_size
    tx = (Mode7.cam_x / Game_Map::TILE_WIDTH).floor
    ty = (Mode7.cam_y / Game_Map::TILE_HEIGHT).floor
    bx0 = (tx - radius_x.to_i) / bs
    bx1 = (tx + radius_x.to_i) / bs
    by0 = (ty - radius_y.to_i) / bs
    by1 = (ty + radius_y.to_i) / bs
    seen = {}
    out = []
    bx = bx0
    while bx <= bx1
      by = by0
      while by <= by1
        (buckets[[bx, by]] || []).each do |i|
          next if seen[i]
          seen[i] = true
          out << i
        end
        by += 1
      end
      bx += 1
    end
    out
  end

  def nds_fast_hide_leaving(full, previous, current)
    keep = {}
    current.each { |i| keep[i] = true }
    (previous || []).each do |i|
      next if keep[i]
      data = full[i]
      spr = data && data[0]
      spr.visible = false if spr && !spr.disposed?
    end
  end

  def update_walls
    return _VERMEIL_V41_fast_orig_update_walls if !@nds_fast_wall_buckets

    step = Mode7::Config::NDS_WALL_REPROJECT_STEP.to_f
    step = 1.0 if step <= 0.0
    key = [(Mode7.cam_x / step).round,
           (Mode7.projection_cam_y / step).round,
           Mode7.projection_cam_elevation.to_f.round(3),
           Mode7.projection_revision]
    return if @nds_fast_wall_key == key
    @nds_fast_wall_key = key

    full = @wall_data || []
    visibility_key = [
      (Mode7.cam_x / Game_Map::TILE_WIDTH).floor,
      (Mode7.projection_cam_y / Game_Map::TILE_HEIGHT).floor,
      Mode7.projection_cam_elevation.to_f.round(2),
      Mode7.projection_revision
    ]
    if @nds_fast_wall_visibility_key != visibility_key
      indices = nds_fast_visible_indices(
        @nds_fast_wall_buckets,
        Mode7::Config::WALL_SPAWN_RADIUS_X,
        Mode7::Config::WALL_SPAWN_RADIUS_Y
      )
      nds_fast_hide_leaving(full, @nds_fast_wall_active, indices)
      @nds_fast_wall_active = indices
      @nds_fast_wall_subset = indices.map { |i| full[i] }.compact
      # Phase 2.4.1: rasteriza solo los componentes que entraron al radio activo.
      # Los demás conservan únicamente su descriptor/bounds y no pagan Bitmap
      # ni blits durante la carga inicial del mapa.
      if respond_to?(:v25_materialize_rigid_component, true)
        @nds_fast_wall_subset.each { |data| v25_materialize_rigid_component(data) }
      end
      @nds_fast_wall_visibility_key = visibility_key
    end

    @wall_data = @nds_fast_wall_subset
    _VERMEIL_V41_fast_orig_update_walls
  ensure
    @wall_data = full if defined?(full) && full
  end

  def update_priority_surfaces
    return _VERMEIL_V41_fast_orig_update_priority_surfaces if !@nds_fast_strip_buckets

    step = Mode7::Config::PRIORITY_REPROJECT_WORLD_STEP.to_f
    step = 1.0 if step <= 0.0
    key = [(Mode7.cam_x / step).round,
           (Mode7.projection_cam_y / step).round,
           Mode7.projection_revision]
    return if @nds_fast_priority_key == key
    @nds_fast_priority_key = key

    rx = Mode7::Config::WALL_SPAWN_RADIUS_X
    ry = Mode7::Config::WALL_SPAWN_RADIUS_Y
    full_strips = @priority_strips || []
    full_objects = @priority_data || []
    visibility_key = [
      (Mode7.cam_x / Game_Map::TILE_WIDTH).floor,
      (Mode7.projection_cam_y / Game_Map::TILE_HEIGHT).floor,
      Mode7.projection_cam_elevation.to_f.round(2),
      Mode7.projection_revision
    ]
    if @nds_fast_priority_visibility_key != visibility_key
      strip_indices = nds_fast_visible_indices(@nds_fast_strip_buckets, rx, ry)
      object_indices = nds_fast_visible_indices(@nds_fast_object_buckets, rx, ry)
      nds_fast_hide_leaving(full_strips, @nds_fast_strip_active, strip_indices)
      nds_fast_hide_leaving(full_objects, @nds_fast_object_active, object_indices)
      @nds_fast_strip_active = strip_indices
      @nds_fast_object_active = object_indices
      @nds_fast_strip_subset = strip_indices.map { |i| full_strips[i] }.compact
      @nds_fast_object_subset = object_indices.map { |i| full_objects[i] }.compact
      @nds_fast_priority_visibility_key = visibility_key
    end

    @priority_strips = @nds_fast_strip_subset
    @priority_data = @nds_fast_object_subset
    _VERMEIL_V41_fast_orig_update_priority_surfaces
  ensure
    @priority_strips = full_strips if defined?(full_strips) && full_strips
    @priority_data = full_objects if defined?(full_objects) && full_objects
  end
end

module Mode7
  class << self
    def nds_fast_stats
      return _INTL("Abre un mapa primero.") if !$scene.is_a?(Scene_Map)
      r = $scene.instance_variable_get(:@map_renderer)
      return _INTL("Renderer 2.5D no disponible.") if !r.is_a?(Mode7Renderer)
      build_ms = r.nds_fast_last_build_ms
      walls = r.instance_variable_get(:@wall_data) || []
      strips = r.instance_variable_get(:@priority_strips) || []
      objs = r.instance_variable_get(:@priority_data) || []
      faces = r.instance_variable_get(:@nds_volume_faces) || []
      active_w = r.instance_variable_get(:@nds_fast_wall_active) || []
      active_p = r.instance_variable_get(:@nds_fast_strip_active) || []
      active_o = r.instance_variable_get(:@nds_fast_object_active) || []
      active_v = r.instance_variable_get(:@nds_volume_active) || []
      [
        _INTL("Build: {1} ms", build_ms ? build_ms.round(1) : "?"),
        _INTL("FPS medio: {1}", nds_average_fps.round(1)),
        _INTL("Walls activos/total: {1}/{2}", active_w.length, walls.length),
        _INTL("Surfaces activas/total: {1}/{2}", active_p.length + active_o.length, strips.length + objs.length),
        _INTL("Volume activo/total: {1}/{2}", active_v.length, faces.length)
      ].join("\n")
    rescue Exception => e
      _INTL("Stats no disponibles: {1}", e.message)
    end
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :mode7_nds_fast_stats, {
    "name"        => _INTL("Perfil rapido NDS V5"),
    "parent"      => :main,
    "description" => _INTL("Muestra tiempo de build y objetos activos/total."),
    "effect"      => proc { pbMessage(Mode7.nds_fast_stats) }
  })
end
