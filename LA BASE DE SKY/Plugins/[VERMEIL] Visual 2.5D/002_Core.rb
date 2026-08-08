#===============================================================================
# [VERMEIL] Visual 2.5D - 002_Core.rb
#===============================================================================
module Mode7
  class << self
    attr_reader :zoom, :current_alpha, :sin, :distance_h, :planet_radius
    # Proyeccion forzada por mapa (nil = usar Config::PROJECTION).
    attr_accessor :map_projection

    def screen_w; return Settings::SCREEN_WIDTH; end
    def screen_h; return Settings::SCREEN_HEIGHT; end
    def center_x; return screen_w / 2; end

    def pivot_ratio
      return @pivot_override if !@pivot_override.nil?
      return Config::PIVOT_RATIO
    end

    def pivot_y; return (screen_h * pivot_ratio).round; end

    # Proyeccion efectiva del mapa actual. El notetag/flag del mapa (visto en
    # Game_Map#setup) puede forzar :affine o :sky; si no, usa Config::PROJECTION.
    def map_mode
      return @map_projection if @map_projection == :affine || @map_projection == :sky
      Config::PROJECTION
    end

    def affine_mode?; return map_mode == :affine; end
    def sky_mode?; return map_mode == :sky; end

    # Interior/exterior es una propiedad del mapa, independiente de la
    # proyeccion elegida. Asi podemos mantener :sky dentro de casas y aun
    # aplicar reglas visuales especificas para interiores.
    def indoor_map?(map_id = nil)
      return false if !defined?(GameData::MapMetadata)
      id = map_id
      id = $game_map.map_id if id.nil? && $game_map
      return false if id.nil?
      meta = GameData::MapMetadata.get(id) rescue nil
      return !!(meta && meta.outdoor_map == false)
    end

    # Lee la metadata del mapa y fuerza proyeccion segun flag/outdoor.
    def detect_map_projection(map_id)
      return nil if !defined?(GameData::MapMetadata)
      meta = GameData::MapMetadata.get(map_id) rescue nil
      return nil if !meta
      if meta.has_flag?(Config::MAP_FLAG_AFFINE)
        return :affine
      elsif meta.has_flag?(Config::MAP_FLAG_SKY)
        return :sky
      elsif Config::AUTO_INDOOR_AFFINE && meta.outdoor_map == false
        return :affine
      end
      nil
    end

    def sky_angle_scale
      return 0.0 if !@current_alpha
      return @current_alpha.to_f / Config::DEFAULT_ALPHA
    end

    # Curva Sky V2: mezcla de curvatura seno y tramo lineal. Sustituye al
    # sin(theta) puro que generaba el efecto cilindrico "banana".
    def sky_curve(theta)
      Config::SKY_CURVE * Math.sin(theta) + Config::SKY_LINEAR * theta
    end

    # Factor de perspectiva DIRECCIONAL. La formula anterior usaba cos(theta),
    # que es simetrico: alejaba y acercaba escalaban igual. Una camara real debe
    # reducir el fondo (theta < 0) y aumentar suavemente el frente (theta > 0).
    def sky_directional_scale(theta, strength)
      strength = strength.to_f
      return 1.0 if strength.abs < 1.0e-9
      den = 1.0 - strength * theta.to_f
      den = 0.25 if den < 0.25
      k = 1.0 / den
      return 0.60 if k < 0.60
      return 1.50 if k > 1.50
      k
    end

    # Escala horizontal del plano. Con 0 mantiene habitaciones rectangulares.
    # La curvatura Sky afecta profundidad Y; no forzar derivada X evita que las
    # filas del borde se cierren y dejen huecos fuera del mapa.
    def sky_width_scale(theta)
      sky_directional_scale(theta, Config::SKY_WIDTH_PERSPECTIVE)
    end

    # Escala de personajes/eventos por profundidad. Puede variar suavemente
    # sin afectar la proporcion interna de los tiles del mapa.
    def sky_sprite_scale(theta)
      sky_directional_scale(theta, Config::SKY_SPRITE_SCALE)
    end

    # Escala UNIFORME de tiles verticales (muros, priority surfaces). Debe ser
    # exactamente la misma que usa el ancho de la fila del suelo: asi dos tiles
    # vecinos siguen tocandose y, sobre todo, zoom_x == zoom_y. Con
    # SKY_WIDTH_PERSPECTIVE=0 el pixel art queda 1:1 aunque el plano se comprima
    # en profundidad por SKY_GROUND_Y_SCALE.
    def tile_billboard_scale_for_world_y(wy)
      return @zoom if !sky_mode?
      @zoom * sky_width_scale(sky_theta_for_world_y(wy))
    end

    def sky_ground_y_scale
      v = Config::SKY_GROUND_Y_SCALE.to_f
      return 0.01 if v <= 0.01
      v
    end

    # Angulo de profundidad a partir de una coordenada Y del mundo, sin mezclar
    # elevacion. Este theta representa exclusivamente distancia sobre el suelo.
    def sky_theta_for_world_y(wy)
      scale = sky_angle_scale
      return 0.0 if scale <= 0.0
      ry = (wy.to_f - cam_y - pivot_y)
      (ry * @zoom * scale * sky_ground_y_scale) / @planet_radius
    end

    # Escala visual de un billboard situado en la Y indicada.
    def object_scale_for_world_y(wy)
      return @zoom if !sky_mode?
      @zoom * sky_sprite_scale(sky_theta_for_world_y(wy))
    end

    # Escala del eje vertical Z. IMPORTANTE: no usa SKY_SPRITE_SCALE.
    # El error de Phase 4 era ancho~=1.0 pero alto<1.0, aplastando muros.
    # Un tile vertical siempre conserva su aspect ratio; la perspectiva del
    # terreno viene de Y, no de deformar la cara del objeto.
    def vertical_scale_for_world_y(wy)
      return object_scale_for_world_y(wy) if !sky_mode?
      tile_billboard_scale_for_world_y(wy) * Config::SKY_VERTICAL_SCALE.to_f
    end

    # Inversa de sky_curve (resolve sky_curve(theta)=t por Newton). Monotona
    # creciente mientras |theta| < 2.14 (derivada 0.65*cos+0.35 > 0); el rango
    # visible de la camara (~+-0.4) queda muy dentro de esa zona.
    def sky_curve_inv(t)
      a = Config::SKY_CURVE.to_f
      b = Config::SKY_LINEAR.to_f
      return t if (a + b).abs < 1.0e-9
      theta = t / (a + b)
      6.times do
        f = a * Math.sin(theta) + b * theta - t
        df = a * Math.cos(theta) + b
        break if df.abs < 1.0e-9
        theta -= f / df
      end
      theta
    end

    # Theta (angulo de profundidad) de una fila de pantalla. Invierte la curva
    # hibrida (sky_curve) para mapear la fila sy a su angulo en el "planeta".
    def sky_theta_for_row(sy)
      t = (sy.to_f - pivot_y) / @planet_radius
      sky_curve_inv(t)
    end

    def effective_mode_blend; return (@mode_blend || 0.0).clamp(0.0, 1.0); end

    def rendering_now?
      return true if @mode_transition_frames && @mode_transition_frames > 0
      return effective_mode_blend > 0.001
    end

    def vanilla_project(wx, wy); return [wx - cam_x + center_x, wy - cam_y + terrain_camera_lift]; end
    def vanilla_world_y_for_row(sy); return sy - terrain_camera_lift + cam_y; end
    def lerp(a, b, t); return a + (b - a) * t; end

    # Movimiento de camara en pantalla. No altera cam_y, por tanto no cambia
    # curvatura ni posicion relativa de tiles vecinos.
    def terrain_camera_lift
      @terrain_camera_lift || 0.0
    end

    def terrain_camera_lift_target
      return 0.0 if Config::TERRAIN_TAG_CAMERA_LIFT.empty? || !$game_player || !$game_map
      map_id = $game_map.map_id
      x = $game_player.x
      y = $game_player.y
      if @terrain_camera_map_id == map_id && @terrain_camera_x == x && @terrain_camera_y == y
        return @terrain_camera_target || 0.0
      end
      @terrain_camera_map_id = map_id
      @terrain_camera_x = x
      @terrain_camera_y = y
      tag = $game_player.pbTerrainTag
      @terrain_camera_target = tag ? (Config::TERRAIN_TAG_CAMERA_LIFT[tag.id] || 0).to_f : 0.0
    rescue
      @terrain_camera_target = 0.0
    end

    def update_terrain_camera_lift
      target = rendering_now? ? terrain_camera_lift_target : 0.0
      current = terrain_camera_lift
      smooth = Config::TERRAIN_TAG_CAMERA_LIFT_SMOOTH.to_f.clamp(0.01, 1.0)
      value = current + (target - current) * smooth
      value = target if (target - value).abs < 0.05
      return if (value - current).abs < 0.01
      @terrain_camera_lift = value
      reset_caches
      invalidate_renderer_ground
    end

    def vanish_y
      return (pivot_y - @distance_h * @cos / @sin).round if !affine_mode?
      if Config::AFFINE_DEPTH > 0
        heff = @distance_h / Config::AFFINE_DEPTH.to_f
        return (pivot_y - heff * @cos / @sin).round
      end
      0
    end

    def configure(alpha = nil, zoom = nil, distance_h = nil, planet_radius = nil)
      @current_alpha = (alpha || @current_alpha || Config::DEFAULT_ALPHA).to_f
      @zoom = (zoom || @zoom || Config::DEFAULT_ZOOM).to_f
      @distance_h = (distance_h || @distance_h || Config::DISTANCE_H).to_f
      @planet_radius = (planet_radius || @planet_radius || Config::PLANET_RADIUS).to_f

      @a = @current_alpha * Math::PI / 180.0
      @cos = Math.cos(@a)
      @sin = Math.sin(@a)
      @dh = @distance_h
      p = pivot_y

      reset_caches
      return if @sin == 0

      @h0 = (-@dh * p * @cos) / (@dh + p * @sin) + p
      @z0 = @dh.to_f / (@dh + p * @sin)
      @slope = (1.0 - @z0) / (p - @h0)
      @corr = 1.0 - p * @slope
      @horizon = p - @dh * @cos / @sin
    end

    # Reinicia las caches de proyeccion (al cambiar mapa/camara/zoom/pivot).
    def reset_caches
      @hscale_cache ||= {}
      @hscale_cache.clear
      @world_y_cache ||= {}
      @world_y_cache.clear
      @sky_row_world_offset_cache ||= {}
      @sky_row_world_offset_cache.clear
      @project_y_cache ||= {}
      @project_y_cache.clear
    end

    def set_pivot(ratio)
      @pivot_override = ratio
      configure(@current_alpha, @zoom, @distance_h, @planet_radius)
    end

    def set_vanish(row)
      @pivot_override = (row + @distance_h * @cos / @sin) / screen_h.to_f
      configure(@current_alpha, @zoom, @distance_h, @planet_radius)
    end

    def reset_vanish
      @pivot_override = nil
      configure(@current_alpha, @zoom, @distance_h, @planet_radius)
    end

    def set_default_camera
      configure(Config::DEFAULT_ALPHA, Config::DEFAULT_ZOOM)
    end

    def persp(sy); return @slope * sy + @corr; end

    # Sin efectivo de la proyeccion afine: AFFINE_PERSPECTIVE aplana la curva
    # (0 = plano, 1 = perspectiva original). Se usa en scale/unscale/hscale y
    # horizonte para mantener la proyeccion autoconsistente.
    def effective_sin
      return @sin * Config::AFFINE_PERSPECTIVE.to_f
    end

    def ortho_blend
      return 0.0 if Config::FOV >= 55
      return 1.0 if Config::FOV <= 0
      return (55.0 - Config::FOV) / 55.0
    end

    def hscale(sy)
      @hscale_cache ||= {}
      return @hscale_cache[sy] if @hscale_cache.key?(sy)
      result = _hscale_uncached(sy)
      @hscale_cache[sy] = result
      result
    end

    def base_hscale(sy)
      if sky_mode?
        return @zoom * sky_sprite_scale(sky_theta_for_row(sy))
      end
      old_a = @a; old_cos = @cos; old_sin = @sin
      base_a = Config::DEFAULT_ALPHA.to_f * Math::PI / 180.0
      @a = base_a; @cos = Math.cos(base_a); @sin = Math.sin(base_a)
      res = _hscale_uncached(sy)
      @a = old_a; @cos = old_cos; @sin = old_sin
      res
    end

    def _hscale_uncached(sy)
      if sky_mode?
        return @zoom * sky_width_scale(sky_theta_for_row(sy))
      end
      if affine_mode?
        if Config::AFFINE_DEPTH > 0
          heff = @dh / Config::AFFINE_DEPTH.to_f
          ry = affine_depth_unscale((sy - pivot_y).to_f)
          zi = @zoom * ry
          d = heff - zi * effective_sin
          return 0.0 if d.abs < 1.0e-9
          return @zoom * heff * heff * @cos / (d * d)
        end
        t = (sy / screen_h.to_f) - 0.5
        return Config::AFFINE_ZOOM * (1.0 + Config::AFFINE_CONVERGENCE * 2.0 * t)
      end
      full = persp(sy) * @zoom
      flat = persp(pivot_y) * @zoom
      return flat + (full - flat) * (1.0 - ortho_blend)
    end

    def horizon_row
      return 0 if sky_mode?
      if affine_mode? && Config::AFFINE_DEPTH > 0
        heff = @dh / Config::AFFINE_DEPTH.to_f
        se = effective_sin
        return 0 if se.abs < 1.0e-9
        return pivot_y - (heff * @cos / se)
      end
      return 0 if affine_mode?
      return @horizon
    end

    # Niebla de profundidad: 0 en el pivot del jugador, FOG_MAX_ALPHA en el
    # horizonte. Interpola por fila de pantalla (screen_y). Consultada por
    # suelo/muros/personajes para difuminar lo lejano.
    def fog_alpha(screen_y)
      return 0 if !Config::FOG_ENABLED
      delta = pivot_y - horizon_row
      return 0 if delta <= 0
      t = (pivot_y - screen_y.to_f) / delta
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      (t * Config::FOG_MAX_ALPHA).round
    end

    def cam_x
      return 0 if !$game_map
      return ($game_map.display_x.to_f / Game_Map::X_SUBPIXELS) + center_x
    end

    def cam_y
      return 0 if !$game_map
      base = $game_map.display_y.to_f / Game_Map::Y_SUBPIXELS
      return base - camera_elevation if Config::HEIGHTMAP_ENABLED
      base
    end

    def camera_elevation
      return 0 if !Config::HEIGHTMAP_ENABLED
      return Mode7::Heightmap.camera_altitude
    rescue
      0
    end

    def affine_depth_scale(ry)
      t = Config::AFFINE_DEPTH
      s = Config::AFFINE_SLOPE
      return s * ry if t <= 0
      heff = @dh / t
      yi = @zoom * ry
      d = heff - yi * effective_sin
      return s * ry if d <= 0.0
      (heff * yi * @cos) / d
    end

    def affine_depth_unscale(so)
      t = Config::AFFINE_DEPTH
      s = Config::AFFINE_SLOPE
      return so / s if t <= 0
      heff = @dh / t
      den = so * effective_sin + heff * @cos
      return so / s if den.abs < 1.0e-9
      yi = so * heff / den
      yi / @zoom
    end

    def _sky_project(wx, wy, elevation = 0)
      rx = wx.to_f - cam_x
      scale = sky_angle_scale
      return vanilla_project(wx, wy - elevation) if scale <= 0.0

      # El suelo y la altura usan ejes distintos. Antes `elevation` se restaba de
      # wy, por lo que un muro "subia" recorriendo el cilindro. Ahora theta se
      # calcula solo con la profundidad del suelo y Z se proyecta verticalmente.
      theta = sky_theta_for_world_y(wy)
      sy_ground = pivot_y + (@planet_radius * sky_curve(theta))
      sx = center_x + rx * @zoom * sky_width_scale(theta)
      sy = sy_ground - elevation.to_f * vertical_scale_for_world_y(wy) + terrain_camera_lift
      return [sx, sy]
    end

    def project(wx, wy, elevation = 0)
      return _sky_project(wx, wy, elevation) if sky_mode?
      if affine_mode?
        rx = wx - cam_x
        ry = (wy - cam_y - elevation) - pivot_y
        sy = pivot_y + affine_depth_scale(ry)
        sx = center_x + hscale(sy) * rx
        return [sx, sy + terrain_camera_lift]
      end
      rx = wx - cam_x
      ry = wy - cam_y - elevation
      yi = @zoom * (ry - pivot_y)
      d = @dh - yi * @sin
      return nil if d <= 0
      sy = pivot_y + (@dh * yi * @cos) / d
      sx = center_x + hscale(sy) * rx
      return [sx, sy + terrain_camera_lift]
    end

    def project_y(wy, elevation = 0)
      @project_y_cache ||= {}
      key = [wy, elevation, cam_y.floor]
      return @project_y_cache[key] if @project_y_cache.key?(key)
      result = _project_y_uncached(wy, elevation)
      @project_y_cache[key] = result
      @project_y_cache.clear if @project_y_cache.size > 2000
      result
    end

    def _sky_project_y(wy, elevation = 0)
      scale = sky_angle_scale
      return wy - cam_y - elevation + terrain_camera_lift if scale <= 0.0
      theta = sky_theta_for_world_y(wy)
      sy_ground = pivot_y + (@planet_radius * sky_curve(theta))
      return sy_ground - elevation.to_f * vertical_scale_for_world_y(wy) + terrain_camera_lift
    end

    def _project_y_uncached(wy, elevation = 0)
      return _sky_project_y(wy, elevation) if sky_mode?
      if affine_mode?
        return pivot_y + affine_depth_scale((wy - cam_y - elevation) - pivot_y) + terrain_camera_lift
      end
      ry = wy - cam_y - elevation
      yi = @zoom * (ry - pivot_y)
      d = @dh - yi * @sin
      return nil if d <= 0
      return pivot_y + (@dh * yi * @cos) / d + terrain_camera_lift
    end

    def wall_scale(sy)
      return nil if sy.nil?
      hscale(sy)
    end

    def wall_half_width(half_w, wy)
      k = wall_scale(wy)
      return half_w if k.nil?
      half_w * k
    end

    # Clave de profundidad compatible con la prioridad clasica de RPG Maker.
    # Priority N no es altura fisica: hace que el tile se ordene como si su base
    # estuviera N tiles mas cerca del jugador. Asi un techo puede tapar al actor
    # durante varias filas sin recurrir a z=9999.
    def depth_z(wy, priority = 0, bias = 0)
      step = defined?(Config::PRIORITY_DEPTH_STEP) ? Config::PRIORITY_DEPTH_STEP.to_f : Game_Map::TILE_HEIGHT.to_f
      virtual_y = wy.to_f + priority.to_i * step
      sy = project_y(virtual_y, 0)
      sy = project_y(wy, 0) if sy.nil?
      return bias.to_i if sy.nil?
      sy.round + bias.to_i
    end

    def world_y_for_row(sy)
      sy -= terrain_camera_lift
      return _sky_world_y_for_row(sy) if sky_mode?
      key = [sy, cam_y.floor]
      return @world_y_cache[key] if @world_y_cache && @world_y_cache.key?(key)
      result = _world_y_for_row_uncached(sy)
      @world_y_cache[key] = result if @world_y_cache
      result
    end

    def _sky_world_y_for_row(sy)
      scale = sky_angle_scale
      return vanilla_world_y_for_row(sy) if scale <= 0.0
      @sky_row_world_offset_cache ||= {}
      offset = @sky_row_world_offset_cache[sy]
      if offset.nil?
        theta = sky_theta_for_row(sy)
        ry = (theta * @planet_radius) / (@zoom * scale * sky_ground_y_scale)
        offset = pivot_y + ry
        @sky_row_world_offset_cache[sy] = offset
      end
      return cam_y + offset
    end

    def _world_y_for_row_uncached(sy)
      return _sky_world_y_for_row(sy) if sky_mode?
      return cam_y + pivot_y + affine_depth_unscale(sy - pivot_y) if affine_mode?
      d = sy - pivot_y
      den = @dh * @cos + d * @sin
      return nil if den.abs < 1.0e-6
      yi = d * @dh / den
      return yi / @zoom + pivot_y + cam_y
    end

    def override; return @override; end
    def override=(value); @override = value; end

    def active_now?
      return @override if !@override.nil?
      return false if !$game_switches
      return $game_switches[Config::SWITCH_ID] if Config::SWITCH_ID > 0
      return $game_switches[Config::PLAYER_SWITCH] if Config::PLAYER_SWITCH > 0
      return false
    end

    def toggle_debug
      if @override.nil?
        @override = true
      elsif @override == true
        @override = false
      else
        @override = nil
      end
    end

    def override_state
      return _INTL("Auto") if @override.nil?
      return _INTL("ON") if @override
      return _INTL("OFF")
    end

    def set_camera(target_alpha, target_zoom, frames = 60, target_distance_h = nil, target_planet_radius = nil)
      @target_alpha = target_alpha.to_f
      @target_zoom = target_zoom.to_f
      @target_distance_h = (target_distance_h || @distance_h || Config::DISTANCE_H).to_f
      @target_planet_radius = (target_planet_radius || @planet_radius || Config::PLANET_RADIUS).to_f
      @transition_frames = frames.to_i

      if @transition_frames <= 0
        configure(@target_alpha, @target_zoom, @target_distance_h, @target_planet_radius)
      else
        @step_alpha = (@target_alpha - @current_alpha) / @transition_frames
        @step_zoom = (@target_zoom - @zoom) / @transition_frames
        @step_distance_h = (@target_distance_h - @distance_h) / @transition_frames
        @step_planet_radius = (@target_planet_radius - @planet_radius) / @transition_frames
      end
    end

    def update_transition
      if @transition_frames && @transition_frames > 0
        @transition_frames -= 1
        if @transition_frames == 0
          configure(@target_alpha, @target_zoom, @target_distance_h, @target_planet_radius)
        else
          configure(@current_alpha + @step_alpha,
                    @zoom + @step_zoom,
                    @distance_h + @step_distance_h,
                    @planet_radius + @step_planet_radius)
        end
        invalidate_renderer_ground
      end
    end

    def invalidate_renderer_ground
      return if !$scene.is_a?(Scene_Map)
      renderer = $scene.instance_variable_get(:@map_renderer)
      renderer.invalidate_ground if renderer.respond_to?(:invalidate_ground)
    end
  end

  configure(Config::DEFAULT_ALPHA, Config::DEFAULT_ZOOM)
end

class Scene_Map
  alias_method :_VERMEIL_25D_core_update, :update unless method_defined?(:_VERMEIL_25D_core_update)
  def update
    _VERMEIL_25D_core_update
    Mode7.update_transition if Mode7.active_now?
    Mode7.update_terrain_camera_lift
  end
end

# Deteccion de interiores: al cargar un mapa se resuelve su proyeccion (flag
# <mode7: affine>/<mode7: sky>, o AUTO_INDOOR_AFFINE) y se invalida lo cacheado.
class Game_Map
  alias_method :_VERMEIL_25D_core_setup, :setup unless method_defined?(:_VERMEIL_25D_core_setup)

  def setup(map_id)
    old_mode = Mode7.map_projection
    Mode7.map_projection = Mode7.detect_map_projection(map_id)
    _VERMEIL_25D_core_setup(map_id)
    if Mode7.map_projection != old_mode
      Mode7.reset_caches
      Mode7.invalidate_renderer_ground rescue nil
    end
  end
end
