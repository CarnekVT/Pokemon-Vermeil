# frozen_string_literal: true
# Headless tests for encounter roll -> visible OW -> capture -> flee.
require "minitest/autorun"
module EventHandlers
  def self.add(*args); end
end
module Graphics
  def self.width; 640; end
  def self.height; 480; end
end
class Color
  def initialize(*_args); end
end
class Scene_Map; end
module GameData
  module Species
    def self.exists?(s); [:PIKACHU,:RAIKOU].include?(s.to_sym); end
    def self.get(s); Struct.new(:catch_rate).new(255); end
  end
  module EncounterType
    def self.get(s); Struct.new(:type).new(:land); end
    def self.exists?(s); true; end
  end
end
module RPG
  class Event
    attr_accessor :id,:name,:pages,:x,:y
    def initialize(x,y); @x,@y=x,y; end
  end
  class EventCommand
    def initialize(*args); end
  end
  class Event::Page
    attr_accessor :graphic,:move_type,:move_speed,:move_frequency,:through,:trigger,:list
    def initialize
      @graphic=Struct.new(:character_name,:direction).new
    end
  end
end
class Game_Event
  attr_reader :id,:map_id,:name,:x,:y,:direction,:map,:character_name,:screen_x,:screen_y
  attr_accessor :transparent,:through,:move_speed,:active
  def initialize(map_id,data,map)
    @map_id,@id,@name,@x,@y,@map=map_id,data.id,data.name,data.x,data.y,map
    @direction=2;@character_name=data.pages[0].graphic.character_name
    @transparent=false;@through=false;@erased=false;@active=false
    @move_speed=3;@screen_x=150;@screen_y=110
  end
  def sprite_size; [32,32]; end
  def erase; @erased=true; end
  def moving?; false; end
  def move_route_forcing; false; end
  def move_away_from_player
    @y += (@y < $game_player.y ? -1 : 1)
  end
end
class FakeMap
  attr_accessor :events
  def initialize; @events={}; end
  def map_id; 7; end
  def valid?(x,y); x.between?(0,30) && y.between?(0,30); end
  def passable?(*args); true; end
  def terrain_tag(x,y)
    Struct.new(:ice,:waterfall,:waterfall_crest,:land_wild_encounters).
      new(false,false,false,true)
  end
  def register_event(event); event.active=true; end
  def unregister_event(event); event.active=false; end
end
class FakePlayer
  attr_reader :party, :pokedex
  def initialize; @party=[]; @pokedex=nil; end
  def party_full?; false; end
end
class FakeBag
  attr_reader :used
  def initialize; @used=0; end
  def quantity(item); 20-@used; end
  def remove(item,count); @used+=count;true; end
end
class PokemonGlobalMetadata; end
class PokemonEncounters
  def encounter_triggered?(*args); true; end
  def choose_wild_pokemon(*args); [:PIKACHU,6]; end
end
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/001_Core"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/002_Runtime"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/004_OverworldEncounters"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/005_ThrowExperience"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/006_Behavior"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/007_CaptureFeedback"
module BifrostCapture::Feedback
  class << self
    def redraw; end
    def play_sfx(*args); end
  end
end
module BifrostCapture
  class << self
    attr_accessor :captures,:contacts
    def contact_fx(e); self.contacts=(contacts||0)+1; end
    def animate_catch(*args); end
    def catch_chance(*args); 1.0; end
  end
end
def pbResolveBitmap(name)
  name == "Graphics/Characters/Followers/PIKACHU" ? name : nil
end
def pbGenerateWildPokemon(species,level)
  Struct.new(:species,:level,:form,:poke_ball).new(species,level,0,nil)
end
def pbAddPokemon(pkmn)
  BifrostCapture.captures ||= []
  BifrostCapture.captures << pkmn
  true
end
def _INTL(s,*args); s; end
class BifrostCaptureIntegrationTest < Minitest::Test
  def setup
    $player=nil
    $scene=Object.new
    $game_map=FakeMap.new
    $game_player=Struct.new(:x,:y,:direction,:screen_x,:screen_y).
      new(10,10,8,150,200)
    $PokemonGlobal=PokemonGlobalMetadata.new
    $PokemonGlobal.bifrost_overrides={
      "encounter_mode"=>"overworld","restricted_species"=>"0"
    }
    $bag=FakeBag.new
    $PokemonEncounters=PokemonEncounters.new
    BifrostCapture.captures=[]
    BifrostCapture.contacts=0
    BifrostCapture.reset_wild_events
    BifrostCapture.reset_behavior
    BifrostCapture::Feedback.reset
  end
  def test_native_grass_roll_creates_capturable_ow
    result=PokemonEncounters.new.encounter_triggered?(:Land)
    refute result
    event=$game_map.events.values.first
    refute_nil event
    assert_equal [:PIKACHU,6,0],BifrostCapture.event_spec(event)
    assert BifrostCapture.valid_target?(event)
    assert event.active, "generated OW must be registered for Game_Map updates"
    assert_equal 1,BifrostCapture.wild_events.length
  end
  def test_spawned_ow_can_be_captured_and_stored
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,6)
    result=BifrostCapture.resolve_throw(event,:ball,:POKEBALL,BifrostCapture.options)
    assert result
    assert_equal 1,$bag.used
    assert_equal 1,BifrostCapture.captures.length
    assert_equal :PIKACHU,BifrostCapture.captures[0].species
    assert_equal :caught,BifrostCapture::Feedback.last_result[:kind]
    assert_equal :PIKACHU,BifrostCapture::Feedback.last_result[:species]
    assert_empty $game_map.events
  end
  def test_success_adds_directly_to_team_without_blocking_message
    $player=FakePlayer.new
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,6)
    assert BifrostCapture.resolve_throw(event,:ball,:POKEBALL,BifrostCapture.options)
    assert_equal 1,$player.party.length
    assert_equal :PIKACHU,$player.party[0].species
    assert_includes [:caught,:critical],BifrostCapture::Feedback.last_result[:kind]
    assert_equal "Añadido al equipo",BifrostCapture::Feedback.last_result[:detail]
  end

  def test_precomputed_hit_roll_controls_visible_miss_and_result
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,6)
    $PokemonGlobal.bifrost_overrides["hit_near"]="25"
    refute BifrostCapture.resolve_throw(event,:ball,:POKEBALL,
                                      BifrostCapture.options,nil,0.9)
    assert_equal :miss,BifrostCapture::Feedback.last_result[:kind]
    assert_equal 1,$bag.used
    assert_equal 0,BifrostCapture.captures.length
  end

  def test_release_has_explicit_distinct_feedback
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,6)
    original=BifrostCapture.method(:catch_chance)
    BifrostCapture.singleton_class.send(:define_method,:catch_chance) { |*| 0.0 }
    begin
      refute BifrostCapture.resolve_throw(event,:ball,:POKEBALL,BifrostCapture.options)
      assert_equal :breakout,BifrostCapture::Feedback.last_result[:kind]
      assert_equal 1,$bag.used
      assert_equal 0,BifrostCapture.captures.length
    ensure
      BifrostCapture.singleton_class.send(:define_method,:catch_chance,original)
    end
  end

  def test_no_ow_does_not_consume_ball
    refute BifrostCapture.resolve_throw(nil,:ball,:POKEBALL,BifrostCapture.options)
    assert_equal :blocked,BifrostCapture::Feedback.last_result[:kind]
    assert_equal 0,$bag.used
  end
  def test_flee_moves_before_disappearing_and_does_not_mark_caught
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    assert BifrostCapture.start_flee(event,BifrostCapture.options)
    refute_empty $game_map.events
    9.times { BifrostCapture.flee_tick(event,BifrostCapture.options) }
    assert_empty $game_map.events
    assert_empty($PokemonGlobal.bifrost_removed_events || {})
  end
  def test_full_ow_generated_stays_capturable_with_legendary_only_roster
    # Original regression: full OW spawns a regular wild, but Bifrost
    # exclusive catalog prevented aiming/capturing it.
    BifrostCapture.spawn_wild(:Land)
    $PokemonGlobal.bifrost_overrides["restricted_species"]="1"
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,6)
    assert_equal :PIKACHU,BifrostCapture.event_spec(event)[0]
    assert BifrostCapture.valid_target?(event)
    assert BifrostCapture.resolve_throw(event,:ball,:POKEBALL,
                                         BifrostCapture.options)
    assert_equal 1,BifrostCapture.captures.length
  end

  def test_decorative_event_never_becomes_wild
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@name,"[OWDECOR]")
    refute BifrostCapture.valid_target?(event)
  end

  def test_full_ow_never_falls_back_to_battle_when_sprite_missing
    # A missing follower graphic must not reach Battle::Scene in OW-only mode.
    BifrostCapture.singleton_class.class_eval do
      alias_method :_test_original_spawn_wild, :spawn_wild
      define_method(:spawn_wild) { |_type| :missing_sprite }
    end
    begin
      refute PokemonEncounters.new.encounter_triggered?(:Land)
    ensure
      BifrostCapture.singleton_class.class_eval do
        alias_method :spawn_wild, :_test_original_spawn_wild
        remove_method :_test_original_spawn_wild
      end
    end
  end

  def test_full_ow_never_falls_back_to_battle_without_free_tile
    BifrostCapture.singleton_class.class_eval do
      alias_method :_test_original_spawn_wild, :spawn_wild
      define_method(:spawn_wild) { |_type| :no_tile }
    end
    begin
      refute PokemonEncounters.new.encounter_triggered?(:Land)
    ensure
      BifrostCapture.singleton_class.class_eval do
        alias_method :spawn_wild, :_test_original_spawn_wild
        remove_method :_test_original_spawn_wild
      end
    end
  end

  def test_eighth_tile_stays_outside_capture_range
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,2)
    refute BifrostCapture.resolve_throw(event,:ball,:POKEBALL,BifrostCapture.options)
    assert_equal 0,$bag.used
  end
end
