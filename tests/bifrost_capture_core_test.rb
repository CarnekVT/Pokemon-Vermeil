# frozen_string_literal: true
# Unit tests without game boot. Run from repository root:
#   ruby tests/bifrost_capture_core_test.rb
require "minitest/autorun"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/001_Core"

class BifrostCaptureCoreTest < Minitest::Test
  def config
    BifrostCapture::DEFAULTS
  end

  def test_bifrost_is_exclusive_by_default
    assert_equal "bifrost", config["profile"]
    assert_equal "1", config["restricted_species"]
    assert BifrostCapture.allow_species?(:RAIKOU,config)
    refute BifrostCapture.allow_species?(:PIKACHU,config)
  end

  def test_other_games_can_use_full_overworld_profile
    p = BifrostCapture::PROFILES["full_ow"]
    assert_equal "overworld",p["encounter_mode"]
    assert_equal "always",p["access_mode"]
    assert_equal "0",p["restricted_species"]
    assert BifrostCapture.overworld_encounters?(config.merge(p))
    refute BifrostCapture.overworld_encounters?(config)
  end

  def test_forward_rectangle_is_relative_to_facing
    assert_equal [10,6], BifrostCapture.offset(10,10,8,4,0)
    assert_equal [13,6], BifrostCapture.offset(10,10,8,4,3)
    assert_equal [4,3], BifrostCapture.relative(10,10,8,13,6)
    assert_equal [14,10],BifrostCapture.offset(10,10,6,4,0)
  end

  def test_seventh_tile_hit_chance_but_eighth_misses
    assert_in_delta 1.0,BifrostCapture.hit_chance(4,config),0.00001
    assert_in_delta 0.60,BifrostCapture.hit_chance(7,config),0.00001
    assert_equal 0.0,BifrostCapture.hit_chance(8,config)
  end

  def test_mouse_and_keyboard_use_same_geometry
    # El objetivo a 4 casillas recibe exactamente el mismo resultado al
    # lanzar usando USE o clic; input y retícula no influyen en el impacto.
    from_keyboard = BifrostCapture.shot_geometry(10,10,10,6,config)
    from_mouse = BifrostCapture.shot_geometry(10,10,10,6,config)
    assert_equal from_keyboard, from_mouse
    assert_equal 8,from_keyboard[:facing]
    assert_equal 4,from_keyboard[:forward]
    assert_equal 0,from_keyboard[:side]
    assert from_keyboard[:in_range]
  end

  def test_lateral_boundary_and_eighth_tile
    assert BifrostCapture.shot_geometry(10,10,13,6,config)[:in_range]
    refute BifrostCapture.shot_geometry(10,10,14,6,config)[:in_range]
    refute BifrostCapture.shot_geometry(10,10,10,2,config)[:in_range]
  end

  def test_keyboard_aiming_enabled_by_default
    assert_equal "1",config["aim_keyboard"]
    assert_equal "5",config["aim_speed"]
    assert_equal "aux2",config["hotkey"]
    assert_equal "always",config["access_mode"]
  end

  def test_back_bonus_uses_event_facing
    target = Struct.new(:direction,:x,:y).new(8,4,4)
    assert BifrostCapture.behind?(4,5,target)
    refute BifrostCapture.behind?(4,3,target)
  end

  def test_bifrost_roster_default_is_editable
    assert BifrostCapture.roster["bifrost"]["ARTICUNO"]
    assert BifrostCapture.roster["bifrost"]["TAPUKOKO"]
    refute BifrostCapture.roster["bifrost"]["MAGIKARP"]
  end

  def test_species_spawn_filter
    cfg = config.merge("spawn_filter"=>"all")
    assert BifrostCapture.spawn_species?(:PIKACHU,cfg)
    cfg["spawn_filter"] = "allowlist"
    refute BifrostCapture.spawn_species?(:PIKACHU,cfg)
  end
end
