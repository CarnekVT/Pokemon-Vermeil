# frozen_string_literal: true
# Maximum alert remains locked until a real item is consumed.
require "minitest/autorun"
def _INTL(msg,*args); msg.gsub(/\{(\d+)\}/) { args[$1.to_i-1].to_s }; end
module EventHandlers
  def self.add(*); end
end
class Scene_Map; end
module BifrostCapture
  class << self
    attr_accessor :reported
    def options(*); @cfg; end
    def setup(cfg); @cfg=cfg; end
    def eligible_event?(event); !!event; end
    def event_spec(event); [:PIDGEY,5,0]; end
    def notice(*); end
    def temperament_for(*); :neutral; end
    def bait_item?(item); [:ORANBERRY,:HONEY].include?(item); end
    def chasing?(*); false; end
    def fleeing?(*); false; end
    def cancel_escape_reaction(*); end
    def cancel_pending_attack(*); end
  end
  module Feedback
    def self.publish(*args); @last=args; end
    def self.last; @last; end
  end
end
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/012_GamefeelPressure"

class BifrostPressureTest < Minitest::Test
  CFG={
    "pressure_enabled"=>"1", "pressure_miss"=>"40",
    "pressure_breakout"=>"40", "pressure_repeat"=>"0",
    "pressure_front"=>"14", "pressure_back"=>"8",
    "pressure_alert_threshold"=>"35", "pressure_block_threshold"=>"80",
    "pressure_decay_frames"=>"6", "pressure_escape_frames"=>"180"
  }.freeze

  class Bag
    def initialize; @inventory={:ORANBERRY=>2,:HONEY=>1}; end
    def quantity(item); @inventory[item] || 0; end
    def remove(item,n)
      return false if quantity(item)<n
      @inventory[item]-=n
      true
    end
  end

  def setup
    @event=Object.new
    @event.define_singleton_method(:id) { 7 }
    $game_map=Struct.new(:events,:map_id).new({7=>@event},1)
    $game_player=Object.new
    $scene=Scene_Map.new
    $bag=Bag.new
    BifrostCapture.setup(CFG)
    BifrostCapture::Pressure.reset
  end
  def pressure; BifrostCapture::Pressure; end

  def test_alert_stays_locked_after_long_period_without_bait
    pressure.add(@event,:miss,CFG)
    assert_equal 40,pressure.value(@event)
    refute pressure.locked?(@event,CFG)
    pressure.add(@event,:breakout,CFG)
    assert_equal 80,pressure.value(@event)
    assert pressure.locked?(@event,CFG)
    600.times { pressure.update }
    assert_equal 80,pressure.value(@event)
    assert pressure.locked?(@event,CFG)
  end

  def test_berry_consumption_is_the_only_nonbattle_unlock
    2.times { pressure.add(@event,:miss,CFG) }
    assert pressure.locked?(@event,CFG)
    assert_equal 2,$bag.quantity(:ORANBERRY)
    assert pressure.calm_with_bait(@event,:ORANBERRY,CFG)
    refute pressure.locked?(@event,CFG)
    assert_equal 0,pressure.value(@event)
    assert_equal 1,$bag.quantity(:ORANBERRY)
    assert_equal :calmed,BifrostCapture::Feedback.last[0]
  end

  def test_invalid_item_cannot_clear_alert
    2.times { pressure.add(@event,:miss,CFG) }
    refute pressure.calm_with_bait(@event,:POKEBALL,CFG)
    assert pressure.locked?(@event,CFG)
  end

  def test_completed_battle_clears_state_for_removed_target
    2.times { pressure.add(@event,:miss,CFG) }
    assert pressure.locked?(@event,CFG)
    pressure.clear_success(@event)
    refute pressure.locked?(@event,CFG)
  end
end
