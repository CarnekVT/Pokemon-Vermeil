#===============================================================================
# [VERMEIL] Visual 2.5D - 014_Passability.rb
# V4.3.2 - Pasabilidad limpia del sistema NDS.
#
# El plugin ya NO altera Mountains, Ladders ni ningun Terrain Tag ajeno.
# Bloquea paredes explicitas y el cuerpo superior de estructuras/billboards.
# El borde inferior conserva la pasabilidad configurada en el tileset para no
# cerrar puertas, sombras ni puntos de entrada.
#===============================================================================
class Mode7Renderer
  def solid_cell_at?(x, y)
    return false if disposed? || !@walls_known
    tx = x.to_i
    ty = y.to_i
    return true if wall_cell_at?(tx, ty)
    entries = @entry_cache && @entry_cache[[tx, ty]]
    return false if !entries || entries.empty?

    rigid_ids = [
      Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG,
      Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG
    ]
    cell_ids = entries.filter_map do |entry|
      id = nds_category_id(entry)
      rigid_ids.include?(id) ? id : nil
    end
    return false if cell_ids.empty?

    below = @entry_cache[[tx, ty + 1]]
    return false if !below || below.empty?
    # ponytail: continuidad vertical basta; matriz manual solo si un asset
    # necesita huecos internos distintos de su pasabilidad del tileset.
    below.any? { |entry| cell_ids.include?(nds_category_id(entry)) }
  rescue Exception
    false
  end
end

module Mode7
  class << self
    def solid_cell_at?(x, y)
      return false if !Config::WALL_BLOCKS_MOVEMENT
      if indoor_map? && defined?(Config::INDOOR_WALL_BLOCKS_MOVEMENT) &&
         !Config::INDOOR_WALL_BLOCKS_MOVEMENT
        return false
      end
      return false if !rendering_now? || !$scene.is_a?(Scene_Map)
      renderer = $scene.instance_variable_get(:@map_renderer)
      return false if !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      renderer.solid_cell_at?(x, y)
    rescue Exception
      false
    end
  end
end

# Envuelve la pasabilidad final del mapa sin tocar mecanicas de otros tags.
module Passability_2p5D
  def self.patch_base!
    return if Game_Map.method_defined?(:_ZBOX_25D_orig_passable)
    Game_Map.class_eval do
      alias_method :_ZBOX_25D_orig_passable, :passable?
      def passable?(x, y, dir, self_event = nil)
        if Mode7.solid_cell_at?(x, y)
          return false if !self_event || !self_event.through
        end
        _ZBOX_25D_orig_passable(x, y, dir, self_event)
      end

      alias_method :_ZBOX_25D_orig_passable_strict, :passableStrict?
      def passableStrict?(x, y, dir, self_event = nil)
        return false if Mode7.solid_cell_at?(x, y)
        _ZBOX_25D_orig_passable_strict(x, y, dir, self_event)
      end

      alias_method :_ZBOX_25D_orig_player_passable, :playerPassable?
      def playerPassable?(x, y, dir, self_event = nil)
        return false if Mode7.solid_cell_at?(x, y)
        _ZBOX_25D_orig_player_passable(x, y, dir, self_event)
      end
    end
  end
end

Passability_2p5D.patch_base!
