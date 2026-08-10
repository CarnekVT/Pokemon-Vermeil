#===============================================================================
# [VERMEIL] Visual 2.5D - 014_Passability.rb
# Pasabilidad mecanica acorde a la elevacion visual: las celdas con un muro
# extruido (columna 2.5D) dejan de ser transitables para jugador y eventos,
# igual que H-Mode7 bloquea sus muros verticales. Asi lo que se VE (elevado)
# coincide con lo que se PUEDE pisar (nada).
#===============================================================================

module Mode7
  class << self
    # true si el renderer 2.5D activo marca la celda (x,y) como muro bloqueante.
    # Devuelve false si el modo no esta activo, el renderer no es el nuestro o
    # aun no ha construido su cache (evita volcar pasabilidad a mitad de carga).
    def wall_cell_at?(x, y)
      return false if !Config::WALL_BLOCKS_MOVEMENT
      if indoor_map? && defined?(Config::INDOOR_WALL_BLOCKS_MOVEMENT) &&
         !Config::INDOOR_WALL_BLOCKS_MOVEMENT
        return false
      end
      return false if !rendering_now?
      renderer = $scene.instance_variable_get(:@map_renderer)
      return false if !renderer.is_a?(Mode7Renderer)
      renderer.wall_cell_at?(x, y)
    end

    # Maker Studio coloca las ladders de Map077 en capa extendida y prioridad
    # 1. Su collision vanilla solo devuelve paso automaticamente con P0, luego
    # cae a Mountains (0x0F) debajo y la escalera queda bloqueada. Aqui la
    # ladder superior conserva sus bits de paso, pero no hereda ese bloqueo.
    def upper_ladder_passability(map, x, y, dir)
      return nil if !defined?(MakerStudio) || !MakerStudio.respond_to?(:each_extended_tile_at)
      return nil if !$game_map || map != $game_map
      bit = (1 << ((dir.to_i / 2) - 1)) & 0x0F
      result = nil

      # Las capas extendidas siempre estan encima de las nativas.
      MakerStudio.each_extended_tile_at(x, y) do |tile_id, tile_data|
        resolved = ladder_tile_passability(map, tile_id, tile_data, bit)
        return nil if resolved == :solid_surface
        result = resolved if resolved == true || resolved == false
      end
      return result unless result.nil?

      # Ladder puede vivir tambien sobre una capa nativa de Mountain. Maker
      # revisa P1 y despues cae al P0 bloqueante; aqui se resuelve antes.
      rpg_map = map.instance_variable_get(:@map)
      return nil if !rpg_map || !rpg_map.data
      ext_data = MakerStudio.get_extended_data_for(map.map_id)
      native_props = ext_data ? ext_data["nativeProperties"] : nil
      key = "#{x},#{y}"
      [2, 1, 0].each do |layer|
        tile_id = rpg_map.data[x, y, layer]
        return nil if tile_id.nil?
        tile_data = native_props ? (native_props[layer] || {})[key] : nil
        next if tile_id == 0 && !(tile_data && tile_data["autotile_name"])
        resolved = ladder_tile_passability(map, tile_id, tile_data, bit)
        return nil if resolved == :solid_surface
        return resolved if resolved == true || resolved == false
      end
      nil
    rescue Exception
      nil
    end

    def ladder_tile_passability(map, tile_id, tile_data, bit)
      ts_id = tile_data && tile_data["tileset_id"]
      tileset = ts_id ? $data_tilesets[ts_id.to_i] : nil
      terrain_id = if tile_data && tile_data.key?("terrain_tag")
                     tile_data["terrain_tag"].to_i
                   elsif tileset
                     tileset.terrain_tags[tile_id] || 0
                   else
                     map.terrain_tags[tile_id] || 0
                   end
      terrain = GameData::TerrainTag.try_get(terrain_id)
      priority = if tile_data && tile_data.key?("priority")
                   tile_data["priority"].to_i
                 elsif tileset
                   tileset.priorities[tile_id] || 0
                 else
                   map.priorities[tile_id] || 0
                 end
      ladder = terrain && [:Ladders, :LaddersSide].include?(terrain.id)
      # P0 encima de la escalera es suelo real. No atravesar decoracion P0.
      return :solid_surface if priority == 0 && !ladder
      return nil unless ladder
      # ponytail: usa passage nativo; rutas especiales solo si Maker expone API.
      passage = if tile_data && tile_data.key?("passage")
                  tile_data["passage"].to_i
                elsif tileset
                  tileset.passages[tile_id] || 0
                else
                  map.passages[tile_id] || 0
                end
      (passage & bit == 0 && passage & 0x0F != 0x0F)
    end
  end
end

# Patch sobre las tres pasabilidades. Coexiste con los aliases de Maker Studio
# (que cargan antes por orden alfabetico): nuestro alias envuelve el metodo YA
# definido (por tanto, la cadena de MS + vanilla). Cero prepend, solo alias.
module Passability_2p5D
  def self.patch!
    # Se llama como Game_Map#passable? (jugador y eventos). El jugador delega
    # en playerPassable? voury (via MS); ambas enganchan aqui.
    Game_Map.class_eval do
      alias_method :__VERMEIL_25D_orig_passable, :passable? unless method_defined?(:__VERMEIL_25D_orig_passable)
      def passable?(x, y, dir, self_event = nil)
        ladder = Mode7.upper_ladder_passability(self, x, y, dir)
        return ladder unless ladder.nil?
        if Mode7.wall_cell_at?(x, y)
          return false if !self_event || !self_event.through
        end
        __VERMEIL_25D_orig_passable(x, y, dir, self_event)
      end

      alias_method :__VERMEIL_25D_orig_passableStrict, :passableStrict? unless method_defined?(:__VERMEIL_25D_orig_passableStrict)
      def passableStrict?(x, y, dir, self_event = nil)
        ladder = Mode7.upper_ladder_passability(self, x, y, dir)
        return ladder unless ladder.nil?
        return false if Mode7.wall_cell_at?(x, y)
        __VERMEIL_25D_orig_passableStrict(x, y, dir, self_event)
      end

      alias_method :__VERMEIL_25D_orig_playerPassable, :playerPassable? unless method_defined?(:__VERMEIL_25D_orig_playerPassable)
      def playerPassable?(x, y, dir, self_event = nil)
        ladder = Mode7.upper_ladder_passability(self, x, y, dir)
        return ladder unless ladder.nil?
        return false if Mode7.wall_cell_at?(x, y)
        __VERMEIL_25D_orig_playerPassable(x, y, dir, self_event)
      end
    end
  end
end
Passability_2p5D.patch!

# Maker Studio redefine playerPassable? despues de cargar algunos plugins.
# Se envuelve su version FINAL al abrir cada mapa. Conserva los aliases previos
# y deja que Ladder P1 gane sobre Mountain P0, sin tocar Maker Studio.
module Passability_2p5D
  def self.patch_after_maker!
    return if Game_Map.method_defined?(:__VERMEIL_25D_after_maker_passable)
    Game_Map.class_eval do
      alias_method :__VERMEIL_25D_after_maker_passable, :passable?
      def passable?(x, y, dir, self_event = nil)
        ladder = Mode7.upper_ladder_passability(self, x, y, dir)
        return ladder unless ladder.nil?
        __VERMEIL_25D_after_maker_passable(x, y, dir, self_event)
      end

      alias_method :__VERMEIL_25D_after_maker_passableStrict, :passableStrict?
      def passableStrict?(x, y, dir, self_event = nil)
        ladder = Mode7.upper_ladder_passability(self, x, y, dir)
        return ladder unless ladder.nil?
        __VERMEIL_25D_after_maker_passableStrict(x, y, dir, self_event)
      end

      alias_method :__VERMEIL_25D_after_maker_playerPassable, :playerPassable?
      def playerPassable?(x, y, dir, self_event = nil)
        ladder = Mode7.upper_ladder_passability(self, x, y, dir)
        return ladder unless ladder.nil?
        __VERMEIL_25D_after_maker_playerPassable(x, y, dir, self_event)
      end
    end
  end
end

EventHandlers.add(:on_game_map_setup, :vermeil_2p5d_ladder_passability,
  proc { |_map_id, _map, _tileset| Passability_2p5D.patch_after_maker! }
)
