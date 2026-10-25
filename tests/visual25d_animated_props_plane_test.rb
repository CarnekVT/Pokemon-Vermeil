# frozen_string_literal: true
# Contract of Visual25D <-> LBDS Animated Props without RGSS / game assets.
require "minitest/autorun"

module Graphics
  def self.width = 640
  def self.height = 480
end
class Game_Map
  TILE_WIDTH = TILE_HEIGHT = 32
  X_SUBPIXELS = Y_SUBPIXELS = 128
end
class TilemapRenderer
  ZOOM_X = ZOOM_Y = 1.0
  SOURCE_TILE_HEIGHT = DISPLAY_TILE_HEIGHT = 32
end
module LBDSAnimatedProps
  DISPLAY_FPS_CAP = 30
  CELL_SIZE = 32
end
class Sprite
  attr_accessor :x, :y, :z, :zoom_x, :zoom_y, :taper, :visible, :bitmap
  def initialize
    @zoom_x = @zoom_y = 1.0
    @bitmap = Object.new
    @taper = 1.0
  end
  def disposed? = false
end
module MenuHandlers
  def self.add(*); end
end
def _INTL(text, *) = text

module Visual25D
  module Config
    MAX_PRIORITY = 12
  end
  TAPER_SUPPORTED = true
  class << self
    attr_accessor :test_enabled, :projection_stamp
    def enabled? = @test_enabled
    def tilt = 32
    def camera_zoom = 100
    def sync_projection_from_map!(_) = nil
    def width_scale_at(_) = 1.25
    def vertical_unit_at(_) = 40.0
    def project_x(x, scale) = (x * scale).round
    def project_y(y) = y + 10
    def row_width_scale_any(_) = 1.25
    def row_taper(_) = 1.0
    def grid_row_for_map_cell(_, cy) = cy
    def wall_field(_) = nil
    def wall_cell_bounds(_, _, _, cy) = [10 + 32 * cy, 10 + 32 * (cy + 1)]
    def display_pixel_offset_y(_) = 0
    def raised_tile_z(z) = z + 10000
    def redraw_map = nil
  end
end
class Spriteset_Map
  def initialize(map, placements, sprites)
    @map = map
    @lbds_prop_placements = placements
    @lbds_prop_sprites = sprites
  end
  def lbds_props_view_bounds(*_args) = [0, 0, 10, 10]
  def lbds_props_update_sprites
    @lbds_prop_frame_slot = (@lbds_prop_frame_slot || 0) + 1
    @lbds_prop_geometry_stamp = [@map.display_x, @map.display_y]
    if Visual25D.enabled?
      # Same single-owner path as the runtime plugin: never write 2D geometry.
      v25_props_apply_geometry(0, 0, 1.0, 1.0)
    else
      @lbds_prop_sprites.each do |entry|
        spr = entry[0]
        spr.x = -100
        spr.y = -100
        spr.zoom_x = spr.zoom_y = 1.0
        spr.taper = 1.0
      end
    end
  end
end

load File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[016] Studio Bridges.rb", __dir__)

class PropsPlaneTest < Minitest::Test
  Map = Struct.new(:map_id, :display_x, :display_y)
  def setup
    Visual25D.test_enabled = true
    Visual25D.projection_stamp = 12
    @map = Map.new(1, 0, 0)
  end
  def make_entry(prop, cx, cy, span, priority)
    [Sprite.new, prop, cx, cy, span, priority, -1, :base]
  end
  def test_upright_fragments_share_position_scale_regardless_of_priority
    obj = { x: 3, y: 2, width: 2, height: 3, layer: 0,
            cells: [{ "priority" => 3 }, { "priority" => 3 },
                    { "priority" => 1 }, { "priority" => 1 },
                    { "priority" => 0 }, { "priority" => 0 }] }
    entries = [make_entry(obj, 0, 0, 1, 3), make_entry(obj, 1, 0, 1, 3),
               make_entry(obj, 0, 1, 2, 1), make_entry(obj, 0, 2, 2, 0)]
    renderer = Spriteset_Map.new(@map, [obj], entries)
    renderer.lbds_props_update_sprites
    a, b, c, d = entries.map(&:first)
    assert_equal a.x + (a.zoom_x * 32).round, b.x
    assert_equal a.y + (a.zoom_y * 32).round, c.y
    assert_equal c.y + (c.zoom_y * 32).round, d.y
    assert_equal a.zoom_y, d.zoom_y
    assert_operator a.z, :>, 10000
    assert_equal 0, d.z
    before = entries.map { |e| [e[0].x, e[0].y, e[0].zoom_x, e[0].zoom_y] }
    renderer.lbds_props_update_sprites
    assert_equal before, entries.map { |e| [e[0].x, e[0].y, e[0].zoom_x, e[0].zoom_y] }
  end
  def test_ground_only_animations_follow_floor_rows
    obj = { x: 2, y: 4, width: 1, height: 2, layer: 0,
            projection_mode: :surface,
            cells: [{ "priority" => 0 }, { "priority" => 0 }] }
    entries = [make_entry(obj, 0, 0, 1, 0), make_entry(obj, 0, 1, 1, 0)]
    renderer = Spriteset_Map.new(@map, [obj], entries)
    renderer.lbds_props_update_sprites
    a, b = entries.map(&:first)
    assert_equal 32, b.y - a.y
    assert_equal 1.0, a.zoom_y
  end
  def test_unmarked_multirow_prop_uses_one_upright_plane
    obj = { x: 4, y: 3, width: 1, height: 2, layer: 0,
            cells: [{ "priority" => 0 }, { "priority" => 0 }] }
    entries = [make_entry(obj, 0, 0, 1, 0), make_entry(obj, 0, 1, 1, 0)]
    renderer = Spriteset_Map.new(@map, [obj], entries)
    renderer.lbds_props_update_sprites
    a, b = entries.map(&:first)
    assert_equal 40, b.y - a.y
    assert_equal a.zoom_y, b.zoom_y
  end

  def test_bridge_does_not_override_base_frame_update
    # The adapter no longer wraps lbds_props_update_sprites with super.
    assert !Visual25D::Props.instance_methods(false).include?(:lbds_props_update_sprites)
    assert Visual25D::Props.instance_methods(false).include?(:v25_props_apply_geometry)
  end

  def test_turning_off_projection_restores_original_renderer_and_taper
    obj = { x: 0, y: 0, width: 1, height: 1, layer: 0,
            cells: [{ "priority" => 0 }] }
    entry = make_entry(obj, 0, 0, 1, 0)
    renderer = Spriteset_Map.new(@map, [obj], [entry])
    renderer.lbds_props_update_sprites
    entry[0].taper = 0.8
    Visual25D.test_enabled = false
    renderer.lbds_props_update_sprites
    assert_equal 1.0, entry[0].taper
    assert_equal(-100, entry[0].x)
  end
end
