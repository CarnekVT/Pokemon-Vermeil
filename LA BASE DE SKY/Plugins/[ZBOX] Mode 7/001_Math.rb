#===============================================================================
# Mode 7 (2.5D) - Matemática de proyección (Perspectiva cónica Gen 5)
#===============================================================================
module Mode7
  module Config
    # Switch global que activa la perspectiva dinámica en el mapa. 0 = desactivado.
    SWITCH_ID     = 0

    # =======================================================================
    # CÁMARA POR DEFECTO (ESTILO GEN 5)
    # Perspectiva cónica central con horizonte elevado y cámara en picado.
    # =======================================================================

    # Fila de pantalla (fracción) donde queda anclado el jugador.
    # 0.50 = centro exacto de pantalla. Combinado con cam_y anclada a pivot_y,
    # mantiene el centro de cámara == centro matemático de proyección.
    PIVOT_RATIO   = 0.50

    # Inclinación de la cámara en grados.
    # 15-20 grados es el "punto dulce": los techos se asoman ligeramente hacia
    # atrás sin deformar severamente las paredes (casi vanilla, sutil 3D).
    DEFAULT_ALPHA = 15

    # FOV horizontal en grados. Controla el aplanado de la cuadrícula,
    # desacoplado del pitch:
    #   55+   -> perspectiva plena (distorsión amplia, esquinas estiradas)
    #   15-30 -> FOV retro: tiles arriba y abajo casi del mismo tamaño
    #   0     -> ortográfico puro (cero distorsión horizontal)
    FOV           = 15

    # Zoom base (1.0 = escala natural del pixel art).
    DEFAULT_ZOOM  = 1.0

    # Altura del ojo (normalmente la altura de pantalla).
    DISTANCE_H    = Settings::SCREEN_HEIGHT

    # Color del cielo (visible si la cámara baja demasiado).
    SKY_COLOR     = Color.new(104, 168, 224)

    # Color renderizado fuera de los límites del mapa.
    OUTSIDE_COLOR = Color.new(0, 0, 0)
  end

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

    # Fracción de pantalla donde se ancla el pivote. Admite override en runtime
    # (minijuegos, cutscenes) vía set_pivot/set_vanish/reset_vanish.
    def pivot_ratio
      return @pivot_override if !@pivot_override.nil?
      return Config::PIVOT_RATIO
    end

    def pivot_y
      return (screen_h * pivot_ratio).round
    end

    # Fila del punto de fuga (vanishing row) en pantalla. Negativa = fuera del
    # límite superior (horizonte elevado). Derivada del pivote y del ángulo.
    def vanish_y
      return (pivot_y - Config::DISTANCE_H * @cos / @sin).round
    end

    def configure(alpha = Config::DEFAULT_ALPHA, zoom = Config::DEFAULT_ZOOM)
      @current_alpha = alpha
      @zoom = zoom

      @a = alpha.to_f * Math::PI / 180.0
      @cos = Math.cos(@a)
      @sin = Math.sin(@a)
      @dh = Config::DISTANCE_H
      p = pivot_y

      # Prevención matemática de división por cero
      return if @sin == 0

      @h0 = (-@dh * p * @cos) / (@dh + p * @sin) + p
      @z0 = @dh.to_f / (@dh + p * @sin)
      @slope = (1.0 - @z0) / (p - @h0)
      @corr = 1.0 - p * @slope
      @horizon = p - @dh * @cos / @sin
    end

    # --- OVERRIDE RUNTIME DE CÁMARA (minijuegos, cutscenes) ---

    # Fija el pivote como fracción de pantalla (0.0..1.0).
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

    # --- MÉTODOS DE CONTROL DE CÁMARA RÁPIDOS ---

    # Vuelve a la perspectiva por defecto (Gen 5).
    def set_default_camera
      configure(Config::DEFAULT_ALPHA, Config::DEFAULT_ZOOM)
    end

    def persp(sy)
      return @slope * sy + @corr
    end

    # Mezcla hacia ortográfico: 0 = perspectiva plena, 1 = plano puro.
    def ortho_blend
      return 0.0 if Config::FOV >= 55
      return 1.0 if Config::FOV <= 0
      return (55.0 - Config::FOV) / 55.0
    end

    # Escala horizontal por fila, aplanada según Config::FOV. El eje vertical
    # (project/project_y) conserva la perspectiva: solo se bloquea la
    # distorsión horizontal de la cuadrícula (look retro Gen 5 / HD-2D).
    def hscale(sy)
      full = persp(sy) * @zoom
      flat = persp(pivot_y) * @zoom
      return flat + (full - flat) * (1.0 - ortho_blend)
    end

    def horizon_row
      return @horizon
    end

    def cam_x
      return 0 if !$game_map
      return ($game_map.display_x.to_f / Game_Map::X_SUBPIXELS) + center_x
    end

    def cam_y
      return 0 if !$game_map
      # [FIX OPENCODE]: Retornar SOLO el display_y nativo. project() ya aplica
      # pivot_y; sumarlo aquí duplicaba la resta y disparaba el jugador arriba
      # (efecto acordeón: estira al subir, aprieta al bajar).
      return $game_map.display_y.to_f / Game_Map::Y_SUBPIXELS
    end

    def project(wx, wy)
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
      ry = wy - cam_y
      yi = @zoom * (ry - pivot_y)
      d = @dh - yi * @sin
      return nil if d <= 0
      return pivot_y + (@dh * yi * @cos) / d
    end

    def world_y_for_row(sy)
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
      return false if !$game_switches || Config::SWITCH_ID <= 0
      return $game_switches[Config::SWITCH_ID]
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

  # Inicializamos con la cámara Gen 5 (default) al arrancar el juego
  configure(Config::DEFAULT_ALPHA, Config::DEFAULT_ZOOM)
end
