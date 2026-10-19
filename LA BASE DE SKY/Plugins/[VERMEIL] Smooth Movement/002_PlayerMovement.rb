# Vermeil Smooth Movement - compatibilidad con pasos, eventos, followers y escaleras.
# Solo el jugador acepta input diagonal; los eventos usan su movimiento nativo.
class Game_Player < Game_Character
  alias vermeil_movement_original_input update_command_new unless method_defined?(:vermeil_movement_original_input)

  def update_command_new
    return vermeil_movement_original_input if $PokemonGlobal.forced_movement?
    return vermeil_movement_original_input if @move_route_forcing
    return vermeil_movement_original_input if pbMapInterpreterRunning? ||
      $game_temp.message_window_showing || $game_temp.in_mini_update || $game_temp.in_menu

    direction = (VermeilMovement.directions == 8) ? Input.dir8 : Input.dir4(@moved_last_frame)
    if [1, 3, 7, 9].include?(direction)
      return vermeil_movement_original_input unless vermeil_diagonal_eligible?
      vermeil_move_diagonal(direction)
      return
    end

    # En el modo original, el primer toque tras un giro solo cambia el facing;
    # este ajuste elimina esa espera sin tocar la logica de Game_Player#move_generic.
    if VermeilMovement.enabled?("instant_turn") && [2, 4, 6, 8].include?(direction)
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
    # Distancia equivalente euclidea, evitando que la diagonal sea mas rapida.
    @move_time = (@move_time || 0.25) * Math.sqrt(2)
    add_move_distance_to_stats(2)
    increase_steps
  end

  alias vermeil_movement_move_end update_move unless method_defined?(:vermeil_movement_move_end)
  def update_move
    diagonal_step = (@move_initial_x && @move_initial_y &&
      @x != @move_initial_x && @y != @move_initial_y && moving?)
    vermeil_movement_move_end
    if diagonal_step && !moving?
      # Restaurar duracion de casilla, normalmente reestablecida por set_movement_type.
      self.move_speed = @move_speed
    end
  end
end
