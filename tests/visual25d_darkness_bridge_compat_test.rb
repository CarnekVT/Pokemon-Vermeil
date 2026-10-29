# frozen_string_literal: true
# Caruban bridge must be optional even when another plugin defines DarknessSprite.
require "minitest/autorun"
BRIDGE_PATH = File.expand_path("../LA BASE DE SKY/Plugins/Visual 2.5D HD/[013] Darkness Bridge.rb", __dir__)

module Visual25D
  class << self
    attr_accessor :test_enabled
    def enabled? = !!test_enabled
  end
end

class DarknessBridgeCompatibilityTest < Minitest::Test
  def teardown
    Object.send(:remove_const, :DarknessSprite) if Object.const_defined?(:DarknessSprite)
    Visual25D.test_enabled = false
  end

  def test_unrelated_darkness_sprite_does_not_crash_plugin_load
    Object.const_set(:DarknessSprite, Class.new)
    load BRIDGE_PATH
    refute DarknessSprite.instance_methods(false).include?(:get_nearby_events)
  end

  def test_incomplete_caruban_api_does_not_alias_missing_methods
    Object.const_set(:DarknessSprite, Class.new do
      def get_nearby_events = :old
    end)
    load BRIDGE_PATH
    assert_equal :old, DarknessSprite.new.get_nearby_events
    refute DarknessSprite.instance_methods(false).include?(:hd25_dd_get_nearby_events)
  end

  def test_full_caruban_api_gets_hooks_and_preserves_2d_fallback
    Object.const_set(:DarknessSprite, Class.new do
      def get_nearby_events = :old_events
      def draw_all_lights = :old_lights
      def refresh(force = false) = force ? :forced : :old_refresh
    end)
    load BRIDGE_PATH
    assert DarknessSprite.instance_methods.include?(:hd25_dd_get_nearby_events)
    assert DarknessSprite.instance_methods.include?(:hd25_dd_draw_all_lights)
    assert DarknessSprite.instance_methods.include?(:hd25_dd_refresh)
    instance = DarknessSprite.new
    assert_equal :old_events, instance.get_nearby_events
    assert_equal :old_lights, instance.draw_all_lights
    assert_equal :old_refresh, instance.refresh
    assert_equal :forced, instance.refresh(true)
  end
end
