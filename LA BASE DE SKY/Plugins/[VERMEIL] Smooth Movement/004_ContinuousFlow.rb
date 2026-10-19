# Vermeil Movement Studio - Continuous Flow v0.4
# Encadena pasos del jugador sin un frame muerto, conservando el orden ORIGINAL:
# mover -> on_step_taken -> encuentros/eventos -> siguiente paso.
# Jamas ejecuta update_move por segunda vez ni invoca triggers extras.
class Game_Player
  alias vermeil_flow_native_update_move update_move unless method_defined?(:vermeil_flow_native_update_move)
  alias vermeil_flow_native_update update unless method_defined?(:vermeil_flow_native_update)

  def update_move
    previous_timer = @move_timer
    previous_duration = @move_time
    vermeil_flow_native_update_move
    return if !previous_timer || @move_timer || jumping?
    return unless @stopped_this_frame && @moved_this_frame
    return unless previous_duration && previous_duration > 0
    # El reloj del juego ya incluye Turbo. Conservar solamente la fraccion
    # sobrante del ultimo paso, NO una segunda actualizacion ni otro step.
    carry = previous_timer.to_f + @delta_t.to_f - previous_duration.to_f
    @_vermeil_flow_finished_step = {
      :map_id => self.map_id, :x => @x, :y => @y,
      :carry => [[carry, 0.0].max, 0.05].min
    }
  end

  def update
    @_vermeil_flow_finished_step = nil
    vermeil_flow_native_update
    finished = @_vermeil_flow_finished_step
    @_vermeil_flow_finished_step = nil
    return unless finished && VermeilMovement.flow?
    return unless vermeil_flow_safe_to_continue?(finished)

    direction = vermeil_live_direction
    return unless [1, 2, 3, 4, 6, 7, 8, 9].include?(direction)

    # REUTILIZAR Game_Player#update_command_new -> move_generic para que
    # pasabilidad, eventos al chocar y estadísticas conserven su lógica.
    # Leer la tecla actual, sin input buffer ni direcciones antiguas.
    update_command_new
    return if !@move_timer || @move_timer > 0
    return if @x == finished[:x] && @y == finished[:y]

    # Consumir tiempo sobrante para enlazar visualmente los tiles.
    # No completar un segundo tile en este mismo tick ni saltarse un evento.
    duration = @move_time.to_f
    duration *= Math.sqrt(2) if @_vermeil_diagonal_active
    return unless duration > 0
    fraction = [finished[:carry] / duration, 0.80].min
    return unless fraction > 0
    @move_timer = duration * fraction
    @real_x = (@move_initial_x + (@x - @move_initial_x) * fraction) * Game_Map::REAL_RES_X
    @real_y = (@move_initial_y + (@y - @move_initial_y) * fraction) * Game_Map::REAL_RES_Y
  end

  def vermeil_flow_safe_to_continue?(finished)
    return false unless $game_map && self.map_id == finished[:map_id]
    return false unless @x == finished[:x] && @y == finished[:y]
    return false if @move_timer || jumping? || @bumping || @through
    return false if @starting || lock? || @move_route_forcing || @wait_count.to_f > 0
    return false if $game_temp.in_battle || $game_temp.in_menu ||
                    $game_temp.in_mini_update || $game_temp.message_window_showing
    return false if $game_temp.encounter_triggered || pbMapInterpreterRunning?
    return false if $PokemonGlobal.forced_movement? || $PokemonGlobal.ice_sliding ||
                    $PokemonGlobal.ascending_waterfall || $PokemonGlobal.descending_waterfall
    # Restriccion inicial a pie: no intervenir en acciones especiales.
    return false if $PokemonGlobal.surfing || $PokemonGlobal.diving || $PokemonGlobal.bicycle
    return false if on_stair? || on_spiral? || $game_map.check_stair_zones(@x, @y)
    terrain = pbTerrainTag
    return false if terrain && (terrain.ice || terrain.ledge)
    # Si se ha iniciado un evento de contacto o un entrenador, no iniciar
    # el siguiente paso mientras el intérprete aún no está ejecutándolo.
    return false if $game_map.events.values.any? { |event| event.starting }
    # Durante una transición que haya quedado pendiente, nunca encadenar.
    return false if respond_to?(:turbo_deferred_touch) && turbo_deferred_touch
    return true
  end
end
