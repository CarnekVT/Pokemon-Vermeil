# Vermeil Movement: camara con respuesta visible aun con switch 59 apagado.
# Conserva scroll forzado, camara sobre eventos y Fancy Camera existentes.
if defined?(FancyCamera)
  class Game_Temp
    alias vermeil_movement_base_camera_speed camera_speed unless method_defined?(:vermeil_movement_base_camera_speed)
    def camera_speed
      speed = vermeil_movement_base_camera_speed
      smoothing = VermeilMovement.camera_smoothing
      # 35%=velocidad Fancy original, 0%=mas rapida, 100%=mas lenta.
      factor = 10.0 ** ((35.0 - smoothing) / 65.0)
      speed * [[factor, 0.08].max, 3.5].min
    end
  end
end

class Game_Player
  alias vermeil_movement_base_camera_update update_screen_position unless method_defined?(:vermeil_movement_base_camera_update)

  def update_screen_position(last_real_x, last_real_y)
    smoothing = VermeilMovement.camera_smoothing
    fancy_active = defined?(FancyCamera) && $game_switches &&
      defined?(Settings::CAMERA_FANCY) && $game_switches[Settings::CAMERA_FANCY]

    # FancyCamera activo: dejar su ruta original, ajustando camera_speed arriba.
    # Suavizado cero en modo normal: seguimiento clasico sin modificaciones.
    if fancy_active || smoothing <= 0 || self.map.scrolling?
      return vermeil_movement_base_camera_update(last_real_x, last_real_y)
    end

    # Respetar la camara dirigida por eventos/cutscenes.
    if ($game_temp.camera_target_event && $game_temp.camera_target_event != 0) ||
       ($game_temp.camera_pos && $game_temp.camera_pos[0] != 0 &&
        $game_temp.camera_pos[1] != 0) ||
       ($game_temp.camera_offset && $game_temp.camera_offset != [0, 0])
      return vermeil_movement_base_camera_update(last_real_x, last_real_y)
    end

    center_x = respond_to?(:carnek_screen_center_x) ? carnek_screen_center_x : SCREEN_CENTER_X
    center_y = respond_to?(:carnek_screen_center_y) ? carnek_screen_center_y : SCREEN_CENTER_Y
    target_x = @real_x - center_x
    target_y = @real_y - center_y

    # Al teletransportarse/cambiar de mapa, no arrastrar la camara lentamente.
    map_id = self.map.map_id
    if @_vermeil_camera_map_id != map_id
      @_vermeil_camera_map_id = map_id
      self.map.display_x = target_x
      self.map.display_y = target_y
      return
    end

    # Alpha calculado en segundos: resultados equivalentes a 60/120 FPS.
    dt = @delta_t || Graphics.delta
    dt = [[dt.to_f, 0.001].max, 0.05].min
    tau = 0.035 + (smoothing.to_f / 100.0) ** 2 * 0.55
    alpha = 1.0 - Math.exp(-dt / tau)
    self.map.display_x = self.map.display_x + (target_x - self.map.display_x) * alpha
    self.map.display_y = self.map.display_y + (target_y - self.map.display_y) * alpha
  end
end
