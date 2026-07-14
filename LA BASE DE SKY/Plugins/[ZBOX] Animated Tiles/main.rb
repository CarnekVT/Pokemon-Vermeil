module ZBOX
  module AnimatedTiles
    DATA_FILE = "Data/ZBOX_AnimatedTiles.json"

    def self.data
      @data ||= {}
    end

    def self.load_data
      return {} unless File.exist?(DATA_FILE)
      JSON.parse(File.read(DATA_FILE))
    rescue => e
      Console.echo_error("AnimatedTiles: #{e.message}")
      {}
    end

    def self.tiles_for_map(map_id)
      @data = load_data if @data.nil?
      placements = @data.dig("maps", map_id.to_s) || []
      templates = @data["templates"] || {}
      placements.each do |p|
        tpl = templates[p["templateId"]]
        next unless tpl
        p["_overlay"] = tpl["overlay"]
        p["_cells"] = (tpl["cells"] || []).map do |c|
          {"x" => c["x"] + p["x"], "y" => c["y"] + p["y"],
           "passage" => c["passage"] || 15,
           "priority" => c["priority"] || 0}
        end
      end
      placements
    end
  end
end

# Override passability per tile for animated tiles
class Game_Map
  alias _zbox_anim_orig_passable? passable?
  def passable?(x, y, dir, self_event = nil)
    pass = _zbox_anim_orig_passable?(x, y, dir, self_event)
    return pass if self_event
    ZBOX::AnimatedTiles.tiles_for_map(@map_id).each do |t|
      (t["_cells"] || []).each do |c|
        next unless c["x"] == x && c["y"] == y
        bit_idx = {2=>0, 4=>1, 6=>2, 8=>3}[dir] || 0
        bit = [1, 2, 4, 8][bit_idx]
        return (c["passage"] & bit) == 0
      end
    end
    pass
  end
end

EventHandlers.add(:on_new_game, :zbox_anim_tiles,
  proc { ZBOX::AnimatedTiles.instance_variable_set(:@data, nil) })
EventHandlers.add(:on_game_map_setup, :zbox_anim_tiles,
  proc { ZBOX::AnimatedTiles.instance_variable_set(:@data, nil) })

module Spriteset_Map_AnimatedTiles
  def create_anim_tiles_overlays
    @anim_tiles_sprites&.each(&:dispose)
    @anim_tiles_sprites = []
    tiles = ZBOX::AnimatedTiles.tiles_for_map($game_map.map_id)
    tiles.each do |t|
      ov = t["_overlay"]
      next unless ov && ov["image"]
      begin
        bmp = Bitmap.new(ov["image"])
      rescue
        next
      end
      frames = ov["frames"] || 1
      fw = bmp.width / frames
      dur_ms = ov["frameDuration"] || 150
      ox = ov["offsetX"] || 0
      oy = ov["offsetY"] || 0
      bx = (t["x"] + ox) * 32
      by = (t["y"] + oy) * 32
      s = Sprite.new(@viewport1)
      s.bitmap = bmp
      s.src_rect.set(0, 0, fw, bmp.height)
      s.x = bx - ($game_map.display_x / 8)
      s.y = by - ($game_map.display_y / 8)
      s.z = 200
      s.instance_variable_set(:@_anim_frames, frames)
      s.instance_variable_set(:@_anim_fw, fw)
      s.instance_variable_set(:@_anim_dur_ms, dur_ms)
      s.instance_variable_set(:@_anim_base_x, bx)
      s.instance_variable_set(:@_anim_base_y, by)
      s.instance_variable_set(:@_anim_start, System.uptime)
      @anim_tiles_sprites << s
    end
  end

  def update_anim_tiles_overlays
    return unless @anim_tiles_sprites
    now = System.uptime
    @anim_tiles_sprites.each do |s|
      frames = s.instance_variable_get(:@_anim_frames)
      fw = s.instance_variable_get(:@_anim_fw)
      dur_ms = s.instance_variable_get(:@_anim_dur_ms)
      bx = s.instance_variable_get(:@_anim_base_x)
      by = s.instance_variable_get(:@_anim_base_y)
      start = s.instance_variable_get(:@_anim_start)
      elapsed_ms = (now - start) * 1000
      frame = (elapsed_ms / dur_ms).to_i % frames
      s.src_rect.x = frame * fw
      s.x = bx - ($game_map.display_x / 8)
      s.y = by - ($game_map.display_y / 8)
    end
  end
end

class Spriteset_Map
  include Spriteset_Map_AnimatedTiles

  alias _zbox_anim_orig_init initialize
  def initialize(*args)
    _zbox_anim_orig_init(*args)
    create_anim_tiles_overlays
  end

  alias _zbox_anim_orig_update update
  def update
    _zbox_anim_orig_update
    update_anim_tiles_overlays
  end

  alias _zbox_anim_orig_dispose dispose
  def dispose
    @anim_tiles_sprites&.each(&:dispose)
    @anim_tiles_sprites = nil
    _zbox_anim_orig_dispose
  end
end
