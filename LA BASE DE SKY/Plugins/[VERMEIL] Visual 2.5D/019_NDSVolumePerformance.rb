#===============================================================================
# [VERMEIL] Visual 2.5D - 019_NDSVolumePerformance.rb
# V3.0: perfil NDS volumetrico + optimizaciones de proyeccion.
#
# Objetivos:
#   * cero Model3D: solo tiles/sprites RGSS + Sprite#corners nativo.
#   * top de cada tile intacto; volumen generado desde sus bordes.
#   * una sola camara/proyeccion para ground, walls, volumen y personajes.
#   * menor coste Ruby por frame para dejar margen a FPS de tres cifras.
#===============================================================================

module Mode7
  class << self
    # -------------------------------------------------------------------------
    # Runtime knobs. Permiten debug sin reescribir constantes.
    # -------------------------------------------------------------------------
    def nds_performance_profile
      @nds_performance_profile ||= Config::NDS_PERFORMANCE_PROFILE
    end

    def nds_performance_profile=(value)
      value = value.to_sym
      value = :performance if ![:performance, :balanced, :quality].include?(value)
      return value if @nds_performance_profile == value
      @nds_performance_profile = value
      @projection_revision = (@projection_revision || 0) + 1
      reset_caches
      renderer = $scene.instance_variable_get(:@map_renderer) if $scene.is_a?(Scene_Map)
      renderer.refresh if renderer && renderer.respond_to?(:refresh)
      value
    end

    def nds_volume_height
      @nds_volume_height ||= Config::NDS_VOLUME_DEFAULT_HEIGHT.to_f
    end

    def nds_volume_height=(value)
      value = value.to_f.clamp(0.0, Config::NDS_VOLUME_MAX_HEIGHT.to_f)
      return value if @nds_volume_height && (@nds_volume_height - value).abs < 0.001
      @nds_volume_height = value
      @projection_revision = (@projection_revision || 0) + 1
      renderer = $scene.instance_variable_get(:@map_renderer) if $scene.is_a?(Scene_Map)
      renderer.refresh if renderer && renderer.respond_to?(:refresh)
      value
    end

    # Balance de focal compartido por TODO el espacio 2.5D.
    # 0.0 conserva mas el ancho; 1.0 conserva mas la altura. 0.5 es el punto
    # NDS equilibrado y evita que un cambio de angulo deforme solo un eje.
    def nds_focal_balance
      return @nds_focal_balance if !@nds_focal_balance.nil?
      Config::PERSPECTIVE_FOCAL_BALANCE.to_f.clamp(0.0, 1.0)
    end

    def nds_focal_balance=(value)
      value = value.to_f.clamp(0.0, 1.0)
      return value if !@nds_focal_balance.nil? && (@nds_focal_balance - value).abs < 0.0001
      @nds_focal_balance = value
      @projection_revision = (@projection_revision || 0) + 1
      @nds_camera_math_key = nil
      reset_caches
      value
    end

    def nds_ground_band_height
      base = case nds_performance_profile
             when :quality then 8
             when :balanced then 12
             else 16
             end
      # Angulos altos necesitan mas subdivision para que la interpolacion del
      # quad no se note. Solo se paga ese coste cuando hace falta.
      a = (@current_alpha || context_default_alpha).to_f
      base = [base, 12].min if a >= 50.0
      base = [base, 8].min if a >= 60.0
      base
    end

    def nds_side_faces?
      return false if !Config::NDS_VOLUME_SIDE_FACES
      nds_performance_profile != :performance
    end

    def nds_average_fps
      return Graphics.average_frame_rate.to_f if Graphics.respond_to?(:average_frame_rate)
      0.0
    rescue Exception
      0.0
    end

    # -------------------------------------------------------------------------
    # Cache barato de trigonometria/focal. project() se llama muchisimas veces.
    # -------------------------------------------------------------------------
    def nds_camera_math
      alpha = (@current_alpha || context_default_alpha).to_f.clamp(0.0, 89.0)
      zoom = (@zoom || 1.0).to_f
      requested_d = (@distance_h || Config::DISTANCE_H).to_f
      if Config::PERSPECTIVE_SAFE_DISTANCE
        safe = Config::PERSPECTIVE_SAFE_DISTANCE_BASE.to_f +
               alpha * Config::PERSPECTIVE_SAFE_DISTANCE_PER_DEGREE.to_f
        requested_d = safe if requested_d < safe
      end
      key = [alpha.round(5), zoom.round(5), requested_d.round(4)]
      if @nds_camera_math_key != key
        rad = alpha * Math::PI / 180.0
        sin = Math.sin(rad)
        cos_raw = Math.cos(rad)
        cos = cos_raw.abs
        min_c = Config::PERSPECTIVE_COS_MIN.to_f
        min_c = 0.10 if min_c <= 0.0
        cos = min_c if cos < min_c
        balance = nds_focal_balance
        # balance=0: conserva ancho local; balance=1: conserva alto local.
        # 0.5 reparte la deformacion y evita tiles excesivamente anchos.
        focal_scale = zoom / (cos ** balance)
        max_scale = Config::PERSPECTIVE_FOCAL_SCALE_MAX.to_f
        focal_scale = [focal_scale, max_scale].min if max_scale > 0.0
        @nds_camera_math = {
          alpha: alpha, sin: sin, cos_raw: cos_raw, cos: cos,
          distance: [requested_d, 64.0].max,
          focal: [requested_d, 64.0].max * focal_scale
        }
        @nds_camera_math_key = key
      end
      @nds_camera_math
    end

    def perspective_sin; nds_camera_math[:sin]; end
    def perspective_cos_raw; nds_camera_math[:cos_raw]; end
    def perspective_cos; nds_camera_math[:cos]; end
    def perspective_distance; nds_camera_math[:distance]; end
    def perspective_focal; nds_camera_math[:focal]; end

    # Sin sqrt: suficiente para cerrar microjuntas entre bandas del mismo plano.
    def nds_fast_expand_quad(points, amount)
      return points if !points || points.length != 8 || amount.to_f <= 0.0
      a = amount.to_f
      [
        points[0] - a, points[1] - a,
        points[2] + a, points[3] - a,
        points[4] + a, points[5] + a,
        points[6] - a, points[7] + a
      ]
    end
  end
end

#-------------------------------------------------------------------------------
# Tags de volumen V4: relieve bajo, alto y cima de montana.
#-------------------------------------------------------------------------------
class Mode7Renderer
  if private_method_defined?(:configured_terrain_tag_height) &&
     !private_method_defined?(:_VERMEIL_V3_orig_configured_terrain_tag_height)
    alias_method :_VERMEIL_V3_orig_configured_terrain_tag_height,
                 :configured_terrain_tag_height
  end

  private

  def configured_terrain_tag_height(entry)
    tag = terrain_tag_for_entry(entry)
    if Mode7::Config::NDS_VOLUME_ENABLED && tag
      height = Mode7.nds_volume_height_for_tag(tag.id)
      return height.to_i if height > 0.0
    end
    _VERMEIL_V3_orig_configured_terrain_tag_height(entry)
  end
end

#-------------------------------------------------------------------------------
# Suelo v3: menos bandas, cache de reproyeccion, expansion barata.
#-------------------------------------------------------------------------------
class Mode7Renderer
  private

  def nds_ground_projection_key
    step = Mode7::Config::NDS_GROUND_REPROJECT_STEP.to_f
    step = 0.25 if step <= 0.0
    cx = (Mode7.cam_x / step).round
    cy = (Mode7.projection_cam_y / step).round
    [cx, cy,
     Mode7.instance_variable_get(:@current_alpha).to_f.round(3),
     Mode7.instance_variable_get(:@zoom).to_f.round(4),
     Mode7.instance_variable_get(:@distance_h).to_f.round(3),
     Mode7.projection_revision]
  rescue Exception
    nil
  end

  def update_nds_ground(force = false)
    return if !nds_ground_active?
    build_nds_ground if !@nds_ground_pool ||
                        @nds_ground_bitmap_id != @ground.object_id

    key = nds_ground_projection_key
    return if !force && key && @nds_ground_v3_key == key
    @nds_ground_v3_key = key

    band_h = Mode7.nds_ground_band_height.to_i
    min_y, max_y = nds_visible_world_y_range
    pool_max = Mode7::Config::GEOMETRY_GROUND_POOL_MAX.to_i
    pool_max = 96 if pool_max <= 0
    span = [max_y - min_y, 1.0].max
    needed_h = (span / pool_max.to_f).ceil
    band_h = [band_h, needed_h].max
    # Mantiene limites alineados a 4px para que src_rect no baile.
    band_h = ((band_h + 3) / 4) * 4

    first_band = (min_y / band_h).floor
    last_band  = (max_y / band_h).ceil
    overlap = Mode7::Config::GEOMETRY_GROUND_OVERLAP.to_f
    screen_margin = Mode7::Config::GEOMETRY_GROUND_CULL_MARGIN.to_f

    pool_index = 0
    band = first_band
    while band < last_band
      y0 = band * band_h.to_f
      y1 = [y0 + band_h, @ground.height.to_f].min
      break if y0 >= @ground.height

      x0, x1 = nds_visible_world_x_range(y0, y1)
      sx0 = x0.floor.clamp(0, @ground.width)
      sx1 = x1.ceil.clamp(0, @ground.width)
      sy0 = y0.floor.clamp(0, @ground.height)
      sy1 = y1.ceil.clamp(0, @ground.height)
      if sx1 <= sx0 || sy1 <= sy0
        band += 1
        next
      end

      tl = Mode7.project(sx0.to_f, sy0.to_f, 0.0)
      tr = Mode7.project(sx1.to_f, sy0.to_f, 0.0)
      br = Mode7.project(sx1.to_f, sy1.to_f, 0.0)
      bl = Mode7.project(sx0.to_f, sy1.to_f, 0.0)
      if tl && tr && br && bl
        points = [tl[0], tl[1], tr[0], tr[1], br[0], br[1], bl[0], bl[1]]
        points = Mode7.nds_fast_expand_quad(points, overlap) if overlap > 0.0
        xs = [points[0], points[2], points[4], points[6]]
        ys = [points[1], points[3], points[5], points[7]]
        visible = xs.max >= -screen_margin &&
                  xs.min <= Mode7.screen_w + screen_margin &&
                  ys.max >= -screen_margin &&
                  ys.min <= Mode7.screen_h + screen_margin
        if visible
          spr = ensure_nds_ground_sprite(pool_index)
          break if !spr
          spr.bitmap = @ground if spr.bitmap != @ground
          spr.src_rect.set(sx0, sy0, sx1 - sx0, sy1 - sy0)
          spr.corners = points
          spr.visible = true
          spr.z = -1000
          spr.tone = @tone
          if Mode7::Config::FOG_ENABLED
            c = nds_ground_color((ys.min + ys.max) * 0.5)
            spr.color.set(c[0], c[1], c[2], c[3])
          elsif spr.color.alpha != 0
            spr.color.set(0, 0, 0, 0)
          end
          pool_index += 1
        end
      end
      band += 1
    end
    hide_unused_nds_ground(pool_index)
  rescue Exception => e
    Console.echo_error("2.5D NDS v3 ground: #{e.message}") if defined?(Console)
    hide_unused_nds_ground(0)
  end
end

#-------------------------------------------------------------------------------
# Volumen por tile: el top ya lo eleva TERRAIN_TAG_TILE_HEIGHT/priority surface.
# Aqui solo se crean caras laterales desde los bordes del mismo tile.
# Las caras se agrupan en runs y se bucketizan para reducir draw calls/updates.
#-------------------------------------------------------------------------------
class Mode7Renderer
  if private_method_defined?(:build) &&
     !private_method_defined?(:_VERMEIL_V3_volume_orig_build)
    alias_method :_VERMEIL_V3_volume_orig_build, :build
  end
  if method_defined?(:update) && !method_defined?(:_VERMEIL_V3_volume_orig_update)
    alias_method :_VERMEIL_V3_volume_orig_update, :update
  end
  if method_defined?(:dispose) && !method_defined?(:_VERMEIL_V3_volume_orig_dispose)
    alias_method :_VERMEIL_V3_volume_orig_dispose, :dispose
  end

  def update
    _VERMEIL_V3_volume_orig_update
    update_nds_volume_faces if Mode7::Config::NDS_VOLUME_ENABLED
  end

  def dispose
    dispose_nds_volume_faces
    _VERMEIL_V3_volume_orig_dispose
  end

  private

  def build
    dispose_nds_volume_faces
    _VERMEIL_V3_volume_orig_build
    build_nds_volume_faces if Mode7::Config::NDS_VOLUME_ENABLED &&
                              Mode7::MKXPZExt.corners?
  end

  def dispose_nds_volume_faces
    if @nds_volume_faces
      @nds_volume_faces.each do |face|
        spr = face[:sprite]
        bmp = face[:bitmap]
        begin
          spr.corners = nil if spr && !spr.disposed? && Mode7::MKXPZExt.corners?
        rescue Exception
        end
        spr.dispose if spr && !spr.disposed?
        bmp.dispose if bmp && !bmp.disposed?
      end
    end
    @nds_volume_faces = nil
    @nds_volume_buckets = nil
    @nds_volume_active = []
    @nds_volume_projection_key = nil
  end

  def nds_volume_cell_height(tx, ty)
    return 0.0 if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    entries = @entry_cache[[tx, ty]]
    return 0.0 if !entries || entries.empty?
    max_h = 0.0
    entries.each do |entry|
      id = respond_to?(:nds_category_id, true) ? nds_category_id(entry) : nil
      h = id ? Mode7.nds_volume_height_for_tag(id).to_f : 0.0
      max_h = h if h > max_h
    end
    max_h
  end

  def nds_volume_cell_bitmap(tx, ty)
    bmp = Bitmap.new(Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
    bmp.clear
    entries = @entry_cache[[tx, ty]] || []
    # Replica el top visible de la celda, sin cambiar el bitmap original.
    entries.sort_by { |e| [e[:unify].to_i, entry_visual_priority(e)] }.each do |entry|
      next if wall_visual_owned?(entry) rescue false
      next if interior_black_entry?(entry) rescue false
      blt_entry_into(bmp, 0, 0, entry, entry[:opacity] || 255)
    end
    bmp
  end

  def nds_explicit_front_face_at?(tx, ty)
    entries = @entry_cache[[tx, ty + 1]]
    return false if !entries || entries.empty?
    entries.any? do |entry|
      id = respond_to?(:nds_category_id, true) ? nds_category_id(entry) : nil
      id == Mode7::Config::NDS_WALL_PLANE_TERRAIN_TAG ||
        id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
    end
  rescue Exception
    false
  end

  def nds_make_front_run(ty, tx0, tx1, top_h, base_h)
    dh = top_h - base_h
    return if dh <= 0.01
    tw = Game_Map::TILE_WIDTH
    th = Game_Map::TILE_HEIGHT
    y = (ty + 1) * th.to_f
    x0 = tx0 * tw.to_f
    x1 = (tx1 + 1) * tw.to_f
    spec = [:front, ty, tx0, tx1, top_h, base_h]
    bitmap = Mode7::Config::NDS_LAZY_VOLUME_FACES ? nil : nds_build_volume_face_bitmap(spec)
    add_nds_volume_face(bitmap, :front,
      [x0, y, top_h, x1, y, top_h, x1, y, base_h, x0, y, base_h],
      tx0, ty, tx1, ty, spec)
  end

  def nds_make_side_run(side, tx, ty0, ty1, top_h, base_h)
    dh = top_h - base_h
    return if dh <= 0.01
    tw = Game_Map::TILE_WIDTH
    th = Game_Map::TILE_HEIGHT
    x = (side == :west ? tx : tx + 1) * tw.to_f
    y0 = ty0 * th.to_f
    y1 = (ty1 + 1) * th.to_f
    spec = [side, tx, ty0, ty1, top_h, base_h]
    bitmap = Mode7::Config::NDS_LAZY_VOLUME_FACES ? nil : nds_build_volume_face_bitmap(spec)
    add_nds_volume_face(bitmap, side,
      [x, y0, top_h, x, y1, top_h, x, y1, base_h, x, y0, base_h],
      tx, ty0, tx, ty1, spec)
  end

  def nds_build_volume_face_bitmap(spec)
    kind = spec[0]
    tw = Game_Map::TILE_WIDTH
    th = Game_Map::TILE_HEIGHT
    if kind == :front
      _kind, ty, tx0, tx1, top_h, base_h = spec
      dh = top_h - base_h
      sample = Mode7::Config::NDS_VOLUME_EDGE_SAMPLE.to_i.clamp(1, th)
      width = (tx1 - tx0 + 1) * tw
      src = Bitmap.new(width, [dh.round, 1].max)
      src.clear
      tx = tx0
      while tx <= tx1
        tile = nds_volume_cell_bitmap(tx, ty)
        src.stretch_blt(Rect.new((tx - tx0) * tw, 0, tw, src.height),
                        tile, Rect.new(0, th - sample, tw, sample))
        tile.dispose
        tx += 1
      end
      shade = Mode7::Config::NDS_VOLUME_FRONT_SHADE.to_i.clamp(0, 255)
      src.fill_rect(0, 0, src.width, src.height, Color.new(0, 0, 0, shade)) if shade > 0
      return src
    end

    side, tx, ty0, ty1, top_h, base_h = spec
    dh = top_h - base_h
    sample = Mode7::Config::NDS_VOLUME_EDGE_SAMPLE.to_i.clamp(1, tw)
    width = (ty1 - ty0 + 1) * th
    src = Bitmap.new(width, [dh.round, 1].max)
    src.clear
    ty = ty0
    while ty <= ty1
      tile = nds_volume_cell_bitmap(tx, ty)
      edge_x = side == :west ? 0 : tw - sample
      strip = Bitmap.new(sample, th)
      strip.blt(0, 0, tile, Rect.new(edge_x, 0, sample, th))
      src.stretch_blt(Rect.new((ty - ty0) * th, 0, th, src.height),
                      strip, Rect.new(0, 0, sample, th))
      strip.dispose
      tile.dispose
      ty += 1
    end
    shade = Mode7::Config::NDS_VOLUME_SIDE_SHADE.to_i.clamp(0, 255)
    src.fill_rect(0, 0, src.width, src.height, Color.new(0, 0, 0, shade)) if shade > 0
    src
  end

  def add_nds_volume_face(bitmap, kind, world_points, min_tx, min_ty, max_tx, max_ty, spec = nil)
    sprite = nil
    if bitmap
      sprite = Sprite.new(@viewport)
      sprite.bitmap = bitmap
      sprite.visible = false
      sprite.z = -999
    end
    face = {
      sprite: sprite, bitmap: bitmap, kind: kind, world: world_points,
      min_tx: min_tx, min_ty: min_ty, max_tx: max_tx, max_ty: max_ty,
      spec: spec, last_used: 0
    }
    index = @nds_volume_faces.length
    @nds_volume_faces << face

    bs = Mode7::Config::NDS_VOLUME_BUCKET_SIZE.to_i
    bs = 8 if bs <= 0
    bx0 = min_tx / bs
    bx1 = max_tx / bs
    by0 = min_ty / bs
    by1 = max_ty / bs
    bx = bx0
    while bx <= bx1
      by = by0
      while by <= by1
        @nds_volume_buckets[[bx, by]] << index
        by += 1
      end
      bx += 1
    end
  end

  def ensure_nds_volume_face_resources(face)
    spr = face[:sprite]
    return spr if spr && !spr.disposed?
    bitmap = face[:bitmap]
    if !bitmap || bitmap.disposed?
      bitmap = nds_build_volume_face_bitmap(face[:spec])
      face[:bitmap] = bitmap
    end
    spr = Sprite.new(@viewport)
    spr.bitmap = bitmap
    spr.visible = false
    spr.z = -999
    face[:sprite] = spr
    spr
  rescue Exception => e
    Console.echo_error("2.5D lazy volume face: #{e.message}") if defined?(Console)
    nil
  end

  def prune_nds_volume_face_cache(active_indices)
    max = Mode7::Config::NDS_VOLUME_FACE_CACHE_MAX.to_i
    return if max <= 0
    live = []
    @nds_volume_faces.each_with_index do |face, i|
      spr = face[:sprite]
      live << [face[:last_used].to_i, i] if spr && !spr.disposed?
    end
    return if live.length <= max
    active_lookup = {}
    active_indices.each { |i| active_lookup[i] = true }
    live.sort_by! { |pair| pair[0] }
    live.each do |_stamp, i|
      next if active_lookup[i]
      face = @nds_volume_faces[i]
      spr = face[:sprite]
      bmp = face[:bitmap]
      spr.dispose if spr && !spr.disposed?
      bmp.dispose if bmp && !bmp.disposed?
      face[:sprite] = nil
      face[:bitmap] = nil
      break if (live.length -= 1) <= max
    end
  rescue Exception
  end

  def build_nds_volume_faces
    @nds_volume_faces = []
    @nds_volume_buckets = Hash.new { |h, k| h[k] = [] }
    @nds_volume_active = []

    heights = Array.new(@map.width) { Array.new(@map.height, 0.0) }
    @map.width.times do |tx|
      @map.height.times { |ty| heights[tx][ty] = nds_volume_cell_height(tx, ty) }
    end

    # Frentes (sur): agrupar runs horizontales con misma altura/base.
    if Mode7::Config::NDS_VOLUME_FRONT_FACES
      @map.height.times do |ty|
        tx = 0
        while tx < @map.width
          h = heights[tx][ty]
          south = ty + 1 < @map.height ? heights[tx][ty + 1] : 0.0
          if h <= south + 0.01 || nds_explicit_front_face_at?(tx, ty)
            tx += 1
            next
          end
          base = south
          start = tx
          tx += 1
          while tx < @map.width
            h2 = heights[tx][ty]
            s2 = ty + 1 < @map.height ? heights[tx][ty + 1] : 0.0
            break if (h2 - h).abs > 0.01 || (s2 - base).abs > 0.01 ||
                     h2 <= s2 + 0.01 || nds_explicit_front_face_at?(tx, ty)
            tx += 1
          end
          nds_make_front_run(ty, start, tx - 1, h, base)
        end
      end
    end

    # Laterales solo en balanced/quality. Performance prioriza draw calls bajos.
    if Mode7.nds_side_faces?
      @map.width.times do |tx|
        [:west, :east].each do |side|
          ty = 0
          while ty < @map.height
            h = heights[tx][ty]
            nx = side == :west ? tx - 1 : tx + 1
            neighbor = (nx >= 0 && nx < @map.width) ? heights[nx][ty] : 0.0
            if h <= neighbor + 0.01
              ty += 1
              next
            end
            base = neighbor
            start = ty
            ty += 1
            while ty < @map.height
              h2 = heights[tx][ty]
              n2 = (nx >= 0 && nx < @map.width) ? heights[nx][ty] : 0.0
              break if (h2 - h).abs > 0.01 || (n2 - base).abs > 0.01 || h2 <= n2 + 0.01
              ty += 1
            end
            nds_make_side_run(side, tx, start, ty - 1, h, base)
          end
        end
      end
    end
  rescue Exception => e
    Console.echo_error("2.5D NDS V5 volume build: #{e.message}") if defined?(Console)
    dispose_nds_volume_faces
  end

  def nds_volume_key
    step = Mode7::Config::NDS_VOLUME_REPROJECT_STEP.to_f
    step = 0.5 if step <= 0.0
    [(Mode7.cam_x / step).round,
     (Mode7.projection_cam_y / step).round,
     Mode7.instance_variable_get(:@current_alpha).to_f.round(3),
     Mode7.instance_variable_get(:@zoom).to_f.round(4),
     Mode7.instance_variable_get(:@distance_h).to_f.round(3),
     Mode7.projection_revision]
  end

  def update_nds_volume_faces
    return if !@nds_volume_faces || @nds_volume_faces.empty?
    key = nds_volume_key
    return if @nds_volume_projection_key == key
    @nds_volume_projection_key = key

    bs = Mode7::Config::NDS_VOLUME_BUCKET_SIZE.to_i
    bs = 8 if bs <= 0
    cam_tx = (Mode7.cam_x / Game_Map::TILE_WIDTH).floor
    cam_ty = (Mode7.cam_y / Game_Map::TILE_HEIGHT).floor
    rx = Mode7::Config::NDS_VOLUME_CULL_TILES_X.to_i
    ry = Mode7::Config::NDS_VOLUME_CULL_TILES_Y.to_i
    bx0 = (cam_tx - rx) / bs
    bx1 = (cam_tx + rx) / bs
    by0 = (cam_ty - ry) / bs
    by1 = (cam_ty + ry) / bs

    indices = {}
    bx = bx0
    while bx <= bx1
      by = by0
      while by <= by1
        (@nds_volume_buckets[[bx, by]] || []).each { |i| indices[i] = true }
        by += 1
      end
      bx += 1
    end

    # Oculta solo lo que estaba activo el frame de reproyeccion anterior.
    (@nds_volume_active || []).each do |i|
      next if indices[i]
      spr = @nds_volume_faces[i][:sprite]
      spr.visible = false if spr && !spr.disposed?
    end

    active = []
    build_budget = Mode7::Config::NDS_VOLUME_FACE_BUILD_BUDGET.to_i
    build_budget = 1 if build_budget < 1
    frame_stamp = Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : 0

    indices.each_key do |i|
      face = @nds_volume_faces[i]
      spr = face[:sprite]
      if !spr || spr.disposed?
        next if build_budget <= 0
        spr = ensure_nds_volume_face_resources(face)
        next if !spr
        build_budget -= 1
      end

      face[:last_used] = frame_stamp
      w = face[:world]
      p0 = Mode7.project(w[0],  w[1],  w[2])
      p1 = Mode7.project(w[3],  w[4],  w[5])
      p2 = Mode7.project(w[6],  w[7],  w[8])
      p3 = Mode7.project(w[9],  w[10], w[11])
      if !p0 || !p1 || !p2 || !p3
        spr.visible = false
        next
      end
      points = [p0[0], p0[1], p1[0], p1[1], p2[0], p2[1], p3[0], p3[1]]
      overlap = Mode7::Config::EXT_CORNERS_OVERLAP.to_f
      points = Mode7.nds_fast_expand_quad(points, overlap) if overlap > 0.0
      xs = [points[0], points[2], points[4], points[6]]
      ys = [points[1], points[3], points[5], points[7]]
      margin = 40.0
      visible = xs.max >= -margin && xs.min <= Mode7.screen_w + margin &&
                ys.max >= -margin && ys.min <= Mode7.screen_h + margin
      spr.visible = visible
      next if !visible
      spr.corners = points
      max_world_y = [w[1], w[4], w[7], w[10]].max
      spr.z = Mode7.depth_z(max_world_y, 0, -2)
      spr.tone = @tone
      active << i
    end
    @nds_volume_active = active
    prune_nds_volume_face_cache(active) if frame_stamp > 0 && (frame_stamp % 120) == 0
  rescue Exception => e
    Console.echo_error("2.5D NDS V5 volume update: #{e.message}") if defined?(Console)
  end
end
