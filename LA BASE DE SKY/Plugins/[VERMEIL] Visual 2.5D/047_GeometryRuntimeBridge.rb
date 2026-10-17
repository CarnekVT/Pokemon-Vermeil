#===============================================================================
# [VERMEIL] Visual 2.5D - Geometry Studio 4.2 gameplay bridge (v5.19 preview)
# Sidecar physics is independent of visibility/model-face streaming.
#===============================================================================
module Mode7
  class << self
    def register_geometry_collision_source(geometry, map_id)
      @v25_collision_geometry_id = map_id.to_i
      @v25_collision_geometry = geometry
    end
    def geometry_collision_source
      return nil if !$game_map || @v25_collision_geometry_id != $game_map.map_id.to_i
      @v25_collision_geometry
    end
  end

  module ModelPhysicsWorld
    class << self
      # Maker Studio 4.2: x,y,collision_code,base,height,model,instance,part
      def build_index_compact(rows)
        out = {}
        Array(rows).each do |row|
          next if !row.is_a?(Array) || row.size < 5
          code = row[2].to_i
          next if code == 3
          mode = { 0 => :solid, 1 => :climb, 2 => :one_way }[code] || :solid
          x, y = row[0].to_i, row[1].to_i
          next if x < 0 || y < 0
          (out[[x, y]] ||= []) << [mode, [row[4].to_f, 0.0].max]
        end
        out
      end
      def build_index(rows)
        return {} if !rows.is_a?(Array)
        codes = { "solid" => 0, "climb" => 1, "one-way" => 2, "none" => 3 }
        build_index_compact(rows.filter_map do |r|
          next if !r.is_a?(Hash)
          [r["x"] || r[:x], r["y"] || r[:y],
           codes[(r["collision"] || r[:collision] || "solid").to_s] || 0,
           r["base"] || r[:base], r["height"] || r[:height]]
        end)
      end
      def activate(map_id, cells)
        @active_map_id = map_id.to_i
        @active_cells = cells.is_a?(Hash) ? cells : {}
      end
      def invalidate(map_id = nil)
        @worlds ||= {}
        if map_id.nil?
          @worlds.clear
          @active_cells = {}
          @active_map_id = nil
        else
          @worlds.delete(map_id.to_i)
          if @active_map_id == map_id.to_i
            @active_cells = {}
            @active_map_id = nil
          end
        end
      end
      def blocked_cell?(x, y, direction, from_x = nil, from_y = nil)
        return false if !$game_map || @active_map_id != $game_map.map_id.to_i
        cells = @active_cells && @active_cells[[x.to_i, y.to_i]]
        return false if !cells
        cells.any? do |mode, height|
          case mode
          when :solid
            true
          when :one_way
            direction.to_i == 2 && !from_y.nil? && from_y.to_i == y.to_i - 1
          when :climb
            from_south = direction.to_i == 8 && !from_y.nil? && from_y.to_i == y.to_i + 1
            !from_south || height > Mode7::Config::NDS_OBJECT_CLIMB_MAX_TILES.to_f + 0.001
          else
            false
          end
        end
      end
      def refresh_surface_fallback(_map_id, _geo); end
    end
  end
end

# Collision sidecars are read at map setup, before any visual models stream.
class Game_Map
  unless method_defined?(:_VERMEIL_V2519_game_map_setup)
    alias_method :_VERMEIL_V2519_game_map_setup, :setup
    def setup(map_id)
      ret = _VERMEIL_V2519_game_map_setup(map_id)
      if Mode7::Config::SURFACE_GEOMETRY_ENABLED &&
         Mode7::Config::SURFACE_GEOMETRY_RUNTIME_FILES &&
         Mode7::Config::NDS_GEOMETRY_OBJECTS_ENABLED
        Mode7::ModelPhysicsWorld.preload(map_id)
      else
        Mode7::ModelPhysicsWorld.activate(map_id, {})
      end
      ret
    end
  end
end

class Mode7Renderer
  private
  def nds_close_model_stream
    io = @nds_model_stream_io
    io.close if io && !io.closed?
    @nds_model_stream_io = nil
    @nds_model_stream_materials = nil
    @nds_model_stream_done = true
  rescue IOError
    @nds_model_stream_io = nil
    @nds_model_stream_done = true
  end

  public
  unless method_defined?(:_VERMEIL_V2519_renderer_update)
    alias_method :_VERMEIL_V2519_renderer_update, :update
    def update(*args, &block)
      result = _VERMEIL_V2519_renderer_update(*args, &block)
      if Mode7::Config::SURFACE_GEOMETRY_ENABLED &&
         Mode7::Config::SURFACE_GEOMETRY_RUNTIME_FILES &&
         Mode7::Config::NDS_GEOMETRY_OBJECTS_ENABLED &&
         !disposed?
        nds_model_stream_step
      end
      result
    end
  end

  unless method_defined?(:_VERMEIL_V2519_renderer_dispose)
    alias_method :_VERMEIL_V2519_renderer_dispose, :dispose
    def dispose(*args, &block)
      nds_close_model_stream
      _VERMEIL_V2519_renderer_dispose(*args, &block)
    end
  end
end
