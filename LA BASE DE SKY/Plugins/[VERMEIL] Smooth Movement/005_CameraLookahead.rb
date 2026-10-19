# Vermeil Movement Studio 0.4 - look-ahead de camara sin retrasar el input.
# Plugin visual; no modifica direccion, hitboxes, colisiones ni Game_Player#x/y.
class Game_Player
  alias vermeil_lead_native_camera_update update_screen_position unless method_defined?(:vermeil_lead_native_camera_update)

  def update_screen_position(last_real_x, last_real_y)
    map = self.map
    return vermeil_lead_native_camera_update(last_real_x, last_real_y) unless map
    if map.scrolling?
      # Devolver el control al scroll de eventos sin dejar un offset residual.
      previous_x = @_vermeil_lead_x || 0.0
      previous_y = @_vermeil_lead_y || 0.0
      map.display_x -= previous_x if previous_x != 0
      map.display_y -= previous_y if previous_y != 0
      @_vermeil_lead_x = @_vermeil_lead_y = 0.0
      return vermeil_lead_native_camera_update(last_real_x, last_real_y)
    end

    # Extraer exclusivamente el desplazamiento aplicado por ESTE plugin en
    # el frame anterior antes de actualizar Fancy Camera / Carnek Settings.
    # Esto evita que ambas camaras luchen por la posicion del mapa.
    map_id = map.map_id
    if @_vermeil_lead_map_id != map_id
      @_vermeil_lead_map_id = map_id
      @_vermeil_lead_x = @_vermeil_lead_y = 0.0
      @_vermeil_lead_updated_at = nil
    end
    old_x = @_vermeil_lead_x || 0.0
    old_y = @_vermeil_lead_y || 0.0
    map.display_x = map.display_x - old_x if old_x != 0
    map.display_y = map.display_y - old_y if old_y != 0

    vermeil_lead_native_camera_update(last_real_x, last_real_y)
    base_x = map.display_x
    base_y = map.display_y

    allowed = !$game_temp.in_battle && !$game_temp.in_menu &&
      !$game_temp.message_window_showing && !pbMapInterpreterRunning?
    allowed = false if $game_temp.camera_target_event &&
      $game_temp.camera_target_event != 0
    allowed = false if $game_temp.camera_shake && $game_temp.camera_shake > 0
    allowed = false if $game_temp.camera_pos &&
      ($game_temp.camera_pos[0] != 0 || $game_temp.camera_pos[1] != 0)
    allowed = false if $game_temp.camera_offset &&
      $game_temp.camera_offset != [0, 0]
    allowed = false if on_stair? || on_spiral?
    pixels = allowed ? VermeilMovement.camera_lookahead : 0

    now = System.respond_to?(:unscaled_uptime) ? System.unscaled_uptime : System.uptime
    dt = @_vermeil_lead_updated_at ? now - @_vermeil_lead_updated_at : 0.0
    @_vermeil_lead_updated_at = now
    dt = 0.0 if dt < 0 || dt > 0.3
    dt = [dt, 0.05].min
    # Evita desplazar la camara al pulsar contra una pared sin caminar.
    # No filtra ni retrasa el input real del jugador.
    dir = (pixels > 0 && @move_timer) ? vermeil_live_direction : 0
    dx = [1, 4, 7].include?(dir) ? -1 : ([3, 6, 9].include?(dir) ? 1 : 0)
    dy = [1, 2, 3].include?(dir) ? 1 : ([7, 8, 9].include?(dir) ? -1 : 0)
    scale = (dx != 0 && dy != 0) ? (1.0 / Math.sqrt(2)) : 1.0
    goal_x = dx * pixels * Game_Map::X_SUBPIXELS * scale
    goal_y = dy * pixels * Game_Map::Y_SUBPIXELS * scale

    # Tiempo REAL: el Turbo no acelera ni salta la transicion visual.
    alpha = 1.0 - Math.exp(-dt / VermeilMovement.camera_lead_response)
    desired_x = old_x + (goal_x - old_x) * alpha
    desired_y = old_y + (goal_y - old_y) * alpha

    map.display_x = base_x + desired_x if desired_x != 0
    map.display_y = base_y + desired_y if desired_y != 0
    # Registrar offset REAL para respetar la pasabilidad de bordes/snap_edges.
    @_vermeil_lead_x = map.display_x - base_x
    @_vermeil_lead_y = map.display_y - base_y
  end
end
