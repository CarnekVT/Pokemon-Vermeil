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
    # Phase 2.5.1: NDS es la unica proyeccion de gameplay.
    # Los flags Affine/Cylindrical antiguos se ignoran; se conservan sus
    # constantes unicamente para que proyectos/plugins viejos no fallen al leerlas.
    def set_projection_mode(_mode)
      changed = @projection_override != :perspective || @map_projection != :perspective
      @projection_override = :perspective
      @map_projection = :perspective
      @projection_revision = (@projection_revision || 0) + 1 if changed
      reset_caches if changed
      renderer = $scene.instance_variable_get(:@map_renderer) if changed && $scene.is_a?(Scene_Map)
      renderer.refresh if renderer && renderer.respond_to?(:refresh)
      :perspective
    end

    def map_mode; :perspective; end
    def perspective_mode?; true; end
    def affine_mode?; false; end
    def cylindrical_mode?; false; end
    def detect_map_projection(_map_id); :perspective; end

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
  # NOTA: el wrapper de update se elimino en v5.15 (021 reemplaza update por
  # completo y nadie llama a _VERMEIL_NDS_orig_update).
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

  def dispose
    dispose_nds_ground
    _VERMEIL_NDS_orig_dispose
  end

  private

  def nds_ground_active?
    # V25 PATCH3: the Luka-derived Game.exe exposes Sprite#corners/Shader, but
    # enabling the experimental quad/GPU ground solely because those APIs exist
    # changed Sky's proven ground path and could leave blue/unrendered bands at
    # the perspective near plane.  Keep the adaptive Sky band renderer as the
    # compatibility authority; corners/native mesh remain enabled elsewhere.
    if Mode7::Config.const_defined?(:V25_NEXT_SAFE_GROUND_BANDS) &&
       Mode7::Config::V25_NEXT_SAFE_GROUND_BANDS
      return false
    end
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

        if rigid_kind == :nds_bush_overlay
          # El bitmap tiene una fila transparente de base para conservar el pie.
          # Alinear su junta (32 px sobre el pie) con el borde norte REAL del
          # tile bush elimina la separacion que quedaba al inclinar la camara.
          base_ty = sprite.instance_variable_get(:@nds_bush_base_ty)
          if !base_ty.nil?
            desired = Mode7.project_y(base_ty.to_f * Game_Map::TILE_HEIGHT, elev)
            if desired
              current = sprite.y - Game_Map::TILE_HEIGHT.to_f * scale
              sprite.y += desired - current
              sprite.y += Mode7::Config::NDS_BUSH_CAP_OVERLAP_PX.to_f
            end
          end
        end

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
# Interior detectado por Terrain Tag: mantiene NDS y cambia solo el contexto.
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

    # NDS-only: los tags indoor solo seleccionan el contexto visual y su angulo.
    # Nunca fuerzan Affine ni otra proyeccion.
    Mode7.map_projection = :perspective
    if Mode7.active_now?
      Mode7.set_camera(Mode7.context_default_alpha, Mode7.camera_zoom,
                       0, Mode7.distance_h, Mode7.cylindrical_radius)
    end
  rescue Exception
  end
end
# >>> [VERMEIL] Visual 2.5D - 019_NDSVolumePerformance.rb
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
      # Una banda por fila de tiles: ningún tile cambia de geometría a mitad de
      # su bitmap y todas las capas horneadas (incluidas sombras MS) conservan
      # los mismos cuatro vértices. A ángulos extremos se subdivide por mitades.
      base = Config::GEOMETRY_GROUND_BAND_HEIGHT.to_i
      base = Game_Map::TILE_HEIGHT if base <= 0
      a = (@current_alpha || context_default_alpha).to_f
      base = [base, Game_Map::TILE_HEIGHT / 2].min if a >= 55.0
      base = [base, Game_Map::TILE_HEIGHT / 4].min if a >= 65.0
      base
    end

    def nds_side_faces?
      return false if !Config::NDS_VOLUME_SIDE_FACES
      # V5.9 puede generar SOLO los laterales de montana incluso en performance:
      # ya no copia el bevel del top, usa la fachada MountainWall de la meseta.
      return true if Config::NDS_MOUNTAIN_AUTO_SIDE_FACES
      return false if nds_performance_profile == :performance
      true
    end

    def nds_full_side_faces?
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
    [cx, cy, Mode7.projection_cam_elevation.to_f.round(3),
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
  # NOTA: el wrapper de update se elimino en v5.15 (021 reemplaza update por
  # completo y nadie llama a _VERMEIL_V3_volume_orig_update).
  if method_defined?(:dispose) && !method_defined?(:_VERMEIL_V3_volume_orig_dispose)
    alias_method :_VERMEIL_V3_volume_orig_dispose, :dispose
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
    @nds_volume_visibility_key = nil
    @nds_volume_visible_indices = []
  end

  def nds_volume_cell_height(tx, ty)
    return 0.0 if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    entries = @entry_cache[[tx, ty]]
    return 0.0 if !entries || entries.empty?
    # Una fachada explícita ocupa la celda aunque debajo haya un MountainTop de
    # respaldo en otra layer. Esto coloca el borde del volumen justo al norte
    # de la primera fila de pared y evita tops que atraviesan la textura.
    if entries.any? do |entry|
         id = respond_to?(:nds_category_id, true) ? nds_category_id(entry) : nil
         id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG ||
           id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG
       end
      return 0.0
    end
    max_h = 0.0
    entries.each do |entry|
      id = respond_to?(:nds_category_id, true) ? nds_category_id(entry) : nil
      h = if id == Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG &&
             respond_to?(:nds_mountain_height_at, true)
            nds_mountain_height_at(tx, ty).to_f
          else
            id ? Mode7.nds_volume_height_for_tag(id).to_f : 0.0
          end
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

  # MountainWall es el material vertical de la meseta. El mapper puede seguir
  # dibujando en 2D: buscamos la pila inmediatamente al sur de la columna del
  # MountainTop y la reutilizamos para frente y laterales automaticos.
  def nds_mountain_wall_stack_entries(tx, ty)
    cy = ty.to_i
    while cy < @map.height && nds_mountain_volume_cell?(tx, cy)
      cy += 1
    end
    result = []
    while cy < @map.height
      entry = respond_to?(:nds_mountain_wall_entry_at, true) ?
                nds_mountain_wall_entry_at(tx, cy) : nil
      break if !entry
      result << entry
      cy += 1
    end
    result
  rescue Exception
    []
  end

  def nds_mountain_wall_stack_bitmap(tx, ty, target_height)
    th = Game_Map::TILE_HEIGHT
    tw = Game_Map::TILE_WIDTH
    target_h = [target_height.to_f.round, 1].max
    entries = nds_mountain_wall_stack_entries(tx, ty)
    if entries.empty? && respond_to?(:nds_mountain_wall_source_for, true)
      source = nds_mountain_wall_source_for(tx, ty)
      entries = [source].compact
    end
    return nil if entries.empty?

    raw_h = [entries.length * th, th].max
    raw = Bitmap.new(tw, raw_h)
    raw.clear
    entries.each_with_index do |entry, i|
      blt_entry_into(raw, 0, i * th, entry, entry[:opacity] || 255)
    end
    return raw if raw_h == target_h

    out = Bitmap.new(tw, target_h)
    out.clear
    out.stretch_blt(Rect.new(0, 0, tw, target_h), raw, Rect.new(0, 0, tw, raw_h))
    raw.dispose
    out
  rescue Exception
    nil
  end

  def nds_volume_side_cell_bitmap(tx, ty, target_height = nil)
    if nds_mountain_volume_cell?(tx, ty)
      target_height ||= (respond_to?(:nds_mountain_height_at, true) ? nds_mountain_height_at(tx, ty) : Game_Map::TILE_HEIGHT)
      wall = nds_mountain_wall_stack_bitmap(tx, ty, target_height)
      return [wall, true] if wall
    end

    # Volumen generico: conserva el muestreo local antiguo. Nunca busca paredes
    # lejanas, para no robar arte de otra estructura.
    [ty, ty + 1].each do |sample_ty|
      next if sample_ty < 0 || sample_ty >= @map.height
      entries = @entry_cache[[tx, sample_ty]] || []
      entry = entries.reverse.find do |candidate|
        id = respond_to?(:nds_category_id, true) ? nds_category_id(candidate) : nil
        id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG ||
          id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG
      end
      next if !entry
      bmp = Bitmap.new(Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
      bmp.clear
      blt_entry_into(bmp, 0, 0, entry, entry[:opacity] || 255)
      return [bmp, true]
    end
    [nds_volume_cell_bitmap(tx, ty), false]
  rescue Exception
    [nds_volume_cell_bitmap(tx, ty), false]
  end

  def nds_mountain_volume_cell?(tx, ty)
    entries = @entry_cache[[tx, ty]]
    return false if !entries || entries.empty?
    entries.any? do |entry|
      id = respond_to?(:nds_category_id, true) ? nds_category_id(entry) : nil
      id == Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
    end
  rescue Exception
    false
  end

  def nds_explicit_front_face_at?(tx, ty)
    entries = @entry_cache[[tx, ty + 1]]
    return false if !entries || entries.empty?
    entries.any? do |entry|
      id = respond_to?(:nds_category_id, true) ? nds_category_id(entry) : nil
      id == Mode7::Config::NDS_WALL_PLANE_TERRAIN_TAG ||
        id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG ||
        id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG
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
        if nds_mountain_volume_cell?(tx, ty) && Mode7::Config::NDS_MOUNTAIN_AUTO_FACES
          tile = nds_mountain_wall_stack_bitmap(tx, ty, dh)
          if tile
            src.stretch_blt(Rect.new((tx - tx0) * tw, 0, tw, src.height),
                            tile, Rect.new(0, 0, tile.width, tile.height))
            tile.dispose
          end
        else
          tile = nds_volume_cell_bitmap(tx, ty)
          src.stretch_blt(Rect.new((tx - tx0) * tw, 0, tw, src.height),
                          tile, Rect.new(0, th - sample, tw, sample))
          tile.dispose
        end
        tx += 1
      end
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
      tile, wall_art = nds_volume_side_cell_bitmap(tx, ty, dh)
      target = Rect.new((ty - ty0) * th, 0, th, src.height)
      if wall_art
        src.stretch_blt(target, tile, Rect.new(0, 0, tw, th))
      else
        edge_x = side == :west ? 0 : tw - sample
        strip = Bitmap.new(sample, th)
        strip.blt(0, 0, tile, Rect.new(edge_x, 0, sample, th))
        src.stretch_blt(target, strip, Rect.new(0, 0, sample, th))
        strip.dispose
      end
      tile.dispose
      ty += 1
    end
    src
  end

  def nds_volume_face_shade(kind)
    value = if kind == :front
              Mode7::Config::NDS_VOLUME_FRONT_SHADE
            else
              Mode7::Config::NDS_VOLUME_SIDE_SHADE
            end
    value.to_i.clamp(0, 255)
  end

  def add_nds_volume_face(bitmap, kind, world_points, min_tx, min_ty, max_tx, max_ty, spec = nil)
    sprite = nil
    if bitmap
      sprite = Sprite.new(@viewport)
      sprite.bitmap = bitmap
      sprite.visible = false
      sprite.z = -999
      sprite.color.set(0, 0, 0, nds_volume_face_shade(kind))
    end
    face = {
      sprite: sprite, bitmap: bitmap, kind: kind, world: world_points,
      min_tx: min_tx, min_ty: min_ty, max_tx: max_tx, max_ty: max_ty,
      spec: spec, last_used: 0, shade: nds_volume_face_shade(kind)
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
    spr.color.set(0, 0, 0, face[:shade].to_i.clamp(0, 255))
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
    @nds_volume_visibility_key = nil
    @nds_volume_visible_indices = []

    # Sparse height map. The previous implementation allocated width*height
    # Floats and then scanned the whole map again for fronts and side faces.
    # Most maps only have volume on a fraction of their cells.
    heights = {}
    (@entry_cache || {}).each do |pos, entries|
      next if !entries || entries.empty?
      tx, ty = pos
      h = nds_volume_cell_height(tx, ty)
      heights[[tx, ty]] = h if h > 0.01
    end
    return if heights.empty?

    rows = Hash.new { |h, k| h[k] = [] }
    cols = Hash.new { |h, k| h[k] = [] }
    heights.each_key do |tx, ty|
      rows[ty] << tx
      cols[tx] << ty
    end

    # Frentes (sur): agrupar runs horizontales con misma altura/base.
    if Mode7::Config::NDS_VOLUME_FRONT_FACES
      rows.each do |ty, xs|
        xs.sort!
        i = 0
        while i < xs.length
          tx = xs[i]
          h = heights[[tx, ty]].to_f
          south = heights[[tx, ty + 1]].to_f
          mountain = nds_mountain_volume_cell?(tx, ty)
          stair_cut = respond_to?(:nds_stair_cell?, true) && nds_stair_cell?(tx, ty + 1)
          auto_mountain = mountain && Mode7::Config::NDS_MOUNTAIN_AUTO_FACES
          blocked_generic = !mountain && nds_explicit_front_face_at?(tx, ty)
          if h <= south + 0.01 || stair_cut || blocked_generic ||
             (mountain && !auto_mountain)
            i += 1
            next
          end
          base = south
          start_tx = tx
          last_tx = tx
          i += 1
          while i < xs.length
            tx2 = xs[i]
            break if tx2 != last_tx + 1
            h2 = heights[[tx2, ty]].to_f
            s2 = heights[[tx2, ty + 1]].to_f
            mountain2 = nds_mountain_volume_cell?(tx2, ty)
            stair2 = respond_to?(:nds_stair_cell?, true) && nds_stair_cell?(tx2, ty + 1)
            generic_block2 = !mountain2 && nds_explicit_front_face_at?(tx2, ty)
            break if (h2 - h).abs > 0.01 || (s2 - base).abs > 0.01 ||
                     h2 <= s2 + 0.01 || stair2 || generic_block2 ||
                     mountain2 != mountain ||
                     (mountain2 && !Mode7::Config::NDS_MOUNTAIN_AUTO_FACES)
            last_tx = tx2
            i += 1
          end
          nds_make_front_run(ty, start_tx, last_tx, h, base)
        end
      end
    end

    # Laterales: sparse columns instead of width*height scans.
    if Mode7.nds_side_faces?
      mountain_only = !Mode7.nds_full_side_faces?
      cols.each do |tx, ys|
        ys.sort!
        [:west, :east].each do |side|
          i = 0
          while i < ys.length
            ty = ys[i]
            h = heights[[tx, ty]].to_f
            nx = side == :west ? tx - 1 : tx + 1
            neighbor = heights[[nx, ty]].to_f
            mountain = nds_mountain_volume_cell?(tx, ty)
            allow_face = mountain ? Mode7::Config::NDS_MOUNTAIN_AUTO_SIDE_FACES : !mountain_only
            if h <= neighbor + 0.01 || !allow_face
              i += 1
              next
            end
            base = neighbor
            start_ty = ty
            last_ty = ty
            i += 1
            while i < ys.length
              ty2 = ys[i]
              break if ty2 != last_ty + 1
              h2 = heights[[tx, ty2]].to_f
              n2 = heights[[nx, ty2]].to_f
              mountain2 = nds_mountain_volume_cell?(tx, ty2)
              allow2 = mountain2 ? Mode7::Config::NDS_MOUNTAIN_AUTO_SIDE_FACES : !mountain_only
              break if (h2 - h).abs > 0.01 || (n2 - base).abs > 0.01 ||
                       h2 <= n2 + 0.01 || mountain2 != mountain || !allow2
              last_ty = ty2
              i += 1
            end
            nds_make_side_run(side, tx, start_ty, last_ty, h, base)
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
     Mode7.projection_cam_elevation.to_f.round(3),
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

    visibility_key = [cam_tx, cam_ty, rx, ry, bs]
    if @nds_volume_visibility_key != visibility_key || !@nds_volume_visible_indices
      seen = {}
      bx = bx0
      while bx <= bx1
        by = by0
        while by <= by1
          (@nds_volume_buckets[[bx, by]] || []).each { |i| seen[i] = true }
          by += 1
        end
        bx += 1
      end
      @nds_volume_visible_indices = seen.keys
      @nds_volume_visibility_key = visibility_key
    end
    indices = @nds_volume_visible_indices || []
    index_lookup = {}
    indices.each { |i| index_lookup[i] = true }

    # Oculta solo lo que estaba activo el frame de reproyeccion anterior.
    (@nds_volume_active || []).each do |i|
      next if index_lookup[i]
      spr = @nds_volume_faces[i][:sprite]
      spr.visible = false if spr && !spr.disposed?
    end

    active = []
    build_budget = Mode7::Config::NDS_VOLUME_FACE_BUILD_BUDGET.to_i
    build_budget = 1 if build_budget < 1
    frame_stamp = Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : 0

    indices.each do |i|
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
      points = Mode7.project_quad(w)
      if !points
        spr.visible = false
        next
      end
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
      # La cara vertical tiene profundidad fisica en Y y Z. Usar solo Y/Z=0
      # permitia que un priority del suelo la sobrepasara. Ordenamos por el
      # centro de la cara hasta disponer de depth-buffer por pixel.
      center_world_y = (w[1] + w[4] + w[7] + w[10]) / 4.0
      center_world_z = (w[2] + w[5] + w[8] + w[11]) / 4.0
      spr.z = Mode7.depth_z_at_elevation(center_world_y, center_world_z, 0, -2)
      spr.tone = @tone
      active << i
    end
    @nds_volume_active = active
    prune_nds_volume_face_cache(active) if frame_stamp > 0 && (frame_stamp % 120) == 0
  rescue Exception => e
    Console.echo_error("2.5D NDS V5 volume update: #{e.message}") if defined?(Console)
  end
end
