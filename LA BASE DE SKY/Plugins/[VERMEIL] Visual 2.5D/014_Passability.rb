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
      return false if !rendering_now?
      renderer = $scene.instance_variable_get(:@map_renderer)
      return false if !renderer.is_a?(Mode7Renderer)
      renderer.wall_cell_at?(x, y)
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
        if Mode7.wall_cell_at?(x, y)
          return false if !self_event || !self_event.through
        end
        __VERMEIL_25D_orig_passable(x, y, dir, self_event)
      end

      alias_method :__VERMEIL_25D_orig_passableStrict, :passableStrict? unless method_defined?(:__VERMEIL_25D_orig_passableStrict)
      def passableStrict?(x, y, dir, self_event = nil)
        return false if Mode7.wall_cell_at?(x, y)
        __VERMEIL_25D_orig_passableStrict(x, y, dir, self_event)
      end

      alias_method :__VERMEIL_25D_orig_playerPassable, :playerPassable? unless method_defined?(:__VERMEIL_25D_orig_playerPassable)
      def playerPassable?(x, y, dir, self_event = nil)
        return false if Mode7.wall_cell_at?(x, y)
        __VERMEIL_25D_orig_playerPassable(x, y, dir, self_event)
      end
    end
  end
end
Passability_2p5D.patch!