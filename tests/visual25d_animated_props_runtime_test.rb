# frozen_string_literal: true
# Real LBDS update_sprites path + Visual25D bridge, without RGSS dependencies.
require "minitest/autorun"

module Graphics
  def self.width = 640
  def self.height = 480
end
module System
  class << self
    attr_accessor :clock
    def uptime = @clock || 0.0
  end
end
class Game_Map
  TILE_WIDTH = TILE_HEIGHT = 32
  X_SUBPIXELS = Y_SUBPIXELS = 128
  attr_accessor :map_id, :display_x, :display_y
  def initialize
    @map_id = 1
    @display_x = @display_y = 0
  end
end
class TilemapRenderer
  ZOOM_X = ZOOM_Y = 1.0
  DISPLAY_TILE_HEIGHT = SOURCE_TILE_HEIGHT = 32
end
class RectMock
  attr_reader :x, :y, :width, :height
  def initialize = set(0, 0, 32, 32)
  def set(x, y, w, h)
    @x, @y, @width, @height = x, y, w, h
  end
end
class Sprite
  attr_accessor :bitmap, :taper, :visible
  attr_reader :x, :y, :z, :zoom_x, :zoom_y, :geometry_writes
  def initialize(*)
    @bitmap = Object.new
    @taper = 1.0
    @visible = true
    @x = @y = @z = 0
    @zoom_x = @zoom_y = 1.0
    @geometry_writes = 0
    @src_rect = RectMock.new
  end
  def src_rect = @src_rect
  def disposed? = false
  def x=(value); @x = value; @geometry_writes += 1; end
  def y=(value); @y = value; @geometry_writes += 1; end
  def z=(value); @z = value; @geometry_writes += 1; end
  def zoom_x=(value); @zoom_x = value; @geometry_writes += 1; end
  def zoom_y=(value); @zoom_y = value; @geometry_writes += 1; end
end
class Spriteset_Map
  def self.viewport = Object.new
end
module MenuHandlers
  def self.add(*); end
end
def _INTL(message, *) = message
module Visual25D
  module Config
    MAX_PRIORITY = 12
  end
  TAPER_SUPPORTED = true
  class << self
    attr_accessor :enabled_for_test
    def enabled? = @enabled_for_test
    def perf_enabled? = false
    def tilt = 45
    def camera_zoom = 100
    def projection_stamp = 1
    def width_scale_at(_) = 1.0
    def vertical_unit_at(_) = 40.0
    def row_width_scale_any(_) = 1.0
    def row_taper(_) = 1.0
    def project_x(x, scale) = (x * scale).round
    def project_y(y) = y.round + 10
    def grid_row_for_map_cell(_, cell_y) = cell_y
    def wall_field(_) = nil
    def wall_cell_bounds(_, _, _, row) = [(row * 32) + 10, ((row + 1) * 32) + 10]
    def sync_projection_from_map!(_) = nil
    def display_pixel_offset_y(_) = 0
    def raised_tile_z(z) = z + 10000
    def redraw_map = nil
  end
end
load File.expand_path("../LA BASE DE SKY/Plugins/LBDS Animated Props/001_Animated_Props.rb", __dir__)
load File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[016] Studio Bridges.rb", __dir__)

class LBDSVisual25DRealIntegrationTest < Minitest::Test
  def setup
    System.clock = 0.0
    Visual25D.enabled_for_test = true
    @map = Game_Map.new
    @obj = {
      x: 2, y: 3, width: 1, height: 2, layer: 0, id: "p",
      source_x: 0, source_y: 0, frame_width: 1,
      fps: 30, frames: 4, timing_mode: "synchronized",
      loop: true, parallel: nil,
      cells: [{ "priority" => 1 }, { "priority" => 0 }]
    }
    @sprite = Sprite.new
    @entry = [@sprite, @obj, 0, 0, 1, 1, -1, :base]
    # Avoid the module's bitmap loading/viewport allocation in this unit test.
    @renderer = Spriteset_Map.allocate
    @renderer.instance_variable_set(:@map, @map)
    @renderer.instance_variable_set(:@lbds_prop_sprites, [@entry])
    @renderer.instance_variable_set(:@lbds_prop_placements, [@obj])
    @renderer.instance_variable_set(:@lbds_prop_started_at, 0.0)
    @renderer.define_singleton_method(:lbds_props_sync_visible) { |*| false }
    @calls = 0
  end

  def test_3d_path_writes_once_per_geometry_change_not_twice
    assert @renderer.lbds_props_visual25d_active?
    @renderer.lbds_props_update_sprites
    assert_equal 1, @entry[6] + 1 # first frame 0
    assert_equal 64, @sprite.x
    assert_equal 90, @sprite.y
    first = @sprite.geometry_writes
    assert_operator first, :>, 0
    # Source frame advances, but the camera has not moved: zero geometry writes.
    System.clock = 0.041
    @renderer.lbds_props_update_sprites
    assert_equal 1, @entry[6]
    assert_equal first, @sprite.geometry_writes
    # Camera moves one pixel: one projected change, no 2D intermediate writes.
    @map.display_y += 128
    @renderer.lbds_props_update_sprites
    assert_equal 89, @sprite.y
    assert_operator @sprite.geometry_writes - first, :<=, 4
  end

  def test_2d_mode_keeps_vanilla_coordinates_and_unsets_taper
    @renderer.lbds_props_update_sprites
    @sprite.taper = 0.84
    Visual25D.enabled_for_test = false
    @renderer.lbds_props_update_sprites
    refute @renderer.lbds_props_visual25d_active?
    assert_equal 64, @sprite.x
    assert_equal 96, @sprite.y
    assert_equal 1.0, @sprite.taper
  end

  def test_no_bridge_if_2_5d_was_removed
    original = Visual25D.enabled_for_test
    Visual25D.enabled_for_test = false
    @renderer.lbds_props_update_sprites
    assert_equal 96, @sprite.y
  ensure
    Visual25D.enabled_for_test = original
  end
end
