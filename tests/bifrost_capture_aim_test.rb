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
    attr_reader :parameters
    def initialize(_code,_indent,parameters); @parameters=parameters; end
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
    @source_data=data
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
  def move_toward_player
    @x += (@x < $game_player.x ? 1 : -1) if @x != $game_player.x
  end
  def turn_toward_player; end
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
class FakeFullPlayer < FakePlayer
  def party_full?; true; end
end
class FakeStorage
  attr_reader :stored
  def pbStoreCaught(pokemon); @stored=pokemon; 0; end
  def [](index); Struct.new(:name).new("Caja 1"); end
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
  def encounter_possible_here?; true; end
  def encounter_type; :Land; end
end
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/001_Core"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/002_Runtime"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/004_OverworldEncounters"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/005_ThrowExperience"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/006_Behavior"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/007_CaptureFeedback"
module BifrostCapture::Feedback
  class << self
    def redraw(*); end
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
def _INTL(s,*args)
  # Mimic Essentials' in-place placeholder replacement to catch FrozenError.
  args.each_with_index do |value,index|
    s.sub!("{#{index+1}}",value.to_s)
  end
  s
end
class BifrostCaptureIntegrationTest < Minitest::Test
  def setup
    $player=nil
    $PokemonStorage=nil
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
  def test_extra_ow_appearance_uses_separate_roll_and_cooldown
    $player=FakePlayer.new
    $game_temp=Struct.new(:in_battle,:in_menu,:message_window_showing).
      new(false,false,false)
    $PokemonGlobal.bifrost_overrides.merge!(
      "encounter_mode"=>"classic","restricted_species"=>"1",
      "ow_extra_spawn_chance"=>"100","ow_extra_spawn_cooldown"=>"4")
    assert_equal :spawned,BifrostCapture.try_extra_spawn
    event=$game_map.events.values.first
    assert event.instance_variable_get(:@bifrost_extra_spawn)
    assert BifrostCapture.eligible_event?(event),
           "regular Pokémon from extra OW roll must be capturable"
    assert_equal :cooldown,BifrostCapture.try_extra_spawn
    assert_equal 1,$game_map.events.length
  end

  def test_aggressive_chases_and_receives_ow_battle_bonus
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    $PokemonGlobal.bifrost_overrides["aggressive_level_bonus"]="3"
    cfg=BifrostCapture.options.merge("temperament"=>"aggressive")
    event.instance_variable_set(:@bifrost_temperament,:aggressive)
    event.instance_variable_set(:@x,14)
    event.instance_variable_set(:@y,10)
    assert BifrostCapture.start_chase(event,cfg)
    # The outer radius warns first: the creature must not instantly
    # fly toward the player from its sensing distance.
    25.times { BifrostCapture.chase_tick(event,cfg) }
    assert_equal 14,event.x
    assert_equal :alert,event.instance_variable_get(:@bifrost_mood_state)
    event.instance_variable_set(:@x,13)
    BifrostCapture.chase_tick(event,cfg)
    assert_equal 12,event.x
    assert_equal :charge,event.instance_variable_get(:@bifrost_mood_state)
    assert_equal 9,BifrostCapture.battle_wild_for(event).level
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
    script=event.instance_variable_get(:@source_data).pages[0].list.first.parameters.first
    assert_match(/BifrostCapture\.interact_battle/,script)
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
    assert_includes [:caught,:critical],BifrostCapture::Feedback.last_result[:kind]
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

  def test_full_team_stores_to_box_and_identifies_destination
    $player=FakeFullPlayer.new
    $PokemonStorage=FakeStorage.new
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,6)
    assert BifrostCapture.resolve_throw(event,:ball,:POKEBALL,BifrostCapture.options)
    assert_equal :PIKACHU,$PokemonStorage.stored.species
    assert_includes [:caught,:critical],BifrostCapture::Feedback.last_result[:kind]
    assert_equal "Enviado a Caja 1",BifrostCapture::Feedback.last_result[:detail]
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

  def test_escaped_pokemon_can_telegraph_a_dodgeable_party_pressure
    $player=FakePlayer.new
    BifrostCapture.spawn_wild(:Land)
    event = $game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,9)
    mon = Struct.new(:hp,:totalhp,:name,:species) do
      def able?; hp > 0; end
    end.new(100,100,"Primero",:PIKACHU)
    $player.party << mon
    cfg = BifrostCapture.options.merge(
      "escape_reaction_enabled"=>"1","escape_reaction_chance"=>"100",
      "escape_reaction_hp_percent"=>"10","escape_reaction_windup"=>"8",
      "escape_reaction_recovery"=>"0","escape_reaction_range"=>"4")
    assert BifrostCapture.trigger_escape_reaction(event,cfg)
    assert_equal 100,mon.hp
    8.times { BifrostCapture.update_escape_reactions }
    assert_equal 100,mon.hp, "The visible lunge must happen before taking damage"
    14.times { BifrostCapture.update_escape_reactions }
    assert_equal 90,mon.hp
    refute event.instance_variable_get(:@bifrost_escape_reaction)
    assert BifrostCapture.trigger_escape_reaction(event,cfg)
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,1)
    22.times { BifrostCapture.update_escape_reactions }
    assert_equal 90,mon.hp
  end

  def test_escape_pressure_cannot_defeat_last_available_pokemon
    $player=FakePlayer.new
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,9)
    mon=Struct.new(:hp,:totalhp,:name,:species) do
      def able?; hp > 0; end
    end.new(2,100,"Primero",:PIKACHU)
    $player.party << mon
    cfg=BifrostCapture.options.merge(
      "escape_reaction_enabled"=>"1","escape_reaction_chance"=>"100",
      "escape_reaction_hp_percent"=>"30","escape_reaction_windup"=>"8",
      "escape_reaction_recovery"=>"0","escape_reaction_range"=>"4")
    assert BifrostCapture.trigger_escape_reaction(event,cfg)
    22.times { BifrostCapture.update_escape_reactions }
    assert_equal 1,mon.hp
  end

  def test_no_ow_does_not_consume_ball
    refute BifrostCapture.resolve_throw(nil,:ball,:POKEBALL,BifrostCapture.options)
    assert_equal :blocked,BifrostCapture::Feedback.last_result[:kind]
    assert_equal 0,$bag.used
  end
  def test_flee_moves_before_disappearing_and_does_not_mark_caught
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    initial_y = event.y
    cfg=BifrostCapture.options.merge("timid_reaction_frames"=>"3")
    assert BifrostCapture.start_flee(event,cfg)
    refute_empty $game_map.events
    3.times { BifrostCapture.flee_tick(event,cfg) }
    assert_equal initial_y,event.y, "Fearful Pokémon should telegraph before fleeing"
    9.times { BifrostCapture.flee_tick(event,cfg) }
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

  def test_throw_uses_release_tile_not_trainer_position_after_moving
    BifrostCapture.spawn_wild(:Land)
    event=$game_map.events.values.first
    event.instance_variable_set(:@x,10)
    event.instance_variable_set(:@y,6)
    # Player has continued walking during the Ball's flight.
    $game_player.y=18
    assert BifrostCapture.resolve_throw(event,:ball,:POKEBALL,
             BifrostCapture.options,nil,0.0,[10,10])
    assert_equal 1,BifrostCapture.captures.length
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
