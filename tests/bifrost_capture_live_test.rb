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
end
module Input
  AUX2=:aux2; AUX1=:aux1; ACTION=:action; SPECIAL=:special
  JUMPUP=:jumpup; JUMPDOWN=:jumpdown; F9=:f9
  BACK=:back; USE=:use; MOUSELEFT=:mouseleft
  @pressed={};@triggered={}
  def self.press?(key); !!@pressed[key]; end
  def self.trigger?(key); !!@triggered[key]; end
  def self.configure(pressed={},triggered={})
    @pressed=pressed;@triggered=triggered
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
    attr_accessor :result
    def options(*)
      {"access_mode"=>"always","control_mode"=>"hold","aim_chain"=>"0",
       "aim_mouse"=>"0","capture_enabled"=>"1","battle_enabled"=>"1",
       "hotkey"=>"jumpup","ball_key"=>"jumpdown",
       "mode_key"=>"none","target_key"=>"none",
       "ball_hold_mode_frames"=>"3","line_of_sight"=>"0"}
    end
    def hotkey; Input::JUMPUP; end
    def input_action(name)
      {"use"=>Input::USE,"back"=>Input::BACK,
       "jumpup"=>Input::JUMPUP,"jumpdown"=>Input::JUMPDOWN}[name]
    end
    def capture_action(cfg,field)
      {"jumpup"=>Input::JUMPUP,"jumpdown"=>Input::JUMPDOWN}[cfg[field]]
    end
    def aim_allowed?; true; end
    def ball_choices; [[:POKEBALL,10],[:GREATBALL,7]]; end
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
    Input.configure
    BifrostCapture.result=nil
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

  def test_s_long_hold_switches_pokemon_mode_and_preserves_d_ready_menu
    able_mon=Object.new
    def able_mon.able?; true; end
    $player.party=[able_mon]
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    4.times do
      Input.configure({Input::JUMPUP=>true,Input::JUMPDOWN=>true},{})
      BifrostCapture::LiveAim.update
    end
    assert_equal :battle,BifrostCapture::LiveAim.session[:mode]
    Input.configure({Input::JUMPUP=>true},{Input::SPECIAL=>true})
    BifrostCapture::LiveAim.update
    assert_equal :battle,BifrostCapture::LiveAim.session[:mode]
    $scene.update_input
    assert_equal 1,$scene.map_input_count
    refute BifrostCapture::LiveAim.active?
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

  def test_cancel_aim_is_immediate
    Input.configure({Input::JUMPUP=>true},{Input::JUMPUP=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::JUMPUP=>true},{Input::BACK=>true})
    BifrostCapture::LiveAim.update
    refute BifrostCapture::LiveAim.active?
  end
end
