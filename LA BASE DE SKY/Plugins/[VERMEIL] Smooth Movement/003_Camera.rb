# Movement Studio: suavizado real y observable sobre la camara FINAL.
# Usa el resultado de la cadena Fancy Camera / Carnek Project Settings.
# No modifica camera_speed ni interfiere con las camaras de eventos.
class Game_Player
  alias vermeil_movement_camera_before_studio update_screen_position unless method_defined?(:vermeil_movement_camera_before_studio)

  def update_screen_position(last_real_x, last_real_y)
    map = self.map
    return vermeil_movement_camera_before_studio(last_real_x, last_real_y) if map.scrolling?

    previous_x = map.display_x
    previous_y = map.display_y
    # Ejecutar primero todas las camaras instaladas para mantener sus efectos.
    vermeil_movement_camera_before_studio(last_real_x, last_real_y)

    return unless defined?(VermeilMovement)
    # No suavizar cutscenes, seguimiento de eventos, shakes ni scroll manual.
    return if $game_temp.camera_target_event && $game_temp.camera_target_event != 0
    return if $game_temp.camera_pos && $game_temp.camera_pos[0] != 0 &&
              $game_temp.camera_pos[1] != 0
    return if $game_temp.camera_shake && $game_temp.camera_shake > 0
    return if $game_temp.camera_offset && $game_temp.camera_offset != [0, 0]

    smoothing = VermeilMovement.camera_smoothing
    return if smoothing == 35 # 35 = camara original del proyecto (baseline).

    # En el primer frame/cambio de mapa no arrastrar la camara desde otro mapa.
    if @_vermeil_smoothing_map_id != map.map_id
      @_vermeil_smoothing_map_id = map.map_id
      return
    end

    # Objetivo: posicion del jugador en coordenadas subpixel del mapa.
    center_x = respond_to?(:carnek_screen_center_x) ? carnek_screen_center_x : SCREEN_CENTER_X
    center_y = respond_to?(:carnek_screen_center_y) ? carnek_screen_center_y : SCREEN_CENTER_Y
    target_x = @real_x - center_x
    target_y = @real_y - center_y
    return if (target_x - previous_x).abs > Game_Map::REAL_RES_X * 6 ||
              (target_y - previous_y).abs > Game_Map::REAL_RES_Y * 6

    dt = @delta_t || Graphics.delta
    dt = [[dt.to_f, 0.001].max, 0.05].min
    # Menor valor = seguimiento mas rapido, mayor = camara mas suave/rezagada.
    tau = 0.005 + 0.65 * ((smoothing.to_f / 100.0) ** 2)
    alpha = 1.0 - Math.exp(-dt / tau)
    map.display_x = previous_x + (target_x - previous_x) * alpha
    map.display_y = previous_y + (target_y - previous_y) * alpha
  end
end
