# frozen_string_literal: true
# Tests the actual Core affine camera formulas without requiring the game engine.
require "minitest/autorun"
class Color
  attr_reader :red, :green, :blue
  def initialize(r, g, b, *_args)
    @red, @green, @blue = r, g, b
  end
end
module Graphics
  def self.width = 640
  def self.height = 480
end
class Scene_Map; end
module EventHandlers
  def self.add(*); end
end
class TilemapRenderer
  DISPLAY_TILE_WIDTH = 32
  DISPLAY_TILE_HEIGHT = 32
  SOURCE_TILE_WIDTH = 32
  SOURCE_TILE_HEIGHT = 32
end
load File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[001] Settings.rb", __dir__)
load File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[002] Core.rb", __dir__)
load File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[008] Options.rb", __dir__)
class Gen5ProjectionTest < Minitest::Test
  def setup
    Visual25D.instance_variable_set(:@active, true)
    Visual25D.instance_variable_set(:@wanted, true)
    Visual25D.instance_variable_set(:@blend, 1.0)
    Visual25D.instance_variable_set(:@tilt, 32)
    Visual25D.instance_variable_set(:@camera_zoom, 100)
    Visual25D.instance_variable_set(:@tile_lift, 0)
    Visual25D.instance_variable_set(:@projection_model, :gen5)
    Visual25D.rebuild_render_params!
    Visual25D.refresh_margins
  end
  def test_gen5_is_selected_by_default
    assert_equal :gen5, Visual25D::Config::PROJECTION_MODEL
    assert_equal :gen5, Visual25D.projection_model
  end
  def test_near_and_far_rows_share_horizontal_scale
    near = Visual25D.width_scale_at(580)
    far = Visual25D.width_scale_at(-280)
    assert_in_delta near, far, 0.00001
    assert_equal 1.0, near
    assert_equal Visual25D.project_x(100, near), Visual25D.project_x(100, far)
  end
  def test_ground_rows_share_one_uniform_affine_plane
    ys = [-192, -32, 64, 160, 320, 480, 672]
    scale = Visual25D.gen5_ground_scale
    assert_operator scale, :<, 1.0
    ys.each_cons(2) do |left, right|
      distance = Visual25D.project_y(right) - Visual25D.project_y(left)
      assert_in_delta((right - left) * scale, distance, 1.0)
    end
    assert_in_delta 32 * scale,
      Visual25D.project_y(64) - Visual25D.project_y(32), 1.0
  end
  def test_fast_camera_avoids_large_margin_grid
    assert_operator Visual25D.margin_columns, :<=, 1
    assert_operator Visual25D.margin_rows, :<=, 5
  end
  def test_projection_calculations_do_not_rebuild_when_unchanged
    Visual25D.update_projection(65)
    stamp = Visual25D.projection_stamp
    Visual25D.update_projection(65)
    assert_equal stamp, Visual25D.projection_stamp
    Visual25D.update_projection(66)
    assert_equal stamp + 1, Visual25D.projection_stamp
  end
  def test_saved_legacy_mode_switches_to_gen5_without_resetting_zoom
    system = PokemonSystem.new
    system.visual25d_model = :camera
    system.visual25d_tilt = 42
    system.visual25d_zoom = 125
    system.visual25d_upgrade_legacy_profile!
    assert_equal :gen5, system.visual25d_model
    assert_equal 42, system.visual25d_tilt
    assert_equal 125, system.visual25d_zoom
  end
end
