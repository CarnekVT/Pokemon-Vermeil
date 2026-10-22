# Vermeil Smooth Movement - compatibilidad con pasos, eventos, followers y escaleras.
# Solo el jugador acepta input diagonal; los eventos usan su movimiento nativo.
class Game_Player < Game_Character
  alias vermeil_movement_original_input update_command_new unless method_defined?(:vermeil_movement_original_input)

  def update_command_new
    return vermeil_movement_original_input if $PokemonGlobal.forced_movement?
    return vermeil_movement_original_input if @move_route_forcing
    return vermeil_movement_original_input if pbMapInterpreterRunning? ||
      $game_temp.message_window_showing || $game_temp.in_mini_update || $game_temp.in_menu
    # Clásico es una excepcion deliberada: el motor original maneja
    # absolutamente todo el input, incluidas las cuatro direcciones.
    return vermeil_movement_original_input unless VermeilMovement.enabled?("instant_turn")

    # El control moderno siempre lee el estado ACTUAL; nunca ejecuta
    # teclas almacenadas o pulsaciones que el jugador ya haya soltado.
    direction = vermeil_live_direction
    if [1, 3, 7, 9].include?(direction)
      return vermeil_movement_original_input unless vermeil_diagonal_eligible?
      vermeil_move_diagonal(direction)
      return
    end

    # En el modo original, el primer toque tras un giro solo cambia el facing;
    # este ajuste elimina esa espera sin tocar la logica de Game_Player#move_generic.
    # Retraso clásico = implementación ORIGINAL de Essentials, sin pausas extras.
    # Inmediato = comienza el paso directamente al pulsar o cambiar dirección.
    return vermeil_movement_original_input unless VermeilMovement.enabled?("instant_turn")
    if [2, 4, 6, 8].include?(direction)
      case direction
      when 2 then move_down
      when 4 then move_left
      when 6 then move_right
      when 8 then move_up
      end
      @last_input_time = nil
      return
    end
    vermeil_movement_original_input
  end

  def vermeil_live_direction
    # Consultar los cuatro botones del frame ACTUAL directamente. Input.dir8
    # de algunas implementaciones prioriza un eje o alterna al sumar teclas.
    # No se guarda ningun input para los fotogramas siguientes.
    if VermeilMovement.directions == 8
      if Input.respond_to?(:press?) && [:UP, :DOWN, :LEFT, :RIGHT].all? { |key| Input.const_defined?(key) }
        up    = Input.press?(Input::UP)
        down  = Input.press?(Input::DOWN)
        left  = Input.press?(Input::LEFT)
        right = Input.press?(Input::RIGHT)
        x = (right ? 1 : 0) - (left ? 1 : 0)
        y = (down ? 1 : 0) - (up ? 1 : 0)
        # El teclado numerico codifica las ocho direcciones. Sin Hash ni
        # Array temporales por frame, a diferencia de una tabla de mapeo.
        return 5 + x - (3 * y) if x != 0 || y != 0
        # Si dos teclas opuestas se cancelan, no generar un paso fantasma.
        return 0 if up || down || left || right
      end
      return Input.dir8 if Input.respond_to?(:dir8)
    end
    Input.dir4(@moved_last_frame)
  end

  # El sprite debe corresponder al DESPLAZAMIENTO que se esta dibujando,
  # no a una nueva tecla pulsada durante el tile previo. Por ejemplo:
  # arriba -> abajo durante una casilla ascendente NO debe cambiar la fila
  # grafica hasta empezar realmente el paso descendente.
  #
  # En un tile diagonal se puede alternar entre las dos orientaciones
  # cardinales de esa diagonal sin contradecir su trayectoria.
  def vermeil_facing_matches_active_step?(dir)
    return false unless @move_initial_x && @move_initial_y
    dx = @x - @move_initial_x
    dy = @y - @move_initial_y
    # En un paso cardinal la orientacion queda fijada hasta terminarlo.
    return false if dx == 0 || dy == 0
    (dx > 0 && dir == 6) || (dx < 0 && dir == 4) ||
      (dy > 0 && dir == 2) || (dy < 0 && dir == 8)
  end

  # Solo ajusta la fila grafica EN la misma trayectoria diagonal.
  # No introduce un retardo al input: Game_Player#update_command_new
  # sigue usando inmediatamente la tecla actual al arrancar el proximo tile.
  def vermeil_update_live_facing
    return unless VermeilMovement.directions == 8 &&
                  VermeilMovement.enabled?("diagonal_live_turn") && moving?
    dir = vermeil_live_direction
    turn_dir = case dir
               when 1, 3, 7, 9
                 horiz = (dir == 1 || dir == 7) ? 4 : 6
                 vert = (dir == 1 || dir == 3) ? 2 : 8
                 vermeil_diagonal_facing_direction(horiz, vert)
               when 2, 4, 6, 8 then dir
               else nil
               end
    return unless turn_dir && @direction != turn_dir
    # La proteccion de coherencia va ANTES de cambiar sprites, evitando
    # cambiar a una animacion inversa en mitad del tile anterior.
    return unless vermeil_facing_matches_active_step?(turn_dir)
    return if @direction_fix || @through || @move_route_forcing || jumping?
    return if pbMapInterpreterRunning? || $game_temp.in_battle || $game_temp.in_menu ||
              $game_temp.message_window_showing || $game_temp.in_mini_update
    return if $PokemonGlobal.forced_movement? || $PokemonGlobal.ice_sliding ||
              $PokemonGlobal.ascending_waterfall || $PokemonGlobal.descending_waterfall ||
              $PokemonGlobal.surfing || $PokemonGlobal.diving || $PokemonGlobal.bicycle
    return if on_stair? || on_spiral? || $game_map.check_stair_zones(@x, @y)
    @direction = turn_dir
  end

  def vermeil_diagonal_eligible?
    return false if moving? || jumping? || @direction_fix || @through
    return false if on_stair? || on_spiral?
    return false if $PokemonGlobal.bicycle || $PokemonGlobal.surfing || $PokemonGlobal.diving
    return false if $PokemonGlobal.ice_sliding || $PokemonGlobal.ascending_waterfall ||
                    $PokemonGlobal.descending_waterfall
    return false if @last_terrain_tag && (@last_terrain_tag.ice || @last_terrain_tag.ledge)
    return false if @width != 1 || @height != 1
    return false if $game_map.check_stair_zones(@x, @y)
    true
  end

  # Sólo controla la representación gráfica en sprites de cuatro filas.
  # Nunca cambia el eje real de movimiento ni la dirección pulsada.
  def vermeil_diagonal_facing_direction(horiz, vert)
    case VermeilMovement.diagonal_facing
    when "horizontal" then horiz
    when "vertical" then vert
    else
      (@direction == horiz || @direction == vert) ? @direction : vert
    end
  end

  def vermeil_slide_axes(horiz, vert)
    case VermeilMovement.wall_slide_priority
    when "vertical" then [vert, horiz]
    when "facing"
      return [vert, horiz] if @direction == vert
      [horiz, vert]
    else
      [horiz, vert]
    end
  end

  def vermeil_move_diagonal(dir)
    horiz = (dir == 1 || dir == 7) ? 4 : 6
    vert  = (dir == 1 || dir == 3) ? 2 : 8
    dx = horiz == 4 ? -1 : 1
    dy = vert == 8 ? -1 : 1

    # Verificar ambos caminos ortogonales evita cortar esquinas bloqueadas.
    # Se conserva el sistema de terreno, eventos y pasabilidad de la Base de Sky.
    x_first = can_move_in_direction?(horiz) &&
              can_move_from_coordinate?(@x + dx, @y, vert)
    y_first = can_move_in_direction?(vert) &&
              can_move_from_coordinate?(@x, @y + dy, horiz)
    if !x_first || !y_first
      if VermeilMovement.enabled?("wall_slide")
        # Prioridad configurable: no guarda teclas ni altera los tiempos.
        # Se usa el movimiento cardinal nativo para respetar las colisiones.
        primary, secondary = vermeil_slide_axes(horiz, vert)
        return move_generic(primary) if can_move_in_direction?(primary)
        return move_generic(secondary) if can_move_in_direction?(secondary)
      end
      return
    end

    # No cruzar diagonales con zonas de escalera.
    return if $game_map.check_stair_zones(@x + dx, @y + dy)
    # Facing cardinal para sprites tradicionales de cuatro filas.
    turn_generic(vermeil_diagonal_facing_direction(horiz, vert), true)
    @move_initial_x = @x
    @move_initial_y = @y
    @x += dx
    @y += dy
    @move_timer = 0.0
    @_vermeil_diagonal_active = true
    add_move_distance_to_stats(2)
    increase_steps
  end

  alias vermeil_movement_original_movement_type set_movement_type unless method_defined?(:vermeil_movement_original_movement_type)
  def set_movement_type(type)
    vermeil_movement_original_movement_type(type)
    # Conservar velocidad fisica equivalente en una diagonal (distancia sqrt(2)).
    @move_time *= Math.sqrt(2) if @_vermeil_diagonal_active && VermeilMovement.diagonal_speed == "uniform"
  end

  alias vermeil_movement_move_end update_move unless method_defined?(:vermeil_movement_move_end)
  def update_move
    vermeil_update_live_facing if VermeilMovement.enabled?("instant_turn")
    diagonal_step = @_vermeil_diagonal_active
    vermeil_movement_move_end
    # Nunca imponer smoothstep a @real_x/@real_y por casilla: introduce
    # frenazo en cada limite y empeora el movimiento al caminar seguido.
    if diagonal_step && !moving?
      @_vermeil_diagonal_active = false
      self.move_speed = @move_speed
    end
  end

end
