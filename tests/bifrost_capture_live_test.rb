# frozen_string_literal: true
# Headless input regression. Normal map updates must never be blocked by aim.
require "minitest/autorun"
def _INTL(string,*args); string.dup; end
module EventHandlers
  def self.add(*); end
end
class Scene_Map
  attr_reader :map_input_count
  def update_input; @map_input_count=(@map_input_count || 0)+1; end
  attr_reader :menu_opened
  def call_menu; @menu_opened=true; end
end
class FakeWorldViewport
  def disposed?; false; end
end
module Spriteset_Map
  def self.viewport; @world ||= FakeWorldViewport.new; end
end
module Input
  AUX2=:aux2; AUX1=:aux1; ACTION=:action; SPECIAL=:special
  JUMPUP=:jumpup; JUMPDOWN=:jumpdown; F9=:f9
  BACK=:back; USE=:use; MOUSELEFT=:mouseleft; MOUSERIGHT=:mouseright
  @pressed={};@triggered={}
  def self.press?(key); !!@pressed[key]; end
  def self.trigger?(key); !!@triggered[key]; end
  def self.scroll_v; @scroll || 0; end
  def self.configure(pressed={},triggered={},scroll=0)
    @pressed=pressed;@triggered=triggered;@scroll=scroll
  end
end
class FakeHUD
  attr_reader :statuses
  def initialize; @statuses=[]; end
  def reticle(*args); @statuses << args; end
  def equip(*); end
  def draw(*); end
  def dispose; end
end
module BifrostCapture
  ThrowHUD=FakeHUD
  @result=nil
  @aim_open=false
  class << self
    attr_accessor :result,:test_options,:test_balls
    def options(*)
      {"access_mode"=>"always","control_mode"=>"hold","aim_chain"=>"0",
       "aim_mouse"=>"0","capture_enabled"=>"1","battle_enabled"=>"1",
       "hotkey"=>"jumpup","ball_key"=>"jumpdown",
       "mode_key"=>"aux2","target_key"=>"none",
       "contextual_mode_toggle"=>"1","mouse_wheel_select"=>"1",
       "mouse_right_mode"=>"1","remember_selection"=>"1",
       "line_of_sight"=>"0"}.merge(@test_options || {})
    end
    def hotkey; Input::JUMPUP; end
    def input_action(name)
      {"use"=>Input::USE,"back"=>Input::BACK,
       "jumpup"=>Input::JUMPUP,"jumpdown"=>Input::JUMPDOWN}[name]
    end
    def capture_action(cfg,field)
      {"jumpup"=>Input::JUMPUP,"jumpdown"=>Input::JUMPDOWN,
       "aux2"=>Input::AUX2}[cfg[field]]
    end
    def aim_allowed?; true; end
    def ball_choices; @test_balls || [[:POKEBALL,10],[:GREATBALL,7]]; end
    def closest_target; nil; end
    def take_notice; nil; end
    def capture_result(*args); self.result=args; end
  end
end
$game_map=Struct.new(:map_id).new(1)
$game_player=Struct.new(:x,:y,:screen_x,:screen_y,:direction,:moving?).
  new(10,10,100,150,8,true)
$game_temp=Struct.new(:in_battle,:in_menu,:message_window_showing,
  :player_transferring,:transition_processing).new(false,false,false,false,false)
$player=Struct.new(:party).new([])
$scene=Scene_Map.new
$bag=Struct.new(:_n) do
  def quantity(*); 10; end
end.new(10)
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/008_LiveGamefeel"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/010_MapInputGuard"
class BifrostLiveTest < Minitest::Test
  def setup
    BifrostCapture::Motion.cancel
    $scene=Scene_Map.new
    $player.party=[]
    Input.configure
    BifrostCapture.result=nil
    BifrostCapture.test_options=nil
    BifrostCapture.test_balls=nil
    $PokemonGlobal=Struct.new(:bifrost_last_ball,
      :bifrost_last_party_index,:bifrost_last_mode).new
  end
  def teardown
    BifrostCapture::Motion.cancel
  end
  def test_w_opens_without_stopping_player_movement
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    assert BifrostCapture::LiveAim.active?
    assert $game_player.moving?
    Input.configure({Input::JUMPUP=>true},{})
    BifrostCapture::LiveAim.update
    assert BifrostCapture::LiveAim.active?
  end
  def test_releasing_w_without_target_reports_blocked_without_locking_map
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({}, {})
    BifrostCapture::LiveAim.update
    assert BifrostCapture::LiveAim.active?
    BifrostCapture::LiveAim.update
    refute BifrostCapture::LiveAim.active?
    assert_equal :blocked,BifrostCapture.result[0]
    assert $game_player.moving?
  end
  def test_s_short_tap_cycles_ball_without_using_d
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true,Input::JUMPDOWN=>true},
                    {Input::JUMPDOWN=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{})
    BifrostCapture::LiveAim.update
    assert_equal 1,BifrostCapture::LiveAim.session[:ball_index]
    assert_equal :ball,BifrostCapture::LiveAim.session[:mode]
  end

  def test_double_tap_s_switches_mode_and_w_is_reserved_for_debug
    able_mon=Object.new
    def able_mon.able?; true; end
    $player.party=[able_mon]
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::AUX2=>true})
    BifrostCapture::LiveAim.update
    assert_equal :ball,BifrostCapture::LiveAim.session[:mode]
    Input.configure({Input::JUMPUP=>true},{Input::JUMPDOWN=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::JUMPDOWN=>true})
    BifrostCapture::LiveAim.update
    assert_equal :battle,BifrostCapture::LiveAim.session[:mode]
    Input.configure({Input::JUMPUP=>true},{Input::SPECIAL=>true})
    BifrostCapture::LiveAim.update
    $scene.update_input
    assert_equal 1,$scene.map_input_count
    refute BifrostCapture::LiveAim.active?
  end

  def test_mouse_wheel_changes_ball_in_both_directions
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{},-1)
    BifrostCapture::LiveAim.update
    assert_equal 1,BifrostCapture::LiveAim.session[:ball_index]
    Input.configure({Input::JUMPUP=>true},{},1)
    BifrostCapture::LiveAim.update
    assert_equal 0,BifrostCapture::LiveAim.session[:ball_index]
  end

  def test_last_ball_restored_after_closing_and_reopening
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::JUMPDOWN=>true})
    BifrostCapture::LiveAim.update
    assert_equal :GREATBALL,$PokemonGlobal.bifrost_last_ball
    BifrostCapture::LiveAim.close
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    assert_equal 1,BifrostCapture::LiveAim.session[:ball_index]
  end

  def test_missing_last_ball_falls_back_to_available_choice
    $PokemonGlobal.bifrost_last_ball=:GREATBALL
    BifrostCapture.test_balls=[[:POKEBALL,4]]
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    assert_equal 0,BifrostCapture::LiveAim.session[:ball_index]
    assert_equal :POKEBALL,
      BifrostCapture::LiveAim.session[:balls][0][0]
    BifrostCapture::LiveAim.close
    assert_equal :POKEBALL,$PokemonGlobal.bifrost_last_ball
  end

  def test_party_mode_and_member_survive_reopening
    party=Array.new(2) do
      mon=Object.new
      def mon.able?; true; end
      mon
    end
    $player.party=party
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::JUMPDOWN=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::JUMPDOWN=>true})
    BifrostCapture::LiveAim.update
    assert_equal :battle,BifrostCapture::LiveAim.session[:mode]
    Input.configure({Input::JUMPUP=>true},{})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::JUMPDOWN=>true})
    BifrostCapture::LiveAim.update
    assert_equal 1,BifrostCapture::LiveAim.session[:party_index]
    BifrostCapture::LiveAim.close
    assert_equal "battle",$PokemonGlobal.bifrost_last_mode
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    assert_equal :battle,BifrostCapture::LiveAim.session[:mode]
    assert_equal 1,BifrostCapture::LiveAim.session[:party_index]
  end

  def test_c_and_x_are_contextual_and_do_not_activate_vanilla_map_actions
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::USE=>true})
    $scene.update_input
    assert_nil $scene.map_input_count
    Input.configure({Input::JUMPUP=>true},{Input::BACK=>true})
    $scene.update_input
    assert_nil $scene.map_input_count
  end

  def test_use_remains_consumed_even_when_aim_closes_before_scene_update
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::USE=>true})
    BifrostCapture::LiveAim.update
    refute BifrostCapture::LiveAim.active?
    $scene.update_input
    assert_nil $scene.map_input_count
  end

  def test_back_remains_consumed_even_when_aim_closes_before_scene_update
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::BACK=>true})
    BifrostCapture::LiveAim.update
    refute BifrostCapture::LiveAim.active?
    $scene.update_input
    assert_nil $scene.map_input_count
  end

  def test_capture_animations_do_not_own_graphics_or_input_update_loops
    root=File.expand_path(
      "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture",__dir__)
    %w[005_ThrowExperience.rb 007_CaptureFeedback.rb 008_LiveGamefeel.rb].each do |name|
      code=File.read(File.join(root,name))
      refute_match(/^\s*Graphics\.update\b/,code,"blocking graphics loop in #{name}")
      refute_match(/^\s*Input\.update\b/,code,"blocking input loop in #{name}")
    end
  end

  def test_projectile_uses_world_viewport_with_character_depth
    vp,owned=BifrostCapture::Motion.map_viewport
    assert_same Spriteset_Map.viewport,vp
    refute owned
    actor=Struct.new(:screen_z).new(288)
    assert_equal 288,BifrostCapture::Motion.depth_for(actor)
    path=File.expand_path(
      "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/008_LiveGamefeel.rb",__dir__)
    source=File.read(path)
    refute_match(/vp\.z\s*=\s*99999\d/,source)
    assert_includes source,"ball.oy = ball.bitmap.height"
  end

  def test_opening_bag_clears_aim_and_inflight_world_sprites
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    assert BifrostCapture::LiveAim.active?
    BifrostCapture::Motion.instance_variable_set(:@flight,
      { :sprites=>[], :vp=>nil, :owns_vp=>false })
    assert BifrostCapture::Motion.busy?
    $scene.call_menu
    assert $scene.menu_opened
    refute BifrostCapture::LiveAim.active?
    refute BifrostCapture::Motion.busy?
  end

  def test_cancel_aim_is_immediate
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::BACK=>true})
    BifrostCapture::LiveAim.update
    refute BifrostCapture::LiveAim.active?
  end
end
