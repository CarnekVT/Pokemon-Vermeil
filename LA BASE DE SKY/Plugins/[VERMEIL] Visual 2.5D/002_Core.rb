#===============================================================================
# [VERMEIL] Visual 2.5D - 002_Core.rb
# Motor matematico de proyeccion (Perspectiva conica Gen 5) + control de camara.
#===============================================================================
module Mode7
  class << self
    attr_reader :zoom, :current_alpha, :sin

    def screen_w
      return Settings::SCREEN_WIDTH
    end

    def screen_h
      return Settings::SCREEN_HEIGHT
    end

    def center_x
      return screen_w / 2
    end

    # Fraccion de pantalla donde se ancla el pivote. Admite override en runtime
    # (minijuegos, cutscenes) via set_pivot/set_vanish/reset_vanish.
    # Fraccion de pantalla donde se ancla el pivote. Admite override en runtime
    # (minijuegos, cutscenes) via set_pivot/set_vanish/reset_vanish.
    def pivot_ratio
      return @pivot_override if !@pivot_override.nil?
      return Config::PIVOT_RATIO
    end

    def pivot_y
      return (screen_h * pivot_ratio).round
    end

    # ¿Modo affin (pendiente fija + scroll) o conico (re-proyeccion dinamica)?
    def affine_mode?
      return Config::PROJECTION == :affine
    end

    # Fila del punto de fuga (vanishing row) en pantalla. Negativa = fuera del
    # limite superior (horizonte elevado). Derivada del pivote y del angulo.
    # Solo tiene sentido en proyeccion conica; en afín puro se devuelve el techo.
    def vanish_y
      return (pivot_y - Config::DISTANCE_H * @cos / @sin).round if !affine_mode?
      # En afín con profundidad: punto de fuga de la heff (coherente con hscale).
      if Config::AFFINE_DEPTH > 0
        heff = Config::DISTANCE_H / Config::AFFINE_DEPTH.to_f
        return (pivot_y - heff * @cos / @sin).round
      end
      0
    end

    def configure(alpha = Config::DEFAULT_ALPHA, zoom = Config::DEFAULT_ZOOM)
      @current_alpha = alpha
      @zoom = zoom

      @a = alpha.to_f * Math::PI / 180.0
      @cos = Math.cos(@a)
      @sin = Math.sin(@a)
      @dh = Config::DISTANCE_H
      p = pivot_y

      # Cache de proyeccion invalidado al reconfigurar (cambia angulo/zoom).
      @hscale_cache = {}
      @world_y_cache = {}

      # Prevencion matematica de division por cero
      return if @sin == 0

      # ---- Conico (camera con altura DISTANCE_H) ----
      @h0 = (-@dh * p * @cos) / (@dh + p * @sin) + p
      @z0 = @dh.to_f / (@dh + p * @sin)
      @slope = (1.0 - @z0) / (p - @h0)
      @corr = 1.0 - p * @slope
      @horizon = p - @dh * @cos / @sin

      # ---- Afin: la VERTICAL usa heff = @dh / AFFINE_DEPTH. Para que la
      #      escala HORIZONTAL sea coherente (el ancho de celda se estrecha al
      #      mismo ritmo que el alto), calibrar la misma formula con heff.
      t = Config::AFFINE_DEPTH.to_f
      if t > 0
        heff = @dh / t
        @aff_h0 = (-heff * p * @cos) / (heff + p * @sin) + p
        @aff_z0 = heff.to_f / (heff + p * @sin)
        @aff_slope = (1.0 - @aff_z0) / (p - @aff_h0)
        @aff_corr = 1.0 - p * @aff_slope
        @aff_horizon = p - heff * @cos / @sin
      else
        @aff_slope = nil
        @aff_corr = nil
        @aff_horizon = nil
      end
    end

    # --- OVERRIDE RUNTIME DE CAMARA (minijuegos, cutscenes) ---

    # Fija el pivote como fraccion de pantalla (0.0..1.0).
    def set_pivot(ratio)
      @pivot_override = ratio
      configure(@current_alpha, @zoom)
    end

    # Fija la vanishing row deseada (px en pantalla) y deriva el pivote.
    def set_vanish(row)
      @pivot_override = (row + Config::DISTANCE_H * @cos / @sin) / screen_h.to_f
      configure(@current_alpha, @zoom)
    end

    def reset_vanish
      @pivot_override = nil
      configure(@current_alpha, @zoom)
    end

    # --- METODOS DE CONTROL DE CAMARA RAPIDOS ---

    # Vuelve a la perspectiva por defecto (Gen 5).
    def set_default_camera
      configure(Config::DEFAULT_ALPHA, Config::DEFAULT_ZOOM)
    end

    def persp(sy)
      return @slope * sy + @corr
    end

    # Mezcla hacia ortografico: 0 = perspectiva plena, 1 = plano puro.
    def ortho_blend
      return 0.0 if Config::FOV >= 55
      return 1.0 if Config::FOV <= 0
      return (55.0 - Config::FOV) / 55.0
    end

    # Escala horizontal por fila, aplanada segun Config::FOV. El eje vertical
    # (project/project_y) conserva la perspectiva: solo se bloquea la
    # distorsion horizontal de la cuadricula (look retro Gen 5 / HD-2D).
    # En afin (con AFFINE_DEPTH>0) la escala horizontal sigue la MISMA conica
    # del terreno (persp): las filas lejanas se estrechan hacia el horizonte.
    # Como persp depende solo de sy (fila de pantalla FIJA), es scroll-estable:
    # el ancho converge con la profundidad sin depender de la posicion del
    # jugador -> la deformacion es del MAPA (terreno 3D horneado), no del
    # movimiento.
    def hscale(sy)
      @hscale_cache ||= {}
      return @hscale_cache[sy] if @hscale_cache.key?(sy)
      result = _hscale_uncached(sy)
      @hscale_cache[sy] = result
      result
    end

    def _hscale_uncached(sy)
      if affine_mode?
        # La VERTICAL es conica real (heff). Para que una celda se proyecte
        # con el MISMO tamano en x que en y a cada profundidad, la escala
        # horizontal debe ser la DERIVADA exacta de la proyeccion vertical:
        #   so = heff*yi*cos/(heff - yi*sin);  yi = zoom*ry
        #   dso/dry = zoom*heff^2*cos / (heff - zoom*ry*sin)^2
        # donde ry = mundo de la fila sy (inverso). Asi el ancho se estrecha
        # al MISMO ritmo que el alto -> la cuadricula converge y el 3D cierra.
        if Config::AFFINE_DEPTH > 0
          heff = @dh / Config::AFFINE_DEPTH.to_f
          ry = affine_depth_unscale((sy - pivot_y).to_f)
          zi = @zoom * ry
          d = heff - zi * @sin
          return 0.0 if d.abs < 1.0e-9
          return @zoom * heff * heff * @cos / (d * d)
        end
        # Afín puro (DEPTH=0): lente fija de pantalla (convergencia).
        t = (sy / screen_h.to_f) - 0.5
        return Config::AFFINE_ZOOM * (1.0 + Config::AFFINE_CONVERGENCE * 2.0 * t)
      end
      full = persp(sy) * @zoom
      flat = persp(pivot_y) * @zoom
      return flat + (full - flat) * (1.0 - ortho_blend)
    end

    # Fila donde la camara "mira" al horizonte. En afín puro (DEPTH=0) no hay
    # horizonte real re-proyectado: el mundo comienza en la fila 0 de pantalla.
    # Con AFFINE_DEPTH>0 la conica horneada SI tiene horizonte (mismo que el
    # conico): el suelo converge ahi arriba.
    def horizon_row
      return @aff_horizon if affine_mode? && Config::AFFINE_DEPTH > 0 && @aff_horizon
      return @horizon if affine_mode? && Config::AFFINE_DEPTH > 0
      return 0 if affine_mode?
      return @horizon
    end

    def cam_x
      return 0 if !$game_map
      return ($game_map.display_x.to_f / Game_Map::X_SUBPIXELS) + center_x
    end

def cam_y
      return 0 if !$game_map
      base = $game_map.display_y.to_f / Game_Map::Y_SUBPIXELS
      # CAMARA 3D: la elevacion del ojo sigue el relieve del terreno.
      return base - camera_elevation if Config::HEIGHTMAP_ENABLED
      base
    end

    # Elevacion de la camara (px de mundo) aplicada a cam_y. La sube el
    # heightmap bajo el jugador (Heightmap.camera_altitude).
    def camera_elevation
      return 0 if !Config::HEIGHTMAP_ENABLED
      return Mode7::Heightmap.camera_altitude
    rescue
      0
    end

    # Escala de profundidad vertical del plano afín (AFFINE_DEPTH). ry es el
    # offset de mundo relativo al ojo (px, + hacia abajo). Proyeccion CONICA
    # REAL (misma formula que el conico), con la camara FIJA: la deformacion
    # pertenece al plano del mapa (terreno 3D horneado), jamas al jugador.
    #   yi = @zoom * ry
    #   so = (heff * yi * cos) / (heff - yi * sin),  heff = DISTANCE_H / t
    # t (AFFINE_DEPTH) = intensidad: 0 => afín puro (ry lineal, plano), 1 => cónica plena.
    # La inversa (affine_depth_unscale) es exacta -> world_y_for_row y project
    # son inversos -> el scroll solo DESPLAZA la textura, no la deforma.
    def affine_depth_scale(ry)
      t = Config::AFFINE_DEPTH
      s = Config::AFFINE_SLOPE
      return s * ry if t <= 0
      heff = @dh / t
      yi = @zoom * ry
      d = heff - yi * @sin
      return s * ry if d <= 0.0 # mas alla del horizonte: no proyectar
      (heff * yi * @cos) / d
    end

    # Inversa de affine_depth_scale (para world_y_for_row). Resolucion exacta
    # de la misma conica: yi = so*heff / (so*sin + heff*cos).
    def affine_depth_unscale(so)
      t = Config::AFFINE_DEPTH
      s = Config::AFFINE_SLOPE
      return so / s if t <= 0
      heff = @dh / t
      den = so * @sin + heff * @cos
      return so / s if den.abs < 1.0e-9
      yi = so * heff / den
      yi / @zoom
    end

    def project(wx, wy)
      if affine_mode?
        # Pivote = ojo: el jugador (wy-cam_y == pivot_y) queda en pivot_y.
        # La curva de profundidad es FIJA en pantalla -> scroll uniforme.
        rx = wx - cam_x
        ry = (wy - cam_y) - pivot_y
        sy = pivot_y + affine_depth_scale(ry)
        sx = center_x + hscale(sy) * rx
        return [sx, sy]
      end

      rx = wx - cam_x
      ry = wy - cam_y
      yi = @zoom * (ry - pivot_y)
      d = @dh - yi * @sin
      return nil if d <= 0
      sy = pivot_y + (@dh * yi * @cos) / d
      sx = center_x + hscale(sy) * rx
      return [sx, sy]
    end

    def project_y(wy)
      return pivot_y + affine_depth_scale((wy - cam_y) - pivot_y) if affine_mode?
      ry = wy - cam_y
      yi = @zoom * (ry - pivot_y)
      d = @dh - yi * @sin
      return nil if d <= 0
      return pivot_y + (@dh * yi * @cos) / d
    end

# Escala ON-SCREEN de un muro de WALL_TERRAIN_TAG_HEIGHT, dada su base en
    # pantalla (sy). Usa la MISMA escala que el suelo en esa fila (hscale):
    # es la unica forma de que el muro sea indistinguible del terreno a su
    # alrededor y jamas se separe de los tiles adyacentes. En proyeccion
    # AFFINE el hscale es estable (no re-muestrea frame a frame) -> el muro
    # NO se corta al moverse; queda con una deformacion imperceptible porque
    # es la misma que el suelo de esa fila.
    def wall_scale(sy)
      return nil if sy.nil?
      hscale(sy)
    end

    # Media anchura ON-SCREEN de un muro a la profundidad mundial wy, con
    # deformacion horizontal MINIMA (blend hacia un ancho casi constante).
    # billboard puro (blend 0) mantiene el ancho; plena (1) = hscale cónico.
    def wall_half_width(half_w, wy)
      k = wall_scale(wy)
      return half_w if k.nil?
      half_w * k
    end

    def world_y_for_row(sy)
      # Cache por (sy, cam_y) - cam_y es constante en idle, cambia poco en movement.
      # Evita recalculo de la conica por fila en draw_ground.
      key = [sy, cam_y.floor]
      return @world_y_cache[key] if @world_y_cache && @world_y_cache.key?(key)
      result = _world_y_for_row_uncached(sy)
      @world_y_cache[key] = result if @world_y_cache
      result
    end

    def _world_y_for_row_uncached(sy)
      # AFFINE: inversa de project_y. Cuando la camara centra al jugador
      # (wy - cam_y == pivot_y) el jugador queda en pivot_y de la pantalla.
      return cam_y + pivot_y + affine_depth_unscale(sy - pivot_y) if affine_mode?
      # Se usa para dibujar el suelo; no debe verse afectada por el factor de un muro.
      d = sy - pivot_y
      den = @dh * @cos + d * @sin
      return nil if den.abs < 1.0e-6
      yi = d * @dh / den
      return yi / @zoom + pivot_y + cam_y
    end

    def override
      return @override
    end

    def override=(value)
      @override = value
    end

    def active_now?
      return @override if !@override.nil?
      return false if !$game_switches
      return $game_switches[Config::SWITCH_ID] if Config::SWITCH_ID > 0
      return $game_switches[Config::PLAYER_SWITCH] if Config::PLAYER_SWITCH > 0
      return false
    end

    def toggle_debug
      @override = (@override.nil?) ? true : !@override
    end

    def override_state
      return _INTL("Auto") if @override.nil?
      return _INTL("ON") if @override
      return _INTL("OFF")
    end
  end

  # Se inicializa con la camara Gen 5 (default) al arrancar el juego.
  configure(Config::DEFAULT_ALPHA, Config::DEFAULT_ZOOM)
end