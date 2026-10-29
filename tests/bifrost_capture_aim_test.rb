# frozen_string_literal: true
# Pure Ruby integration stub: load the real plugin files without mkxp scenes.
require "minitest/autorun"

module Graphics
  def self.width; 480; end
  def self.height; 320; end
end

module EventHandlers
  def self.add(*); end
end

module GameData
  module Species
    def self.exists?(species); species == :RAIKOU; end
  end
end

class FakeBifrostEvent
  attr_reader :id, :name, :x, :y, :direction, :screen_x, :screen_y
  attr_accessor :through, :name, :move_speed
  attr_reader :character_name, :map_id
  def sprite_size; [32,32]; end
  def moving?; false; end
  def move_route_forcing; false; end
  def move_away_from_player
    @y += (@y < $game_player.y ? -1 : 1)
  end
  def initialize(id=1, x=10, y=6)
    @id, @x, @y = id, x, y
    @name = "[OWCAP:RAIKOU:50]"
    @map_id = 10
    @character_name = "Followers/RAIKOU"
    @move_speed = 3
    @direction = 2
    @screen_x = 150
    @screen_y = 110
    @through = false
    @erased = false
  end
  def erase; @erased = true; end
  def erased?; @erased; end
end

class FakeBifrostMap
  attr_accessor :events
  def initialize
    @events = {1 => FakeBifrostEvent.new}
  end
  def map_id; 10; end
  def valid?(x,y); x.between?(0,30) && y.between?(0,30); end
  def passable?(*); true; end
end

class FakeBifrostBag
  attr_reader :removed
  def initialize; @removed = 0; end
  def remove(item,count)
    raise "wrong item" unless item == :POKEBALL && count == 1
    @removed += 1
    true
  end
end

class PokemonGlobalMetadata; end
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/001_Core"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/002_Runtime"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/005_ThrowExperience"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/006_Behavior"

module BifrostCapture
  class << self
    attr_accessor :test_hits, :test_notices, :test_stored
    def generated?(event)
      false
    end
    def contact_fx(event)
      self.test_hits ||= []
      self.test_hits << event
    end
    def notice(message)
      self.test_notices ||= []
      self.test_notices << message
    end
    def impact(*); end
    def capture_sequence(*); end
    def catch_chance(*); 1.0; end
  end
end

def pbGenerateWildPokemon(species,level)
  Struct.new(:species,:level,:form,:poke_ball).new(species,level,0,nil)
end

def pbAddPokemon(pokemon)
  BifrostCapture.test_stored ||= []
  BifrostCapture.test_stored << pokemon
  true
end

def _INTL(text,*)
  text
end

class BifrostCaptureAimTest < Minitest::Test
  def setup
    $game_map = FakeBifrostMap.new
    $game_player = Struct.new(:x,:y,:direction).new(10,10,8)
    $PokemonGlobal = PokemonGlobalMetadata.new
    $bag = FakeBifrostBag.new
    BifrostCapture.test_hits = []
    BifrostCapture.test_notices = []
    BifrostCapture.test_stored = []
  end

  def test_keyboard_and_mouse_focus_same_real_event
    target = $game_map.events[1]
    cfg = BifrostCapture::DEFAULTS
    assert_equal target,BifrostCapture.nearest_aimable_target(cfg)
    mouse_target, x, y = BifrostCapture.current_focus([150,94],cfg)
    assert_equal target,mouse_target
    assert_in_delta 150,x,0.1
    assert_in_delta 96,y,2
    geo = BifrostCapture.shot_geometry(10,10,target.x,target.y,cfg)
    assert geo[:in_range]
    assert_equal 4,geo[:forward]
  end

  def test_at_optimal_range_a_well_aligned_throw_hits_and_consumes_ball
    target = $game_map.events[1]
    cfg = BifrostCapture::DEFAULTS
    result = BifrostCapture.resolve_throw(target,:ball,:POKEBALL,cfg)
    assert result
    assert_equal 1,$bag.removed
    assert_equal [target],BifrostCapture.test_hits
    assert_equal 1,BifrostCapture.test_stored.length
    assert target.erased?
  end

  def test_eighth_tile_cannot_hit
    far_target = FakeBifrostEvent.new(1,10,2)
    $game_map.events[1] = far_target
    cfg = BifrostCapture::DEFAULTS
    result = BifrostCapture.resolve_throw(far_target,:ball,:POKEBALL,cfg)
    refute result
    assert_empty BifrostCapture.test_hits
    assert_empty BifrostCapture.test_stored
  end
  def test_unregistered_visible_ow_cannot_waste_balls
    event = $game_map.events[1]
    event.name = "ambient OW"
    refute BifrostCapture.valid_target?(event)
    assert_nil BifrostCapture.nearest_aimable_target(BifrostCapture::DEFAULTS)
    refute BifrostCapture.perform_throw(nil,:ball,:POKEBALL,
                                      BifrostCapture::DEFAULTS,[150,96])
    assert_equal 0,$bag.removed
  end

  def test_registration_allows_existing_external_ow_only_when_explicit
    event = $game_map.events[1]
    event.name = "External roaming event"
    refute BifrostCapture.valid_target?(event)
    assert BifrostCapture.register_ow(event,:RAIKOU,50)
    assert BifrostCapture.valid_target?(event)
    BifrostCapture.unregister_ow(event)
    refute BifrostCapture.valid_target?(event)
  end

  def test_flee_walks_before_disappearing
    event = $game_map.events[1]
    cfg = BifrostCapture::DEFAULTS
    assert BifrostCapture.begin_flee(event,cfg)
    refute event.erased?
    BifrostCapture.tick_flee(event,cfg)
    assert_equal 5,event.y
    refute event.erased?
    6.times { BifrostCapture.tick_flee(event,cfg) }
    assert event.erased?
    assert_empty($PokemonGlobal.bifrost_removed_events || {})
  end

  def test_aim_locked_on_same_event_at_different_tile
    event = $game_map.events[1]
    event.instance_variable_set(:@y,5)
    assert BifrostCapture.resolve_throw(event,:ball,:POKEBALL,
                                       BifrostCapture::DEFAULTS)
    assert_equal 1,$bag.removed
    assert_equal 1,BifrostCapture.test_stored.length
  end

end
