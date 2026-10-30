# frozen_string_literal: true
# Headless regression for non-modal left slide, queue and result visibility.
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
module BifrostCapture
  def self.options(*)
    {"feedback_enabled"=>"1", "feedback_enter_frames"=>"12",
     "feedback_hold_frames"=>"60","feedback_exit_frames"=>"14",
     "feedback_queue_limit"=>"4"}
  end
end
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/007_CaptureFeedback"

class MockToastBitmap
  def width; 280; end
  def disposed?; false; end
  def dispose; end
end
class MockToast
  attr_accessor :x,:y,:opacity
  def initialize; @x=-288; @y=0; @opacity=0; end
  def bitmap; @bitmap ||= MockToastBitmap.new; end
  def disposed?; false; end
  def dispose; end
end
module BifrostCapture::Feedback
  def self.redraw
    @toast ||= MockToast.new
  end
end
class BifrostFeedbackTest < Minitest::Test
  def setup
    $scene=Scene_Map.new
    BifrostCapture::Feedback.reset
  end

  def test_left_slide_is_progressive_and_fades_out
    feedback=BifrostCapture::Feedback
    feedback.publish(:caught,:PIKACHU,"Equipo")
    toast=feedback.instance_variable_get(:@toast)
    assert_equal(-288,toast.x)
    feedback.update
    assert_operator toast.x,:>,-288
    assert_operator toast.x,:<,12
    assert_operator toast.opacity,:<,255
    11.times { feedback.update }
    assert_in_delta 12,toast.x,0.01
    assert_equal 255,toast.opacity
    62.times { feedback.update }
    assert_operator toast.x,:<,12
    assert_operator toast.opacity,:<,255
  end

  def test_results_wait_in_order_and_last_result_remains_visible
    feedback=BifrostCapture::Feedback
    feedback.publish(:caught,:PIKACHU,"Equipo")
    feedback.publish(:breakout,:RAIKOU,"Se liberó")
    assert_equal :breakout,feedback.last_result[:kind]
    assert_equal :caught,feedback.instance_variable_get(:@active)[:kind]
    assert_equal 1,feedback.instance_variable_get(:@queue).length
    87.times { feedback.update }
    assert_equal :breakout,feedback.instance_variable_get(:@active)[:kind]
    assert_equal 0,feedback.instance_variable_get(:@queue).length
  end
end
