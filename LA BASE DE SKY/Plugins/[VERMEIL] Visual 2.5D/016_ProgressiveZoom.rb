#===============================================================================
# [VERMEIL] Visual 2.5D - 016_ProgressiveZoom.rb
# Zoom espacial configurado desde el mod Visual 2.5D de Maker Studio.
#===============================================================================
require "json"

module Mode7
  module ProgressiveZoom
    FILE_PATH = File.join("Plugins", "[VERMEIL] Visual 2.5D",
                          "progressive_zoom.json")
    DIRECTIONS = {
      "left"  => [-1.0, 0.0],
      "right" => [1.0, 0.0],
      "up"    => [0.0, -1.0],
      "down"  => [0.0, 1.0]
    }.freeze

    @map_id = nil
    @profiles = []
    @zones = []

    class << self
      def setup(map_id)
        Mode7.zoom_effect_override = nil
        @map_id = map_id.to_i
        @profiles, @zones = load_map_data(@map_id)
      end

      def update
        if !$game_map || !$game_player || !Mode7.active_now?
          Mode7.zoom_effect_override = nil
          return
        end
        setup($game_map.map_id) if @map_id != $game_map.map_id

        real_x = $game_player.real_x.to_f / Game_Map::REAL_RES_X
        real_y = $game_player.real_y.to_f / Game_Map::REAL_RES_Y
        cell = "#{real_x.round},#{real_y.round}"
        # ponytail: pocos tramos/zonas por mapa; indexar por celda si crece.
        zone = zone_for_cell(cell)
        base = zone ? zone[:zoom] : Mode7.camera_zoom.to_f
        profile = @profiles.find { |candidate| candidate[:cells][cell] }
        if !profile
          Mode7.zoom_effect_override = zone ? base : nil
          return
        end

        axis = real_x * profile[:direction][0] + real_y * profile[:direction][1]
        if axis <= profile[:middle_axis]
          weight = (axis - profile[:start_axis]) /
                   (profile[:middle_axis] - profile[:start_axis])
          start_zoom = profile[:start_zoom]
          target_zoom = profile[:middle_zoom]
        else
          weight = (axis - profile[:middle_axis]) /
                   (profile[:end_axis] - profile[:middle_axis])
          start_zoom = profile[:middle_zoom]
          target_zoom = profile[:end_zoom]
        end
        weight = weight.clamp(0.0, 1.0)
        weight = weight * weight * (3.0 - 2.0 * weight)
        Mode7.zoom_effect_override = start_zoom + (target_zoom - start_zoom) * weight
      rescue Exception
        Mode7.zoom_effect_override = nil
      end

      private

      def load_map_data(map_id)
        data = JSON.parse(File.read(FILE_PATH))
        maps = data.is_a?(Hash) ? data["maps"] : nil
        map = maps.is_a?(Hash) ? maps[map_id.to_s] : nil
        return [[], []] if !map.is_a?(Hash)
        zones = map["zones"]
        normalized_zones = zones.is_a?(Hash) ?
                           zones.filter_map { |_id, zone| normalize_zone(zone) } : []
        @zones = normalized_zones
        profiles = map["profiles"]
        normalized_profiles = profiles.is_a?(Hash) ?
                              profiles.filter_map { |_id, profile| normalize_profile(profile) } : []
        [normalized_profiles, normalized_zones]
      rescue Exception
        [[], []]
      end

      def normalize_profile(profile)
        return nil if !profile.is_a?(Hash)
        direction = DIRECTIONS[profile["direction"].to_s]
        start = normalize_point(profile["start"])
        middle = normalize_point(profile["middle"])
        finish = normalize_point(profile["end"])
        cells = profile["cells"]
        zoom = profile["middleZoom"]
        return nil if !direction || !start || !middle || !finish
        return nil if !cells.is_a?(Array) || !zoom.is_a?(Numeric)

        start_axis = point_axis(start, direction)
        middle_axis = point_axis(middle, direction)
        end_axis = point_axis(finish, direction)
        return nil if !(start_axis < middle_axis && middle_axis < end_axis)

        {
          direction: direction,
          start_axis: start_axis,
          middle_axis: middle_axis,
          end_axis: end_axis,
          start_zoom: zone_zoom_for_point(start),
          end_zoom: zone_zoom_for_point(finish),
          middle_zoom: zoom.to_f.clamp(Config::CAMERA_ZOOM_MIN.to_f,
                                       Config::CAMERA_ZOOM_MAX.to_f),
          cells: normalize_cells(cells)
        }
      end

      def normalize_zone(zone)
        return nil if !zone.is_a?(Hash)
        zoom = zone["zoom"]
        cells = zone["cells"]
        return nil if !zoom.is_a?(Numeric) || !cells.is_a?(Array)
        {
          zoom: zoom.to_f.clamp(Config::CAMERA_ZOOM_MIN.to_f,
                                Config::CAMERA_ZOOM_MAX.to_f),
          cells: normalize_cells(cells)
        }
      end

      def normalize_cells(cells)
        cells.each_with_object({}) { |cell, index| index[cell.to_s] = true }
      end

      def zone_for_cell(cell)
        @zones.find { |candidate| candidate[:cells][cell] }
      end

      def zone_zoom_for_point(point)
        zone = zone_for_cell("#{point[0].round},#{point[1].round}")
        zone ? zone[:zoom] : Mode7.camera_zoom.to_f
      end

      def normalize_point(point)
        return nil if !point.is_a?(Array) || point.length < 2
        return nil if !point[0].is_a?(Numeric) || !point[1].is_a?(Numeric)
        [point[0].to_f, point[1].to_f]
      end

      def point_axis(point, direction)
        point[0] * direction[0] + point[1] * direction[1]
      end
    end
  end
end

EventHandlers.add(:on_game_map_setup, :vermeil_2p5d_progressive_zoom_setup,
  proc { |map_id, _map, _tileset| next Mode7::ProgressiveZoom.setup(map_id) }
)

EventHandlers.add(:on_frame_update, :vermeil_2p5d_progressive_zoom_update,
  proc { next Mode7::ProgressiveZoom.update }
)
