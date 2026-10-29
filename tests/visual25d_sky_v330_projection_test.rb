# frozen_string_literal: true
# Regression tests of Skyflyer v3.3.0's OWN projection, not a replacement model.
require "minitest/autorun"

class Color
  attr_reader :red, :green, :blue
  def initialize(r, g, b, *_)
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
module MenuHandlers
  def self.add(*); end
end
def _INTL(message, *) = message
class TilemapRenderer
  DISPLAY_TILE_WIDTH = 32
  DISPLAY_TILE_HEIGHT = 32
  SOURCE_TILE_WIDTH = 32
  SOURCE_TILE_HEIGHT = 32
end
load File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[001] Settings.rb", __dir__)
load File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[002] Core.rb", __dir__)
load File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[008] Options.rb", __dir__)
module Visual25D
  def self.build_row_slices(*); end
end

class Sky330ProjectionTest < Minitest::Test
  def setup
    Visual25D.instance_variable_set(:@active, true)
    Visual25D.instance_variable_set(:@wanted, true)
    Visual25D.instance_variable_set(:@blend, 1.0)
    Visual25D.instance_variable_set(:@tilt, 22)
    Visual25D.instance_variable_set(:@camera_zoom, 100)
    Visual25D.instance_variable_set(:@tile_lift, 0)
    Visual25D.instance_variable_set(:@projection_model, :classic)
    Visual25D.rebuild_render_params!
    Visual25D.refresh_margins
  end

  def test_sky_fidelity
    assert_equal :classic, Visual25D::Config::PROJECTION_MODEL
    assert_equal 50, Visual25D::Config::MAX_TILT_DEGREES
    assert_equal 2, Visual25D::Config::GROUND_SLICES
    assert_equal :classic, Visual25D.projection_model
  end

  def test_perspective_at_22_degrees_is_not_flat
    far = Visual25D.width_scale_at(-120)
    near = Visual25D.width_scale_at(580)
    assert_operator near, :>, far
    assert_operator Visual25D.scale_at(580), :>, Visual25D.scale_at(-120)
    refute_equal Visual25D.project_x(160, far), Visual25D.project_x(160, near)
  end

  def test_height_curvature_integral_shares_adjacent_edges
    ys = [0, 32, 64, 96, 192, 320, 480]
    projected = ys.map { |v| Visual25D.project_y(v) }
    assert projected.each_cons(2).all? { |a, b| b > a }
    assert_equal Visual25D.project_y(96),
                 Visual25D.project_y(64 + 32)
  end

  def test_margins_remain_bounded_at_high_tilt
    Visual25D.instance_variable_set(:@tilt, 50)
    Visual25D.rebuild_render_params!
    Visual25D.refresh_margins
    assert_operator Visual25D.margin_columns, :<=, Visual25D::Config::MAX_MARGIN_COLUMNS
    assert_operator Visual25D.margin_rows, :<=, Visual25D::Config::MAX_MARGIN_ROWS
  end

  def test_user_selected_22_degrees_survives_saved_options
    game_options = PokemonSystem.new
    game_options.visual25d_tilt = 22
    game_options.visual25d_zoom = 100
    assert_equal 22, game_options.visual25d_tilt
    assert_equal 100, game_options.visual25d_zoom
  end

  def test_projection_rebuild_is_cached_while_idle
    Visual25D.update_projection(64)
    stamp = Visual25D.projection_stamp
    Visual25D.update_projection(64)
    assert_equal stamp, Visual25D.projection_stamp
    Visual25D.update_projection(65)
    assert_equal stamp + 1, Visual25D.projection_stamp
  end
end
