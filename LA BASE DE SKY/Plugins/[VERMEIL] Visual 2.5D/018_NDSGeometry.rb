#===============================================================================
# [VERMEIL] Visual 2.5D - 018_NDSGeometry.rb
# Renderer V3: camara NDS + geometria proyectada real sobre mkxp-z-ext.
#
# Arquitectura:
#   * :perspective usa una camara pinhole inclinada (0° = cenital).
#   * el suelo es una malla dinamica de bandas de mundo con Sprite#corners.
#   * P1/borders/walls comparten exactamente la misma Mode7.project().
#   * personajes y props son billboards anclados al suelo.
#   * no hay stretch_blt por scanline durante el movimiento.
#
# La matematica esta inspirada en el comportamiento observado en el video de
# referencia: al aumentar el angulo, el plano se inclina y los billboards ganan
# escala de forma fuerte, manteniendose verticales.
#
# Si Sprite#corners no existe, el renderer legacy sigue disponible.
#===============================================================================

module Mode7
  class << self
    # -------------------------------------------------------------------------
    # Seleccion de modo
    # -------------------------------------------------------------------------
    def set_projection_mode(mode)
      normalized = mode.nil? ? nil : mode.to_sym
      normalized = nil if normalized == :auto
      valid = [:perspective, :affine, :cylindrical]
      return map_mode if normalized && !valid.include?(normalized)
      @projection_override = normalized
      @projection_revision = (@projection_revision || 0) + 1
      reset_caches
      renderer = $scene.instance_variable_get(:@map_renderer) if $scene.is_a?(Scene_Map)
      renderer.refresh if renderer && renderer.respond_to?(:refresh)
      map_mode
    end

    def map_mode
      valid = [:perspective, :affine, :cylindrical]
      return @projection_override if valid.include?(@projection_override)
      if indoor_map?
        mode = Config::INDOOR_PROJECTION
        return valid.include?(mode) ? mode : :perspective
      end
      return @map_projection if valid.include?(@map_projection)
      mode = Config::PROJECTION
      valid.include?(mode) ? mode : :perspective
    end

    def perspective_mode?; map_mode == :perspective; end
    def affine_mode?;      map_mode == :affine; end
    def cylindrical_mode?; map_mode == :cylindrical; end

    def detect_map_projection(map_id)
      candidates = map_metadata_candidates_for(map_id)
      if defined?(Config::MAP_FLAG_PERSPECTIVE) &&
         candidates.any? { |meta| metadata_has_flag?(meta, Config::MAP_FLAG_PERSPECTIVE) }
        return :perspective
      end
      return :affine if candidates.any? { |meta| metadata_has_flag?(meta, Config::MAP_FLAG_RASTER_AFFINE) }
      return :affine if candidates.any? do |meta|
        metadata_has_flag?(meta, Config::MAP_FLAG_AFFINE) ||
          metadata_has_flag?(meta, Config::MAP_FLAG_AFFINE_LEGACY)
      end
      return :cylindrical if candidates.any? { |meta| metadata_has_flag?(meta, Config::MAP_FLAG_CYLINDRICAL) }
      return Config::INDOOR_PROJECTION if indoor_map?(map_id)
      nil
    end

    def pivot_ratio
      return @pivot_override if !@pivot_override.nil?
      return Config::PERSPECTIVE_PIVOT_RATIO if perspective_mode?
      return Config::AFFINE_PIVOT_RATIO if affine_mode?
      Config::CYLINDRICAL_PIVOT_RATIO
    end

    def perspective_pivot_percent
      (pivot_ratio.to_f * 100.0).round
    end

    def set_perspective_pivot_percent(value)
      ratio = (value.to_f / 100.0).clamp(0.20, 0.80)
      @pivot_override = ratio
      @projection_revision = (@projection_revision || 0) + 1
      reset_caches
      invalidate_renderer_ground if respond_to?(:invalidate_renderer_ground)
      ratio
    end

    # -------------------------------------------------------------------------
    # Camara NDS / pinhole
    #
    # Sistema:
    #   X = derecha
    #   Y = sur/abajo en el mapa
    #   Z = elevacion
    #
    # La camara esta al sur y por encima del pivote, mirando hacia el norte.
    # alpha es inclinacion desde cenital:
    #   0°  -> cenital
    #   25° -> perfil exterior sutil por defecto (V5.7)
    #   75° -> perspectiva extrema como la demostracion del video
    #
    # Para conservar 1:1 vertical del suelo alrededor del pivote usamos
    # la focal final se resuelve en 019_NDSVolumePerformance con un balance X/Y.
    # Asi el angulo no ensancha los tiles de forma unilateral.
    # -------------------------------------------------------------------------
    def perspective_angle_rad
      a = (@current_alpha || context_default_alpha).to_f
      a = a.clamp(0.0, 89.0)
      a * Math::PI / 180.0
    end

    def perspective_sin
      Math.sin(perspective_angle_rad)
    end

    def perspective_cos_raw
      Math.cos(perspective_angle_rad)
    end

    def perspective_cos
      c = perspective_cos_raw.abs
      min_c = Config::PERSPECTIVE_COS_MIN.to_f
      min_c = 0.10 if min_c <= 0.0
      c < min_c ? min_c : c
    end

    def perspective_distance
      d = (@distance_h || Config::DISTANCE_H).to_f
      d = 64.0 if d < 64.0
      d
    end

    def perspective_focal
      scale = @zoom.to_f / perspective_cos
      max_scale = Config::PERSPECTIVE_FOCAL_SCALE_MAX.to_f
      scale = [scale, max_scale].min if max_scale > 0.0
      perspective_distance * scale
    end

    def perspective_pivot_world_y
      projection_cam_y + pivot_y
    end

    def perspective_depth_for(wy, elevation = 0.0)
      dy = wy.to_f - perspective_pivot_world_y
      # Todo se expresa relativo a la altura de camara. Si el jugador sube
      # 64 px, una superficie a Z=64 vuelve a tener Z relativa 0 y permanece
      # estable alrededor del pivote en pantalla.
      relative_elevation = elevation.to_f - projection_cam_elevation.to_f
      perspective_distance -
        dy * perspective_sin -
        relative_elevation * perspective_cos_raw
    end

    def perspective_valid_depth(depth)
      near = Config::PERSPECTIVE_NEAR_CLIP.to_f
      near = 8.0 if near <= 0.0
      depth.to_f > near
    end

    def perspective_scale_for_world_y(wy, elevation = 0.0)
      depth = perspective_depth_for(wy, elevation)
      near = Config::PERSPECTIVE_NEAR_CLIP.to_f
      near = 8.0 if near <= 0.0
      depth = near if depth < near

      scale = perspective_focal / depth
      lo = Config::PERSPECTIVE_GROUND_MIN_SCALE.to_f
      hi = Config::PERSPECTIVE_GROUND_MAX_SCALE.to_f
      lo = 0.001 if lo <= 0.0
      hi = lo if hi < lo
      scale.clamp(lo, hi)
    end

    def perspective_project(wx, wy, elevation = 0)
      dy = wy.to_f - perspective_pivot_world_y
      elev = elevation.to_f
      relative_elevation = elev - projection_cam_elevation.to_f
      depth = perspective_depth_for(wy, elev)
      return nil if !perspective_valid_depth(depth)

      focal = perspective_focal
      sx = center_x + focal * (wx.to_f - cam_x) / depth

      # Eje vertical de imagen. Y del mundo baja en pantalla, Z sube.
      vertical = dy * perspective_cos_raw - relative_elevation * perspective_sin
      sy = pivot_y + focal * vertical / depth
      [sx, sy]
    end

    def project(wx, wy, elevation = 0)
      return perspective_project(wx, wy, elevation) if perspective_mode?
      return _cylindrical_project(wx, wy, elevation) if cylindrical_mode?

      rx = wx.to_f - cam_x
      relative_elevation = elevation.to_f - projection_cam_elevation.to_f
      ry = (wy.to_f - projection_cam_y - relative_elevation) - pivot_y
      sy = pivot_y + affine_depth_scale(ry)
      sx = center_x + hscale(sy) * rx
      [sx, sy]
    end

    def perspective_project_y(wy, elevation = 0)
      point = perspective_project(cam_x, wy, elevation)
      point ? point[1] : nil
    end

    def _project_y_uncached(wy, elevation = 0)
      return perspective_project_y(wy, elevation) if perspective_mode?
      return _cylindrical_project_y(wy, elevation) if cylindrical_mode?
      relative_elevation = elevation.to_f - projection_cam_elevation.to_f
      pivot_y + affine_depth_scale(
        (wy.to_f - projection_cam_y - relative_elevation) - pivot_y
      )
    end

    # Inversa analitica del plano Z=0 incluyendo traslacion vertical de camara.
    # Para ground, Z relativa = -Ecam:
    # s = F * (dy*cos + Ecam*sin) / (D - dy*sin + Ecam*cos)
    def perspective_world_y_for_row(sy)
      s = sy.to_f - pivot_y
      f = perspective_focal
      c = perspective_cos_raw
      si = perspective_sin
      e = projection_cam_elevation.to_f
      den = f * c + s * si
      return perspective_pivot_world_y if den.abs < 1.0e-7
      dy = (s * (perspective_distance + e * c) - f * e * si) / den
      perspective_pivot_world_y + dy
    end

    def world_y_for_row(sy)
      return perspective_world_y_for_row(sy) if perspective_mode?
      return _cylindrical_world_y_for_row(sy) if cylindrical_mode?

      @affine_row_world_offset_cache ||= {}
      offset = @affine_row_world_offset_cache[sy]
      if offset.nil?
        offset = pivot_y + affine_depth_unscale(sy - pivot_y)
        @affine_row_world_offset_cache[sy] = offset
      end
      projection_cam_y - projection_cam_elevation.to_f + offset
    end

    def perspective_world_x_for_screen(sx, wy)
      scale = perspective_scale_for_world_y(wy)
      return cam_x if scale.abs < 1.0e-8
      cam_x + (sx.to_f - center_x) / scale
    end

    def _hscale_uncached(sy)
      return perspective_scale_for_world_y(perspective_world_y_for_row(sy)) if perspective_mode?
      @zoom
    end

    def horizon_row
      if perspective_mode?
        si = perspective_sin
        return -1.0e9 if si.abs < 1.0e-7
        # Limite Y cuando la distancia del suelo tiende a infinito.
        return pivot_y - perspective_focal * perspective_cos_raw / si
      end
      return 0.0 if cylindrical_mode?
      t = affine_depth_value
      return 0 if t <= 0 || @sin.abs < 1.0e-9
      heff = @dh / t
      pivot_y - heff * @cos / @sin
    end

    # Billboard facing-camera: misma F/depth que la malla del suelo.
    def object_scale_for_world_y(wy, elevation = 0.0)
      if perspective_mode?
        return perspective_scale_for_world_y(wy, elevation)
      end
      return @zoom if !cylindrical_mode?
      @zoom * camera_billboard_pitch_scale *
        cylindrical_sprite_scale(cylindrical_theta_for_world_y(wy))
    end

    def tile_billboard_scale_for_world_y(wy)
      return object_scale_for_world_y(wy) if perspective_mode?
      return @zoom if !cylindrical_mode?
      strength = Config::CYLINDRICAL_BILLBOARD_PERSPECTIVE
      @zoom * camera_billboard_pitch_scale *
        cylindrical_directional_scale(cylindrical_theta_for_world_y(wy), strength)
    end

    # Derivada vertical local del plano de una pared. La geometria corners usa
    # project() directamente; esto solo sirve de aproximacion para codigo legacy.
    def perspective_vertical_scale_for_world_y(wy, elevation = 0.0)
      dy = wy.to_f - perspective_pivot_world_y
      d = perspective_depth_for(wy, elevation.to_f)
      near = Config::PERSPECTIVE_NEAR_CLIP.to_f
      near = 8.0 if near <= 0.0
      d = near if d < near
      # d/dy de F * dy * cos(a) / (D - dy * sin(a)). Usar la
      # derivada real evita que las sombras sobre el plano parezcan curvas.
      camera_elev = projection_cam_elevation.to_f
      value = perspective_focal *
              (perspective_distance * perspective_cos_raw + camera_elev) /
              (d * d)
      value.abs
    end

    def vertical_scale_for_world_y(wy)
      return perspective_vertical_scale_for_world_y(wy) if perspective_mode?
      return object_scale_for_world_y(wy) if !cylindrical_mode?
      tile_billboard_scale_for_world_y(wy) * Config::CYLINDRICAL_VERTICAL_SCALE.to_f
    end
  end
end

#-------------------------------------------------------------------------------
# Ground mesh dinamica:
#   * crea solo las bandas visibles
#   * comparte el bitmap @ground; no duplica texturas
#   * recorta src_rect tambien en X para no mandar el mapa entero por quad
#-------------------------------------------------------------------------------
class Mode7Renderer
  if private_method_defined?(:build) &&
     !private_method_defined?(:_VERMEIL_NDS_orig_build)
    alias_method :_VERMEIL_NDS_orig_build, :build
  end
  if private_method_defined?(:draw_ground) &&
     !private_method_defined?(:_VERMEIL_NDS_orig_draw_ground)
    alias_method :_VERMEIL_NDS_orig_draw_ground, :draw_ground
  end
  if method_defined?(:update) && !method_defined?(:_VERMEIL_NDS_orig_update)
    alias_method :_VERMEIL_NDS_orig_update, :update
  end
  if method_defined?(:dispose) && !method_defined?(:_VERMEIL_NDS_orig_dispose)
    alias_method :_VERMEIL_NDS_orig_dispose, :dispose
  end
  if private_method_defined?(:make_priority_strip) &&
     !private_method_defined?(:_VERMEIL_NDS_orig_make_priority_strip)
    alias_method :_VERMEIL_NDS_orig_make_priority_strip, :make_priority_strip
  end
  if private_method_defined?(:redraw_projected_priority_strip) &&
     !private_method_defined?(:_VERMEIL_NDS_orig_redraw_projected_priority_strip)
    alias_method :_VERMEIL_NDS_orig_redraw_projected_priority_strip, :redraw_projected_priority_strip
  end
  if private_method_defined?(:update_walls) &&
     !private_method_defined?(:_VERMEIL_NDS_orig_update_walls)
    alias_method :_VERMEIL_NDS_orig_update_walls, :update_walls
  end

  def update
    _VERMEIL_NDS_orig_update
    update_nds_ground if nds_ground_active?
  end

  def dispose
    dispose_nds_ground
    _VERMEIL_NDS_orig_dispose
  end

  private

  def nds_ground_active?
    Mode7::Config::GEOMETRY_GROUND_ENABLED &&
      Mode7.respond_to?(:perspective_mode?) &&
      Mode7.perspective_mode? &&
      Mode7::MKXPZExt.corners? &&
      @ground && !@ground.disposed?
  rescue Exception
    false
  end

  def build
    dispose_nds_ground
    _VERMEIL_NDS_orig_build
    build_nds_ground if nds_ground_active?
  end

  def build_nds_ground
    dispose_nds_ground
    @nds_ground_pool = []
    @nds_ground_pool_used = 0
    @nds_ground_bitmap_id = @ground.object_id if @ground
    @ground_sprite.z = -1001 if @ground_sprite
  end

  def dispose_nds_ground
    if @nds_ground_pool
      @nds_ground_pool.each do |spr|
        next if !spr
        begin
          spr.corners = nil if Mode7::MKXPZExt.corners? && !spr.disposed?
        rescue Exception
        end
        spr.dispose if !spr.disposed?
      end
    end
    @nds_ground_pool = nil
    @nds_ground_pool_used = 0
    @nds_ground_bitmap_id = nil
  end

  def ensure_nds_ground_sprite(index)
    @nds_ground_pool ||= []
    spr = @nds_ground_pool[index]
    return spr if spr && !spr.disposed?

    max_pool = Mode7::Config::GEOMETRY_GROUND_POOL_MAX.to_i
    return nil if max_pool > 0 && index >= max_pool

    spr = Sprite.new(@viewport)
    spr.bitmap = @ground
    spr.z = -1000
    spr.visible = false
    @nds_ground_pool[index] = spr
    spr
  end

  def hide_unused_nds_ground(from_index)
    return if !@nds_ground_pool
    i = from_index
    while i < @nds_ground_pool.length
      spr = @nds_ground_pool[i]
      spr.visible = false if spr && !spr.disposed?
      i += 1
    end
    @nds_ground_pool_used = from_index
  end

  def nds_visible_world_y_range
    map_h = @ground.height.to_f
    margin = Mode7::Config::GEOMETRY_GROUND_CULL_MARGIN.to_f

    ys = []
    [-margin, Mode7.screen_h + margin].each do |screen_y|
      begin
        wy = Mode7.world_y_for_row(screen_y)
        ys << wy if wy && wy.finite?
      rescue Exception
      end
    end

    # Incluye siempre la fila del pivote y protege mapas/angulos extremos.
    ys << Mode7.perspective_pivot_world_y
    min_y = ys.min || 0.0
    max_y = ys.max || map_h

    # Un tile extra evita pop-in en scroll subpixel.
    pad = Game_Map::TILE_HEIGHT * 2.0
    min_y = (min_y - pad).clamp(0.0, map_h)
    max_y = (max_y + pad).clamp(0.0, map_h)
    [min_y, max_y]
  end

  def nds_visible_world_x_range(y0, y1)
    # V4.3: el recorte X demasiado agresivo generaba diagonales azules y
    # bandas cortadas al mover la camara. En mapas razonables usamos el ancho
    # completo del bitmap; en mapas enormes usamos margen amplio y snap a tile.
    if defined?(Mode7::Config::GROUND_SAFE_X_COVERAGE) && Mode7::Config::GROUND_SAFE_X_COVERAGE &&
       @ground.width <= 8192
      return [0.0, @ground.width.to_f]
    end

    margin = [Mode7::Config::GEOMETRY_GROUND_X_MARGIN.to_f, 256.0].max
    values = []
    [y0, y1, (y0 + y1) * 0.5].each do |wy|
      begin
        values << Mode7.perspective_world_x_for_screen(-margin, wy)
        values << Mode7.perspective_world_x_for_screen(Mode7.screen_w + margin, wy)
      rescue Exception
      end
    end
    return [0.0, @ground.width.to_f] if values.empty?

    tile = Game_Map::TILE_WIDTH.to_f
    pad = tile * 8.0
    x0 = (((values.min - pad) / tile).floor * tile).clamp(0.0, @ground.width.to_f)
    x1 = (((values.max + pad) / tile).ceil  * tile).clamp(0.0, @ground.width.to_f)
    [x0, x1]
  end

  def draw_ground
    return _VERMEIL_NDS_orig_draw_ground if !nds_ground_active?

    begin
      # El Sprite legacy queda unicamente como fondo/sky/outside. El mapa se
      # dibuja por quads en @nds_ground_pool.
      bmp = @ground_sprite.bitmap
      bmp.fill_rect(0, 0, Mode7.screen_w, Mode7.screen_h, projection_fill_color)
      @ground_sprite.z = -1001
      update_nds_ground(true)
    rescue Exception => e
      Console.echo_error("2.5D NDS ground fallback: #{e.message}") if defined?(Console)
      _VERMEIL_NDS_orig_draw_ground
    end
  end

  def nds_ground_color(screen_y)
    fog_alpha = Mode7.respond_to?(:fog_alpha) ? Mode7.fog_alpha(screen_y) : 0
    base = @color || Color.new(0, 0, 0, 0)
    return [base.red, base.green, base.blue, base.alpha] if fog_alpha <= 0

    fog = Mode7::Config::FOG_COLOR
    a1 = base.alpha.to_f / 255.0
    a2 = fog_alpha.to_f / 255.0
    out_a = 1.0 - (1.0 - a1) * (1.0 - a2)
    return [fog.red, fog.green, fog.blue, fog_alpha] if out_a <= 0.0001

    r = (base.red * a1 * (1.0 - a2) + fog.red * a2) / out_a
    g = (base.green * a1 * (1.0 - a2) + fog.green * a2) / out_a
    b = (base.blue * a1 * (1.0 - a2) + fog.blue * a2) / out_a
    [r.round, g.round, b.round, (out_a * 255.0).round]
  end

  def update_nds_ground(force = false)
    return if !nds_ground_active?
    build_nds_ground if !@nds_ground_pool ||
                        @nds_ground_bitmap_id != @ground.object_id

    band_h = Mode7::Config::GEOMETRY_GROUND_BAND_HEIGHT.to_i
    band_h = 4 if band_h < 4
    min_y, max_y = nds_visible_world_y_range

    # Si un angulo extremo ve demasiada distancia, aumentar automaticamente
    # el alto de banda antes de agotar el pool. Asi nunca desaparece el suelo
    # cercano por haber gastado todos los quads en la zona lejana.
    pool_max = Mode7::Config::GEOMETRY_GROUND_POOL_MAX.to_i
    pool_max = 160 if pool_max <= 0
    span = [max_y - min_y, 1.0].max
    needed_h = (span / pool_max.to_f).ceil
    if needed_h > band_h
      band_h = ((needed_h + 3) / 4) * 4
    end

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
      if x1 - x0 < 1.0
        band += 1
        next
      end

      # src_rect exige enteros. Expandir hacia fuera mantiene cobertura.
      sx0 = x0.floor
      sx1 = x1.ceil
      sy0 = y0.floor
      sy1 = y1.ceil
      sx0 = sx0.clamp(0, @ground.width)
      sx1 = sx1.clamp(0, @ground.width)
      sy0 = sy0.clamp(0, @ground.height)
      sy1 = sy1.clamp(0, @ground.height)
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
        points = Mode7::MKXPZExt.expand_quad(points, overlap) if overlap > 0.0

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

          c = nds_ground_color((ys.min + ys.max) * 0.5)
          spr.color.set(c[0], c[1], c[2], c[3])
          pool_index += 1
        end
      end

      band += 1
    end

    hide_unused_nds_ground(pool_index)
  rescue Exception => e
    Console.echo_error("2.5D NDS geometry: #{e.message}") if defined?(Console)
    hide_unused_nds_ground(0)
  end

  # -------------------------------------------------------------------------
  # Walls/P2+ directamente desde los cuatro vertices del mundo.
  # No se hace un pase zoom_x/zoom_y previo. Corners es la geometria final.
  # -------------------------------------------------------------------------
  def update_walls
    if !Mode7::Config::GEOMETRY_WALLS || !Mode7::MKXPZExt.corners?
      return _VERMEIL_NDS_orig_update_walls
    end

    cam_tx = Mode7.cam_x / Game_Map::TILE_WIDTH
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT
    radius_x = Mode7::Config::WALL_SPAWN_RADIUS_X.to_f
    radius_y = Mode7::Config::WALL_SPAWN_RADIUS_Y.to_f
    overlap = Mode7::Config::EXT_CORNERS_OVERLAP.to_f

    @wall_data.each do |data|
      sprite, wx, wyb, h, _entries, rigid_kind, _unify, depth,
      _shadow_opacity, min_tx, min_ty, max_tx, max_ty, elevation = data
      next if !sprite || sprite.disposed? || !sprite.bitmap || sprite.bitmap.disposed?

      min_tx ||= ((wx - sprite.bitmap.width / 2.0) / Game_Map::TILE_WIDTH).floor
      max_tx ||= ((wx + sprite.bitmap.width / 2.0) / Game_Map::TILE_WIDTH).ceil - 1
      min_ty ||= ((wyb - h) / Game_Map::TILE_HEIGHT).floor
      max_ty ||= (wyb / Game_Map::TILE_HEIGHT).ceil

      if max_tx < cam_tx - radius_x || min_tx > cam_tx + radius_x ||
         max_ty < cam_ty - radius_y || min_ty > cam_ty + radius_y
        sprite.visible = false
        next
      end

      elev = elevation.to_f
      sort_elevation = elev
      plane_kind = [:nds_wall_plane, :nds_mountain_wall_plane].include?(rigid_kind)
      mountain_plane = rigid_kind == :nds_mountain_wall &&
                       Mode7::Config::NDS_MOUNTAIN_WALLS_AS_PLANES
      project_as_plane = plane_kind || mountain_plane
      stair_depth = nil
      # Un WallPlane se coloca sobre el borde norte de las celdas que guardan
      # su textura. Asi conecta con el top elevado, no una fila mas al sur.
      base_wy = project_as_plane ? min_ty.to_f * Game_Map::TILE_HEIGHT : wyb.to_f
      base = Mode7.project(wx.to_f, base_wy, elev)
      if !base
        sprite.visible = false
        next
      end

      # ponytail: pixel art 2D como billboard; quad solo en planes explicitos.
      rigid_2d = [
        :component, :wall_component, :indoor_prop, :nds_billboard,
        :nds_structure, :nds_overlay, :nds_bush_overlay, :nds_wall,
        :nds_roof, :nds_roof_high
      ]
      rigid_2d << :nds_mountain_wall if !mountain_plane
      if rigid_kind == :nds_stair || rigid_kind == :nds_stair_row
        # Rampa por fila: su borde sur usa la altura local y el norte suma el
        # rise del tramo. Los bordes de filas consecutivas coinciden exactos.
        left_wx  = min_tx.to_f * Game_Map::TILE_WIDTH
        right_wx = (max_tx.to_f + 1.0) * Game_Map::TILE_WIDTH
        south_wy = (max_ty.to_f + 1.0) * Game_Map::TILE_HEIGHT
        north_wy = min_ty.to_f * Game_Map::TILE_HEIGHT
        stair_h  = if rigid_kind == :nds_stair_row
                     sprite.instance_variable_get(:@nds_stair_rise).to_f
                   else
                     north_z = sprite.instance_variable_get(:@nds_stair_north_z)
                     south_z = sprite.instance_variable_get(:@nds_stair_south_z)
                     if !north_z.nil? && !south_z.nil?
                       north_z.to_f - south_z.to_f
                     else
                       Mode7::Config::NDS_STAIR_HEIGHT.to_f
                     end
                   end
        # La rampa es suelo transitable: todo el quad queda por debajo del
        # personaje. Usamos su esquina norte/alta, el menor depth visual del
        # recorrido, en vez del pie sur del bitmap completo.
        stair_depth = [north_wy, elev + stair_h, south_wy, elev]
        bl = Mode7.project(left_wx,  south_wy, elev)
        br = Mode7.project(right_wx, south_wy, elev)
        tl = Mode7.project(left_wx,  north_wy, elev + stair_h)
        tr = Mode7.project(right_wx, north_wy, elev + stair_h)
        if !bl || !br || !tl || !tr
          sprite.visible = false
          next
        end
        points = [tl[0], tl[1], tr[0], tr[1], br[0], br[1], bl[0], bl[1]]
        points = Mode7::MKXPZExt.expand_quad(points, overlap) if overlap > 0.0
        xs = [points[0], points[2], points[4], points[6]]
        ys = [points[1], points[3], points[5], points[7]]
        margin = Game_Map::TILE_WIDTH.to_f
        visible = xs.max >= -margin && xs.min <= Mode7.screen_w + margin &&
                  ys.max >= -margin && ys.min <= Mode7.screen_h + margin
        sprite.visible = visible
        next if !visible

        sprite.corners = points
        sprite.x = (xs.min + xs.max) * 0.5
        sprite.y = (points[5] + points[7]) * 0.5
        sprite.ox = sprite.bitmap.width / 2.0
        sprite.oy = sprite.bitmap.height.to_f
        sprite.zoom_x = [xs.max - xs.min, 0.001].max / sprite.bitmap.width.to_f
        sprite.zoom_y = [ys.max - ys.min, 0.001].max / sprite.bitmap.height.to_f
      elsif rigid_2d.include?(rigid_kind)
        begin
          sprite.corners = nil if sprite.corners
        rescue Exception
        end
        # Una sola camara: escala uniforme por el pie del componente.
        scale = Mode7.nds_rigid_scale_for_world_y(wyb, rigid_kind, elev).to_f
        scale = 0.001 if scale <= 0.001
        sprite.x = base[0]
        sprite.y = base[1]
        sprite.ox = sprite.bitmap.width / 2.0
        sprite.oy = sprite.bitmap.height.to_f
        sprite.zoom_x = scale
        sprite.zoom_y = scale

        half_w = sprite.bitmap.width * scale * 0.5
        top = sprite.y - sprite.bitmap.height * scale
        sprite.visible = !(sprite.x + half_w < -Game_Map::TILE_WIDTH ||
                           sprite.x - half_w > Mode7.screen_w + Game_Map::TILE_WIDTH ||
                           sprite.y < -Game_Map::TILE_HEIGHT ||
                           top > Mode7.screen_h + Game_Map::TILE_HEIGHT)
        next if !sprite.visible
      else
        left_wx  = min_tx.to_f * Game_Map::TILE_WIDTH
        right_wx = (max_tx.to_f + 1.0) * Game_Map::TILE_WIDTH
        base_wy  = project_as_plane ? min_ty.to_f * Game_Map::TILE_HEIGHT : wyb.to_f
        height   = h.to_f
        if rigid_kind == :nds_wall_plane
          height *= Mode7::Config::NDS_WALL_HEIGHT_SCALE.to_f
        elsif rigid_kind == :nds_mountain_wall_plane || mountain_plane
          # La textura puede ocupar varias filas en el editor, pero representa
          # una sola cara entre suelo y MountainTop. La altura geométrica debe
          # coincidir con la meseta, no con el alto del bitmap fuente.
          # Una fachada con N filas apiladas representa N niveles verticales.
          # Usar solo 32 px comprimia el bitmap y desalineaba el MountainTop.
          height = h.to_f * Mode7::Config::NDS_MOUNTAIN_WALL_HEIGHT_SCALE.to_f
        end
        # Un plano vertical ocupa un rango de Z. Ordenarlo solo por su base
        # (Z=0) hacia que Priority/suelo bajo ganaran al muro de una meseta.
        # El centro fisico de la cara es una aproximacion estable hasta contar
        # con depth-buffer por pixel.
        sort_elevation = elev + height * 0.5

        bl = Mode7.project(left_wx,  base_wy, elev)
        br = Mode7.project(right_wx, base_wy, elev)
        tl = Mode7.project(left_wx,  base_wy, elev + height)
        tr = Mode7.project(right_wx, base_wy, elev + height)
        if !tl || !tr || !br || !bl
          sprite.visible = false
          next
        end

        points = [tl[0], tl[1], tr[0], tr[1], br[0], br[1], bl[0], bl[1]]
        points = Mode7::MKXPZExt.expand_quad(points, overlap) if overlap > 0.0
        xs = [points[0], points[2], points[4], points[6]]
        ys = [points[1], points[3], points[5], points[7]]
        margin = Game_Map::TILE_WIDTH.to_f
        visible = xs.max >= -margin && xs.min <= Mode7.screen_w + margin &&
                  ys.max >= -margin && ys.min <= Mode7.screen_h + margin
        sprite.visible = visible
        next if !visible

        sprite.corners = points
        sprite.x = (xs.min + xs.max) * 0.5
        sprite.y = (points[5] + points[7]) * 0.5
        sprite.ox = sprite.bitmap.width / 2.0
        sprite.oy = sprite.bitmap.height.to_f
        sprite.zoom_x = [xs.max - xs.min, 0.001].max / sprite.bitmap.width.to_f
        sprite.zoom_y = [ys.max - ys.min, 0.001].max / sprite.bitmap.height.to_f
      end

      if stair_depth
        # Una rampa es terreno: el quad completo debe quedar detras del actor en
        # cualquier punto. Usa el menor Z de ambos extremos, no solo el norte.
        z_north = Mode7.depth_z_at_elevation(stair_depth[0], stair_depth[1], 0, -4)
        z_south = Mode7.depth_z_at_elevation(stair_depth[2], stair_depth[3], 0, -4)
        sprite.z = [z_north, z_south].min
      else
        depth_wyb, depth_priority, depth_unify = depth || [base_wy, 0, 0]
        depth_wyb = base_wy if project_as_plane
        bias = depth_unify.to_i
        bias += Mode7::Config::WALL_TOP_Z_BIAS if depth_priority.to_i > 0
        sprite.z = Mode7.depth_z_at_elevation(
          depth_wyb, sort_elevation, depth_priority, bias
        )
      end
      apply_depth_fog_to_sprite(sprite, sprite.y)
    end
  rescue Exception => e
    Console.echo_error("2.5D NDS V5 walls: #{e.message}") if defined?(Console)
    _VERMEIL_NDS_orig_update_walls
  end

  # -------------------------------------------------------------------------
  # P1 / borders como superficies proyectadas reales.
  # -------------------------------------------------------------------------
  def make_priority_strip(cells, ty, priority, unify, elevation)
    if !Mode7::Config::GEOMETRY_PRIORITY_SURFACES || !Mode7::MKXPZExt.corners?
      return _VERMEIL_NDS_orig_make_priority_strip(cells, ty, priority, unify, elevation)
    end
    return if !cells || cells.empty?

    min_tx = cells.keys.min
    max_tx = cells.keys.max
    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
    source = Bitmap.new(width, Game_Map::TILE_HEIGHT)
    source.clear

    cells.each do |tx, entries|
      x = (tx - min_tx) * Game_Map::TILE_WIDTH
      entries.sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }.each do |entry|
        blt_entry_into(source, x, 0, entry, entry[:opacity] || 255)
      end
    end

    sprite = Sprite.new(@viewport)
    sprite.bitmap = source
    sprite.visible = false
    @priority_strips.push([
      sprite, source, min_tx, ty, priority, unify, elevation,
      cells, :entries_only, nil
    ])
  end

  def redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation = 0)
    if !Mode7::Config::GEOMETRY_PRIORITY_SURFACES || !Mode7::MKXPZExt.corners?
      return _VERMEIL_NDS_orig_redraw_projected_priority_strip(
        sprite, source, min_tx, ty, elevation
      )
    end
    return false if !source || source.disposed?

    x0 = min_tx.to_f * Game_Map::TILE_WIDTH
    x1 = x0 + source.width
    y0 = ty.to_f * Game_Map::TILE_HEIGHT
    y1 = y0 + Game_Map::TILE_HEIGHT
    elev = elevation.to_f

    tl = Mode7.project(x0, y0, elev)
    tr = Mode7.project(x1, y0, elev)
    br = Mode7.project(x1, y1, elev)
    bl = Mode7.project(x0, y1, elev)
    return false if !tl || !tr || !br || !bl

    points = [tl[0], tl[1], tr[0], tr[1], br[0], br[1], bl[0], bl[1]]
    overlap = Mode7::Config::EXT_CORNERS_OVERLAP.to_f
    points = Mode7::MKXPZExt.expand_quad(points, overlap) if overlap > 0.0

    sprite.bitmap = source if sprite.bitmap != source
    sprite.corners = points

    xs = [points[0], points[2], points[4], points[6]]
    ys = [points[1], points[3], points[5], points[7]]
    sprite.x = xs.min
    sprite.y = ys.max
    sprite.ox = 0.0
    sprite.oy = source.height.to_f
    sprite.zoom_x = [xs.max - xs.min, 0.001].max / source.width.to_f
    sprite.zoom_y = [ys.max - ys.min, 0.001].max / source.height.to_f
    true
  rescue Exception => e
    Console.echo_error("2.5D NDS priority quad: #{e.message}") if defined?(Console)
    false
  end
end

#-------------------------------------------------------------------------------
# Interior detectado por Terrain Tag: respeta INDOOR_PROJECTION.
#-------------------------------------------------------------------------------
class Mode7Renderer
  private

  def resolve_projection_from_indoor_tags
    return if !defined?(Mode7::Config::INDOOR_DETECT_FROM_TERRAIN_TAGS)
    return if !Mode7::Config::INDOOR_DETECT_FROM_TERRAIN_TAGS
    return if Mode7.respond_to?(:projection_override) && Mode7.projection_override

    indoor_tags = {}
    Mode7::Config::INDOOR_WALL_TERRAIN_TAG_HEIGHT.each_key { |id| indoor_tags[id] = true }
    Mode7::Config::INTERIOR_BORDER_TERRAIN_TAGS.each_key { |id| indoor_tags[id] = true }
    Mode7::Config::INDOOR_PROP_TERRAIN_TAGS.each_key { |id| indoor_tags[id] = true }
    Mode7::Config::INDOOR_BLACK_TERRAIN_TAGS.each_key { |id| indoor_tags[id] = true }

    found = @entry_cache.any? do |_position, entries|
      entries.any? do |entry|
        tag = terrain_tag_for_entry(entry)
        tag && indoor_tags[tag.id]
      end
    end

    Mode7.tag_indoor_map_id = found ? @map_id : nil
    return if !found

    candidates = Mode7.map_metadata_candidates_for(@map_id)
    explicit = candidates.any? do |meta|
      (defined?(Mode7::Config::MAP_FLAG_PERSPECTIVE) &&
       Mode7.metadata_has_flag?(meta, Mode7::Config::MAP_FLAG_PERSPECTIVE)) ||
        Mode7.metadata_has_flag?(meta, Mode7::Config::MAP_FLAG_RASTER_AFFINE) ||
        Mode7.metadata_has_flag?(meta, Mode7::Config::MAP_FLAG_AFFINE) ||
        Mode7.metadata_has_flag?(meta, Mode7::Config::MAP_FLAG_AFFINE_LEGACY) ||
        Mode7.metadata_has_flag?(meta, Mode7::Config::MAP_FLAG_CYLINDRICAL)
    end
    return if explicit

    Mode7.map_projection = Mode7::Config::INDOOR_PROJECTION
    if Mode7.active_now?
      Mode7.set_camera(Mode7.context_default_alpha, Mode7.camera_zoom,
                       0, Mode7.distance_h, Mode7.cylindrical_radius)
    end
    Mode7.reset_caches
  rescue Exception
  end
end
