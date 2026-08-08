#===============================================================================
# [VERMEIL] Visual 2.5D - 014_SideLadders.rb
# Escaleras laterales activadas por terrain tag. Funciona con 2.5D apagado o
# encendido. Maker Studio define orientacion por celda. Usa paso diagonal real,
# no interpolacion visual de evento.
#===============================================================================
module Mode7
  module SideLadders
    FILE_PATH = File.join("Plugins", "[VERMEIL] Visual 2.5D", "side_ladders.json")

    @mtime = :unloaded
    @maps = {}

    class << self
      def refresh
        mtime = File.exist?(FILE_PATH) ? File.mtime(FILE_PATH) : nil
        return if @mtime == mtime
        @mtime = mtime
        data = JSON.parse(File.read(FILE_PATH))
        @maps = data.is_a?(Hash) && data["maps"].is_a?(Hash) ? data["maps"] : {}
      rescue Exception
        # ponytail: metadata opcional; default conserva pendientes ya pintadas.
        @maps = {}
      end

      def slope_at(map_id, x, y)
        refresh
        cells = @maps[map_id.to_s]
        return nil if !cells.is_a?(Hash)
        slope = cells["#{x},#{y}"].to_i
        return slope if slope == -1 || slope == 1
        nil
      end
    end

    def self.side_ladder_tag?(tag)
      return false if !tag || !tag.respond_to?(:id)
      Config::SIDE_LADDER_TERRAIN_TAG_SLOPE_Y.key?(tag.id)
    end

    def self.diagonal_for(character, direction)
      return nil if !character || (direction != 4 && direction != 6)
      tag = character.pbTerrainTag
      return nil if !side_ladder_tag?(tag)
      slope_y = slope_at($game_map.map_id, character.x, character.y)
      slope_y ||= Config::SIDE_LADDER_TERRAIN_TAG_SLOPE_Y[tag.id]
      x_offset = direction == 6 ? 1 : -1
      y_offset = direction == 6 ? slope_y.to_i : -slope_y.to_i
      target_x = character.x + x_offset
      target_y = character.y + y_offset
      return nil if !$game_map.valid?(target_x, target_y)

      # ponytail: una pendiente solo conecta celdas que pertenecen al mismo
      # carril. Sin esta comprobacion el ultimo paso podia salir en diagonal y
      # el siguiente input normal recolocaba al jugador en otra celda.
      target_tag = $game_map.terrain_tag(target_x, target_y)
      return nil if !side_ladder_tag?(target_tag)
      target_slope = slope_at($game_map.map_id, target_x, target_y)
      target_slope ||= Config::SIDE_LADDER_TERRAIN_TAG_SLOPE_Y[target_tag.id]
      return nil if target_slope.to_i != slope_y.to_i

      diagonal = if x_offset > 0
                   y_offset < 0 ? 9 : 3
                 else
                   y_offset < 0 ? 7 : 1
                 end
      [x_offset, y_offset, diagonal]
    end
  end
end

class Game_Player
  alias_method :_VERMEIL_25D_side_ladders_move_generic, :move_generic unless method_defined?(:_VERMEIL_25D_side_ladders_move_generic)

  def move_generic(direction, turn_enabled = true)
    diagonal = nil
    if !on_stair? && !on_spiral? && !@through && $game_map
      diagonal = Mode7::SideLadders.diagonal_for(self, direction)
    end
    return _VERMEIL_25D_side_ladders_move_generic(direction, turn_enabled) if !diagonal
    return if $game_temp.encounter_triggered

    turn_generic(direction, true) if turn_enabled
    if !can_move_in_direction?(diagonal[2])
      bump_into_object
      $game_temp.encounter_triggered = false
      return
    end

    # ponytail: un tag solo expresa pendiente recta de 1x1. Curvas o rampas
    # largas necesitan metadata por celda en Maker Studio.
    @move_initial_x = @x
    @move_initial_y = @y
    @x += diagonal[0]
    @y += diagonal[1]
    @move_timer = 0.0
    add_move_distance_to_stats(1)
    increase_steps
    $game_temp.encounter_triggered = false
  end
end
