# Vermeil Smooth Movement - compatibilidad con pasos, eventos, followers y escaleras.
# Solo el jugador acepta input diagonal; los eventos usan su movimiento nativo.
class Game_Player < Game_Character
  alias vermeil_movement_original_input update_command_new unless method_defined?(:vermeil_movement_original_input)

  def update_command_new
    return vermeil_movement_original_input if $PokemonGlobal.forced_movement?
    return vermeil_movement_original_input if @move_route_forcing
    return vermeil_movement_original_input if pbMapInterpreterRunning? ||
      $game_temp.message_window_showing || $game_temp.in_mini_update || $game_temp.in_menu

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
    return Input.dir8 if VermeilMovement.directions == 8 && Input.respond_to?(:dir8)
    Input.dir4(@moved_last_frame)
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
        if can_move_in_direction?(horiz)
          return move_generic(horiz)
        elsif can_move_in_direction?(vert)
          return move_generic(vert)
        end
      end
      return
    end

    # No cruzar diagonales con zonas de escalera.
    return if $game_map.check_stair_zones(@x + dx, @y + dy)
    # Facing cardinal para sprites tradicionales de cuatro filas.
    turn_generic((@direction == horiz || @direction == vert) ? @direction : vert, true)
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
    @move_time *= Math.sqrt(2) if @_vermeil_diagonal_active
  end

  alias vermeil_movement_move_end update_move unless method_defined?(:vermeil_movement_move_end)
  def update_move
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
