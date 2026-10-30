# frozen_string_literal: true
require "minitest/autorun"

module EventHandlers
  def self.add(*args); end
end
module Graphics
  def self.width; 640; end
  def self.height; 480; end
end
class Scene_Map; end
class Color
  def initialize(*args); end
end
class Viewport
  def disposed?; false; end
end
class Bitmap
  attr_reader :width,:height
  def initialize(w,h); @width,@height=w,h;@disposed=false;end
  def fill_rect(*); end
  def dispose;@disposed=true;end
  def disposed?;@disposed;end
end
class Sprite
  attr_accessor :bitmap,:ox,:oy,:x,:y,:z,:opacity,:zoom_x,:zoom_y,
                :visible,:blend_type
  @@created=0
  def self.created; @@created; end
  def initialize(vp)
    @@created+=1
    @visible=true
    @disposed=false
  end
  def dispose;@disposed=true;end
  def disposed?;@disposed;end
end
class Spriteset_Map
  def self.viewport; @viewport ||= Viewport.new; end
end
class FakeShinyEvent
  attr_reader :id, :pokemon
  attr_accessor :opacity,:transparent
  def initialize(id,shiny=true)
    @id=id;@opacity=255;@transparent=false
    @bifrost_wild_pokemon=Struct.new(:shiny?) .new(shiny)
  end
  def screen_z; 100; end
end
module BifrostCapture
  class << self
    attr_accessor :visible,:config
    def visible_targets;@visible || [];end
    def event_spec(event);[:PIKACHU,5,0];end
    def target_rect(event);[100,75,32,40];end
    def options(*);@config;end
  end
  module Audio
    class << self
      attr_reader :played
      def play(kind,cfg)
        @played ||= []
        @played << kind
        true
      end
      def reset; @played = []; end
    end
  end
end
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/013_ShinySignals"

class ShinySignalsTest < Minitest::Test
  def setup
    @cfg = {
      "shiny_fx_enabled"=>"1", "shiny_fx_intensity"=>"2",
      "shiny_pulse_frames"=>"150", "shiny_sound_enabled"=>"1",
      "shiny_repeat_sound"=>"0"
    }
    BifrostCapture.config=@cfg
    BifrostCapture::Audio.reset
    BifrostCapture::ShinySignals.reset
    $game_map=Struct.new(:events,:map_id).new({},1)
    $scene=Scene_Map.new
    $game_temp=Struct.new(:in_battle).new(false)
    @event=FakeShinyEvent.new(1)
    $game_map.events[1]=@event
    BifrostCapture.visible=[@event]
  end

  def test_spawn_has_one_chime_and_a_burst_followed_by_persistent_stars
    shiny=BifrostCapture::ShinySignals
    assert shiny.on_spawn(@event,@cfg)
    shiny.update
    assert_equal [:shiny],BifrostCapture::Audio.played
    state=shiny.instance_variable_get(:@states)[@event.object_id]
    assert state[:halo].visible
    assert_operator state[:sprites].length,:>=,3
    assert_equal 102,state[:sprites].first.z
    creations=Sprite.created
    350.times { shiny.update }
    assert_equal creations,Sprite.created, "Shared sprites should be reused"
    assert_equal [:shiny],BifrostCapture::Audio.played,
      "Persistent sparkles must not spam the chime by default"
    assert state[:sprites].any? { |sp| sp.visible }
  end

  def test_persistent_ambient_sparkle_disables_without_mutating_pokemon
    shiny=BifrostCapture::ShinySignals
    shiny.update
    @cfg["shiny_fx_enabled"]="0"
    shiny.update
    state=shiny.instance_variable_get(:@states)[@event.object_id]
    assert_empty state[:sprites]
    assert @event.instance_variable_get(:@bifrost_wild_pokemon).shiny?
    assert_equal [:shiny],BifrostCapture::Audio.played
  end

  def test_hidden_or_removed_target_is_cleaned_up
    shiny=BifrostCapture::ShinySignals
    shiny.update
    state=shiny.instance_variable_get(:@states)[@event.object_id]
    sprite=state[:sprites].first
    BifrostCapture.visible=[]
    shiny.update
    refute sprite.visible
    $game_map.events.delete(1)
    shiny.update
    assert sprite.disposed?
    assert_empty shiny.instance_variable_get(:@states)
  end

  def test_non_shiny_creates_no_effects
    @event.instance_variable_set(:@bifrost_wild_pokemon,Struct.new(:shiny?).new(false))
    before=Sprite.created
    BifrostCapture::ShinySignals.update
    assert_equal before,Sprite.created
    assert_empty BifrostCapture::Audio.played
  end

  def test_many_shiny_spawns_do_not_stack_ear_piercing_chimes
    shiny=BifrostCapture::ShinySignals
    second=FakeShinyEvent.new(2)
    $game_map.events[2]=second
    BifrostCapture.visible=[@event,second]
    shiny.on_spawn(@event,@cfg)
    shiny.on_spawn(second,@cfg)
    shiny.update
    assert_equal 1,BifrostCapture::Audio.played.length
  end
end
