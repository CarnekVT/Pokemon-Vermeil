# frozen_string_literal: true
# Run: ruby tests/bss_reference_visual_regression_test.rb
# Stub-only checks: compile edited Ruby files and exercise the BSS-native
# Animated Pokemon visibility state. NOT a substitute for an in-game render.
require "ripper"

ROOT=File.expand_path("..",__dir__)
BSS=File.join(ROOT,"LA BASE DE SKY","Plugins","[CARNEK] Battle Scene Studio Runtime")
INPUT=File.join(ROOT,"LA BASE DE SKY","Plugins","[VERMEIL] Input Studio","001_Core.rb")
TARGETS=[
  INPUT,
  File.join(BSS,"10_EBDX_Source","005_Faithful_EBDX_Room.rb"),
  File.join(BSS,"99_Hotfix","044_Cinematic_Camera_Director.rb"),
  File.join(BSS,"99_Hotfix","050_NDS_Intro_Camera_Handoff.rb"),
  File.join(BSS,"99_Hotfix","052_Battler_Visibility_and_Cinematic_HUD.rb"),
  File.join(BSS,"99_Hotfix","998_BSS_Review_Fixes.rb")
]
def assert(message,condition)
  raise "FAIL: #{message}" unless condition
end
TARGETS.each do |path|
  assert("Ruby source exists: #{path}",File.file?(path))
  assert("Ruby syntax parses: #{path}",!Ripper.sexp(File.read(path)).nil?)
end

input=File.read(INPUT)
review=File.read(TARGETS[-1])
cinema=File.read(TARGETS[2])
intro=File.read(TARGETS[3])
assert("battle context wins over map scene",input.include?("$game_temp.in_battle"))
assert("only one camera module is prepended",!review.include?("Battle::Scene.prepend(BSSVideoSceneCamera)"))
assert("review has no duplicate formation writer",!review.include?("Battle::Scene.prepend(BSSVideoFormationMetrics)"))
assert("cinematic return does not poll Input",!cinema.match?(/Graphics\.update\s*\n\s*Input\.update/))
assert("NDS reveal uses EBDX screenshot",intro.include?("Graphics.snap_to_bitmap"))
assert("NDS wild handoff keeps intro cry",intro.include?("Animation::Intro2.new"))

module BSS064
  def self.log(*); end
end
class Battle
  class Scene
    def bss070_ebdx_active?; true; end
    def bss070_ebdx_apply_world_alignment; true; end
  end
end
require File.join(BSS,"99_Hotfix","052_Battler_Visibility_and_Cinematic_HUD")

class SpriteStub
  attr_accessor :opacity,:vanishMode,:substitute
  attr_reader :visible
  def initialize
    @visible=false
    @spriteVisible=false
    @opacity=0
    @vanishMode=1
    @substitute=false
  end
  def disposed?; false; end
  def visible=(value)
    @spriteVisible=value unless @updating
    @visible=value
  end
  def update
    @updating=true
    self.visible=@spriteVisible
    @updating=false
  end
end
class BattlerStub
  attr_reader :index,:pokemon
  attr_accessor :faint,:semi
  def initialize(index)
    @index=index;@pokemon=Object.new;@faint=false;@semi=false
  end
  def fainted?;@faint;end
  def semiInvulnerable?;@semi;end
end

scene=Battle::Scene.new
bat=BattlerStub.new(1)
mon=SpriteStub.new
shadow=SpriteStub.new
scene.instance_variable_set(:@battle,Struct.new(:battlers).new([nil,bat]))
scene.instance_variable_set(:@sprites,{"pokemon_1"=>mon,"shadow_1"=>shadow})
scene.bss_recover_active_battlers_after_sendout([1])
assert("post-sendout resets the old vanish state",mon.vanishMode==0)
assert("post-sendout makes the second trainer Pokemon visible",mon.visible && mon.opacity==255)
mon.update
assert("native animated update keeps the visibility correction",mon.visible)
scene.instance_variable_set(:@bss_dialogue_revealed,{1=>bat.pokemon.object_id})
mon.visible=false;mon.opacity=0;mon.vanishMode=1
scene.bss_dialogue_restore_revealed
assert("scripted dialogue restores the same living Pokemon",mon.visible && mon.opacity==255 && mon.vanishMode==0)
mon.substitute=true;mon.visible=false
scene.bss_recover_active_battlers_after_sendout([1])
assert("substitute presentation is never forcibly revealed",!mon.visible)
mon.substitute=false
bat.semi=true
scene.bss_recover_active_battlers_after_sendout([1])
assert("semi-invulnerable Pokemon stays intentionally hidden",!mon.visible)
puts "BSS source and visibility regression contracts PASS (no rendering test)"
