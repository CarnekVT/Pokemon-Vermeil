# frozen_string_literal: true
# Headless input regression. Normal map updates must never be blocked by aim.
require "minitest/autorun"
module EventHandlers
  def self.add(*); end
end
class Scene_Map; end
module Input
  AUX2=:aux2; AUX1=:aux1; ACTION=:action; SPECIAL=:special
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
       "aim_mouse"=>"0","capture_enabled"=>"1","battle_enabled"=>"0",
       "line_of_sight"=>"0"}
    end
    def hotkey; Input::AUX2; end
    def aim_allowed?; true; end
    def ball_choices; [[:POKEBALL,10]]; end
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
    Input.configure({Input::AUX2=>true},{Input::AUX2=>true})
    BifrostCapture::LiveAim.update
    assert BifrostCapture::LiveAim.active?
    assert $game_player.moving?
    Input.configure({Input::AUX2=>true},{})
    BifrostCapture::LiveAim.update
    assert BifrostCapture::LiveAim.active?
  end
  def test_releasing_w_without_target_reports_blocked_without_locking_map
    Input.configure({Input::AUX2=>true},{Input::AUX2=>true})
    BifrostCapture::LiveAim.update
    Input.configure({}, {})
    BifrostCapture::LiveAim.update
    assert BifrostCapture::LiveAim.active?
    BifrostCapture::LiveAim.update
    refute BifrostCapture::LiveAim.active?
    assert_equal :blocked,BifrostCapture.result[0]
    assert $game_player.moving?
  end
  def test_cancel_aim_is_immediate
    Input.configure({Input::AUX2=>true},{Input::AUX2=>true})
    BifrostCapture::LiveAim.update
    Input.configure({Input::AUX2=>true},{Input::BACK=>true})
    BifrostCapture::LiveAim.update
    refute BifrostCapture::LiveAim.active?
  end
end
