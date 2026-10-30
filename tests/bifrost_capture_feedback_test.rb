# frozen_string_literal: true
# Stacked notifications: simultaneous entrance, independent timers, overflow.
require "minitest/autorun"
module EventHandlers
  def self.add(*); end
end
module Graphics
  def self.width; 640; end
  def self.height; 480; end
end
class Scene_Map; end
class Color
  def initialize(*); end
end
class Viewport
  attr_accessor :z
  def initialize(*); @dead=false; end
  def disposed?; @dead; end
  def dispose; @dead=true; end
end
class Bitmap
  attr_reader :width,:height
  def initialize(w,h); @width=w;@height=h;@dead=false; end
  def disposed?; @dead; end
  def dispose; @dead=true; end
end
class Sprite
  attr_accessor :x,:y,:opacity,:bitmap
  def initialize(_viewport); @x=0;@y=0;@opacity=0;@dead=false; end
  def disposed?; @dead; end
  def dispose; @dead=true; end
end
module BifrostCapture
  def self.options(*)
    {"feedback_enabled"=>"1", "feedback_enter_frames"=>"12",
     "feedback_hold_frames"=>"60", "feedback_exit_frames"=>"14",
     "feedback_queue_limit"=>"5", "feedback_stack_count"=>"3"}
  end
end
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/007_CaptureFeedback"
# Visual shape drawing is covered by in-game QA; only animate timing here.
module BifrostCapture::Feedback
  def self.redraw(*); end
end
class BifrostFeedbackTest < Minitest::Test
  def setup
    $scene=Scene_Map.new
    BifrostCapture::Feedback.reset
  end
  def feedback; BifrostCapture::Feedback; end
  def visible; feedback.instance_variable_get(:@visible); end
  def queue; feedback.instance_variable_get(:@queue); end

  def test_first_three_notices_are_simultaneous_and_vertically_stacked
    feedback.publish(:caught,:PIKACHU,"Equipo")
    feedback.publish(:breakout,:EEVEE,"Se liberó")
    feedback.publish(:pressure,:LUCARIO,"Alerta")
    assert_equal 3,visible.length
    assert_equal 0,queue.length
    feedback.update
    assert_equal 3,visible.length
    sprites=visible.map { |state| state[:sprite] }
    assert_equal 3,sprites.uniq.length
    assert_equal [73,73],sprites.each_cons(2).map { |a,b| b.y-a.y }
    sprites.each do |sprite|
      assert_operator sprite.x,:>,-sprite.bitmap.width-8
      assert_operator sprite.opacity,:>,0
      assert_operator sprite.opacity,:<,255
    end
  end

  def test_fourth_notice_waits_only_if_all_three_slots_are_taken
    3.times { |n| feedback.publish(:miss,:"MON#{n}",n.to_s) }
    fourth=feedback.publish(:max_alert,:PIDGEY,"Solo combate")
    assert_equal 3,visible.length
    assert_equal 1,queue.length
    90.times { feedback.update }
    assert_includes visible, fourth
    assert_equal 0,queue.length
  end

  def test_single_notice_still_enters_and_exits_from_left
    feedback.publish(:caught,:PIKACHU,"Equipo")
    sprite=visible.first[:sprite]
    assert_operator sprite.x,:<,0
    feedback.update
    assert_operator sprite.x,:<,12
    11.times { feedback.update }
    assert_in_delta 12,sprite.x,0.01
    assert_equal 255,sprite.opacity
    62.times { feedback.update }
    assert_operator sprite.x,:<,12
    assert_operator sprite.opacity,:<,255
  end

  def test_identical_blocked_notice_does_not_spam_all_slots
    5.times { feedback.publish(:blocked,:PIKACHU,"Alerta maxima") }
    assert_equal 1,visible.length
    assert_equal 0,queue.length
  end
end
