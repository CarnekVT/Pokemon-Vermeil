# frozen_string_literal: true
# Regression: SleepAnimations cannot alias a prepended UmbraVeil frame hook.
require "minitest/autorun"

module Battle
  class Scene
    attr_reader :trace
    def initialize; @trace=[]; end
    def pbFrameUpdate(*_args); @trace << :engine; end
    def _carnek_sleep_ensure_bitmaps; @trace << :sleep; end
  end
end

module UmbraVeil
  module SceneHooks
    def pbFrameUpdate(*args)
      @trace << :umbra_enter
      result=super
      @trace << :umbra_exit
      result
    end
  end
end
Battle::Scene.prepend(UmbraVeil::SceneHooks)

sleep_file=File.expand_path(
  "../LA BASE DE SKY/Plugins/Carnek Project Settings/patches/040_SleepAnimations.rb",
  __dir__
)
source=File.read(sleep_file)
raise "legacy recursive pbFrameUpdate alias found" if
  source.include?("alias _carnek_sleep_orig_pbFrameUpdate")
start=source.index("module CarnekSleepFrameUpdate\n")
raise "safe prepend frame hook missing" unless start
eval(source[start..-1], TOPLEVEL_BINDING, sleep_file, source[0...start].count("\n")+1)

class BifrostCaptureBattlePatchTest < Minitest::Test
  def test_sleep_fog_and_base_frame_hooks_run_once
    scene=Battle::Scene.new
    scene.pbFrameUpdate
    assert_equal [:umbra_enter,:engine,:umbra_exit,:sleep],scene.trace
  end
end
