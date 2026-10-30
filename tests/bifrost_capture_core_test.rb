# frozen_string_literal: true
require "minitest/autorun"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/001_Core"

class BifrostCoreTest < Minitest::Test
  def setup
    BifrostCapture.reload!
  end

  def test_translation_placeholders_always_receive_mutable_strings
    root=File.expand_path(
      "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture",__dir__)
    Dir.glob(File.join(root,"*.rb")).each do |path|
      source=File.read(path)
      unsafe=source.scan(/_INTL\("[^"]*\{\d+\}[^"]*"\s*,/)
      assert_empty unsafe, "FrozenError risk in #{File.basename(path)}: #{unsafe.inspect}"
    end
  end

  def test_project_defaults_keep_exclusive_bifrost
    cfg = BifrostCapture::DEFAULTS
    assert_equal "bifrost",cfg["profile"]
    assert_equal "1",cfg["restricted_species"]
    assert_equal "classic",cfg["encounter_mode"]
    assert_equal "always",cfg["access_mode"]
  end

  def test_other_project_can_enable_full_ow
    cfg = BifrostCapture::DEFAULTS.merge(
      BifrostCapture::PROFILES["full_ow"])
    assert_equal "0",cfg["restricted_species"]
    assert_equal "overworld",cfg["encounter_mode"]
    assert BifrostCapture.overworld_encounters?(cfg)
  end

  def test_all_species_are_eligible_in_full_overworld
    cfg = BifrostCapture::DEFAULTS.merge("restricted_species"=>"0")
    assert BifrostCapture.allow_species?(:PIKACHU,cfg)
    assert BifrostCapture.allow_species?(:RAIKOU,cfg)
  end

  def test_bifrost_only_catalog_is_configurable
    cfg = BifrostCapture::DEFAULTS
    assert BifrostCapture.allow_species?(:RAIKOU,cfg)
    refute BifrostCapture.allow_species?(:PIKACHU,cfg)
  end

  def test_eight_tiles_always_outside_seven_tile_limit
    cfg = BifrostCapture::DEFAULTS
    assert BifrostCapture.geometry(10,10,10,6,cfg)[:in_range]
    assert BifrostCapture.geometry(10,10,13,6,cfg)[:in_range]
    refute BifrostCapture.geometry(10,10,10,2,cfg)[:in_range]
    assert_in_delta 1.0,BifrostCapture.hit_chance(4,cfg),0.00001
    assert_equal 0.0,BifrostCapture.hit_chance(8,cfg)
  end
end
